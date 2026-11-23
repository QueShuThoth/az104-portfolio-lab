"""List the per-document summaries the Session 24 function wrote.

Usage:
  python summaries.py            -> every summary, newest first
  python summaries.py session-23 -> only sources that contain "session-23"

Needs $env:COSMOS_ENDPOINT. Uses your az login (your Cosmos data role covers ragfeed too).
"""
import os
import sys

from azure.cosmos import CosmosClient
from azure.identity import DefaultAzureCredential

summaries = (
    CosmosClient(os.environ["COSMOS_ENDPOINT"], credential=DefaultAzureCredential())
    .get_database_client("ragfeed")
    .get_container_client("summaries")
)

query = "SELECT * FROM c"
params = []
if len(sys.argv) > 1:
    query += " WHERE CONTAINS(c.source, @text)"
    params = [{"name": "@text", "value": sys.argv[1]}]

items = list(summaries.query_items(query, parameters=params, enable_cross_partition_query=True))
items.sort(key=lambda i: i["updated_utc"], reverse=True)

for i in items:
    print(f"{i['source']}  ({i['chunk_count']} chunks, {i['tokens']} tokens, updated {i['updated_utc']} UTC)")
    print(f"  {i['summary']}\n")
print(f"{len(items)} summaries")
