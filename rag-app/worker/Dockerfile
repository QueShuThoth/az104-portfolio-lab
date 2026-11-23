# Session 22: image for the ingest worker. Built in Azure by ACR Tasks.
FROM python:3.13-slim

ENV PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY worker.py .

RUN useradd --create-home appuser
USER appuser

CMD ["python", "worker.py"]
