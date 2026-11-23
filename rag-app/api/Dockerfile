# Session 19: image for the Dev Diary RAG API. Built in Azure by ACR Tasks (no Docker on the laptop).
FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app

# Dependencies first, so a code-only change reuses this layer
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py .

# The version shows up in /, in /ask answers, and later in the logs (Session 21)
ARG APP_VERSION=dev
ENV APP_VERSION=${APP_VERSION}

# Don't run as root inside the container
RUN useradd --create-home appuser
USER appuser

EXPOSE 8000
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
