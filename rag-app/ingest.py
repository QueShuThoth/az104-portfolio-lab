"""Session 17: load my Dev Diary logs into Cosmos DB as vectors.

For each dev-diary/session-NN.md file:
  1. split it into chunks at the "## " headings (What I did, What broke, ...)
  2. embed every chunk with text-embedding-3-small (one call per file)
  3. upsert each chunk into the Cosmos "chunks" container with its session number

Safe to rerun: chunk ids are fixed (session-11-02), so a rerun overwrites, never duplicates.
No keys anywhere: both services use your az login through DefaultAzureCredential.
"""
import os
import re
import sys
from pathlib import Path

from azure.cosmos import CosmosClient
from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from openai import OpenAI

# Default: the repo's dev-diary folder, one level up from rag-app
DIARY = Path(sys.argv[1]) if len(sys.argv) > 1 else Path(__file__).resolve().parent.parent / "dev-diary"

credential = DefaultAzureCredential()

ai = OpenAI(
    base_url=os.environ["OPENAI_ENDPOINT"] + "/openai/v1/",
    api_key=get_bearer_token_provider(credential, "https://cognitiveservices.azure.com/.default"),
    max_retries=8,  # the embedding deployment allows 10K tokens/min; this waits out any 429
)

container = (
    CosmosClient(os.environ["COSMOS_ENDPOINT"], credential=credential)
    .get_database_client("ragdb")
    .get_container_client("chunks")
)


def split_log(text):
    """Return (heading, body) pairs. The part before the first '## ' is the overview."""
    parts = re.split(r"^## ", text, flags=re.MULTILINE)
    chunks = [("Overview", parts[0].strip())]
    for part in parts[1:]:
        heading, _, body = part.partition("\n")
        if body.strip():
            chunks.append((heading.strip(), body.strip()))
    return chunks


files = sorted(DIARY.glob("session-*.md"))
if not files:
    sys.exit(f"No session-*.md files found in {DIARY}")

total = 0
for path in files:
    session = int(re.search(r"session-(\d+)", path.stem).group(1))
    chunks = split_log(path.read_text(encoding="utf-8"))

    # Put the session number and heading inside the text too, so the vector "knows" them
    texts = [f"Session {session}. {heading}.\n{body}" for heading, body in chunks]
    vectors = ai.embeddings.create(model="text-embedding-3-small", input=texts).data

    for i, ((heading, _), text, vec) in enumerate(zip(chunks, texts, vectors)):
        container.upsert_item({
            "id": f"{path.stem}-{i:02d}",
            "source": path.name,      # partition key: one document = one partition
            "session": session,       # used as a filter in Session 18
            "heading": heading,
            "text": text,
            "embedding": vec.embedding,
        })
    total += len(chunks)
    print(f"{path.name}: {len(chunks)} chunks")

count = list(container.query_items("SELECT VALUE COUNT(1) FROM c", enable_cross_partition_query=True))[0]
print(f"\nUpserted {total} chunks from {len(files)} files. Container now holds {count} items.")
