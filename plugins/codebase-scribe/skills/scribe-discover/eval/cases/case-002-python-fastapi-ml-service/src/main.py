from contextlib import asynccontextmanager
from typing import AsyncIterator

import uvicorn
from fastapi import FastAPI

from api.routes import router
from core.config import get_settings
from models.classifier import MLClassifier

_classifier: MLClassifier | None = None


@asynccontextmanager
async def lifespan(app: FastAPI) -> AsyncIterator[None]:
    """Load ML model on startup and release it on shutdown."""
    global _classifier
    settings = get_settings()
    _classifier = MLClassifier(model_path=settings.model_path)
    _classifier.load()
    app.state.classifier = _classifier
    yield
    _classifier = None


def create_app() -> FastAPI:
    settings = get_settings()
    app = FastAPI(
        title="ML Inference Service",
        version="1.0.0",
        description="FastAPI service for scikit-learn model inference",
        lifespan=lifespan,
    )
    app.include_router(router, prefix="/api/v1")
    return app


app = create_app()

if __name__ == "__main__":
    settings = get_settings()
    uvicorn.run(
        "main:app",
        host=settings.host,
        port=settings.port,
        reload=settings.debug,
    )
