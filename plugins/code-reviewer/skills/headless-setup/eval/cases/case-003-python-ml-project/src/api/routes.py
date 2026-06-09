"""FastAPI router for model inference endpoints."""

from __future__ import annotations

from fastapi import APIRouter, HTTPException
from pydantic import BaseModel, Field

from models.classifier import TextClassifier

router = APIRouter(tags=["inference"])

# Module-level singleton loaded once at startup.
_classifier: TextClassifier | None = None


def get_classifier() -> TextClassifier:
    """Return the shared TextClassifier instance, loading it lazily."""
    global _classifier
    if _classifier is None:
        _classifier = TextClassifier()
        _classifier.load("models/weights/classifier.pkl")
    return _classifier


class PredictRequest(BaseModel):
    """Request body for the /predict endpoint."""

    text: str = Field(..., min_length=1, description="Input text to classify.")
    top_k: int = Field(default=3, ge=1, le=10, description="Number of top labels to return.")


class PredictResponse(BaseModel):
    """Response body for the /predict endpoint."""

    label: str
    confidence: float
    alternatives: list[dict[str, float]] = []


@router.post("/predict", response_model=PredictResponse, summary="Run inference on text input")
async def predict(request: PredictRequest) -> PredictResponse:
    """
    Classify the provided text and return the top predicted label with confidence.

    - **text**: Raw text string to classify (must be non-empty).
    - **top_k**: How many alternative predictions to include in the response.
    """
    clf = get_classifier()
    try:
        label, confidence, alternatives = clf.predict(request.text, top_k=request.top_k)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    return PredictResponse(label=label, confidence=confidence, alternatives=alternatives)


@router.get("/labels", summary="List all known class labels")
async def list_labels() -> dict[str, list[str]]:
    """Return the list of class labels the model was trained on."""
    clf = get_classifier()
    return {"labels": clf.classes_}
