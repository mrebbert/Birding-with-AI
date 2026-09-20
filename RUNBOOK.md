# Runbook: bird detection from an IP camera

Two containers, one existing camera. BirdNET-Go analyses the audio of an RTSP stream and delivers
detections to Home Assistant; Saezuri presents them as an illustrated collage.

**Target picture:** camera → RTSP → `birdnet-go` → MQTT → Home Assistant. In parallel `saezuri` reads the
detections over the Compose network. Both containers publish on `127.0.0.1` only; the reverse proxy is the
single entry point from the network.

**Scope:** audio clips are discarded on purpose, only detections persist. Camera microphones also capture
conversations on the pavement, so the BirdNET-Go privacy filter stays on. See
[README, Privacy and law](README.md#privacy-and-law).

**Duration:** about 60 minutes including verification.

**Reference deployment**, verified over 13 days of continuous operation:

| | Value |
|---|---|
| Hardware | AMD Athlon 3000G, 16 GB RAM |
| Camera | UniFi Protect camera, one audio source |
| Host port BirdNET-Go | 8081 (container 8080) |
| Host port Saezuri | 8090 (container 8080) |
| CPU load | around 34 % of the machine for one stream |
| Result | detections every day, no restarts, no measurable system load |

---

## Preparation: fill in your values once

Every snippet in this repository carries literal placeholders (`CAMERA_HOST`, `BIRDNET_HOSTNAME`,
`SOURCE_SLUG`, …); the [README](README.md#placeholders) lists them all. Fill them in once and every file
below fits together:

```bash
cp snippets/.env.example .env
$EDITOR .env
./snippets/scripts/apply-placeholders.sh
```

This writes `build/` with your values substituted and leaves `snippets/` untouched as the source. From here
on the runbook names the file in `build/` and links the template it came from. `build/` and `.env` stay out
of git.

Working without the script is fine too: copy the files from `snippets/` by hand and replace the
placeholders as you go.

Four helper scripts come along, all reading the same `.env`:

| Script | Purpose | Used in |
|---|---|---|
| `apply-placeholders.sh` | writes `build/` from `snippets/` and `.env` | here |
| `check-rtsp-stream.sh` | ten seconds of camera audio through ffmpeg | step 0 |
| `check-gemini-key.sh` | verifies the Gemini API key before a restart | step 7 |
| `reset-illustration-misses.sh` | unlocks species Saezuri gave up on | [troubleshooting](docs/troubleshooting.md#illustrations) |

---

## Step 0: verify the stream

The BirdNET-Go image ships ffmpeg, so test without installing anything:

```bash
./snippets/scripts/check-rtsp-stream.sh
```

The script runs this command with the values from your `.env`:

```bash
docker run --rm --entrypoint ffmpeg ghcr.io/tphakala/birdnet-go:latest \
  -hide_banner -rtsp_transport tcp -timeout 5000000 \
  -i rtsp://CAMERA_HOST:7447/RTSP_TOKEN \
  -vn -t 10 -f null -
```

**Checkpoint:** the output names an audio stream and ends after 10 seconds without an error. A line such as
`Stream #0:1: Audio: opus, 48000 Hz` is the one you want.

Notes that cost time to find out:

- **Take the wide-band track.** UniFi Protect carries two: AAC at 16 kHz mono (usable up to 8 kHz) and Opus
  at 48 kHz stereo (up to 24 kHz). BirdNET evaluates up to 15 kHz, so only the second one covers the range.
  ffmpeg picks it on its own.
- **The NVR serves the stream, not the management interface.** On a UniFi setup the RTSP port 7447 answers
  on the gateway address even when the Protect UI shows a different management address.
- **Tokens are per quality level** and Protect issues a new one whenever you switch the RTSP stream off and
  on again.
- **Port 7447 blocked?** `rtsps://CAMERA_HOST:7441/RTSP_TOKEN` works as well, without the `?enableSrtp`
  parameter. Plain RTSP inside a trusted network avoids TLS corner cases in ffmpeg.

## Step 1: set the camera microphone gain

Set the microphone sensitivity to 100 % in the camera settings. This is the only amplification ahead of the
compression and therefore the only control that truly improves the distance between a bird call and the
noise floor. Every gain stage behind the stream raises both alike.

Pull back to 80 or 90 % when the live spectrogram already saturates on ambient noise.

Switch off the camera's noise suppression where the vendor offers it: it is tuned for speech and damps high
frequencies, which is exactly where bird calls live.

## Step 2: directories and Compose blocks

```bash
ss -ltnp | grep -E ':(8081|8090) '     # both ports must be free
mkdir -p /srv/docker/birdnet-go/{config,data}
mkdir -p /srv/docker/saezuri/{illustrations,calls}
chown -R 1000:1000 /srv/docker/saezuri
id                                      # UID and GID for the Compose block
```

Copy the service definitions from `build/docker-compose.yml` into `/srv/docker/docker-compose.yml` and your
`.env` next to it. The file reads its values through `${VARIABLE}` substitution, which is why the
placeholder script passes it through unchanged. Template:
[`snippets/docker-compose.yml`](snippets/docker-compose.yml), variables:
[`snippets/.env.example`](snippets/.env.example).

Run the stack from `/srv/docker`, not from `build/`: the volume paths are relative to the Compose file, and
`apply-placeholders.sh` empties `build/` on every run.

Three points decide whether the stack comes up:

- **`chown` on the Saezuri directories is mandatory.** The container runs as 1000:1000 and otherwise aborts
  with `… is not writable by uid 1000:1000`. The `docker run … alpine chown` the log suggests applies to
  named volumes; with bind mounts a `chown` on the host is enough.
- **`BIRDNET_HOST`** sets the hostname BirdNET-Go uses for links in notifications behind a reverse proxy.
- **Saezuri reaches BirdNET-Go by container name on port 8080**, not over the loopback address. Both sit in
  the same Compose network.

## Step 3: reverse proxy

`build/caddy/Caddyfile` holds both virtual hosts with your hostnames already in place (template:
[`snippets/caddy/Caddyfile`](snippets/caddy/Caddyfile)). Caddy runs in the host network in this setup, hence
loopback addresses rather than container names. Validate the configuration and
reload afterwards:

```bash
caddy validate --config /etc/caddy/Caddyfile
systemctl reload caddy
```

## Step 4: configure BirdNET-Go

```bash
cd /srv/docker
docker compose up -d birdnet-go
docker compose logs -f birdnet-go
```

Work through the setup assistant at `https://BIRDNET_HOSTNAME`:

| Setting | Value |
|---|---|
| Location | `LATITUDE` / `LONGITUDE` |
| Language and species names | your locale |
| Audio source | the RTSP URL from step 0, transport `tcp` |
| Model | BirdNET v2.4 |
| Audio export | off |
| Privacy filter | on |
| Login | set a password |

Set the password even on a private network: the interface contains a browser terminal with access to the
container.

Configure through the assistant rather than by hand. The key names in `config.yaml` have changed several
times between versions; BirdNET-Go writes the file itself and picks changes up without a restart.

**Checkpoint:** the interface reports 48000 Hz for the source, the level meter moves, and live listening
works.

## Step 5: MQTT and Home Assistant

Check name resolution inside the container first. The image carries no network tools, so `getent` replaces
`ping`:

```bash
docker compose exec birdnet-go getent hosts MQTT_HOST
```

Then open Settings → Integrations → MQTT in the interface: broker `tcp://MQTT_HOST:1883`, user `MQTT_USER`,
topic `birdnet`, Home Assistant discovery enabled.

```bash
docker compose logs --since 5m birdnet-go | grep -i mqtt
```

**Checkpoint:** `Successfully connected to MQTT broker` and `Home Assistant discovery messages published
successfully`. Home Assistant gains `binary_sensor.birdnet_go_status` plus, per source,
`sensor.birdnet_go_SOURCE_SLUG_last_species`, `…_scientific_name` and `…_confidence`.

> **`Connection … lost error=EOF` after pressing "Test" is harmless.** The test opens a second connection
> with the same client ID `BirdNET-Go`, so the broker drops the older one. BirdNET-Go reconnects within a
> second and republishes discovery.

## Step 6: species list and notification in Home Assistant

Copy `build/home-assistant/templates/birds.yaml` into your Home Assistant `templates/` directory and
`build/home-assistant/automations/bird_new_species.yaml` into `automations/`. Both carry your `SOURCE_SLUG`
and your notify service already; the templates are
[`snippets/home-assistant/templates/birds.yaml`](snippets/home-assistant/templates/birds.yaml) and
[`snippets/home-assistant/automations/bird_new_species.yaml`](snippets/home-assistant/automations/bird_new_species.yaml).
Both files come in list form, which is what `!include_dir_merge_list` in `configuration.yaml` expects.

All four sensors share one trigger block so the same event advances them together. Four design decisions
carry the file:

- **A sensor of your own for the last species.** The raw BirdNET-Go entity falls back to empty states
  between two detections, which show up in the logbook as "Unknown" and "Unavailable". The own sensor holds
  the last valid species together with confidence and timestamp.
- **A start trigger.** Trigger-based template sensors start without state. Without `homeassistant: start`
  the counters read `unknown` after every restart, and cards and charts stay empty.
- **The `bird_reset` event.** Clears both species lists from Developer tools → Events. This is how a false
  positive leaves the list again.
- **`detected_at` as its own attribute.** `relative_time` returns English text; a timestamp lets the
  dashboard format it freely.

> **Check the confidence scale.** If Developer tools show 82 rather than 0.82, the threshold in the template
> file becomes 75 and the factor 100 in the dashboard goes away.

**Checkpoint:** after a reload, `sensor.last_bird_species` carries a species name, and
`sensor.bird_species_total` counts up with the next new species.

## Step 7: start Saezuri

```bash
cd /srv/docker
docker compose up -d saezuri
docker compose logs -f saezuri
```

**Checkpoint:** `https://SAEZURI_HOSTNAME` shows the collage with species names in your locale; a click
opens the card with a reference call.

A `401` in the log means an API token is missing: create one in BirdNET-Go and add it as `BIRDNETGO_TOKEN`
to the Compose block. It stays server-side and never reaches the browser.

### Illustrations: library and generation

Saezuri shows a species once artwork exists: two images per species, perched and in flight. Without them the
tile stays absent even though the detection arrived. Saezuri first downloads from the library
`vrwrts/saezuri-illustrations` (free, no account); for species missing there it generates artwork in the
same style through the Gemini API, provided a key is configured.

Keep the key in `/srv/docker/.env` and reference it from the Compose block:

```bash
echo 'GEMINI_API_KEY=AIza…' >> /srv/docker/.env
chmod 600 /srv/docker/.env
```

```yaml
    environment:
      BIRDNETGO_URL: http://birdnet-go:8080
      SPECIES_DICT_LOCALES: de,en
      GEMINI_API_KEY: ${GEMINI_API_KEY}
```

Then run `docker compose up -d saezuri`; a plain `restart` reads the `.env` again only on recreation.

**Cost:** Google bills the image models without a free tier, at roughly 0.039 US dollars per image. That
makes about eight cents per new species, once. Generation is capped at four images per pass with six seconds
between them.

Two traps wait here, both covered in [docs/troubleshooting.md](docs/troubleshooting.md): the AI Studio also
hands out an OAuth token that the API rejects with `400`, and failed attempts lock a species in
`_art-state.json` until you clear the markers. Verify the key before restarting:

```bash
./snippets/scripts/check-gemini-key.sh
```

Watch progress straight on the directory; `docker compose logs … | grep -i saezuri-generate` names the
source per image (`repo` or `generated`):

```bash
watch -n 30 'ls -1 /srv/docker/saezuri/illustrations'
```

Your own artwork works too: place `<genus>-<species>.png` and `<genus>-<species>-2.png` in the same
directory, owned by 1000:1000.

## Step 8: the Home Assistant dashboard

Create a dashboard under Settings → Dashboards → Add dashboard, then paste
`build/home-assistant/dashboards/birds.yaml` into the raw configuration editor (template:
[`snippets/home-assistant/dashboards/birds.yaml`](snippets/home-assistant/dashboards/birds.yaml)). It needs the HACS cards ApexCharts and Mushroom plus the four sensors from step 6.

Three details proved necessary in operation:

- **`fill: zero` in the chart.** `func: diff` returns no value for hours without a data point; without this
  line ApexCharts draws `null` instead of a zero.
- **The logbook points at `sensor.last_bird_species`.** The raw entity would record every empty state as
  "Unknown" and "Unavailable".
- **`entity` on the counter cards.** A tap then opens the entity with its history.

The collage gets a view of its own with `panel: true` and uses the full width.

> **Empty frame?** When the browser refuses the embedding, Saezuri lacks the permission for it. Add a header
> with `frame-ancestors` for your Home Assistant address to the Saezuri virtual host and reload the proxy.
> The Caddyfile snippet carries the line, commented out.

---

## Where to go next

| Question | Document |
|---|---|
| Why this architecture and what each choice costs | [docs/architecture.md](docs/architecture.md) |
| Fewer false positives, more real detections | [docs/tuning.md](docs/tuning.md) |
| Updates, backup, a second camera, rollback | [docs/operations.md](docs/operations.md) |
| Something went wrong | [docs/troubleshooting.md](docs/troubleshooting.md) |
