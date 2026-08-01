# Audio Source Kit

This folder is for authored sound source material before it becomes runtime WAV files in `assets/audio`.

The game should not depend on files in this folder at runtime. Runtime audio stays in `assets/audio/*.wav`, and `AudioManager` loads those files first with generated fallback streams behind them.

## Goal

Move the game away from pure code-synth SFX toward authored, card-driven sound.

Each final SFX should feel like a short layered game asset:

- `body`: the short impact or magical core.
- `texture`: metal, paper, fire, wind, bone, dust, breath, or cloth detail.
- `tail`: a controlled decay that gives weight without a repeated drum feel.

Avoid long 30-80Hz pulses. Those read as uncomfortable `dung-dung` on headphones and laptop speakers.

## Source Layout

```text
assets/audio/source/
  README.md
  sfx_palette.json
  raw/        original recorded or downloaded source clips, not used by runtime
  work/       edited layered sessions or intermediate exports
  refs/       reference notes or short descriptions, not copyrighted audio
```

Keep licensed or downloaded assets documented in `sfx_palette.json`. Do not add files with unclear rights.

## Palette Direction

- Human: metal guard, shield edge, leather armor, short command accent.
- Elf: bow string, wind, leaf sweep, light magic shimmer.
- Undead: dry bone crack, brittle scrape, ghost breath, low tone kept short.
- Common: neutral card cloth, paper, table tap, simple magic click.
- Fire: quick flame burst, spark crackle, hot air snap.
- Draw: paper sweep, light chime, fast upward motion.
- Buff: metal/rune lock-in, stat rise, clean confirmation.
- Summon: arrival shimmer plus short landing, not a long thump.
- Death: brittle break plus soul pull, short and dry.
- Low HP: heartbeat-like tension only as a quick accent, not a loop.

Adaptive battle BGM uses four low-volume loop layers:

- `battle_base.wav`: normal board state.
- `battle_tension.wav`: boss or incoming enemy pressure.
- `battle_lethal.wav`: enemy is low or the player has a winning attack.
- `battle_low_hp.wav`: player hero is in danger.

## Export Rules

- Format: WAV, mono, 44.1kHz, 16-bit PCM.
- Target length: 0.25s to 0.75s for normal actions.
- Victory and defeat may be 1.5s to 2.5s.
- Battle BGM loops should be about 8s and sit under combat SFX.
- Peak: below -1 dBFS.
- Perceived loudness should be lower than current combat visuals imply; repeated sounds must be comfortable.
- Runtime filenames must match `sfx_palette.json` and `tools/generate_game_sfx.gd`.

Build authored runtime WAVs from the committed source layers with:

```bash
python3 tools/build_authored_sfx.py
```

Generate ElevenLabs text-to-sound runtime WAVs with:

```bash
ELEVENLABS_API_KEY=... python3 tools/build_elevenlabs_sfx.py
```

Never commit or document the API key. The script stores generated MP3 sources in
`assets/audio/source/raw/elevenlabs` and exports final WAV files to
`assets/audio`.

Use `tools/generate_game_sfx.gd` only as a fallback generator when no authored source layer exists yet.

## First Replacement Targets

Replace these first because they drive most combat feel:

- `hit_human.wav`
- `hit_elf.wav`
- `hit_undead.wav`
- `impact_heavy.wav`
- `summon_human.wav`
- `summon_elf.wav`
- `summon_undead.wav`
- `spell_fire.wav`
- `spell_death.wav`
- `victory_burst.wav`
- `battle_base.wav`
- `battle_tension.wav`
- `battle_lethal.wav`
- `battle_low_hp.wav`

These targets now have authored sample-based exports. The generated versions remain fallback only.

## Current Source Packs

- Kenney Impact Sounds: https://kenney.nl/assets/impact-sounds
- Kenney RPG Audio: https://kenney.nl/assets/rpg-audio
- ElevenLabs Text to Sound Effects API: https://elevenlabs.io/docs/api-reference/text-to-sound-effects/convert

Both Kenney packs are listed by Kenney as Creative Commons CC0. The committed
`raw/kenney_*` files are selected source layers from those packs, not full
packs. ElevenLabs generated files are project-specific generated outputs from
the user's account; usage must follow that account's ElevenLabs terms.
