# Session 23 design note: the upload pipeline

This note gets uploaded to Blob Storage during Session 23. If you can read it in an /ask answer, the pipeline worked.

## Flow
A Markdown file lands in the docs container of the storage account. The Event Grid system topic on that account raises a BlobCreated event. The event subscription sends it to the Service Bus ingest queue. The worker container app wakes up, downloads the blob with its managed identity, splits it at its headings, embeds each chunk and stores it in Cosmos DB.

## Why a queue in the middle
Event Grid could call the worker directly, but then the worker would need a public endpoint and would have to be awake when the event arrives. With the queue in the middle, the worker keeps no ingress, scales to zero, and messages wait safely until it starts. A file that keeps failing goes to the queue's dead-letter queue after 5 tries instead of being lost.

## Why the filter
The subscription only passes BlobCreated events from the docs container whose name ends in .md. Any other upload is dropped by Event Grid before it costs a queue message or wakes the worker.

## Security choices
Shared Key is off on the storage account, so there are no account keys or SAS tokens to leak. Event Grid delivers to the queue with its own system-assigned managed identity, which only has Azure Service Bus Data Sender on that one queue. The worker's identity only has Storage Blob Data Reader on the docs container.

## Cost
The storage account has no fixed charge. A few small files cost a fraction of a cent a month. Event Grid's first 100,000 operations each month are free.
