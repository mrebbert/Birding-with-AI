# Troubleshooting

Every entry below comes from this installation. Symptom first, then the fix.

## The stream

**`Connection refused` on port 7447.** The RTSP endpoint often answers on the NVR address, not on the
address the management interface shows. On a UniFi setup that is the gateway. When the port stays closed,
`rtsps://CAMERA_HOST:7441/RTSP_TOKEN` works as well, without the `?enableSrtp` parameter.

**The token stopped working.** The camera issues a new token whenever the RTSP stream is switched off and on
again, and one token per quality level. Copy it again from the camera settings.

**ffmpeg reports 16000 Hz.** It picked the AAC track. Check with `ffprobe` whether the stream carries a
second, wide-band track and address it explicitly with `-map 0:a:1` if needed.

## The containers

**`… is not writable by uid 1000:1000`.** Saezuri runs as 1000:1000 and cannot create its directories. Run
`chown -R 1000:1000 /srv/docker/saezuri` on the host. The `docker run … alpine chown` suggested in the log
applies to named volumes; with bind mounts the host-side `chown` is enough.

**`ping` is missing inside the container.** The BirdNET-Go image ships no network tools. Check name
resolution with `docker compose exec birdnet-go getent hosts MQTT_HOST`.

**Saezuri logs `401`.** BirdNET-Go requires an API token. Create one in its interface and add it as
`BIRDNETGO_TOKEN` to the Compose block. It stays server-side.

**Saezuri cannot reach BirdNET-Go.** `BIRDNETGO_URL` points at the container name and the container port
(`http://birdnet-go:8080`), not at the published loopback port.

## MQTT

**`Connection … lost error=EOF` after pressing "Test".** Harmless. The test opens a second connection with
the same client ID `BirdNET-Go`, so the broker drops the older one. BirdNET-Go reconnects within a second
and republishes discovery.

**No entities in Home Assistant.** Discovery must be enabled in the BirdNET-Go MQTT settings, and the MQTT
integration must be configured in Home Assistant. Check the log with
`docker compose logs --since 5m birdnet-go | grep -i mqtt`; the line to look for is `Home Assistant
discovery messages published successfully`.

## Home Assistant

**Sensors read `unknown` after a restart.** Trigger-based template sensors start without state. The
`homeassistant: start` trigger in `snippets/home-assistant/templates/birds.yaml` fills them again.

**The logbook shows "Unknown" and "Unavailable".** The raw BirdNET-Go entity falls back to empty states
between detections. Point the logbook card at `sensor.last_bird_species` instead.

**The chart shows gaps instead of zeros.** `func: diff` returns no value for hours without a data point.
`fill: zero` in the `group_by` block draws the zero.

**The threshold does nothing.** Check the scale in Developer tools. When confidence reads 82 rather than
0.82, the threshold in the template file is 75 and the factor 100 in the dashboard goes away.

**The collage frame stays empty.** The browser refuses the embedding. Add a `Content-Security-Policy` header
with `frame-ancestors` for your Home Assistant address to the Saezuri virtual host; the Caddyfile snippet
carries the line, commented out.

## Illustrations

**The API rejects the key with `400`, and Saezuri says nothing about it.** The AI Studio also hands out an
OAuth access token (`AQ.Ab8…`, 53 characters). A usable API key starts with `AIza`. Verify before
restarting:

```bash
./snippets/scripts/check-gemini-key.sh
```

Expect `200`. A `403` means the Generative Language API is switched off in the project. Billing and key
belong to the same project, not to the account.

**A species stays silent after you fixed the key.** Saezuri records every failure in
`illustrations/_art-state.json` as `downloadMissAt` or `generateMissAt` and waits afterwards, seven days in
the download case. Clear the failure markers and keep the finished entries:

```bash
./snippets/scripts/reset-illustration-misses.sh
```

**A species has no artwork at all.** Place your own images as `<genus>-<species>.png` and
`<genus>-<species>-2.png` in `/srv/docker/saezuri/illustrations`, owned by 1000:1000.
