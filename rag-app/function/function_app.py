"""Dev Diary summarizer (Session 24). Azure Functions, Python v2 model, Flex Consumption.

Trigger: the Cosmos DB change feed on ragdb/chunks. Whenever chunks are created or changed
(by ingest.py or the queue worker), this function gets the changed items in a batch.

For each document (source) in the batch it:
  1. reads all of that document's chunks (one partition, so a cheap query)
  2. hashes their text; if the stored summary has the same hash, it stops (no model call)
  3. otherwise asks gpt-5-mini for a 2 to 3 sentence summary
  4. upserts it into ragfeed/summaries, one item per document

No keys: the trigger connects with the "COSMOS__*" settings (managed identity), and this
code uses DefaultAzureCredential, which picks up AZURE_CLIENT_ID.
"""
import hashlib
import json
import logging
import os
import re
import time
from datetime import datetime, timezone

import azure.functions as func
from azure.cosmos import CosmosClient
from azure.cosmos.exceptions import CosmosResourceNotFoundError
from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from openai import OpenAI

app = func.FunctionApp()

CHAT_MODEL = os.getenv("CHAT_MODEL", "gpt-5-mini")
MAX_INPUT_CHARS = 12000  # keeps one summary well under the 10K tokens/minute quota

SYSTEM_PROMPT = (
    "You summarize one entry of an Azure lab Dev Diary. In 2 or 3 plain sentences say what was "
    "built, what broke (if anything) and what it cost. No bullet points, no preamble."
)

_clients = {}


def clients():
    """Create the clients once per instance, on first use (not while the host is indexing)."""
    if not _clients:
        credential = DefaultAzureCredential()
        cosmos = CosmosClient(os.environ["COSMOS_ENDPOINT"], credential=credential)
        _clients["chunks"] = cosmos.get_database_client("ragdb").get_container_client("chunks")
        _clients["summaries"] = cosmos.get_database_client("ragfeed").get_container_client("summaries")
        _clients["ai"] = OpenAI(
            base_url=os.environ["OPENAI_ENDPOINT"] + "/openai/v1/",
            api_key=get_bearer_token_provider(credential, "https://cognitiveservices.azure.com/.default"),
            max_retries=8,  # back off and retry on 429 (rate limit) instead of failing
        )
    return _clients


def log(**fields):
    logging.info(json.dumps({"event": "summarize", **fields}))


def summarize(source):
    c = clients()
    start = time.time()
    items = list(c["chunks"].query_items(
        "SELECT c.id, c.text FROM c WHERE c.source = @source",
        parameters=[{"name": "@source", "value": source}],
        partition_key=source,
    ))
    if not items:
        log(source=source, status="no-chunks")
        return
    items.sort(key=lambda i: i["id"])
    full_text = "\n\n".join(i["text"] for i in items)
    content_hash = hashlib.sha256(full_text.encode("utf-8")).hexdigest()

    try:
        existing = c["summaries"].read_item(item=source, partition_key=source)
        if existing.get("content_hash") == content_hash:
            log(source=source, status="unchanged", chunks=len(items))  # FinOps: no model call
            return
    except CosmosResourceNotFoundError:
        pass

    reply = c["ai"].chat.completions.create(
        model=CHAT_MODEL,
        reasoning_effort="low",
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": full_text[:MAX_INPUT_CHARS]},
        ],
    )
    match = re.search(r"session-(\d+)", source)
    c["summaries"].upsert_item({
        "id": source,
        "source": source,
        "session": int(match.group(1)) if match else None,
        "summary": reply.choices[0].message.content.strip(),
        "chunk_count": len(items),
        "content_hash": content_hash,
        "model": CHAT_MODEL,
        "tokens": reply.usage.total_tokens,
        "updated_utc": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    })
    log(source=source, status="written", chunks=len(items), tokens=reply.usage.total_tokens,
        ms=int((time.time() - start) * 1000))


@app.cosmos_db_trigger(
    arg_name="changes",
    connection="COSMOS",                         # reads the COSMOS__* app settings
    database_name="ragdb",
    container_name="chunks",
    lease_database_name="ragfeed",
    lease_container_name="leases",
    create_lease_container_if_not_exists=False,  # an identity can't create containers; Terraform did
)
def summarize_documents(changes: func.DocumentList) -> None:
    # One document is many chunks, so a batch usually holds several chunks of the same file.
    sources = sorted({doc.to_dict().get("source") for doc in changes} - {None})
    log(status="batch", changed_chunks=len(changes), documents=len(sources))
    for source in sources:
        summarize(source)  # an error here fails the batch, and the trigger retries it
