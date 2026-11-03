"""
API Integration Tests for Smart RFQ Generator Endpoints
"""

import pytest
from fastapi.testclient import TestClient
from database.database import Base, engine, SessionLocal, get_db
from main import app
from modules.auth.security import create_access_token
from modules.users.model import User


@pytest.fixture(scope="module")
def auth_client():
    client = TestClient(app)
    client.headers = {
        "x-user-role": "ADMIN",
        "x-user-name": "admin",
    }
    return client


def test_generate_custom_smart_rfq_api(auth_client):
    payload = {
        "shipment_mode": "Air",
        "incoterm_code": "EXW",
        "pickup_address": "Siemens Logistics Hub, Frankfurt, Germany",
        "port_of_loading": "Frankfurt Airport (FRA)",
        "port_of_discharge": "Cairo International Airport (CAI)",
        "commodity_description": "Electronic Sensors",
        "hs_code": "8537.10",
        "packages": [
            {
                "length_cm": 120.0,
                "width_cm": 80.0,
                "height_cm": 80.0,
                "quantity": 3,
                "gross_weight_kg": 93.33,
                "package_type": "Crate",
            }
        ],
    }
    response = auth_client.post("/api/v1/freight-quotations/smart-rfq/generate", json=payload)
    assert response.status_code == 200
    data = response.json()
    assert "URGENT RFQ - AIR FREIGHT" in data["subject"]
    assert data["metrics"]["shipment_mode"] == "AIR"
    assert data["metrics"]["volumetric_divisor"] == 6000.0
    assert data["metrics"]["chargeable_weight_kg"] == 384.0
    assert "Cairo International Airport (CAI)" in data["body_text"]
