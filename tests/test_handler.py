from app.handler import triage

def test_flags_suspicious():
    assert triage("Failed password for root").get("verdict") == "suspicious"

def test_passes_benign():
    assert triage("user logged in successfully").get("verdict") == "benign"