# Short combat edits

These are edits of Kenney CC0 sound assets, not new recordings or AI outputs.
The 12 impact identities remain distinct.
UI sounds and music are unchanged. Original source packs are retained for
provenance and rebuilding; this pack takes priority for combat only.

`manifest.json` records source hashes, source URLs and exact edits.
Original Kenney licenses are included here. Magic uses short cloth, glass,
metal and coin foley textures rather than synthesized drones or explosions.

Rebuild: `python3 tools/package_combat_audio.py --source-dir /path/to/extracted-packs`
Extract RPG Audio into `rpg/`, Impact Sounds into `impact/` under that directory.
Validate: `python3 tools/package_combat_audio.py --check`
Dependencies: numpy, scipy, soundfile.

Edits keep the first substantial transient, cap the duration at 0.26-0.55 s,
reduce low-frequency energy, soften the upper band, match level with a peak cap,
and fade the final 80 ms. Objective checks do not establish listening comfort;
phone-speaker listening still needs user evaluation.
