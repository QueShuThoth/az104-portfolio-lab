# Session 15 — 2026-11-23

**Goal (one thing):** Start the RAG chatbot: a keyless Foundry resource with a chat model and an embedding model, then destroy
**Time:** morning, off camera (OBS was updating)
**Recording:** webcam ❌ · screen ❌ (screenshots kept as proof)

## What I did
- Made a new `rag-app` folder in the repo, its own Terraform project with its own state, separate from the network lab
- Created `providers.tf`, `variables.tf`, `main.tf`, `outputs.tf` and `.gitignore` in rag-app
- `terraform init`: azurerm v4.81.0 and random v3.9.1
- `terraform apply`: 7 added (random suffix, rg-rag-app-eus, log-rag-app-eus, Foundry resource ais-rag-eus-…, gpt-5-mini and text-embedding-3-small deployments, Cognitive Services OpenAI User role for me)
- Portal check: Foundry resource (kind AIServices) showed Succeeded in East US ✅
- `terraform destroy`: 7 destroyed ✅

## What broke
- OBS wouldn't record, so the session ran off camera
- First pass skipped the PowerShell model calls; moved them to the start of Session 16 to prove on camera

## What I learned
- Every folder is its own Terraform project. A new folder needs its own `terraform init`, and separate state means destroying the chatbot never touches the hub and spokes
- `local_auth_enabled = false` turns API keys off, so only Entra ID sign-in works
- Owner alone can't call the models. Calling them needs the Cognitive Services OpenAI User role
- Global Standard deployments bill per token only; capacity is a rate limit, not a cost

## Azure cost check
- Resources left running: none from the lab (Network Watchers are free)
- `terraform destroy` run: yes
- Cost: well under a cent (list-price estimate)

## Next session's goal
- Prove the keyless model calls on camera, add a free-tier Cosmos DB account and run a first vector search
