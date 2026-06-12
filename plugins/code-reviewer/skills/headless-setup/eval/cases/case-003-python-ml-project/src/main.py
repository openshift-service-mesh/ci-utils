"""Entry point for the ML inference API."""

import uvicorn
from fastapi import FastAPI

from api.routes import router

app = FastAPI(
    title="ML Inference API",
    description="Exposes a trained text classifier via REST.",
    version="0.1.0",
)

app.include_router(router, prefix="/api/v1")


@app.get("/healthz", tags=["ops"])
async def health_check() -> dict[str, str]:
    """Return a simple liveness probe."""
    return {"status": "ok"}


if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)
