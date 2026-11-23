# Session 16 — 2026-11-23

**Goal (one thing):** Prove keyless model calls, add a free-tier Cosmos DB account with keys off, and run a first vector search, then destroy
**Time:** late morning, wrapped up about 11:15 AM (recording paused during create and destroy)
**Recording:** webcam ✅ · screen ✅

## What I did
- Checks: Python 3.14 ✅, no existing Cosmos DB account ✅
- Added `cosmos.tf` (Cosmos DB for NoSQL account with free tier on and keys off, database ragdb, Cosmos DB Built-in Data Contributor role for me), `vector-policy.json`, `index-policy.json` and `vector_test.py` to rag-app
- `terraform validate`, then `terraform plan`: 10 to add
- `terraform apply`: Cosmos took about 5 to 10 minutes
- Keyless model calls with my Entra ID token: gpt-5-mini answered in one sentence, text-embedding-3-small returned 1536 numbers ✅
- Cosmos check: free tier and keys off both returned true ✅
- Made the `chunks` container with the Azure CLI and the two JSON files; vector policy showed /embedding, float32, 1536, cosine ✅
- Installed openai, azure-identity and azure-cosmos, set both endpoints, ran `vector_test.py`: stored 3 notes
- Vector search: "How do I link my lab to an on-premises site?" put note-2 (VPN gateway) on top at 0.415, ahead of the firewall note at 0.244 ✅
- `terraform destroy`, then `az resource list`: only Network Watchers left ✅

## What broke
- First `terraform plan` ran from the repo top folder after a restart and showed the network lab's 22. Moved into rag-app and it showed 10
- The subscription ID showed in apply output; blur it in the edit
- Nothing else; no 401/403 from the role assignments

## What I learned
- The Terraform azurerm provider can't set a Cosmos DB vector policy yet, so the container is made with the Azure CLI. A vector policy can't be changed after the container exists
- Vector search matches on meaning: the question never said "VPN" and still found the VPN note
- DefaultAzureCredential uses my az login for both Azure OpenAI and Cosmos DB, so no keys anywhere
- Only one free-tier Cosmos DB account is allowed per subscription

## Azure cost check
- Resources left running: none from the lab (Network Watchers are free)
- `terraform destroy` run: yes
- Cost: about $0 (free tier plus a fraction of a cent in tokens; list-price estimate)

## Next session's goal
- Back in December: keep building the RAG app
