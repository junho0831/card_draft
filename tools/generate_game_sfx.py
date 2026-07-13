#!/usr/bin/env python3
"""Generate deterministic fantasy TCG sound effects as 16-bit mono WAV files."""

from __future__ import annotations

import math
import random
import wave
from pathlib import Path


SAMPLE_RATE = 44_100
OUT_DIR = Path(__file__).resolve().parents[1] / "assets" / "audio"
RNG = random.Random(916273)


def clamp(value: float, low: float = -1.0, high: float = 1.0) -> float:
    return max(low, min(high, value))


def saturate(value: float, drive: float = 1.0) -> float:
    driven = value * drive
    return clamp(driven / (1.0 + abs(driven) * 0.28))


def env_hit(progress: float, attack: float, decay: float) -> float:
    if progress < attack:
        return progress / max(attack, 0.001)
    return math.exp(-(progress - attack) * decay)


def env_release(progress: float, curve: float = 2.0) -> float:
    return max(0.0, 1.0 - progress) ** curve


def sine(freq: float, t: float, phase: float = 0.0) -> float:
    return math.sin((2.0 * math.pi * freq * t) + phase)


def noise() -> float:
    return RNG.uniform(-1.0, 1.0)


def write_wav(name: str, samples: list[float]) -> None:
    OUT_DIR.mkdir(parents=True, exist_ok=True)
    path = OUT_DIR / f"{name}.wav"
    with wave.open(str(path), "wb") as wav:
        wav.setnchannels(1)
        wav.setsampwidth(2)
        wav.setframerate(SAMPLE_RATE)
        frames = bytearray()
        for sample in samples:
            frames += int(clamp(sample) * 32767.0).to_bytes(2, "little", signed=True)
        wav.writeframes(bytes(frames))


def render(duration: float, fn) -> list[float]:
    total = int(SAMPLE_RATE * duration)
    return [fn(i / SAMPLE_RATE, i / max(1, total - 1)) for i in range(total)]


def click() -> list[float]:
    duration = 0.16

    def sample(t: float, p: float) -> float:
        knock = sine(62.0 - 16.0 * p, t) * math.exp(-p * 18.0) * 0.7
        wood = sine(135.0 - 35.0 * p, t, sine(90.0, t) * 0.5) * math.exp(-p * 13.0) * 0.34
        ring = sine(720.0, t) * math.exp(-p * 8.0) * 0.1
        grit = noise() * math.exp(-p * 24.0) * 0.08
        return saturate(knock + wood + ring + grit, 1.35)

    return render(duration, sample)


def hover() -> list[float]:
    duration = 0.035

    def sample(t: float, p: float) -> float:
        tick = sine(240.0 - 90.0 * p, t) * math.exp(-p * 16.0) * 0.16
        air = noise() * math.exp(-p * 18.0) * 0.035
        return saturate(tick + air, 0.9)

    return render(duration, sample)


def draw() -> list[float]:
    duration = 0.48

    def sample(t: float, p: float) -> float:
        sweep_env = math.sin(math.pi * p)
        paper = noise() * sweep_env * 0.32
        whoosh = sine(420.0 - 270.0 * p, t, sine(42.0, t) * 1.2) * sweep_env * 0.24
        low_slide = sine(144.0 - 68.0 * p, t) * sweep_env * 0.22
        final_tap = sine(92.0, t) * env_hit(max(0.0, (p - 0.72) / 0.28), 0.025, 13.0) * 0.58
        shine = sine(1180.0, t) * math.exp(-max(0.0, p - 0.68) * 13.0) * 0.08
        return saturate(paper + whoosh + low_slide + final_tap + shine, 1.45)

    return render(duration, sample)


def play() -> list[float]:
    duration = 0.82

    def sample(t: float, p: float) -> float:
        impact = env_hit(p, 0.006, 9.5)
        second = env_hit(max(0.0, (p - 0.08) / 0.92), 0.018, 7.5)
        tail = env_release(p, 1.45)
        sub = sine(62.0 - 36.0 * p, t) * impact * 1.15
        table = sine(130.0 - 54.0 * p, t, sine(64.0, t) * 1.0) * impact * 0.58
        slap = noise() * math.exp(-p * 32.0) * 0.34
        after = sine(46.0, t) * second * 0.45
        room = sine(230.0, t) * tail * math.exp(-p * 3.4) * 0.16
        return saturate(sub + table + slap + after + room, 2.55)

    return render(duration, sample)


