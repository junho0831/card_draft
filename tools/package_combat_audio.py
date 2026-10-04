#!/usr/bin/env python3
"""Package short CC0 Kenney edits, never synthesize or use AI outputs.

Requires numpy, scipy and soundfile. Run with --check to verify shipped files.
"""
import argparse
import hashlib
import json
from pathlib import Path

import numpy as np
import soundfile as sf
from scipy.signal import butter, sosfilt

ROOT = Path(__file__).resolve().parents[1]
DEST = ROOT / "assets/audio/combat_edited_v1"
SOURCES = {
    "sword_hit": ("rpg", "knifeSlice", 0.30),
    "heavy_hit": ("impact", "impactMining_000", 0.38),
    "arrow_hit": ("impact", "impactWood_light_002", 0.26),
    "wind_hit": ("rpg", "cloth1", 0.32),
    "bone_hit": ("rpg", "chop", 0.30),
    "blood_hit": ("impact", "impactPunch_medium_002", 0.28),
    "poison_hit": ("rpg", "clothBelt2", 0.32),
    "spell_hit": ("rpg", "clothBelt", 0.36),
    "ice_hit": ("impact", "impactGlass_light_000", 0.32),
    "lightning_hit": ("rpg", "metalLatch", 0.28),
    "shadow_hit": ("rpg", "cloth4", 0.34),
    "heal": ("rpg", "handleCoins2", 0.45),
    "summon": ("rpg", "bookOpen", 0.40),
    "ultimate": ("rpg", "knifeSlice2", 0.55),
    "unit_death": ("rpg", "dropLeather", 0.32),
}
PACKS = {
    "rpg": ("https://kenney.nl/assets/rpg-audio", "https://kenney.nl/media/pages/assets/rpg-audio/8e99002d76-1677590336/kenney_rpg-audio.zip"),
    "impact": ("https://kenney.nl/assets/impact-sounds", "https://kenney.nl/media/pages/assets/impact-sounds/87b4ddecda-1677589768/kenney_impact-sounds.zip"),
}


def sha(path):
    return hashlib.sha256(path.read_bytes()).hexdigest()


def metrics(samples, rate):
    mono = samples.mean(axis=1)
    spectrum = np.abs(np.fft.rfft(mono)) ** 2
    low = np.fft.rfftfreq(len(mono), 1 / rate) < 120
    return {
        "seconds": len(samples) / rate,
        "peak": float(np.max(np.abs(samples))),
        "rms": float(np.sqrt(np.mean(samples ** 2))),
        "low_band_ratio": float(spectrum[low].sum() / max(spectrum.sum(), 1e-12)),
        "end_rms": float(np.sqrt(np.mean(samples[-round(rate * 0.01):] ** 2))),
    }


def validate(record):
    path = DEST / record["file"]
    samples, rate = sf.read(path, always_2d=True)
    values = metrics(samples, rate)
    assert np.isfinite(samples).all(), path
    assert sha(path) == record["output_sha256"], path
    assert record["license"] == "CC0-1.0" and record["author"] == "Kenney", path
    assert 0.1 <= values["seconds"] <= SOURCES[record["key"]][2] + 0.01, values
    assert 0.02 < values["peak"] < 0.46, values
    assert 0.005 < values["rms"] < 0.13, values
    assert values["low_band_ratio"] < 0.08, values
    assert values["end_rms"] < 0.01, values
    print(f'PASS {record["key"]}: {values}')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--check", action="store_true")
    parser.add_argument("--source-dir", type=Path, help="Extract the two packs into rpg/ and impact/ subdirectories")
    args = parser.parse_args()
    if args.check:
        records = json.loads((DEST / "manifest.json").read_text())
        assert {r["key"] for r in records} == set(SOURCES)
        for record in records:
            validate(record)
        return
    if args.source_dir is None:
        parser.error("--source-dir is required to rebuild")
    DEST.mkdir(parents=True, exist_ok=True)
    records = []
    for pack in PACKS:
        license_text = (args.source_dir / pack / "License.txt").read_text()
        assert "CC0" in license_text
        (DEST / (pack + "-LICENSE.txt")).write_text(license_text)
    for key, (pack, filename, seconds) in SOURCES.items():
        source = args.source_dir / pack / "Audio" / (filename + ".ogg")
        samples, rate = sf.read(source, always_2d=True)
        samples = sosfilt(butter(6, 200, "highpass", fs=rate, output="sos"), samples, axis=0)
        samples = sosfilt(butter(2, 6500, "lowpass", fs=rate, output="sos"), samples, axis=0)
        block = max(1, round(rate * 0.01))
        blocks = samples[:len(samples) // block * block].reshape(-1, block, samples.shape[1])
        energy = np.mean(blocks ** 2, axis=(1, 2))
        onset = int(np.flatnonzero(energy >= energy.max() * 0.6)[0]) * block
        start = max(0, onset - round(rate * 0.015))
        clip = samples[start:start + round(rate * seconds)].copy()
        fade = min(round(rate * 0.08), len(clip))
        clip[:round(rate * 0.004)] *= np.linspace(0, 1, round(rate * 0.004))[:, None]
        clip[-fade:] *= np.linspace(1, 0, fade)[:, None] ** 2
        rms = np.sqrt(np.mean(clip ** 2))
        clip *= min(0.10 / max(rms, 1e-8), 0.38 / max(np.abs(clip).max(), 1e-8))
        target = DEST / (key + ".ogg")
        sf.write(target, clip, rate, format="OGG", subtype="VORBIS")
        record = {
            "key": key, "file": target.name,
            "source": str(source.relative_to(args.source_dir)), "source_sha256": sha(source),
            "author": "Kenney", "license": "CC0-1.0",
            "license_url": "https://creativecommons.org/publicdomain/zero/1.0/",
            "source_page": PACKS[pack][0], "download_url": PACKS[pack][1],
            "reviewed_on": "2026-10-04",
            "trim_start_seconds": start / rate, "output_sha256": sha(target),
            "duration_seconds": len(clip) / rate,
            "processing": "First substantial transient; short crop; 200 Hz highpass; 6500 Hz lowpass; 4 ms attack / 80 ms squared fade; RMS 0.10 with peak cap 0.38; no pitch change or synthesized layers.",
        }
        validate(record)
        records.append(record)
    (DEST / "manifest.json").write_text(json.dumps(records, ensure_ascii=False, indent=2) + "\n")


if __name__ == "__main__":
    main()
