# Session 24 — 2026-11-23

**Goal (one thing):** Deploy a Python Azure Function on the Flex Consumption plan that wakes on the Cosmos DB change feed and writes a short summary of each document, skipping the model call when nothing really changed
**Time:** late afternoon, about 4:25 to 4:52 PM
**Recording:** webcam ✅ · screen ✅

## What I did
- Registered Microsoft.Web; replaced `providers.tf` (adds the azapi provider) and `.gitignore` (adds `*.zip`); created `functions.tf`, `summaries.py` and the `function` folder (`function_app.py`, `host.json`, `requirements.txt`)
- `terraform init -upgrade` installed azure/azapi v2.14.0; `terraform validate`: success
- `terraform plan`: 8 to add (database `ragfeed` with `leases` and `summaries` containers, function storage account with Shared Key off, `app-package` container, one role assignment, Flex Consumption plan, function app). Nothing changed or destroyed. Applied: 8 added, new output `function_name = func-rag-eus-5atrz`
- Zip-deployed the `function` folder with `--build-remote true`: "Deployment was successful"
- Part 1: `az functionapp function list` shows `func-rag-eus-5atrz/summarize_documents` ✅
- Part 2: Cosmos Data Explorer shows 2 items in `ragfeed/leases`, Mode "Incremental Feed" with an Owner, so the trigger had claimed the feed ✅
- Part 3: re-uploaded `session-23-design.md`; the whole chain ran (Blob Storage, Event Grid, queue, worker, Cosmos, change feed, function). `summaries.py session-23` showed 1 summary: 6 chunks, 653 tokens, updated 22:47:05 UTC ✅
- Part 4: uploaded the same file again; the updated time stayed at 22:47:05, so the function saw the same content hash and skipped the model call ✅
- Part 5 (optional, summarize every Dev Diary entry): skipped
- Cost check: 14 resources in rg-rag-app-eus

## What broke
- Nothing on the build: plan, apply, deploy and all four checks passed first time
- Misstep: for Part 3 I clicked **Upload Item** in Cosmos Data Explorer and the file picker showed nothing, because that button only takes JSON documents. The upload belongs in the terminal (`az storage blob upload --auth-mode login`), which worked straight away

## What I learned
- Flex Consumption bills only while the function runs and scales to zero; with a monthly free grant, an idle function costs nothing
- The Cosmos DB trigger reads the change feed and keeps its place in a lease container; leases are created when it starts, so old documents aren't reprocessed (no burst of model calls on deploy)
- Identity-based connections: the function reaches Cosmos, storage and the model with the managed identity, no connection strings
- A content hash check in the function is a FinOps control: rewritten chunks with the same text don't trigger a paid model call
- `--build-remote true` installs Python packages on Linux in Azure, so Windows-built packages can't break the deploy
- Sharing one 400 RU/s database across the leases and summaries containers keeps Cosmos inside the free tier's 1,000 RU/s

## Azure cost check
- 14 resources: the 11 from Session 23 plus the function storage account, the Flex Consumption plan and the function app. Billing while idle unchanged: registry (about 1 cent an hour) and Service Bus (about 1.4 cents an hour); total about 2.5 cents an hour
- `terraform destroy` run: no (end-of-day destroy)
- Cost: under a cent (one summary call, a few embeddings, Flex Consumption inside the free grant; list-price estimate)

## Next session's goal
- Move the API's settings into App Configuration and its one secret into Key Vault, then change a setting and rotate the secret without redeploying
