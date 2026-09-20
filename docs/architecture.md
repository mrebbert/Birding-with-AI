# Architecture decisions

Each decision below shaped the installation. They are written as "we chose X because Y", so you can reverse
any of them knowingly.

## The camera talks to BirdNET-Go directly

A restreamer such as go2rtc in between adds a component to operate and to debug. ffmpeg inside the
BirdNET-Go container reads the RTSP stream on its own and reconnects after an interruption. Put a
restreamer in when several consumers need the same stream, or when the camera tolerates only one client.

## Plain RTSP inside the trusted network

Port 7447 carries RTSP, port 7441 carries RTSPS. The unencrypted variant inside a private network spares
you TLS corner cases in ffmpeg, and the stream never leaves the local segment. Reach for RTSPS when the
path crosses a network you do not control.

## The wide-band audio track

UniFi Protect carries two audio tracks:

| Track | Sample rate | Usable up to | Fits BirdNET |
|---|---|---|---|
| AAC | 16 kHz mono | 8 kHz | partly |
| Opus | 48 kHz stereo | 24 kHz | yes |

BirdNET evaluates up to 15 kHz. Only the Opus track covers that range, and ffmpeg selects it on its own.
Cameras with a single 16 kHz track still work, they just lose the high calls: treecreepers, goldcrests, and
most warbler alarm calls sit above 8 kHz.

## The web interface instead of a handwritten `config.yaml`

The key names in BirdNET-Go's configuration file have changed several times between versions. The container
writes the file itself and reloads changes without a restart, so clicking through the settings pages stays
correct across upgrades while a copied file silently stops matching. The key names in the runbook serve as
a reference for reading `config.yaml`, not as a template to write.

## BirdNET v2.4 rather than Google Perch v2

Perch recognises around 14,800 species against BirdNET's roughly 6,500, and it needs ONNX plus noticeably
more CPU. One audio stream on BirdNET v2.4 costs about a third of an Athlon 3000G. Measure your base load
before you trade that for the larger species set.

## Both containers bind to loopback

`127.0.0.1:8081` and `127.0.0.1:8090` keep the interfaces off the network. The reverse proxy is the single
entry point, which puts TLS and access control in one place. The BirdNET-Go interface contains a browser
terminal with access to the container, so its password matters even at home.

## Saezuri reads BirdNET-Go over the Compose network

Saezuri addresses `http://birdnet-go:8080`, the container name and the container port, not the published
loopback port. The two services share a Compose network, so the detour through the host stays unnecessary.

## Images stay on `latest`

Both projects move fast and ship fixes worth having. The rollback path runs over the digest of the previous
image, which stays available locally after a pull. See [operations.md](operations.md#updates).

## Local inference, outbound connections by exception

The detector, the database and both web interfaces run on one machine with no dependency on a remote
service. That decision costs the species set a cloud model could offer and buys independence from an
account, an API quota and a provider's lifetime. The exceptions are listed in the
[README](../README.md#local-by-default): artwork downloads, reference calls, optional artwork generation,
image pulls. None of them carries audio, and each one has an off switch.

## Detections persist, audio does not

Audio export stays off and the privacy filter stays on. The SQLite database under
`/srv/docker/birdnet-go/data` keeps every detection with timestamp, species, and confidence; that is the
record worth backing up. Spectrograms of recent detections live in a tmpfs and disappear on restart by
design.
