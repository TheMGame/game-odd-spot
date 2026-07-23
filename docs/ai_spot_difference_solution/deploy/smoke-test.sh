#!/usr/bin/env bash
set -euo pipefail
base_url=${1:-http://127.0.0.1:8080}
curl --fail --silent "$base_url/health/live" >/dev/null
curl --fail --silent "$base_url/health/ready" >/dev/null
installation_id=$(printf 'smoke-%s' "$(date +%s%N)" | sha256sum | cut -d' ' -f1)
session=$(curl --fail --silent -X POST "$base_url/v1/sessions/anonymous" -H 'Content-Type: application/json' -d "{\"installation_id\":\"$installation_id\",\"app_version\":\"0.1.0\",\"platform\":\"desktop\",\"locale\":\"en-US\"}")
token=$(printf '%s' "$session" | python3 -c 'import json,sys; print(json.load(sys.stdin)["data"]["access_token"])')
curl --fail --silent "$base_url/v1/bootstrap" -H "Authorization: Bearer $token" >/dev/null
curl --fail --silent "$base_url/v1/home" -H "Authorization: Bearer $token" >/dev/null
echo "smoke test passed"
