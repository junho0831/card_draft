#!/usr/bin/env python3
"""Generate runtime game SFX with ElevenLabs text-to-sound.

Requires ELEVENLABS_API_KEY in the environment. The key is never written to disk.
Generated MP3 sources are stored under assets/audio/source/raw/elevenlabs, then
converted to runtime WAV files under assets/audio.
"""

from __future__ import annotations

import argparse
import json
import os
import subprocess
import sys
import time
import urllib.error
import urllib.request
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "audio"
RAW = ROOT / "assets" / "audio" / "source" / "raw" / "elevenlabs"
API_URL = "https://api.elevenlabs.io/v1/sound-generation"


SFX: dict[str, dict] = {
    "play": {
        "duration": 0.8,
        "prompt": "premium fantasy trading card placed onto a game board, crisp leather card slap, subtle magical rune snap, no voice, no music",
    },
    "draw": {
        "duration": 0.8,
        "prompt": "fantasy card drawn from a deck, fast parchment swipe with tiny magical shimmer, clean and satisfying, no voice, no music",
    },
    "hit_human": {
        "duration": 0.9,
        "prompt": "dark fantasy human warrior sword impact, steel blade hits armor and shield, heavy but short, satisfying combat hit, no voice, no music",
    },
    "hit_elf": {
        "duration": 0.9,
        "prompt": "elven wind blade slash impact, fast bowstring snap, airy magical cut, bright forest magic, no voice, no music",
    },
    "hit_undead": {
        "duration": 1.0,
        "prompt": "undead bone weapon impact, brittle bone crack and dark soul burst, dry heavy hit, no voice, no music",
    },
    "hit_common": {
        "duration": 0.85,
        "prompt": "neutral fantasy creature impact, wood and leather strike, compact battle hit, no voice, no music",
    },
    "impact_heavy": {
        "duration": 1.2,
        "prompt": "massive dark fantasy battle impact, armor crunch, magical shockwave, powerful screen shake moment, no voice, no music",
    },
    "summon_human": {
        "duration": 1.1,
        "prompt": "human knight card summoned onto battlefield, armored boots land, banner flare, steel and holy glow, no voice, no music",
    },
    "summon_elf": {
        "duration": 1.1,
        "prompt": "elven unit summoned onto battlefield, wind swirl, leaves burst, elegant magic arrival, no voice, no music",
    },
    "summon_undead": {
        "duration": 1.2,
        "prompt": "undead minion summoned from dark magic, bones assemble, grave dust and soul whoosh, no voice, no music",
    },
    "summon_common": {
        "duration": 1.0,
        "prompt": "neutral fantasy card creature summoned, short magical landing and table impact, no voice, no music",
    },
    "spell_fire": {
        "duration": 1.0,
        "prompt": "fantasy fire spell cast and hits target, explosive flame burst with sparks, punchy and short, no voice, no music",
    },
    "spell_death": {
        "duration": 1.1,
        "prompt": "dark necromancy spell, soul drain then bone crack impact, sinister but short, no voice, no music",
    },
    "spell_buff": {
        "duration": 1.0,
        "prompt": "fantasy stat buff spell, armor rune locks in, rising magical power shimmer, satisfying upgrade, no voice, no music",
    },
    "spell_draw": {
        "duration": 1.0,
        "prompt": "fantasy card draw magic, pages flick rapidly with blue arcane shimmer and satisfying upward sparkle, no voice, no music",
    },
    "spell_summon": {
        "duration": 1.1,
        "prompt": "summoning spell creates a battlefield portal, magical card energy condenses then lands, no voice, no music",
    },
    "spell_low_hp": {
        "duration": 1.0,
        "prompt": "low health survival magic, tense heartbeat accent then healing spark and defensive rune pulse, no voice, no music",
    },
    "spell_common": {
        "duration": 0.9,
        "prompt": "generic fantasy spell card cast, clean arcane whoosh and tiny impact sparkle, no voice, no music",
    },
    "equipment_human": {
        "duration": 0.9,
        "prompt": "human knight equipment equipped, metal armor buckle, sword unsheathe, confident fantasy upgrade, no voice, no music",
    },
    "equipment_elf": {
        "duration": 0.9,
        "prompt": "elven equipment equipped, bowstring tighten, wind charm shimmer, elegant fantasy upgrade, no voice, no music",
    },
    "equipment_undead": {
        "duration": 0.95,
        "prompt": "undead equipment equipped, rusty chain lock, bone charm crackle, dark fantasy upgrade, no voice, no music",
    },
    "equipment_common": {
        "duration": 0.85,
        "prompt": "neutral fantasy equipment equipped, leather strap pull and small metal click, no voice, no music",
    },
    "power_human": {
        "duration": 1.3,
        "prompt": "human faction ultimate ability, royal rally, shield wall slam, heroic metal impact and banner flare, no voice, no music",
    },
    "power_elf": {
        "duration": 1.3,
        "prompt": "elf faction ultimate ability, rushing wind circle, magical leaves, elegant energy surge, no voice, no music",
    },
    "power_undead": {
        "duration": 1.4,
        "prompt": "undead faction ultimate ability, dark pact, soul drain, bones rise from grave dust, powerful low impact, no voice, no music",
    },
    "combo": {
        "duration": 1.0,
        "prompt": "fantasy card combo trigger, three quick magical locks then bright reward burst, satisfying, no voice, no music",
    },
    "counter": {
        "duration": 0.9,
        "prompt": "fantasy counterattack impact, shield parry then quick return slash, compact and readable, no voice, no music",
    },
    "reward": {
        "duration": 1.2,
        "prompt": "fantasy card reward pickup, gold sparkle and magical chest chime, short dopamine reward, no voice, no music",
    },
    "finisher": {
        "duration": 1.5,
        "prompt": "cinematic dark fantasy finishing blow, huge magical weapon impact, bright burst, heavy final slam, no voice, no music",
    },
    "victory_burst": {
        "duration": 2.0,
        "prompt": "short dark fantasy victory burst for a card battle, triumphant magic flare, gold chime, powerful dopamine reward, no voice, no long music",
    },
}