def summon() -> list[float]:
    duration = 1.08

    def sample(t: float, p: float) -> float:
        rise = min(1.0, p / 0.18)
        portal_env = rise * math.exp(-max(0.0, p - 0.10) * 2.45)
        drop_env = env_hit(max(0.0, (p - 0.18) / 0.82), 0.012, 5.2)
        shock = env_hit(max(0.0, (p - 0.28) / 0.72), 0.008, 8.0)
        portal = sine(220.0 - 148.0 * p, t, sine(48.0, t) * 2.8) * portal_env * 0.52
        sub_drop = sine(52.0 - 28.0 * p, t) * drop_env * 1.05
        shockwave = sine(34.0, t) * shock * 0.76
        shimmer = sine(520.0 - 120.0 * p, t, sine(8.0, t) * 0.8) * portal_env * 0.2
        rune = sine(880.0, t) * math.exp(-max(0.0, p - 0.2) * 6.0) * 0.1
        dust = noise() * portal_env * 0.2
        return saturate(portal + sub_drop + shockwave + shimmer + rune + dust, 2.35)

    return render(duration, sample)


def spell() -> list[float]:
    duration = 0.7

    def sample(t: float, p: float) -> float:
        charge = math.sin(math.pi * p)
        arcane = sine(300.0 + 760.0 * p, t, sine(120.0, t) * 3.2) * charge * 0.4
        low = sine(76.0 - 40.0 * p, t) * math.exp(-p * 4.0) * 0.58
        sparks = noise() * charge * 0.26
        cast_pop = sine(98.0, t) * env_hit(max(0.0, (p - 0.54) / 0.46), 0.012, 8.2) * 0.72
        crackle = sine(1480.0, t) * env_hit(max(0.0, (p - 0.45) / 0.55), 0.02, 10.0) * 0.1
        return saturate(arcane + low + sparks + cast_pop + crackle, 2.0)

    return render(duration, sample)


def heal() -> list[float]:
    duration = 1.18
    notes = [130.81, 164.81, 196.0, 261.63, 329.63]

    def sample(t: float, p: float) -> float:
        chord = 0.0
        for index, note in enumerate(notes):
            chord += sine(note, t, sine(note * 0.33, t) * 0.25) * (0.26 - index * 0.025)
        bell = (sine(523.25, t) + sine(659.25, t) * 0.65 + sine(783.99, t) * 0.4) * math.exp(-p * 2.6) * 0.15
        breath = noise() * math.sin(math.pi * p) * 0.04
        return saturate((chord * env_release(p, 1.65)) + bell + breath, 1.35)

    return render(duration, sample)


def hit() -> list[float]:
    duration = 0.56

    def sample(t: float, p: float) -> float:
        impact = env_hit(p, 0.003, 11.5)
        meat = env_hit(max(0.0, (p - 0.045) / 0.955), 0.012, 9.0)
        body = sine(92.0 - 58.0 * p, t) * impact * 1.2
        thud = sine(44.0, t) * meat * 0.62
        blade = sine(480.0 - 290.0 * p, t, sine(170.0, t) * 1.7) * math.exp(-p * 13.0) * 0.42
        crunch = noise() * math.exp(-p * 18.0) * 0.42
        ring = sine(1040.0, t) * math.exp(-p * 9.0) * 0.12
        return saturate(body + thud + blade + crunch + ring, 2.75)

    return render(duration, sample)


def counter() -> list[float]:
    duration = 0.46

    def sample(t: float, p: float) -> float:
        block = sine(70.0 - 34.0 * p, t) * math.exp(-p * 7.0) * 0.78
        clang = sine(920.0 - 360.0 * p, t, sine(240.0, t) * 0.9) * math.exp(-p * 8.0) * 0.34
        recoil = sine(48.0, t) * env_hit(max(0.0, (p - 0.12) / 0.88), 0.02, 7.0) * 0.34
        grit = noise() * math.exp(-p * 18.0) * 0.24
        return saturate(block + clang + recoil + grit, 2.3)

    return render(duration, sample)


