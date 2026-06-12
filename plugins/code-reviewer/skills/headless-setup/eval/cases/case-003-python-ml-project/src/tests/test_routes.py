"""Tests for the /api/v1/predict and /api/v1/labels endpoints."""

from __future__ import annotations

from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from main import app


@pytest.fixture()
def client() -> TestClient:
    return TestClient(app)


@pytest.fixture()
def mock_classifier() -> MagicMock:
    clf = MagicMock()
    clf.predict.return_value = (
        "sports",
        0.87,
        [{"label": "news", "confidence": 0.09}, {"label": "tech", "confidence": 0.04}],
    )
    clf.classes_ = ["news", "sports", "tech"]
    return clf


def test_predict_success(client: TestClient, mock_classifier: MagicMock) -> None:
    """POST /predict with valid input returns a label and confidence."""
    with patch("api.routes.get_classifier", return_value=mock_classifier):
        response = client.post(
            "/api/v1/predict",
            json={"text": "The team scored in the final minute.", "top_k": 2},
        )

    assert response.status_code == 200
    body = response.json()
    assert body["label"] == "sports"
    assert body["confidence"] == pytest.approx(0.87)
    assert len(body["alternatives"]) == 2


def test_predict_invalid_input(client: TestClient, mock_classifier: MagicMock) -> None:
    """POST /predict with an empty string returns 422."""
    mock_classifier.predict.side_effect = ValueError("Input text must not be empty.")

    with patch("api.routes.get_classifier", return_value=mock_classifier):
        response = client.post("/api/v1/predict", json={"text": "   "})

    assert response.status_code == 422


def test_predict_missing_body(client: TestClient) -> None:
    """POST /predict with no body returns 422 from FastAPI validation."""
    response = client.post("/api/v1/predict", json={})
    assert response.status_code == 422


def test_list_labels_success(client: TestClient, mock_classifier: MagicMock) -> None:
    """GET /labels returns the classifier's known class labels."""
    with patch("api.routes.get_classifier", return_value=mock_classifier):
        response = client.get("/api/v1/labels")

    assert response.status_code == 200
    assert response.json() == {"labels": ["news", "sports", "tech"]}


def test_health_check(client: TestClient) -> None:
    """GET /healthz always returns 200."""
    response = client.get("/healthz")
    assert response.status_code == 200
    assert response.json() == {"status": "ok"}
