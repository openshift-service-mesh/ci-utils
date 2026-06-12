"""Thin wrapper around a scikit-learn text classification pipeline."""

from __future__ import annotations

import pickle
from pathlib import Path
from typing import Any

import numpy as np
from sklearn.feature_extraction.text import TfidfVectorizer
from sklearn.linear_model import LogisticRegression
from sklearn.pipeline import Pipeline


class TextClassifier:
    """A TF-IDF + Logistic Regression text classifier."""

    def __init__(self) -> None:
        self._pipeline: Pipeline | None = None

    @property
    def classes_(self) -> list[str]:
        """Return sorted list of class labels known to the model."""
        if self._pipeline is None:
            raise RuntimeError("Model is not loaded. Call load() or fit() first.")
        return list(self._pipeline.classes_)

    def fit(self, texts: list[str], labels: list[str]) -> "TextClassifier":
        """
        Train the classifier on the provided texts and labels.

        Args:
            texts: A list of raw text samples.
            labels: Corresponding class labels for each sample.

        Returns:
            self, to allow method chaining.
        """
        if len(texts) != len(labels):
            raise ValueError("texts and labels must have the same length.")

        self._pipeline = Pipeline(
            [
                ("tfidf", TfidfVectorizer(max_features=20_000, ngram_range=(1, 2))),
                ("clf", LogisticRegression(max_iter=1000, C=1.0)),
            ]
        )
        self._pipeline.fit(texts, labels)
        return self

    def predict(
        self, text: str, top_k: int = 3
    ) -> tuple[str, float, list[dict[str, float]]]:
        """
        Predict the class label for a single text input.

        Args:
            text: The raw text string to classify.
            top_k: Number of top alternative predictions to return.

        Returns:
            A tuple of (best_label, confidence, alternatives) where alternatives
            is a list of ``{"label": str, "confidence": float}`` dicts.

        Raises:
            ValueError: If the text is empty after stripping.
            RuntimeError: If the model has not been loaded or fitted.
        """
        if not text.strip():
            raise ValueError("Input text must not be empty.")
        if self._pipeline is None:
            raise RuntimeError("Model is not loaded. Call load() or fit() first.")

        proba: np.ndarray = self._pipeline.predict_proba([text])[0]
        classes: list[str] = list(self._pipeline.classes_)

        sorted_indices = np.argsort(proba)[::-1]
        best_label = classes[sorted_indices[0]]
        confidence = float(proba[sorted_indices[0]])

        alternatives = [
            {"label": classes[i], "confidence": float(proba[i])}
            for i in sorted_indices[1 : top_k + 1]
        ]

        return best_label, confidence, alternatives

    def save(self, path: str | Path) -> None:
        """Persist the fitted pipeline to disk using pickle."""
        path = Path(path)
        path.parent.mkdir(parents=True, exist_ok=True)
        with path.open("wb") as fh:
            pickle.dump(self._pipeline, fh)

    def load(self, path: str | Path) -> "TextClassifier":
        """Load a previously saved pipeline from disk."""
        with Path(path).open("rb") as fh:
            self._pipeline = pickle.load(fh)  # noqa: S301
        return self
