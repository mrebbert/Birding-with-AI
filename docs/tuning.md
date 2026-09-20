# Detection quality

## Read the clock before you judge the system

Most detections fall into the first hour after sunrise. A quiet afternoon says nothing about whether the
chain works.

## End-to-end test

Play a recording from [xeno-canto.org](https://xeno-canto.org) loudly at one to two metres from the camera.
When the species appears in the list, every link works: stream, detector, MQTT, template sensors,
dashboard.

## The controls that matter, in order

1. **Microphone gain at the camera** (step 1 of the runbook). The only amplification ahead of compression.
2. **A high-pass filter at 150 Hz** in the BirdNET-Go equalizer. It removes traffic rumble and wind, and
   BirdNET evaluates from 150 Hz upwards anyway.
3. **The range filter.** It weighs all species by region and season, and it catches future candidates of the
   same kind without per-species work. This is the durable control.
4. **The confidence threshold.** Lower it only after a few mornings of data, for instance from 0.8 to 0.7.
   Deep detection absorbs most of the extra false positives.
5. **Per-species thresholds.** Worth it only when a species returns despite an active range filter.

## Removing a false positive

Low, steady continuous noise (a heat pump, a refrigeration unit, traffic) produces hits on species with low
calls. The example from the first day of operation: a little bittern, a bird that breeds in reed beds and
does not call over a suburban garden.

1. Listen to the detection in BirdNET-Go and look at the spectrogram. Machine noise shows as a continuous
   band and is obvious at a glance.
2. Mark the hit as a false positive in BirdNET-Go.
3. Clear the species list in Home Assistant through the `bird_reset` event so the species disappears there
   too.
4. If the tile stays in Saezuri, delete the two images from `/srv/docker/saezuri/illustrations`.

Then raise the range filter rather than the per-species threshold. It generalises; a threshold does not.

## What 13 days of operation showed

Detections arrive every day without gaps, the template sensors hold their state across restarts once the
start trigger is in place, and the collage fills gradually because each species waits for its two images.
The single recurring error source stayed the one named above: low, steady noise.
