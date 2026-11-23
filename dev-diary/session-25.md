# Session 25 — 2026-11-23

**Goal (one thing):** Stop hard-coding the API's settings: move the chat model and top-k into App Configuration and the one secret into Key Vault, read both with the managed identity, then change a setting and rotate the secret without a redeploy
**Time:** early evening, about 4:56 to 5:25 PM
**Recording:** webcam ✅ · screen ✅

## What I did
- Created `config.tf`; replaced `containerapps.tf`, `api/app.py`, `api/requirements.txt` and `today.auto.tfvars` (`api_image_tag = "v3"`); `terraform validate`: success
- Built the v3 image with ACR Tasks before the plan (`az acr build ... rag-api:v3`): successful
- `terraform plan`: 6 to add (Key Vault, App Configuration, four role assignments), 2 to change, 0 to destroy. Listed the changes with `Select-String`: `ca-rag-api` moving to v3, plus the function app. Applied: 6 added, 2 changed, new outputs `key_vault_name`, `key_vault_uri`, `appconfig_endpoint`
- Stored a generated admin key as Key Vault secret `admin-key`; set `rag:chat_model = gpt-5-mini`, `rag:top_k = 5` and `rag:admin_key` as a Key Vault reference in App Configuration (`kv list` showed 3 rows; the secret row holds only the secret's URI)
- Restarted revision `ca-rag-api--v3`: "Restart succeeded"
- Part 1: App Configuration `free` with keys off `True`; Key Vault RBAC `True`, soft delete 7 days ✅
- Part 2: `/config` showed version v3, source app-configuration, gpt-5-mini, top_k 5, admin_key_loaded True, no error ✅
- Part 3: set top-k to 3; `/ask` still returned 5 sources (settings are read once); after `/admin/reload` it returned 3. Changed in production with no new image or revision ✅
- Part 4: rotated the secret (2 versions). Old key reloaded once (picking up the new key), then got 401; the new key reloaded the config ✅
- Part 5: top-k back to 5
- Cost check: 16 resources in rg-rag-app-eus

## What broke
- Nothing: every step and check passed first time
- The plan said 2 to change where I expected 1. I listed the changes before applying: the extra one was the Session 24 function app, harmless azapi drift right after a deploy, so I applied

## What I learned
- App Configuration holds settings and Key Vault holds secrets; a Key Vault reference in App Configuration lets the app load both through one provider, with the managed identity reading each store
- Access keys off on App Configuration and RBAC mode on Key Vault mean only Entra ID identities with data roles can read them
- Reading settings once and reloading on demand keeps the app inside App Configuration Free's 1,000 requests a day (a FinOps control)
- A Key Vault reference with no version always resolves to the latest secret, so rotation is just a new version plus a reload
- Always list what a plan will change before applying when the count isn't what you expected

## Azure cost check
- 16 resources: the 14 from Session 24 plus the Key Vault and the App Configuration store. App Configuration Free and Key Vault operations add about $0. Billing while idle unchanged: registry (about 1 cent an hour) and Service Bus (about 1.4 cents an hour); total about 2.5 cents an hour
- `terraform destroy` run: no (end-of-day destroy)
- Cost: under a cent (one image build, a few questions; list-price estimate)

## Next session's goal
- Send traces from the API, the worker and the function to one keyless Application Insights with OpenTelemetry, follow one question through every hop, and chart token use with KQL