def combo() -> list[float]:
    duration = 0.9

    def sample(t: float, p: float) -> float:
        pulse_a = env_hit((p * 4.0) % 1.0, 0.018, 6.5)
        low = sine(82.0 - 20.0 * p, t) * env_release(p, 1.0) * 0.48
        chant = (sine(220.0 + 210.0 * p, t) * 0.28 + sine(330.0 + 320.0 * p, t) * 0.22) * env_release(p, 1.2)
        pulse = sine(104.0, t) * pulse_a * env_release(p, 0.9) * 0.34
        sparkle = sine(1320.0 + 260.0 * p, t) * pulse_a * 0.08
        dust = noise() * math.exp(-p * 8.0) * 0.1
        return saturate(low + chant + pulse + sparkle + dust, 1.85)

    return render(duration, sample)


def finisher() -> list[float]:
    duration = 1.35

    def sample(t: float, p: float) -> float:
        impact = env_hit(p, 0.002, 4.6)
        sub = sine(96.0 - 74.0 * p, t) * impact * 1.32
        gong = sine(108.0, t, sine(38.0, t) * 0.62) * math.exp(-p * 1.35) * 0.52
        blade = sine(720.0 - 460.0 * p, t) * math.exp(-p * 12.0) * 0.26
        break_noise = noise() * math.exp(-p * 16.0) * 0.46
        aftershock = sine(38.0, t) * env_hit(max(0.0, (p - 0.36) / 0.64), 0.025, 3.4) * 0.52
        second_boom = sine(31.0, t) * env_hit(max(0.0, (p - 0.58) / 0.42), 0.025, 4.2) * 0.38
        shine = sine(1480.0, t) * math.exp(-max(0.0, p - 0.05) * 5.8) * 0.1
        return saturate(sub + gong + blade + break_noise + aftershock + second_boom + shine, 2.9)

    return render(duration, sample)


def reward() -> list[float]:
    duration = 1.08
    notes = [196.0, 246.94, 293.66, 392.0, 493.88]

    def sample(t: float, p: float) -> float:
        sample_value = 0.0
        for idx, note in enumerate(notes):
            note_p = max(0.0, p - idx * 0.11)
            sample_value += sine(note, t) * math.exp(-note_p * 3.8) * (0.25 - idx * 0.025)
        low = sine(73.42, t) * math.exp(-p * 3.0) * 0.24
        glitter = sine(1568.0, t) * math.sin(math.pi * p) * 0.055
        return saturate(sample_value + low + glitter, 1.45)

    return render(duration, sample)


def fanfare(is_win: bool) -> list[float]:
    duration = 2.15 if is_win else 1.75
    notes = [73.42, 98.0, 123.47, 146.83, 196.0] if is_win else [82.41, 73.42, 65.41, 55.0, 49.0]

    def sample(t: float, p: float) -> float:
        idx = min(len(notes) - 1, int(p * len(notes)))
        local = (p * len(notes)) % 1.0
        note = notes[idx]
        horn = (sine(note, t) + sine(note * 1.012, t) * 0.35 + sine(note * 0.988, t) * 0.35)
        horn *= env_hit(local, 0.025, 3.2) * env_release(p, 1.05)
        drum = sine(49.0, t) * math.exp(-local * 13.0) * env_release(p, 1.0) * (0.34 if is_win else 0.24)
        shine = sine(784.0 + 320.0 * p, t) * env_release(p, 1.1) * (0.08 if is_win else 0.02)
        return saturate(horn * (0.42 if is_win else 0.4) + drum + shine, 1.8 if is_win else 1.45)

    return render(duration, sample)


def main() -> None:
    generators = {
        "click": click,
        "hover": hover,
        "draw": draw,
        "play": play,
        "summon": summon,
        "spell": spell,
        "heal": heal,
        "hit": hit,
        "counter": counter,
        "combo": combo,
        "finisher": finisher,
        "reward": reward,
        "victory": lambda: fanfare(True),
        "defeat": lambda: fanfare(False),
    }
    for name, generator in generators.items():
        write_wav(name, generator())
    print(f"Generated {len(generators)} WAV files in {OUT_DIR}")


if __name__ == "__main__":
    main()
