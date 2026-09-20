#!/usr/bin/env bash
# Ten seconds of the camera stream through the ffmpeg inside the BirdNET-Go
# image. Nothing is installed on the host.
#
#   ./snippets/scripts/check-rtsp-stream.sh
#
# Expected: a line naming an audio stream, ideally "opus, 48000 Hz", and a
# clean exit after 10 seconds.
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/../.." && pwd)"
ENV_FILE="${ENV_FILE:-$ROOT/.env}"

if [ -f "$ENV_FILE" ]; then
  set -a
  # shellcheck disable=SC1090
  . "$ENV_FILE"
  set +a
fi

: "${CAMERA_HOST:?set CAMERA_HOST in .env}"
: "${RTSP_TOKEN:?set RTSP_TOKEN in .env}"
RTSP_PORT="${RTSP_PORT:-7447}"

echo "Testing rtsp://${CAMERA_HOST}:${RTSP_PORT}/<token> for 10 seconds"
docker run --rm --entrypoint ffmpeg ghcr.io/tphakala/birdnet-go:latest \
  -hide_banner -rtsp_transport tcp -timeout 5000000 \
  -i "rtsp://${CAMERA_HOST}:${RTSP_PORT}/${RTSP_TOKEN}" \
  -vn -t 10 -f null -
