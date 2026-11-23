# Session 23 — 2026-11-23

**Goal (one thing):** Let documents ingest themselves: a Markdown file uploaded to Blob Storage triggers Event Grid, which hands it to the Service Bus queue, and the worker vectorizes it, with no keys anywhere
**Time:** late afternoon, about 3:45 to 4:15 PM
**Recording:** webcam ✅ · screen ✅

## What I did
- Registered Microsoft.EventGrid on the subscription; replaced `providers.tf`; created `events.tf`, `uploads/session-23-design.md` and `uploads/not-markdown.txt`
- `terraform validate`: success
- `terraform plan`: 9 to add (storage account with Shared Key off, `docs` and `eventgrid-deadletter` containers, 4 role assignments, Event Grid system topic `egst-rag-docs`, subscription `docs-to-ingest`). Nothing changed or destroyed on the apps, the registry or Service Bus
- Apply created 8 of 9; the subscription failed (see What broke). After a one-line scope fix, apply finished: 2 added, 0 changed, 1 destroyed
- Part 1: Shared Key off, public blob access off, minimum TLS 1.2. A deliberate `--auth-mode key` call was refused ✅
- Part 2: subscription delivers with the system-assigned identity to the Service Bus queue, filter is BlobCreated + `.md` only, retry 10 attempts ✅
- Part 3: uploaded `session-23-design.md` in the portal. Watch loop showed waiting 1, then replicas 1 and waiting 0: one file, one message, one worker ✅
- Part 4: worker logs show the file ingested with status ok ✅
- Part 5: asked /ask why uploads go through a queue; the answer cited `session-23-design.md` about a minute after the upload ✅
- Part 6: uploaded `not-markdown.txt` with the CLI and my Entra sign-in; nothing reached the queue and the worker didn't wake ✅
- Cost check: 11 resources in rg-rag-app-eus

## What broke
- **First apply: the event subscription failed** with "Managed Identity Authorization Error ... does not have authorization to deliver to the deadletter endpoint". Event Grid validates its permissions the moment the subscription is created.
- **I first treated it as role propagation delay** (new role assignments can take minutes to take effect), waited about 3 minutes, and applied again. Same error. Waited 3 more minutes: same error again. Nine minutes ruled out propagation.
- **Real cause: the dead-letter role was scoped to the wrong level.** `eg_deadletter_writer` granted Storage Blob Data Contributor on the `eventgrid-deadletter` container only. Event Grid checks the dead-letter destination at the storage account level, so it never saw the role.
- **Fix:** one line in `events.tf` (line 97), scope changed from `local.deadletter_container_scope` to `azurerm_storage_account.docs[0].id`. Apply replaced the container-level assignment with an account-level one (1 destroyed, 1 added) and the subscription created on the first try (2 added total).
- The steps file's "If it breaks" section blamed this kind of error on propagation delay, which was the wrong diagnosis here.

## What I learned
- Shared Key off means no account keys and no SAS: everything (portal, CLI, Terraform, Event Grid, the worker) has to use Entra ID and RBAC roles
- An Event Grid system topic listens to one Azure resource; a subscription filters its events (event type, subject prefix and suffix) and routes them to a destination such as a Service Bus queue
- Event Grid can deliver and dead-letter with its own managed identity, so no connection strings are stored anywhere
- Filtering at the subscription means non-matching files never reach the queue, so the worker never wakes (and never bills) for them
- When a retry doesn't fix a "permission" error after a few minutes, stop waiting and check the role's scope; least-privilege scoping can be too narrow for a service's validation check

## Azure cost check
- 11 resources: the 9 from Session 22 plus the storage account and the Event Grid system topic. Billing while idle: registry (about 1 cent an hour) and Service Bus Standard (about 1.4 cents an hour); total about 2.5 cents an hour
- `terraform destroy` run: no (end-of-day destroy)
- Cost: about 1 to 2 cents (Service Bus hours, a few storage operations, a handful of embeddings and one gpt-5-mini answer; list-price estimate)

## Next session's goal
- Deploy an Azure Function on the Flex Consumption plan that reacts to the Cosmos DB change feed and writes a summary of each document
