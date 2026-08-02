#!/usr/bin/env python3
"""Build sample-based game SFX from licensed source layers.

The generated WAV files are runtime assets. Source OGG files stay under
assets/audio/source/raw and are documented in sfx_palette.json.
"""

from __future__ import annotations

import subprocess
from pathlib import Path


ROOT = Path(__file__).resolve().parents[1]
OUT = ROOT / "assets" / "audio"
IMPACT = ROOT / "assets" / "audio" / "source" / "raw" / "kenney_impact"
RPG = ROOT / "assets" / "audio" / "source" / "raw" / "kenney_rpg"


def src(name: str) -> Path:
    if (IMPACT / name).exists():
        return IMPACT / name
    if (RPG / name).exists():
        return RPG / name
    raise FileNotFoundError(name)


def layer(
    filename: str,
    volume: float = 1.0,
    delay_ms: int = 0,
    trim: float = 0.55,
    pitch: float = 1.0,
    highpass: int = 90,
    lowpass: int = 9000,
) -> dict:
    return {
        "file": src(filename),
        "volume": volume,
        "delay": delay_ms,
        "trim": trim,
        "pitch": pitch,
        "highpass": highpass,
        "lowpass": lowpass,
    }


RECIPES: dict[str, list[dict]] = {
    "click": [
        layer("metalClick.ogg", 0.52, 0, 0.12, 1.08, 420, 13000),
        layer("impactWood_medium_003.ogg", 0.18, 10, 0.12, 1.35, 260, 9000),
    ],
    "hover": [
        layer("metalClick.ogg", 0.18, 0, 0.08, 1.45, 800, 14000),
    ],
    "hit_human": [
        layer("drawKnife1.ogg", 0.48, 0, 0.24, 1.1, 260, 12000),
        layer("impactMetal_medium_001.ogg", 0.72, 18, 0.28, 0.98, 150, 10000),
        layer("impactPlate_medium_000.ogg", 0.34, 36, 0.22, 0.92, 140, 8500),
    ],
    "hit_elf": [
        layer("knifeSlice.ogg", 0.58, 0, 0.24, 1.22, 260, 13000),
        layer("footstep_grass_002.ogg", 0.38, 24, 0.28, 1.28, 280, 9000),
        layer("impactGlass_light_001.ogg", 0.3, 35, 0.22, 1.35, 500, 14000),
    ],
    "hit_undead": [
        layer("impactWood_medium_003.ogg", 0.68, 0, 0.3, 0.82, 130, 7000),
        layer("clothBelt.ogg", 0.44, 20, 0.34, 0.9, 160, 6500),
        layer("metalLatch.ogg", 0.24, 32, 0.22, 0.8, 180, 8000),
    ],
    "hit_common": [
        layer("impactGeneric_light_002.ogg", 0.74, 0, 0.22, 1.0, 160, 9000),
        layer("impactWood_heavy_001.ogg", 0.35, 16, 0.24, 1.05, 150, 7500),
    ],
    "counter": [
        layer("impactPlate_medium_000.ogg", 0.58, 0, 0.28, 1.0, 160, 9500),
        layer("metalClick.ogg", 0.46, 20, 0.24, 1.18, 260, 12000),
    ],
    "impact_heavy": [
        layer("impactMetal_heavy_000.ogg", 0.76, 0, 0.36, 0.88, 115, 9000),
        layer("impactPlate_heavy_002.ogg", 0.58, 28, 0.34, 0.82, 120, 8500),
        layer("impactBell_heavy_001.ogg", 0.25, 70, 0.68, 0.78, 80, 6500),
        layer("impactWood_heavy_001.ogg", 0.22, 86, 0.28, 0.72, 95, 5200),
    ],
    "direct_attack": [
        layer("drawKnife3.ogg", 0.52, 0, 0.24, 1.16, 280, 13000),
        layer("knifeSlice.ogg", 0.42, 34, 0.22, 1.18, 320, 13000),
        layer("impactMetal_medium_001.ogg", 0.54, 86, 0.26, 0.96, 150, 10000),
        layer("impactBell_heavy_002.ogg", 0.16, 116, 0.44, 0.9, 120, 7000),
    ],
    "summon_human": [
        layer("bookPlace2.ogg", 0.56, 0, 0.34, 0.96, 120, 8000),
        layer("metalClick.ogg", 0.42, 56, 0.24, 1.06, 240, 11000),
        layer("cloth2.ogg", 0.28, 18, 0.28, 1.0, 180, 7500),
    ],
    "summon_elf": [
        layer("bookFlip1.ogg", 0.46, 0, 0.36, 1.12, 180, 11000),
        layer("footstep_grass_002.ogg", 0.46, 34, 0.34, 1.18, 240, 9000),
        layer("impactGlass_light_001.ogg", 0.32, 86, 0.22, 1.35, 500, 14000),
    ],
    "summon_undead": [
        layer("impactWood_heavy_001.ogg", 0.46, 0, 0.34, 0.82, 110, 6500),
        layer("clothBelt.ogg", 0.54, 30, 0.42, 0.74, 130, 6000),
        layer("metalLatch.ogg", 0.25, 88, 0.24, 0.82, 180, 8000),
    ],
    "summon_common": [
        layer("bookPlace2.ogg", 0.52, 0, 0.32, 1.0, 140, 8500),
        layer("impactGeneric_light_002.ogg", 0.3, 42, 0.2, 1.0, 180, 9000),
    ],
    "spell_fire": [
        layer("impactWood_medium_003.ogg", 0.46, 0, 0.3, 1.18, 180, 8000),
        layer("impactGlass_light_001.ogg", 0.42, 24, 0.28, 1.45, 500, 15000),
        layer("impactGeneric_light_002.ogg", 0.34, 52, 0.22, 1.2, 220, 10000),
    ],
    "spell_draw": [
        layer("bookFlip1.ogg", 0.54, 0, 0.36, 1.06, 170, 10000),
        layer("bookFlip2.ogg", 0.38, 58, 0.34, 1.12, 180, 10000),
        layer("cloth2.ogg", 0.2, 24, 0.3, 1.0, 200, 8000),
    ],
    "spell_death": [
        layer("impactWood_heavy_001.ogg", 0.44, 0, 0.34, 0.78, 105, 6500),
        layer("clothBelt.ogg", 0.48, 24, 0.42, 0.78, 120, 6000),
        layer("metalLatch.ogg", 0.3, 70, 0.28, 0.76, 160, 7500),
    ],
    "spell_buff": [
        layer("metalClick.ogg", 0.48, 0, 0.24, 1.05, 220, 12000),
        layer("metalLatch.ogg", 0.36, 48, 0.28, 1.0, 180, 10000),
        layer("impactBell_heavy_002.ogg", 0.24, 78, 0.38, 1.24, 260, 12000),
    ],
    "spell_summon": [
        layer("bookPlace2.ogg", 0.46, 0, 0.34, 0.98, 130, 8500),
        layer("footstep_grass_002.ogg", 0.34, 44, 0.3, 1.12, 220, 9000),
        layer("impactGeneric_light_002.ogg", 0.26, 72, 0.22, 1.05, 180, 9000),
    ],
    "spell_low_hp": [
        layer("metalLatch.ogg", 0.42, 0, 0.28, 0.84, 150, 8500),
        layer("clothBelt.ogg", 0.5, 38, 0.4, 0.72, 110, 6000),
    ],
    "spell_common": [
        layer("bookFlip2.ogg", 0.5, 0, 0.32, 1.02, 160, 9000),
        layer("impactGeneric_light_002.ogg", 0.26, 54, 0.22, 1.0, 180, 9000),
    ],
    "equipment_human": [
        layer("metalClick.ogg", 0.48, 0, 0.24, 1.0, 220, 12000),
        layer("impactPlate_medium_000.ogg", 0.42, 46, 0.28, 1.02, 160, 9500),
    ],
    "equipment_elf": [
        layer("knifeSlice.ogg", 0.34, 0, 0.24, 1.22, 260, 12000),
        layer("impactGlass_light_001.ogg", 0.32, 42, 0.22, 1.34, 500, 14000),
    ],
    "equipment_undead": [
        layer("metalLatch.ogg", 0.42, 0, 0.28, 0.78, 160, 8000),
        layer("impactWood_medium_003.ogg", 0.34, 36, 0.3, 0.84, 130, 6500),
    ],
    "equipment_common": [
        layer("metalClick.ogg", 0.32, 0, 0.24, 1.0, 220, 11000),
        layer("handleSmallLeather.ogg", 0.38, 18, 0.32, 1.0, 160, 8500),
    ],
    "play": [
        layer("bookPlace2.ogg", 0.42, 0, 0.26, 0.92, 120, 7200),
        layer("impactWood_medium_003.ogg", 0.28, 44, 0.18, 1.0, 150, 6500),
        layer("metalClick.ogg", 0.18, 72, 0.16, 1.18, 340, 11000),
    ],
    "draw": [
        layer("bookFlip1.ogg", 0.36, 0, 0.28, 1.08, 210, 11000),
        layer("bookFlip2.ogg", 0.24, 44, 0.24, 1.16, 220, 11000),
        layer("cloth2.ogg", 0.12, 18, 0.22, 1.05, 280, 9000),
    ],
    "summon": [
        layer("bookPlace2.ogg", 0.42, 0, 0.32, 1.0, 140, 8500),
        layer("impactGeneric_light_002.ogg", 0.22, 50, 0.2, 1.0, 180, 9000),
    ],
    "hit": [
        layer("impactMetal_medium_001.ogg", 0.58, 0, 0.28, 1.0, 150, 10000),
        layer("impactGeneric_light_002.ogg", 0.24, 24, 0.2, 1.0, 180, 9000),
    ],
    "spell": [
        layer("bookFlip2.ogg", 0.38, 0, 0.32, 1.08, 170, 10000),
        layer("impactGlass_light_001.ogg", 0.26, 42, 0.22, 1.28, 480, 14000),
    ],
    "combo": [
        layer("impactBell_heavy_002.ogg", 0.38, 0, 0.46, 1.12, 220, 11000),
        layer("metalClick.ogg", 0.24, 56, 0.22, 1.08, 240, 12000),
    ],
    "finisher": [
        layer("impactBell_heavy_001.ogg", 0.55, 0, 0.78, 0.88, 110, 9000),
        layer("impactPlate_heavy_002.ogg", 0.42, 80, 0.4, 0.9, 120, 8500),
        layer("knifeSlice.ogg", 0.28, 36, 0.24, 1.18, 220, 12000),
    ],
    "victory_burst": [
        layer("impactBell_heavy_001.ogg", 0.46, 0, 0.9, 0.96, 130, 9500),
        layer("impactPlate_heavy_002.ogg", 0.3, 120, 0.38, 0.9, 120, 8500),
        layer("impactBell_heavy_002.ogg", 0.32, 230, 0.8, 1.14, 190, 11000),
        layer("handleCoins.ogg", 0.24, 510, 0.48, 1.12, 240, 12000),
    ],
}


