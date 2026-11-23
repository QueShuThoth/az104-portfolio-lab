"""Dev Diary ingest worker (Session 22). No ingress: it only reads the Service Bus queue.

Each message is one document to ingest. Two shapes are accepted:
  1. {"source": "note.md", "text": "..."}             <- test messages (Session 22)
  2. an Event Grid "BlobCreated" event with data.url  <- uploads to Blob Storage (Session 23)

For each document: split at "## " headings, embed the chunks, upsert them into Cosmos "chunks".
A message that fails is abandoned, so Service Bus redelivers it. After 5 tries
(max delivery count) Service Bus moves it to the dead-letter queue by itself.

No keys: DefaultAzureCredential uses the app's managed identity (AZURE_CLIENT_ID).
"""
import json
import os
import re
import time
from pathlib import PurePosixPath
from urllib.parse import unquote, urlparse

from azure.cosmos import CosmosClient
from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from azure.servicebus import ServiceBusClient
from azure.storage.blob import BlobClient
from openai import OpenAI

QUEUE = os.getenv("QUEUE_NAME", "ingest")
WORK_DELAY_SECONDS = float(os.getenv("WORK_DELAY_SECONDS", "0"))  # demo only: makes scaling visible

credential = DefaultAzureCredential()
ai = OpenAI(
    base_url=os.environ["OPENAI_ENDPOINT"] + "/openai/v1/",
    api_key=get_bearer_token_provider(credential, "https://cognitiveservices.azure.com/.default"),
    max_retries=8,
)
chunks = (
    CosmosClient(os.environ["COSMOS_ENDPOINT"], credential=credential)
    .get_database_client("ragdb")
    .get_container_client("chunks")
)


def log(**fields):
    print(json.dumps({"event": "ingest", **fields}), flush=True)


def split_doc(text):
    parts = re.split(r"^## ", text, flags=re.MULTILINE)
    out = [("Overview", parts[0].strip())] if parts[0].strip() else []
    for part in parts[1:]:
        heading, _, body = part.partition("\n")
        if body.strip():
            out.append((heading.strip(), body.strip()))
    return out


def read_message(body):
    """Return (source, text) from either message shape. Raises on anything else."""
    msg = json.loads(body)  # not JSON -> exception -> abandon -> retried -> dead-lettered
    if "text" in msg and "source" in msg:
        return msg["source"], msg["text"]
    url = msg.get("data", {}).get("url")  # Event Grid BlobCreated event
    if url:
        name = PurePosixPath(unquote(urlparse(url).path)).name
        text = BlobClient.from_blob_url(url, credential=credential).download_blob().readall().decode("utf-8")
        return name, text
    raise ValueError("message has neither text nor a blob url")


def ingest(source, text):
    stem = PurePosixPath(source).stem
    match = re.search(r"session-(\d+)", stem)
    session = int(match.group(1)) if match else None
    pieces = split_doc(text)
    if not pieces:
        raise ValueError(f"{source} is empty")
    label = f"Session {session}" if session else stem
    texts = [f"{label}. {heading}.\n{body}" for heading, body in pieces]
    vectors = ai.embeddings.create(model="text-embedding-3-small", input=texts).data
    for i, ((heading, _), t, v) in enumerate(zip(pieces, texts, vectors)):
        chunks.upsert_item({
            "id": f"{stem}-{i:02d}",
            "source": source,
            "session": session,
            "heading": heading,
            "text": t,
            "embedding": v.embedding,
        })
    return len(pieces)


def main():
    namespace = os.environ["SERVICEBUS_NAMESPACE_FQDN"]  # e.g. sb-rag-eus-xxxxx.servicebus.windows.net
    log(status="started", queue=QUEUE)
    with ServiceBusClient(namespace, credential=credential) as client:
        while True:
            with client.get_queue_receiver(QUEUE, max_wait_time=30) as receiver:
                for msg in receiver:
                    try:
                        source, text = read_message(str(msg))
                        count = ingest(source, text)
                        if WORK_DELAY_SECONDS:
                            time.sleep(WORK_DELAY_SECONDS)
                        receiver.complete_message(msg)
                        log(status="ok", source=source, chunks=count, delivery=msg.delivery_count)
                    except Exception as err:  # noqa: BLE001 - any failure = let Service Bus retry
                        receiver.abandon_message(msg)
                        log(status="failed", error=str(err)[:200], delivery=msg.delivery_count)


if __name__ == "__main__":
    main()
