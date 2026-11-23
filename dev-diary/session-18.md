# Session 18 — 2026-11-23

**Goal (one thing):** Wrap search plus gpt-5-mini in a FastAPI `/ask` endpoint that answers from my Dev Diary with its sources, with an optional session-number filter
**Time:** early afternoon, about 12:55 to 1:05 PM
**Recording:** webcam ✅ · screen ✅

## What I did
- Created `rag-app\api` with `app.py` (FastAPI: `/healthz` and `POST /ask`) and `requirements.txt`
- Replaced `rag-app\.gitignore` to add `__pycache__/` and `.venv/`
- `python -m pip install --user -r api\requirements.txt`, then `terraform plan`: **No changes** (today was all code)
- Started the API with `python -m uvicorn app:app --app-dir api --port 8000`
- Health check from a second terminal: `status: ok` ✅
- Cross-log question "When did I forget to press Ctrl+S?": answer from session-12.md, session-12 on top of the sources (0.46) ✅
- Same API with `"session": 11`: all 5 sources were session-11.md, answer "Nothing broke, all commands worked first time" ✅
- Tried the built-in `/docs` page in the browser (POST /ask > Try it out > Execute)
- Stopped the API with Ctrl+C

## What broke
- Nothing
- The API terminal showed `POST /mcp 404` lines: a VS Code extension checking port 8000 for an MCP server. Harmless, the API just has no such route
- The `terraform plan` refresh line shows the subscription ID; blur it in the recording

## What I learned
- RAG in one request: embed the question, vector search for the top chunks, then the model answers only from those chunks and names them
- A metadata filter (`WHERE c.session = @session`) fixes what pure vector search missed in Session 17: "this session" means nothing to embeddings, but the filter scopes the ranking to one log
- FastAPI builds the interactive `/docs` page from the code for free

## Azure cost check
- No new resources. Log Analytics, Foundry and Cosmos DB free tier still up on purpose for Session 19
- `terraform destroy` run: no (end-of-day destroy)
- Cost: a few cents at most in tokens (list-price estimate)

## Next session's goal
- Add a Basic container registry with Terraform and build the API into an image with ACR Tasks (no Docker on the laptop)