ALIASES = {
    "power_human": "summon_human",
    "power_elf": "summon_elf",
    "power_undead": "spell_death",
    "reward": "victory_burst",
}


def repeated(
    filename: str,
    every_ms: int,
    count: int,
    volume: float,
    start_ms: int = 0,
    trim: float = 0.34,
    pitch: float = 1.0,
    highpass: int = 90,
    lowpass: int = 9000,
) -> list[dict]:
    return [
        layer(filename, volume, start_ms + every_ms * index, trim, pitch, highpass, lowpass)
        for index in range(count)
    ]


BGM_RECIPES: dict[str, list[dict]] = {
    "battle_base": [
        *repeated("cloth2.ogg", 1600, 5, 0.055, 180, 0.24, 0.9, 220, 5200),
        *repeated("bookFlip1.ogg", 3200, 3, 0.055, 620, 0.2, 0.84, 240, 5000),
        *repeated("impactBell_heavy_002.ogg", 4000, 2, 0.07, 1300, 0.34, 0.62, 90, 2400),
    ],
    "battle_tension": [
        *repeated("metalLatch.ogg", 1800, 5, 0.095, 220, 0.2, 0.92, 170, 6200),
        *repeated("impactPlate_medium_000.ogg", 2400, 4, 0.08, 720, 0.2, 0.78, 120, 3800),
        *repeated("knifeSlice.ogg", 3200, 3, 0.06, 1120, 0.18, 1.12, 320, 8200),
    ],
    "battle_lethal": [
        *repeated("impactBell_heavy_002.ogg", 2200, 4, 0.16, 0, 0.38, 0.98, 120, 6000),
        *repeated("drawKnife1.ogg", 1400, 6, 0.08, 360, 0.16, 1.22, 340, 9000),
        *repeated("impactMetal_light_003.ogg", 2800, 3, 0.085, 980, 0.18, 1.08, 200, 8200),
    ],
    "battle_low_hp": [
        *repeated("impactWood_heavy_001.ogg", 1600, 5, 0.11, 0, 0.2, 0.58, 80, 2400),
        *repeated("clothBelt.ogg", 1600, 5, 0.07, 260, 0.24, 0.68, 130, 3600),
        *repeated("metalLatch.ogg", 3200, 3, 0.075, 620, 0.22, 0.78, 160, 5200),
    ],
}


