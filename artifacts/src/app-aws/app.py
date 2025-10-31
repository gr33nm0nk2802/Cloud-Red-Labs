import os
import json
import traceback

# auth defaults (override via env)
AUTH_USERNAME = os.environ.get("AUTH_USERNAME", "admin")
AUTH_PASSWORD = os.environ.get("AUTH_PASSWORD", "39d25d9e1d5d793c062f3f6e62da13377ec5a1a1fc1e60f650b1f3c566bcdb42")
os.environ["FLAG"] = 'flag{23d982c49d9ebdf33249c8cead166c7f5e16e24d23d226156facb01f2a083d62}'


# secret token required in header X-EVAL-TOKEN to use eval
EVAL_TOKEN = os.environ.get("EVAL_TOKEN", "Sup3r53cr37-70k3n")

# helper to make JSON responses
def _json(status, obj):
    return {
        "statusCode": status,
        "headers": {"Content-Type": "application/json"},
        "body": json.dumps(obj),
    }

def handler(event, context):
    try:
        # parse headers and body (guarding for missing keys)
        headers = {k.lower(): v for k, v in (event.get("headers") or {}).items()}
        raw_body = event.get("body") or "{}"
        # If body is base64-encoded payload from some clients (not typical), API Gateway marks isBase64Encoded
        if event.get("isBase64Encoded"):
            import base64
            raw_body = base64.b64decode(raw_body).decode("utf-8", errors="ignore")

        data = json.loads(raw_body)

        username = data.get("username")
        password = data.get("password")
        expr = data.get("expr")

        if username is None or password is None or expr is None:
            return _json(400, {"error": "required keys: username, password, expr"})

        # simple auth check
        if not (username == AUTH_USERNAME and password == AUTH_PASSWORD):
            return _json(401, {"error": "invalid credentials"})

        # Check token header
        token = headers.get("x-eval-token", "")
        if not EVAL_TOKEN or token != EVAL_TOKEN:
            return _json(403, {"error": "missing or invalid eval token (X-EVAL-TOKEN header)"})

        try:
            result = eval(expr, {"__builtins__": __builtins__}, {})
            return _json(200, {"ok": True, "result": result})
        except Exception as e:
            tb = traceback.format_exc()
            return _json(400, {"error": "evaluation error", "detail": str(e), "trace": tb})

    except Exception as e:
        tb = traceback.format_exc()
        return _json(500, {"error": "internal error", "detail": str(e), "trace": tb})
