# Session 21 — 2026-11-23

**Goal (one thing):** Ship a v2 of the API next to v1, test it on its own URL, give it 20% of traffic as a canary, and prove the split with KQL
**Time:** mid-afternoon, about 2:25 to 2:55 PM
**Recording:** webcam ✅ · screen ✅

## What I did
- Replaced `containerapps.tf`: multiple-revision mode, revision suffix taken from the image tag, and a lifecycle rule so Terraform leaves traffic weights to the CLI
- `terraform validate`: success. Plan 0 to add, 1 to change, 0 to destroy; apply created revision `ca-rag-api--v1`
- Pinned 100% of traffic to `ca-rag-api--v1` by name, so the next revision would start at 0%
- Built `rag-api:v2` with ACR Tasks (v2 adds structured JSON logs: version, top source, tokens, milliseconds)
- Set `api_image_tag = "v2"` in `today.auto.tfvars`; plan 0/1/0 (image v1 to v2); apply created `ca-rag-api--v2` at 0% traffic
- Tested v2 on its own revision URL before any user traffic ✅
- Canary split 80/20 with `az containerapp ingress traffic set`; 30 calls to the main URL answered 18 v1 / 12 v2, and the portal showed 80/20 ✅
- KQL in Log Analytics:
  - Query 1 (console logs, requests per revision): v1 18, v2 13 ✅
  - Query 2 (parse_json on v2's log lines): both test questions with version v2, top sources session-16.md and session-05.md, 767 and 897 tokens, 2.3 and 4.1 seconds ✅
  - Query 3 (system logs): v2 created, image pulled, replica scheduled, then both revisions scaling from 1 to 0 once traffic stopped ✅
- Promoted v2 to 100% (`latest=100`) and deactivated v1
- Cost check: v2 at 100, v1 inactive

## What broke
- Step 4's first `terraform plan` showed no changes, because I hadn't replaced `today.auto.tfvars` with the v2 version yet. Updated it, saved, and the plan showed the expected 1 change
- Pasted the first KQL query into the portal's new Observability Agent chat instead of the query editor. Turned the Agent toggle off to get the KQL editor back
- Not broken, but worth knowing: the system logs show "Probe of StartUp failed" and "ScaledObjectCheckFailed" during cold start. The startup probe fires before uvicorn is listening, and the scaler checks before the revision exists. Both revisions answered fine afterwards

## What I learned
- In multiple-revision mode every revision gets its own URL, so a new version can be tested with zero user traffic
- Pin traffic to a revision by name before deploying the next one; otherwise traffic follows "latest" and the new revision gets 100% immediately
- Traffic splitting is random per request, so a 30-call sample can lean away from the weights; the logs are the better count
- Rollback is one command pointing traffic back at the old revision, with no rebuild or redeploy
- Container Apps logs land in Log Analytics in two tables: ContainerAppConsoleLogs_CL (what my code prints) and ContainerAppSystemLogs_CL (what the platform does). The system logs are the first place to look when a revision won't start
- Writing JSON log lines lets KQL parse them with parse_json and report per-request fields

## Azure cost check
- Same 7 resources as Session 20. Only the registry bills while idle (about a cent an hour); both revisions scaled to zero
- `terraform destroy` run: no (end-of-day destroy)
- Cost: about 1 to 2 cents (registry time, one ACR build, a few gpt-5-mini answers, a few KB of logs; list-price estimate)

## Next session's goal
- Add a keyless Service Bus queue and a worker with no public endpoint that scales 0 to 3 to 0 on queue length, and see a bad message land in the dead-letter queue