def build_one(name: str, recipe: list[dict]) -> None:
    output = OUT / f"{name}.wav"
    cmd = ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error"]
    for item in recipe:
        cmd.extend(["-i", str(item["file"])])

    filters: list[str] = []
    labels: list[str] = []
    for index, item in enumerate(recipe):
        label = f"a{index}"
        pitch = float(item["pitch"])
        chain = [
            f"atrim=0:{float(item['trim']):.3f}",
            "asetpts=PTS-STARTPTS",
        ]
        if abs(pitch - 1.0) > 0.001:
            chain.append(f"asetrate=44100*{pitch:.4f}")
            chain.append("aresample=44100")
        chain.extend(
            [
                f"highpass=f={int(item['highpass'])}",
                f"lowpass=f={int(item['lowpass'])}",
                f"volume={float(item['volume']):.3f}",
                "afade=t=out:st=0.18:d=0.24",
                f"adelay={int(item['delay'])}:all=1",
                "aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=mono",
            ]
        )
        filters.append(f"[{index}:a]" + ",".join(chain) + f"[{label}]")
        labels.append(f"[{label}]")

    mix = "".join(labels) + f"amix=inputs={len(labels)}:duration=longest:normalize=0"
    mix += ",alimiter=limit=0.82,volume=0.86,atrim=0:2.3,asetpts=PTS-STARTPTS,aformat=sample_fmts=s16:sample_rates=44100:channel_layouts=mono[out]"
    filters.append(mix)
    cmd.extend(["-filter_complex", ";".join(filters), "-map", "[out]", "-ac", "1", "-ar", "44100", str(output)])
    subprocess.run(cmd, check=True)


