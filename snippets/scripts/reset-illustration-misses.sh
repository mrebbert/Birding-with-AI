#!/usr/bin/env bash
# Clear the failure markers in Saezuri's art state so locked species get
# another attempt. Finished entries (those carrying "source") stay.
#
#   ./snippets/scripts/reset-illustration-misses.sh [/srv/docker]
#
# Saezuri records every failed download or generation as downloadMissAt or
# generateMissAt and waits afterwards, seven days in the download case. After
# fixing an invalid API key the affected species stay silent until these
# markers go.
set -euo pipefail

STACK_DIR="${1:-/srv/docker}"
STATE="$STACK_DIR/saezuri/illustrations/_art-state.json"
BACKUP="$STATE.$(date +%Y%m%d-%H%M%S).bak"

command -v jq >/dev/null || { echo "jq is required" >&2; exit 1; }
[ -f "$STATE" ] || { echo "Not found: $STATE" >&2; exit 1; }

cd "$STACK_DIR"
docker compose stop saezuri

cp "$STATE" "$BACKUP"
echo "Backup: $BACKUP"

jq 'with_entries(select(.value.source != null))' "$BACKUP" > "$STATE"
chown 1000:1000 "$STATE"

before=$(jq 'length' "$BACKUP")
after=$(jq 'length' "$STATE")
echo "Entries: $before -> $after, $((before - after)) failure markers removed"

docker compose start saezuri
echo "Follow along with: docker compose logs -f saezuri | grep -i saezuri-generate"
