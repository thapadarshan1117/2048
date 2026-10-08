#!/usr/bin/env python3
"""Synthesises the game's audio assets with the Python standard library.

Every sound and the music loop are original work generated here - no third
party audio, no licensed samples, no recordings. The output is plain PCM WAV at
44.1 kHz, 16-bit, mono, which Flame loads on every platform without a codec
dependency.

Usage:
    python3 tool/generate_audio.py [--out assets]
"""
from __future__ import annotations

import argparse
import math
import struct
import sys
import wave
from pathlib import Path

SAMPLE_RATE = 44100

# Sound effects: (name, generator parameters).
# Each is a short, distinct, "juicy" cue that reads clearly on a phone speaker.
SOUNDS = {
    "button.wav": ("click", 0.075),
    "drop.wav": ("thud", 0.13),
    "merge.wav": ("blip", 0.16),
    "big_merge.wav": ("fanfare", 0.42),
    "combo.wav": ("arpeggio", 0.30),
    "booster.wav": ("sweep", 0.26),
    "level_complete.wav": ("fanfare", 0.75),
    "level_failed.wav": ("descend", 0.55),
    "reward.wav": ("arpeggio", 0.40),
}

MUSIC = {
    "music_menu.wav": ("calm", 24.0),
    "music_game.wav": ("drive", 24.0),
}


def _envelope(t: float, duration: float, attack: float = 0.01) -> float:
    """Linear attack, exponential release. Keeps every cue click-free."""
    if t < attack:
        return t / attack
    release = duration - t
    if release <= 0:
        return 0.0
    return max(0.0, release / max(duration * 0.35, 1e-6))


def _tone(
    t: float,
    freq: float,
    kind: str,
    duration: float,
) -> float:
    env = _envelope(t, duration)
    phase = 2 * math.pi * freq * t
    if kind == "sine":
        wave_value = math.sin(phase)
    elif kind == "square":
        wave_value = 1.0 if math.sin(phase) >= 0 else -1.0
    elif kind == "saw":
        wave_value = 2.0 * ((freq * t) % 1.0) - 1.0
    elif kind == "tri":
        wave_value = 2.0 * abs(2.0 * ((freq * t) % 1.0) - 1.0) - 1.0
    else:
        wave_value = math.sin(phase)
    return wave_value * env


def _noise(t: float, duration: float, seed: int = 1) -> float:
    """Deterministic pseudo-noise, so builds are reproducible."""
    state = seed * 2654435761 % (2**32)
    value = 0.0
    for _ in range(3):
        state = (1103515245 * state + 12345) % (2**32)
        value += (state / 2**32) * 2 - 1
    return value * _envelope(t, duration, attack=0.002) * 0.25


def render(name: str, kind: str, duration: float) -> list[int]:
    frames = int(SAMPLE_RATE * duration)
    out: list[int] = []
    for i in range(frames):
        t = i / SAMPLE_RATE
        if kind == "click":
            value = _tone(t, 880, "square", duration) * 0.5
            value += _noise(t, duration, seed=i) * 0.3
        elif kind == "thud":
            freq = 180 * math.exp(-t * 12)
            value = _tone(t, freq, "sine", duration) * 0.85
            value += _noise(t, duration * 0.5, seed=7) * 0.4
        elif kind == "blip":
            freq = 520 * (1 + 0.6 * (t / duration))
            value = _tone(t, freq, "tri", duration) * 0.7
        elif kind == "fanfare":
            notes = [523.25, 659.25, 783.99, 1046.5]
            index = min(int(t / duration * len(notes)), len(notes) - 1)
            value = _tone(t, notes[index], "tri", duration / len(notes) * 1.6) * 0.7
            value += _tone(t, notes[index] / 2, "sine", duration) * 0.35
        elif kind == "arpeggio":
            notes = [392.0, 523.25, 659.25, 783.99]
            index = min(int(t / duration * len(notes)), len(notes) - 1)
            value = _tone(t, notes[index], "tri", duration / len(notes) * 1.4) * 0.7
        elif kind == "sweep":
            freq = 300 + 900 * (t / duration)
            value = _tone(t, freq, "saw", duration) * 0.45
        elif kind == "descend":
            freq = 400 * math.exp(-t * 3.2)
            value = _tone(t, freq, "sine", duration) * 0.8
        elif kind == "calm":
            # Slow arpeggio over a sustained pad.
            chord = [261.63, 329.63, 392.0, 493.88]
            step = int(t * 2) % len(chord)
            value = _tone(t, chord[step], "sine", 0.5) * 0.22
            value += _tone(t, chord[(step + 2) % len(chord)], "tri", 0.5) * 0.14
            value += math.sin(2 * math.pi * 130.81 * t) * 0.08
        elif kind == "drive":
            chord = [293.66, 369.99, 440.0, 587.33]
            step = int(t * 4) % len(chord)
            value = _tone(t, chord[step], "square", 0.25) * 0.13
            value += _tone(t, chord[step] / 2, "saw", 0.25) * 0.10
            value += math.sin(2 * math.pi * 98 * t) * 0.10
        else:
            value = 0.0
        out.append(int(max(-1.0, min(1.0, value)) * 30000))
    return out


def write_wav(path: Path, frames: list[int]) -> None:
    path.parent.mkdir(parents=True, exist_ok=True)
    with wave.open(str(path), "wb") as handle:
        handle.setnchannels(1)
        handle.setsampwidth(2)
        handle.setframerate(SAMPLE_RATE)
        handle.writeframes(b"".join(struct.pack("<h", f) for f in frames))


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("--out", default="assets")
    args = parser.parse_args()

    root = Path(args.out)
    total = 0
    for name, (kind, duration) in SOUNDS.items():
        frames = render(name, kind, duration)
        write_wav(root / "sounds" / name, frames)
        total += len(frames)
    for name, (kind, duration) in MUSIC.items():
        frames = render(name, kind, duration)
        write_wav(root / "music" / name, frames)
        total += len(frames)

    print(f"wrote {len(SOUNDS)} sound effects and {len(MUSIC)} music tracks")
    print(f"{total} frames total ({total / SAMPLE_RATE:.1f}s of audio)")
    return 0


if __name__ == "__main__":
    sys.exit(main())
