# Original synthesized audio — Embers at the Border

Created for Card Draft on 2026-09-10 using `tools/compose_original_audio.py`.

All audio is generated from mathematical oscillators, seeded pseudo-random noise, envelopes and delay taps. The score's note sequence is authored in that script. No third-party recordings, samples, soundfonts, reference melodies, or audio-generation services are inputs. NumPy calculates samples; FFmpeg encodes the resulting PCM as Ogg Vorbis.

- Music: 48 seconds, 80 BPM, 16 bars; one menu theme and four synchronized battle layers.
- Effects: 39 distinct outputs covering every runtime SFX key.
- Output: 32 kHz stereo Ogg Vorbis.
- Rebuild: `python3 tools/compose_original_audio.py` (Python 3, NumPy, FFmpeg required).
- `manifest.json`: generator, seed, duration, decoded levels and SHA-256 for every output.

The previous audio files remain in the repository as historical assets. Runtime custom audio loads exclusively from this directory, with existing procedural synthesis as fallback. Export presets exclude the old source directory and WAV files. This provenance applies only to this directory, not to other existing project assets.
