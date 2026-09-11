"""FastAPI application. Populated by feature/api-app."""

from __future__ import annotations

from fastapi import FastAPI

app = FastAPI(title="PropLedger Quebec API", version="0.1.0")


@app.get("/health")
def health() -> dict[str, str]:
    return {"status": "ok"}
