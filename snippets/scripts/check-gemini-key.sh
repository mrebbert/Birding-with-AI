#!/usr/bin/env bash
# Verify the Gemini API key before restarting Saezuri.
#
#   ./snippets/scripts/check-gemini-key.sh [path to .env]
#
# A usable key starts with AIza. The AI Studio also hands out an OAuth access
# token (AQ.Ab8…, 53 characters); the API answers 400 to that one and Saezuri
# stays silent about it.
#
# 200 -> the key works.
# 400 -> not an API key, most likely an OAuth token.
# 403 -> the Generative Language API is off in this project, or billing is
#        missing. Both belong to the project, not to the account.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${1:-${ENV_FILE:-$ROOT/.env}}"

KEY="${GEMINI_API_KEY:-}"
if [ -z "$KEY" ] && [ -f "$ENV_FILE" ]; then
  KEY=$(grep -m1 '^GEMINI_API_KEY=' "$ENV_FILE" | cut -d= -f2-)
fi
[ -n "$KEY" ] || { echo "No GEMINI_API_KEY found in $ENV_FILE" >&2; exit 1; }

case "$KEY" in
  AIza*) ;;
  *) echo "Warning: the key does not start with AIza (${#KEY} characters)." >&2 ;;
esac

code=$(curl -s -o /dev/null -w '%{http_code}' \
  -H "x-goog-api-key: $KEY" \
  https://generativelanguage.googleapis.com/v1beta/models)

echo "HTTP $code"
[ "$code" = "200" ]
