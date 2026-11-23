"""Dev Diary RAG API (Session 18).

POST /ask {"question": "...", "session": 11}
  1. embed the question
  2. TOP-K vector search in Cosmos DB (optionally only one session's chunks)
  3. send those chunks to gpt-5-mini and return its answer with the sources

No keys: DefaultAzureCredential uses your az login on the laptop, and the app's
managed identity once it runs in Container Apps (Session 20).
"""
import os

from azure.cosmos import CosmosClient
from azure.identity import DefaultAzureCredential, get_bearer_token_provider
from fastapi import FastAPI
from openai import OpenAI
from pydantic import BaseModel

CHAT_MODEL = os.getenv("CHAT_MODEL", "gpt-5-mini")
EMBED_MODEL = os.getenv("EMBED_MODEL", "text-embedding-3-small")
TOP_K = int(os.getenv("TOP_K", "5"))
APP_VERSION = os.getenv("APP_VERSION", "dev")

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


@app.post("/ask")
def ask(req: AskRequest):
    q_vec = ai.embeddings.create(model=EMBED_MODEL, input=req.question).data[0].embedding

    # Metadata filter + vector search in one query. The WHERE runs first, then the ranking.
    where = "WHERE c.session = @session " if req.session is not None else ""
    params = [{"name": "@q", "value": q_vec}]
    if req.session is not None:
        params.append({"name": "@session", "value": req.session})

    hits = list(chunks.query_items(
        query=(
            f"SELECT TOP {TOP_K} c.source, c.heading, c.text, VectorDistance(c.embedding, @q) AS score "
            f"FROM c {where}ORDER BY VectorDistance(c.embedding, @q)"
        ),
        parameters=params,
        enable_cross_partition_query=True,
    ))
    if not hits:
        return {"answer": "I found nothing to answer from.", "sources": [], "version": APP_VERSION}

    excerpts = "\n\n".join(f"[{h['source']}] {h['text']}" for h in hits)
    reply = ai.chat.completions.create(
        model=CHAT_MODEL,
        reasoning_effort="low",  # gpt-5-mini is a reasoning model; low = faster, fewer tokens
        messages=[
            {"role": "system", "content": SYSTEM_PROMPT},
            {"role": "user", "content": f"Excerpts:\n{excerpts}\n\nQuestion: {req.question}"},
        ],
    )
    return {
        "answer": reply.choices[0].message.content,
        "sources": [{"source": h["source"], "heading": h["heading"], "score": round(h["score"], 3)} for h in hits],
        "version": APP_VERSION,
    }
