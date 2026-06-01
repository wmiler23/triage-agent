import json

SUSPICIOUS_SIGNALS = ("failed password", "sudo", "/etc/shadow", "rm -rf", "curl http")

def triage(log_line: str) -> dict:
    # In a real agentic product this is where you'd call the model / tool-use loop.
    score = sum(1 for s in SUSPICIOUS_SIGNALS if s in log_line.lower())
    verdict = "suspicious" if score else "benign"
    return {"verdict": verdict, "score": score}

def lambda_handler(event, context):
    body = json.loads(event.get("body") or "{}")
    line = body.get("log_line", "")
    result = triage(line)
    return {
        "statusCode": 200,
        "headers": {"content-type": "application/json"},
        "body": json.dumps(result),
    }