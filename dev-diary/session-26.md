# Session 26 — 2026-11-23

**Goal (one thing):** Send traces from the API, the worker and the function to one keyless Application Insights with OpenTelemetry, follow one question through every hop, and chart token use with KQL
**Time:** evening, about 5:30 to 6:35 PM
**Recording:** webcam ✅ · screen ✅ (paused during the long apply)

## What I did
- Committed and pushed Session 25 first (cc12af4)
- Created `monitoring.tf` (workspace-based Application Insights `appi-rag-eus`, local auth off, 1 GB daily cap, Monitoring Metrics Publisher role for the app identity) and `uploads/session-26-tracing.md`
- Replaced nine files: `providers.tf`, `containerapps.tf`, `messaging.tf`, `functions.tf`, `api/app.py`, `api/requirements.txt`, `worker/worker.py`, `worker/requirements.txt`, `today.auto.tfvars` (api v4, worker v2)
- `terraform validate`: success
- Built both images with ACR Tasks: `rag-api:v4` and `rag-worker:v2`, both successful
- `terraform plan` checked out; started `terraform apply`
- Stopped the apply with Ctrl+C and ran the end-of-day `terraform destroy` so nothing bills while the laptop is away

## What broke
- `azurerm_application_insights.rag` sat at "Still creating..." for over 42 minutes. Application Insights normally creates in under a minute, so this was a hang, not a slow deploy. Cause not found yet; with the laptop going in at 7 PM I stopped the apply and tore down instead of debugging
- Verify parts 1 to 7 (traffic, end-to-end transaction, Application Map, KQL for time, tokens and function logs) not run

## What I learned
- Know the normal duration of each resource; when one runs far past it, stop and investigate instead of waiting it out
- Interrupting an apply can leave a resource in Azure that isn't in Terraform state; the end-of-day steps include deleting leftovers by hand if the resource group won't delete
- Workspace-based Application Insights writes into the existing Log Analytics workspace, so the first 5 GB a month cost nothing; the daily cap is the FinOps guard rail
- Image builds come before the plan, because new revisions need their images to exist

## Azure cost check
- Ran the end-of-day `terraform destroy` on rag-app (Cosmos took about 8 minutes, Container Apps environment a few more). Lab root not up (Session 28 not reached)
- Cost: under a cent for two image builds; the whole day stays within the plan's estimate (list-price estimate)

## Next session's goal
- Dec 1: rebuild rag-app, find why Application Insights hangs on create, finish Session 26 apply and verify
