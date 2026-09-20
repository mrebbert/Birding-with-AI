# Operations

## Updates

Both containers track `latest` on purpose and take every new version:

```bash
cd /srv/docker
docker compose pull birdnet-go saezuri
docker compose up -d birdnet-go saezuri
```

When a new version behaves worse, go back over the digest of the previous image. As long as the old image
is still on the host, `docker images --digests | grep birdnet-go` gives you the value, and it goes into the
Compose file in place of `latest` for as long as you need it.

## Backup

Three directories hold everything worth keeping:

| Path | Contents |
|---|---|
| `/srv/docker/birdnet-go/config` | configuration written by the setup assistant |
| `/srv/docker/birdnet-go/data` | SQLite database with every detection |
| `/srv/docker/saezuri` | illustrations and reference calls |

A backup that already covers `/srv/docker` takes them along without further work. The `hls` directory is a
RAM disk and needs no backup.

## Lowering network load

ffmpeg receives the full stream and discards the video afterwards. The "low" quality level in the camera
carries the same audio and has a token of its own, so switching to it cuts the traffic without costing
detection quality.

## A second camera

CPU load grows roughly linearly per stream. Measure before you add one:

```bash
docker stats birdnet-go
```

Each source gets its own set of MQTT entities, named after the source. The template sensors in
`snippets/home-assistant/templates/birds.yaml` then need a second trigger and a second source entity, or a
second file per camera.

## Rollback

```bash
cd /srv/docker
docker compose stop birdnet-go saezuri
docker compose rm -f birdnet-go saezuri
# data survives so far; only this step removes it:
rm -rf /srv/docker/birdnet-go /srv/docker/saezuri
```

Remove the two virtual hosts from the proxy separately and reload it. In Home Assistant, delete
`templates/birds.yaml` and `automations/bird_new_species.yaml`, remove the dashboard under Settings →
Dashboards, and reload the configuration; the MQTT entities disappear with the "BirdNET-Go" device. Take the
`GEMINI_API_KEY` line out of `/srv/docker/.env` and revoke the key in the AI Studio.
