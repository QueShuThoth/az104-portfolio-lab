"""Dev Diary RAG API (Session 18; v2 Session 21: JSON log line per /ask;
v3 Session 25: settings from App Configuration, admin key from Key Vault).

POST /ask {"question": "...", "session": 11}
  1. embed the question
  2. TOP-K vector search in Cosmos DB (optionally only one session's chunks)
  3. send those chunks to the chat model and return its answer with the sources

GET  /config        what the app is running with right now (never the secret itself)
POST /admin/reload  re-read App Configuration and Key Vault. Needs header X-Admin-Key.

Settings live in App Configuration under the "rag:" prefix:
  rag:chat_model   e.g. gpt-5-mini
  rag:top_k        e.g. 5
  rag:admin_key    a Key Vault reference to the secret "admin-key"
If APPCONFIG_ENDPOINT isn't set (running on the laptop), it falls back to env vars.

No keys: DefaultAzureCredential uses your az login on the laptop, and the app's
managed identity in Container Apps. The same credential reads Key Vault.
"""
import json
import os
import secrets
import threading
import time
from datetime import datetime, timezone

from azure.appconfiguration.provider import SettingSelector, load
from azure.cosmos import CosmosClient
from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from fastapi import FastAPI, Header, HTTPException
from openai import OpenAI
from pydantic import BaseModel

EMBED_MODEL = os.getenv("EMBED_MODEL", "text-embedding-3-small")
APP_VERSION = os.getenv("APP_VERSION", "dev")
APPCONFIG_ENDPOINT = os.getenv("APPCONFIG_ENDPOINT")

credential = DefaultAzureCredential()
ai = OpenAI(
    base_url=os.environ["OPENAI_ENDPOINT"] + "/openai/v1/",
    api_key=get_bearer_token_provider(credential, "https://cognitiveservices.azure.com/.default"),
    max_retries=5,
)
chunks = (
    CosmosClient(os.environ["COSMOS_ENDPOINT"], credential=credential)
    .get_database_client("ragdb")
    .get_container_client("chunks")
)

SYSTEM_PROMPT = (
    "You answer questions about an Azure lab Dev Diary. Use only the excerpts provided. "
    "Cite the file you used in square brackets, like [session-12.md]. "
    "If the excerpts don't contain the answer, say you don't know. Keep it to three sentences."
)

# ---------- settings ----------

_lock = threading.Lock()
SETTINGS = {}


def load_settings():
    """Read settings once. Called at startup and by /admin/reload, never per request."""
    defaults = {
        "chat_model": os.getenv("CHAT_MODEL", "gpt-5-mini"),
        "top_k": os.getenv("TOP_K", "5"),
        "admin_key": None,
    }
    source, error = "environment", None
    if APPCONFIG_ENDPOINT:
        try:
            store = load(
                endpoint=APPCONFIG_ENDPOINT,
                credential=credential,
                selects=[SettingSelector(key_filter="rag:*")],
                trim_prefixes=["rag:"],
                keyvault_credential=credential,  # resolves rag:admin_key from Key Vault
            )
            defaults.update({k: store[k] for k in ("chat_model", "top_k", "admin_key") if k in store})
            source = "app-configuration"
        except Exception as exc:  # roles still spreading, store empty, etc.: keep running on defaults
            error = type(exc).__name__
    new = {
        "chat_model": str(defaults["chat_model"]),
        "top_k": max(1, min(int(defaults["top_k"]), 20)),
        "admin_key": defaults["admin_key"],
        "source": source,
        "error": error,
        "loaded_at": datetime.now(timezone.utc).isoformat(timespec="seconds"),
    }
    with _lock:
        SETTINGS.clear()
        SETTINGS.update(new)
    print(json.dumps({"event": "settings", "version": APP_VERSION, "source": source,
                      "chat_model": new["chat_model"], "top_k": new["top_k"],
                      "admin_key_loaded": new["admin_key"] is not None, "error": error}), flush=True)


load_settings()

# ---------- API ----------

app = FastAPI(title="Dev Diary RAG API", version=APP_VERSION)


class AskRequest(BaseModel):
    question: str
    session: int | None = None  # optional filter: only search this session's log


@app.get("/")
def root():
    return {"app": "dev-diary-rag", "version": APP_VERSION}


@app.get("/healthz")
def healthz():
    return {"status": "ok"}


@app.get("/config")
def config():
    with _lock:
        s = dict(SETTINGS)
    return {
        "version": APP_VERSION,
        "source": s["source"],
        "chat_model": s["chat_model"],
        "top_k": s["top_k"],
        "admin_key_loaded": s["admin_key"] is not None,  # yes/no only, never the value
        "loaded_at": s["loaded_at"],
        "error": s["error"],
    }


@app.post("/admin/reload")
def admin_reload(x_admin_key: str | None = Header(default=None)):
    with _lock:
        current = SETTINGS.get("admin_key")
    if not current:
        raise HTTPException(status_code=503, detail="No admin key loaded yet")
    # compare_digest takes the same time whether the first or last character is wrong
    if not x_admin_key or not secrets.compare_digest(x_admin_key, current):
        raise HTTPException(status_code=401, detail="Wrong or missing X-Admin-Key")
    load_settings()
    return config()


@app.post("/ask")
def ask(req: AskRequest):
    started = time.perf_counter()
    with _lock:
        chat_model, top_k = SETTINGS["chat_model"], SETTINGS["top_k"]

    q_vec = ai.embeddings.create(model=EMBED_MODEL, input=req.question).data[0].embedding

    # Metadata filter + vector search in one query. The WHERE runs first, then the ranking.
    where = "WHERE c.session = @session " if req.session is not None else ""
    params = [{"name": "@q", "value": q_vec}]
    if req.session is not None:
        params.append({"name": "@session", "value": req.session})

    hits = list(chunks.query_items(
        query=(
            f"SELECT TOP {top_k} c.source, c.heading, c.text, VectorDistance(c.embedding, @q) AS score "
            f"FROM c {where}ORDER BY VectorDistance(c.embedding, @q)"
        ),
        parameters=params,
        enable_cross_partition_query=True,
    ))
    if not hits:
        return {"answer": "I found nothing to answer from.", "sources": [], "version": APP_VERSION}

    excerpts = "\n\n".join(f"[{h['source']}] {h['text']}" for h in hits)
    reply = ai.chat.completions.create(
        model=chat_model,
        reasoning_effort="low",  # gpt-5-mini is a reasoning model; low = faster, fewer tokens
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": f"Excerpts:\n{excerpts}\n\nQuestion: {req.question}"},
        ],
    )
    # One structured log line per question. Container Apps ships stdout to Log Analytics,
    # where KQL can parse it with parse_json(Log_s).
    print(json.dumps({
        "event": "ask",
        "version": APP_VERSION,
        "session_filter": req.session,
        "top_k": top_k,
        "top_source": hits[0]["source"],
        "top_score": round(hits[0]["score"], 3),
        "tokens": reply.usage.total_tokens,
        "ms": round((time.perf_counter() - started) * 1000),
    }), flush=True)

    return {
        "answer": reply.choices[0].message.content,
        "sources": [{"source": h["source"], "heading": h["heading"], "score": round(h["score"], 3)} for h in hits],
        "version": APP_VERSION,
    }