def request_sound(api_key: str, name: str, spec: dict) -> bytes:
    payload = {
        "text": spec["prompt"],
        "duration_seconds": spec["duration"],
        "prompt_influence": 0.58,
        "model_id": "eleven_text_to_sound_v2",
    }
    request = urllib.request.Request(
        f"{API_URL}?output_format=mp3_44100_128",
        data=json.dumps(payload).encode("utf-8"),
        headers={
            "xi-api-key": api_key,
            "Content-Type": "application/json",
            "Accept": "audio/mpeg",
        },
        method="POST",
    )
    try:
        with urllib.request.urlopen(request, timeout=120) as response:
            return response.read()
    except urllib.error.HTTPError as exc:
        detail = exc.read().decode("utf-8", errors="replace")
        raise RuntimeError(f"{name}: ElevenLabs HTTP {exc.code}: {detail}") from exc


def convert_to_wav(name: str) -> None:
    source = RAW / f"{name}.mp3"
    target = OUT / f"{name}.wav"
    cmd = [
        "ffmpeg",
        "-y",
        "-hide_banner",
        "-loglevel",
        "error",
        "-i",
        str(source),
        "-af",
        "highpass=f=45,lowpass=f=15500,alimiter=limit=0.86,volume=0.90,aformat=sample_fmts=s16:sample_rates=44100:channel_layouts=mono",
        "-ac",
        "1",
        "-ar",
        "44100",
        str(target),
    ]
    subprocess.run(cmd, check=True)


def main() -> int:
    parser = argparse.ArgumentParser()
    parser.add_argument("--force", action="store_true", help="Regenerate existing ElevenLabs source MP3 files.")
    parser.add_argument("--only", nargs="*", default=[], help="Optional list of SFX keys to generate.")
    args = parser.parse_args()

    api_key = os.environ.get("ELEVENLABS_API_KEY", "").strip()
    if not api_key:
        print("ELEVENLABS_API_KEY is required.", file=sys.stderr)
        return 2

    names = args.only if args.only else list(SFX.keys())
    unknown = [name for name in names if name not in SFX]
    if unknown:
        print(f"Unknown SFX keys: {', '.join(unknown)}", file=sys.stderr)
        return 2

    RAW.mkdir(parents=True, exist_ok=True)
    OUT.mkdir(parents=True, exist_ok=True)

    for index, name in enumerate(names, start=1):
        source = RAW / f"{name}.mp3"
        if args.force or not source.exists():
            print(f"[{index}/{len(names)}] Generating {name}")
            source.write_bytes(request_sound(api_key, name, SFX[name]))
            time.sleep(0.4)
        else:
            print(f"[{index}/{len(names)}] Reusing {name}")
        convert_to_wav(name)

    print(f"Built {len(names)} ElevenLabs SFX into {OUT}")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
