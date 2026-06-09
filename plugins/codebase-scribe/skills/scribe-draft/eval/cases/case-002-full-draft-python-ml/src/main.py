"""Entry point for the ml-classifier-service FastAPI application."""

from fastapi import FastAPI
from contextlib import asynccontextmanager

from app.routers import classify
from app.ml.classifier import MLClassifier
from app.config import Settings

settings = Settings()
classifier: MLClassifier | None = None


@asynccontextmanager
async def lifespan(app: FastAPI):
    """Load ML model at startup; release resources on shutdown."""
    global classifier
    classifier = MLClassifier(model_path=settings.MODEL_PATH)
    classifier.load()
    yield
    classifier = None


app = FastAPI(
    title="ML Classifier Service",
    description="Text classification via scikit-learn inference API",
    version="1.0.0",
    lifespan=lifespan,
)

app.include_router(classify.router, prefix="/api/v1")