def build_music_one(name: str, recipe: list[dict]) -> None:
    output = OUT / f"{name}.wav"
    cmd = ["ffmpeg", "-y", "-hide_banner", "-loglevel", "error"]
    for item in recipe:
        cmd.extend(["-i", str(item["file"])])

    filters: list[str] = []
    labels: list[str] = []
    for index, item in enumerate(recipe):
        label = f"m{index}"
        pitch = float(item["pitch"])
        chain = [
            f"atrim=0:{float(item['trim']):.3f}",
            "asetpts=PTS-STARTPTS",
        ]
        if abs(pitch - 1.0) > 0.001:
            chain.append(f"asetrate=44100*{pitch:.4f}")
            chain.append("aresample=44100")
        chain.extend(
            [
                f"highpass=f={int(item['highpass'])}",
                f"lowpass=f={int(item['lowpass'])}",
                f"volume={float(item['volume']):.3f}",
                "afade=t=out:st=0.16:d=0.28",
                f"adelay={int(item['delay'])}:all=1",
                "aformat=sample_fmts=fltp:sample_rates=44100:channel_layouts=mono",
            ]
        )
        filters.append(f"[{index}:a]" + ",".join(chain) + f"[{label}]")
        labels.append(f"[{label}]")

    mix = "".join(labels) + f"amix=inputs={len(labels)}:duration=longest:normalize=0"
    mix += ",alimiter=limit=0.72,volume=0.72,atrim=0:8.0,afade=t=in:st=0:d=0.08,afade=t=out:st=7.88:d=0.12,asetpts=PTS-STARTPTS,aformat=sample_fmts=s16:sample_rates=44100:channel_layouts=mono[out]"
    filters.append(mix)
    cmd.extend(["-filter_complex", ";".join(filters), "-map", "[out]", "-ac", "1", "-ar", "44100", str(output)])
    subprocess.run(cmd, check=True)


def copy_alias(name: str, source_name: str) -> None:
    (OUT / f"{name}.wav").write_bytes((OUT / f"{source_name}.wav").read_bytes())


def main() -> None:
    OUT.mkdir(parents=True, exist_ok=True)
    for name, recipe in RECIPES.items():
        build_one(name, recipe)
    for name, recipe in BGM_RECIPES.items():
        build_music_one(name, recipe)
    for name, source_name in ALIASES.items():
        copy_alias(name, source_name)
    print(f"Built {len(RECIPES) + len(BGM_RECIPES) + len(ALIASES)} authored sample-based audio files in {OUT}")


if __name__ == "__main__":
    main()
