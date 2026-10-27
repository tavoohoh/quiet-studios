"""Minimal App Store Connect API client (no dependencies beyond `cryptography`).

Credentials stay outside the repo: ~/.appstoreconnect/quiet-numbers.json holds
{"key_id": …, "issuer_id": …} and the key is ~/.appstoreconnect/private_keys/AuthKey_<key_id>.p8.

    python3 scripts/asc.py GET /v1/bundleIds        # quick manual calls
"""
import base64
import json
import pathlib
import ssl
import sys
import time
import urllib.error
import urllib.request

from cryptography.hazmat.primitives import hashes, serialization
from cryptography.hazmat.primitives.asymmetric import ec
from cryptography.hazmat.primitives.asymmetric.utils import decode_dss_signature

CONFIG = pathlib.Path.home() / ".appstoreconnect"
BASE = "https://api.appstoreconnect.apple.com"
# python.org builds ship without root certificates; macOS keeps them here.
SSL = ssl.create_default_context(cafile="/etc/ssl/cert.pem" if pathlib.Path("/etc/ssl/cert.pem").exists() else None)


def _b64(data):
    return base64.urlsafe_b64encode(data).rstrip(b"=")


def token():
    config = json.loads((CONFIG / "quiet-numbers.json").read_text())
    key = serialization.load_pem_private_key(
        (CONFIG / "private_keys" / f"AuthKey_{config['key_id']}.p8").read_bytes(), password=None)
    header = {"alg": "ES256", "kid": config["key_id"], "typ": "JWT"}
    now = int(time.time())
    claims = {"iss": config["issuer_id"], "iat": now, "exp": now + 15 * 60, "aud": "appstoreconnect-v1"}
    signing_input = _b64(json.dumps(header).encode()) + b"." + _b64(json.dumps(claims).encode())
    r, s = decode_dss_signature(key.sign(signing_input, ec.ECDSA(hashes.SHA256())))
    return (signing_input + b"." + _b64(r.to_bytes(32, "big") + s.to_bytes(32, "big"))).decode()


def request(method, path, body=None, raw=None, headers=None, url=None):
    """JSON in, JSON out. `raw` uploads bytes to `url` (asset upload operations)."""
    data = raw if raw is not None else (json.dumps(body).encode() if body is not None else None)
    all_headers = {} if raw is not None else {"Authorization": f"Bearer {token()}", "Content-Type": "application/json"}
    all_headers.update(headers or {})
    req = urllib.request.Request(url or BASE + path, data=data, method=method, headers=all_headers)
    # Apple's side fails now and then (500/503); retry those a few times.
    for attempt in range(4):
        try:
            with urllib.request.urlopen(req, context=SSL) as response:
                text = response.read()
                return json.loads(text) if text else None
        except urllib.error.HTTPError as error:
            if error.code < 500 or attempt == 3:
                raise SystemExit(f"{method} {path or url} → {error.code}\n{error.read().decode()}")
            time.sleep(2 ** attempt * 3)


def get_all(path):
    """Follows `links.next` and returns every item."""
    items, page = [], request("GET", path)
    items += page["data"]
    while page.get("links", {}).get("next"):
        page = request("GET", "", url=page["links"]["next"])
        items += page["data"]
    return items


if __name__ == "__main__":
    method, path = sys.argv[1], sys.argv[2]
    body = json.loads(sys.argv[3]) if len(sys.argv) > 3 else None
    print(json.dumps(request(method, path, body), indent=2))
