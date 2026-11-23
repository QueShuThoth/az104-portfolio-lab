"""Session 16: embed 3 notes, store them in Cosmos DB, find the closest one to a question.
No keys anywhere: both services use your az login through DefaultAzureCredential."""
import os

from azure.cosmos import CosmosClient
from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from openai import OpenAI

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


def embed(text):
    return ai.embeddings.create(model="text-embedding-3-small", input=text).data[0].embedding


notes = {
    "note-1": "Azure Firewall Basic needs a management subnet and its own public IP.",
    "note-2": "A VPN gateway connects the hub to the simulated on-prem network over IPsec.",
    "note-3": "Cosmos DB free tier gives 1000 RU/s and 25 GB of storage free.",
}

for doc_id, text in notes.items():
    container.upsert_item({"id": doc_id, "text": text, "embedding": embed(text)})
    print("stored", doc_id)

question = "How do I link my lab to an on-premises site?"
results = container.query_items(
    query=(
        "SELECT TOP 2 c.id, c.text, VectorDistance(c.embedding, @q) AS score "
        "FROM c ORDER BY VectorDistance(c.embedding, @q)"
    ),
    parameters=[{"name": "@q", "value": embed(question)}],
    enable_cross_partition_query=True,
)

print("\nQuestion:", question)
for r in results:
    print(f"{r['score']:.3f}  {r['id']}  {r['text']}")