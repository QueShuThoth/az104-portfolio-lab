# Session 22 — 2026-11-23

**Goal (one thing):** Add a keyless Service Bus queue and a worker with no public endpoint that scales on queue length, and watch a bad message land in the dead-letter queue
**Time:** mid-afternoon, about 3:00 to 3:40 PM
**Recording:** webcam ✅ · screen ✅

## What I did
- Created the `worker` folder (`worker.py`, `requirements.txt`, `Dockerfile`, `.dockerignore`) plus `messaging.tf` and `send_test.py`; added `enable_messaging = true` to `today.auto.tfvars`
- `terraform validate`: success
- Built `rag-worker:v1` with ACR Tasks before the apply, because the worker app needs its image to exist
- `terraform plan`: 6 to add (namespace, `ingest` queue, my two queue roles, the app identity's queue role, the worker app). Applied
- Part 1: Service Bus namespace is Standard with local auth (keys) disabled; worker has `ingress: null`, min 0 and max 3 replicas ✅
- Part 3: sent 20 test messages; the worker scaled from 0 to 3 replicas and the queue drained to 0 ✅
- Part 4: worker logs show `status: ok`, 1 chunk per test note (each replica only logs the notes it handled) ✅
- Part 5: sent a message that isn't JSON. After 5 deliveries it moved to the dead-letter queue; Service Bus Explorer (with Microsoft Entra auth) showed it with delivery count 5 and reason MaxDeliveryCountExceeded ✅
- Part 6: `send_test.py cleanup` deleted the 20 test chunks from Cosmos so they don't show up in /ask answers ✅
- Cost check: 9 resources in rg-rag-app-eus

## What broke
- The replica-watch loop failed with "-o was unexpected at this time". On Windows, `az` runs through a batch file that chokes on the parentheses in `--query "length(@)"`. Fixed by listing names with `--query "[].name"` and counting with PowerShell's `.Count`
- Because of that, the first 20 messages were processed before I was watching; I sent 20 again with the fixed loop
- `az containerapp logs show` said "Could not find a replica" once the worker was back at zero. Not a failure: there's nothing to read logs from at zero replicas
- Didn't film the scale back down to 0 replicas

## What I learned
- A Container App with no ingress can't be called by anyone; it only reacts to the queue
- KEDA scales on queue length (one replica per 5 waiting messages here, up to 3), checking every 30 seconds with the managed identity, and scales back to zero about 5 minutes after the queue empties
- Abandoned messages are redelivered; after the max delivery count (5) Service Bus moves them to the dead-letter queue instead of retrying forever
- With local auth disabled, even the portal's Service Bus Explorer has to switch to Microsoft Entra authentication, and my Data Receiver role is what lets me peek
- Several replicas share a queue, so each replica's logs show only the messages it handled

## Azure cost check
- 9 resources: the 7 from Session 20 plus the Service Bus namespace and the worker app. Billing while idle: registry (about 1 cent an hour) and Service Bus Standard (about 1.4 cents an hour)
- `terraform destroy` run: no (end-of-day destroy)
- Cost: about 2 to 4 cents (Service Bus hours, one ACR build, about 40 embeddings; list-price estimate)

## Next session's goal
- Upload a Markdown file to Blob Storage and let Event Grid feed the queue, so documents ingest themselves
