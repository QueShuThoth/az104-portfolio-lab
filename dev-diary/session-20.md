# Session 20 — 2026-11-23

**Goal (one thing):** Deploy the v1 API image to Azure Container Apps with a managed identity, no keys, a public URL and scale to zero
**Time:** early afternoon, about 1:40 to 2:20 PM (recording paused during apply)
**Recording:** webcam ✅ · screen ✅

## What I did
- Registered the `Microsoft.App` and `Microsoft.OperationalInsights` resource providers
- Added `containerapps.tf`: a user-assigned managed identity (`id-rag-app-eus`) with three roles (AcrPull on the registry, OpenAI User on Foundry, Cosmos DB data role), a Container Apps environment (workload profiles, Consumption) and the `ca-rag-api` app pulling `rag-api:v1` with that identity
- `terraform validate`: success. `terraform plan`: 6 to add. `terraform apply`: about 5 minutes
- `Invoke-RestMethod "$url/"` woke the app from zero replicas: `app: dev-diary-rag`, `version: v1` ✅
- Asked from the cloud: "Which session added the Azure Firewall, and what did it need?" Answer: Session 12, its own AzureFirewallManagementSubnet (/26), a second public IP and a Firewall Policy, with session-12.md as the top sources ✅
- Opened `/docs` on the Azure URL in the browser
- Listed replicas (one running) and read the Log stream in the portal
- Cost check: 7 resources in rg-rag-app-eus

## What broke
- Nothing
- Skipped the `az containerapp show` no-secrets check on camera, and didn't rerun the replica list after 5 minutes to show zero. Both are worth a quick look in Session 21

## What I learned
- A user-assigned managed identity can be shared by every app in the project (API now, worker and function later) and holds all the role assignments, so nothing stores a key or password
- The registry pull uses the same identity (AcrPull), which is why the registry's admin user stays off
- Container Apps scales to zero replicas when idle; the first request after that takes 10 to 30 seconds to start one
- The Consumption profile has a free monthly grant, so an idle or lightly used app costs about nothing

## Azure cost check
- 7 resources: Log Analytics, Foundry, Cosmos DB, registry, identity, Container Apps environment, the app. Only the registry bills while idle (about a cent an hour)
- `terraform destroy` run: no (end-of-day destroy)
- Cost: about 1 to 2 cents (registry time and a few KB of logs; list-price estimate)

## Next session's goal
- Build a v2 image, run it alongside v1 as a second revision, split traffic 80/20 and query the logs with KQL
