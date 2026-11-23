# Session 17 — 2026-11-23

**Goal (one thing):** Bring the Session 15 and 16 stack back up, remake the vector container, load every Dev Diary log into it as vectors, and search my own history by meaning
**Time:** early afternoon, about 12:25 to 12:45 PM (recording paused during apply)
**Recording:** webcam ✅ · screen ✅

## What I did
- From today the project is "the AZ Lab", since the portfolio will hold more than one project
- First back-to-back session of the day: the stack stays up between sessions, with one destroy at the end of the day
- Added `ingest.py` (splits each log at its `## ` headings, embeds the chunks, upserts them with their session number) and `search.py` (TOP 5 `VectorDistance` query) to rag-app
- `terraform validate`, then `terraform plan`: 10 to add; `terraform apply` while Cosmos built
- Remade the `chunks` container with the Azure CLI, partition key now `/source` (one log per partition); check showed `/source`, `/embedding`, `1536` ✅
- `python ingest.py`: upserted 92 chunks from 15 files in under a minute ✅
- Search "When did I forget to press Ctrl+S?": session-12.md, What broke on top at 0.422 ✅
- Search "Why did terraform plan show 22 resources instead of 10?": session-05.md on top at 0.482; session-16 didn't make the top 5
- Cost check: 3 resources (Log Analytics, Foundry, Cosmos DB), left up on purpose

## What broke
- The second search missed. Session 16's log doesn't use the words "22 resources", so meaning-only search ranked another Terraform surprise (Session 5's unsaved main.tf) first. A real limit of vector-only search, kept on camera
- Nothing in the build itself

## What I learned
- Pure vector search matches meaning, not exact facts. A metadata filter (session number) fixes that, which is Session 18
- A partition key can't be changed after the container exists; `/source` keeps each document in one partition, so re-ingesting or summarizing one log stays cheap
- Fixed chunk ids (`session-11-02`) make ingest safe to rerun: it overwrites instead of duplicating

## Azure cost check
- Resources left running: Log Analytics, Foundry, Cosmos DB free tier, all about $0 while idle, on purpose for Session 18
- `terraform destroy` run: no (end-of-day destroy)
- Cost: about a cent (embeddings for 92 chunks; list-price estimate)

## Next session's goal
- Wrap the search in a FastAPI `/ask` endpoint that answers with gpt-5-mini, with a session-number filter
