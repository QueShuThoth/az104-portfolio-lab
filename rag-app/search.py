"""Session 17: ask a question, get the 5 closest Dev Diary chunks back (no chat model yet).

Usage:  python search.py "What broke when I added the VPN gateway?"
"""
import os
import sys

from azure.cosmos import CosmosClient
from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from openai import OpenAI

question = " ".join(sys.argv[1:]) or "What broke when I added the VPN gateway?"

credential = DefaultAzureCredential()
ai = OpenAI(
    base_url=os.environ["OPENAI_ENDPOINT"] + "/openai/v1/",
    api_key=get_bearer_token_provider(credential, "https://cognitiveservices.azure.com/.default"),
)
container = (
    CosmosClient(os.environ["COSMOS_ENDPOINT"], credential=credential)
    .get_database_client("ragdb")
    .get_container_client("chunks")
)

q_vec = ai.embeddings.create(model="text-embedding-3-small", input=question).data[0].embedding

# TOP 5 by cosine similarity. Cosmos returns the closest first (highest score).
results = container.query_items(
    query=(
        "SELECT TOP 5 c.source, c.heading, c.text, VectorDistance(c.embedding, @q) AS score "
        "FROM c ORDER BY VectorDistance(c.embedding, @q)"
    ),
    parameters=[{"name": "@q", "value": q_vec}],
    enable_cross_partition_query=True,
)

print("Question:", question, "\n")
for r in results:
    preview = r["text"].split("\n", 1)[-1].replace("\n", " ")[:70]
    print(f"{r['score']:.3f}  {r['source']:<14} {r['heading']:<16} {preview}")
