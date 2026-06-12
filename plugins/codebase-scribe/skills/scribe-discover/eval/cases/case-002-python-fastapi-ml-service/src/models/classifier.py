from __future__ import annotations

import joblib
import numpy as np
from sklearn.base import ClassifierMixin
from sklearn.pipeline import Pipeline


class MLClassifier:
    """Wraps a scikit-learn pipeline for inference."""

    def __init__(self, model_path: str) -> None:
        self.model_path = model_path
        self.version: str = "unknown"
        self._pipeline: Pipeline | None = None

    def load(self) -> None:
        """Load the persisted pipeline from disk."""
        artifact: dict = joblib.load(self.model_path)
        self._pipeline = artifact["pipeline"]
        self.version = artifact.get("version", "1.0.0")

    def predict(self, features: list[float]) -> tuple[str, float]:
        """Return (label, confidence) for the given feature vector."""
        if self._pipeline is None:
            raise RuntimeError("Model not loaded. Call load() first.")

        X = np.array(features, dtype=np.float32).reshape(1, -1)
        label: str = self._pipeline.predict(X)[0]

        estimator: ClassifierMixin = self._pipeline.steps[-1][1]
        if hasattr(estimator, "predict_proba"):
            proba = self._pipeline.predict_proba(X)[0]
            confidence = float(proba.max())
        else:
            confidence = 1.0

        return label, confidence
