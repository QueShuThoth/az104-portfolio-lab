"""Session 22: send test messages to the ingest queue, or clean up afterwards.

  python send_test.py 20       -> 20 good messages (short notes the worker will ingest)
  python send_test.py bad      -> 1 message that isn't JSON (ends up in the dead-letter queue)
  python send_test.py cleanup  -> delete the test notes' chunks from Cosmos

Uses your az login (Azure Service Bus Data Sender on the queue, Cosmos data role).
"""
import json
import os
import sys

from azure.cosmos import CosmosClient
from azure.identity import DefaultAzureCredential
from azure.servicebus import ServiceBusClient, ServiceBusMessage

arg = sys.argv[1] if len(sys.argv) > 1 else "20"
credential = DefaultAzureCredential()

if arg == "cleanup":
    container = (
        CosmosClient(os.environ["COSMOS_ENDPOINT"], credential=credential)
        .get_database_client("ragdb")
        .get_container_client("chunks")
    )
    items = list(container.query_items(
        "SELECT c.id, c.source FROM c WHERE STARTSWITH(c.source, 'queue-test-')",
        enable_cross_partition_query=True,
    ))
    for item in items:
        container.delete_item(item["id"], partition_key=item["source"])
    print(f"Deleted {len(items)} test chunks")
    sys.exit()

namespace = os.environ["SERVICEBUS_NAMESPACE_FQDN"]
with ServiceBusClient(namespace, credential=credential) as client, client.get_queue_sender("ingest") as sender:
    if arg == "bad":
        sender.send_messages(ServiceBusMessage("this is not json"))
        print("Sent 1 bad message")
    else:
        count = int(arg)
        sender.send_messages([
            ServiceBusMessage(json.dumps({
                "source": f"queue-test-{n:02d}.md",
                "text": f"Queue test note {n}. Sent through Service Bus and ingested by the worker.",
            }))
            for n in range(1, count + 1)
        ])
        print(f"Sent {count} messages")
