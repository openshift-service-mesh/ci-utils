from unittest.mock import MagicMock, patch

import pytest
from fastapi.testclient import TestClient

from main import create_app


@pytest.fixture
def mock_classifier() -> MagicMock:
    clf = MagicMock()
    clf.version = "1.0.0"
    clf.predict.return_value = ("cat", 0.92)
    return clf


@pytest.fixture
def client(mock_classifier: MagicMock) -> TestClient:
    app = create_app()
    app.state.classifier = mock_classifier
    return TestClient(app)


def test_health_returns_ok(client: TestClient) -> None:
    response = client.get("/api/v1/health")
    assert response.status_code == 200
    data = response.json()
    assert data["status"] == "ok"
    assert data["model_loaded"] is True


def test_predict_returns_label_and_confidence(
    client: TestClient, mock_classifier: MagicMock
) -> None:
    payload = {"features": [0.1, 0.5, 0.3, 0.8]}
    response = client.post("/api/v1/predict", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert data["label"] == "cat"
    assert data["confidence"] == pytest.approx(0.92)
    assert data["model_version"] == "1.0.0"


def test_predict_without_model_returns_503(client: TestClient) -> None:
    client.app.state.classifier = None
    response = client.post("/api/v1/predict", json={"features": [1.0]})
    assert response.status_code == 503
