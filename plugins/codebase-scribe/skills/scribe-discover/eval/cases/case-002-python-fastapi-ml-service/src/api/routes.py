from fastapi import APIRouter, HTTPException, Request
from pydantic import BaseModel

router = APIRouter()


class PredictRequest(BaseModel):
    features: list[float]


class PredictResponse(BaseModel):
    label: str
    confidence: float
    model_version: str


class HealthResponse(BaseModel):
    status: str
    model_loaded: bool


@router.post("/predict", response_model=PredictResponse)
async def predict(request: Request, payload: PredictRequest) -> PredictResponse:
    """Run inference on the provided feature vector."""
    classifier = getattr(request.app.state, "classifier", None)
    if classifier is None:
        raise HTTPException(status_code=503, detail="Model not loaded")

    try:
        label, confidence = classifier.predict(payload.features)
    except ValueError as exc:
        raise HTTPException(status_code=422, detail=str(exc)) from exc

    return PredictResponse(
        label=label,
        confidence=confidence,
        model_version=classifier.version,
    )


@router.get("/health", response_model=HealthResponse)
async def health(request: Request) -> HealthResponse:
    """Return service health and model load status."""
    classifier = getattr(request.app.state, "classifier", None)
    return HealthResponse(
        status="ok",
        model_loaded=classifier is not None,
    )
