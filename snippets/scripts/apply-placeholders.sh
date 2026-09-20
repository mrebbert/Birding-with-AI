#!/usr/bin/env bash
# Copy the snippets into build/ with every placeholder replaced by the value
# from .env. The originals stay reusable.
#
#   ./snippets/scripts/apply-placeholders.sh [output directory]
#
# docker-compose.yml is copied unchanged: it reads .env itself through
# ${VARIABLE} substitution.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/.env}"
OUT="${1:-$ROOT/build}"

if [ ! -f "$ENV_FILE" ]; then
  echo "No $ENV_FILE. Start with: cp snippets/.env.example .env" >&2
  exit 1
fi

set -a
# shellcheck disable=SC1090
. "$ENV_FILE"
set +a

KEYS=(
  CAMERA_HOST RTSP_TOKEN RTSP_PORT
  BIRDNET_HOSTNAME SAEZURI_HOSTNAME HA_HOSTNAME
  SOURCE_SLUG NOTIFY_SERVICE
  MQTT_HOST MQTT_PORT MQTT_USER MQTT_TOPIC
  LATITUDE LONGITUDE
)

rm -rf "$OUT"
mkdir -p "$OUT"
cp -R "$ROOT/snippets/." "$OUT/"
rm -rf "$OUT/scripts" "$OUT/.env.example"

escape() { printf '%s' "$1" | sed -e 's/[\\&|]/\\&/g'; }

while IFS= read -r file; do
  for key in "${KEYS[@]}"; do
    value="${!key-}"
    [ -n "$value" ] || continue
    sed -i.bak "s|${key}|$(escape "$value")|g" "$file"
    rm -f "${file}.bak"
  done
  echo "written: ${file#"$OUT"/}"
done < <(find "$OUT" -type f ! -name 'docker-compose.yml')

echo
echo "Ready in $OUT. Remaining values (MQTT credentials, coordinates) go into"
echo "the BirdNET-Go setup assistant, see RUNBOOK.md step 4 and step 5."
