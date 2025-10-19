#!/usr/bin/env bash
set -euo pipefail

HOST="${HOST:-localhost}"
BASE="http://$HOST:8080"

echo "== health =="
curl -sS "$BASE/"

echo "== hmac sign =="
curl -sSI "$BASE/sign" | grep -E 'X-Time|X-Sign' || true

echo "== report raw =="
curl -sS "$BASE/report"

echo "== report filtered (redacted) =="
curl -sS "$BASE/report-filtered"

echo "== api gate (requires x-api-key) =="
echo "-- v1/v2 without cookie (random by FF_PERCENT)"
curl -sS -H 'x-api-key: demo' "$BASE/api/hello"; echo

echo "-- force stable (cookie user=stable123)"
curl -sS -H 'x-api-key: demo' --cookie 'user=stable123' "$BASE/api/hello"; echo

echo "-- force canary-ish (cookie user=canary1)"
curl -sS -H 'x-api-key: demo' --cookie 'user=canary1' "$BASE/api/hello"; echo
