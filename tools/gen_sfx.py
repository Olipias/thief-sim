#!/usr/bin/env python3
"""Generate placeholder retro SFX as WAV files (assets/sfx/).

Pure stdlib synthesis, no external deps.  Run:
    python3 tools/gen_sfx.py
"""
import math
import os
import random
import struct
import wave

SR = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "assets", "sfx")


def envelope(t, dur, attack=0.01, release=0.15):
    a = min(1.0, t / attack) if attack > 0 else 1.0
    r = min(1.0, (dur - t) / release) if release > 0 else 1.0
    return max(0.0, min(a, r))


def osc(kind, phase):
    if kind == "sine":
        return math.sin(phase)
    if kind == "square":
        return 1.0 if math.sin(phase) >= 0.0 else -1.0
    if kind == "saw":
        return 2.0 * ((phase / (2.0 * math.pi)) % 1.0) - 1.0
    if kind == "tri":
        frac = (phase / (2.0 * math.pi)) % 1.0
        return 4.0 * abs(frac - 0.5) - 1.0
    raise ValueError(kind)


def tone(freq, dur, kind="square", vol=0.4, attack=0.005, release=0.05):
    out = []
    for i in range(int(SR * dur)):
        t = i / SR
        phase = 2.0 * math.pi * freq * t
        out.append(osc(kind, phase) * vol * envelope(t, dur, attack, release))
    return out


def sweep(f0, f1, dur, kind="square", vol=0.4, release=0.05):
    out = []
    phase = 0.0
    for i in range(int(SR * dur)):
        t = i / SR
        freq = f0 + (f1 - f0) * (t / dur)
        phase += 2.0 * math.pi * freq / SR
        out.append(osc(kind, phase) * vol * envelope(t, dur, 0.005, release))
    return out


def noise(dur, vol=0.4, cutoff=0.25, release=0.1):
    out = []
    y = 0.0
    for i in range(int(SR * dur)):
        t = i / SR
        x = random.uniform(-1.0, 1.0)
        y += cutoff * (x - y)
        out.append(y * vol * envelope(t, dur, 0.005, release))
    return out


def mix(*tracks):
    length = max(len(t) for t in tracks)
    out = [0.0] * length
    for track in tracks:
        for i, s in enumerate(track):
            out[i] += s
    return out


def pad(track, dur):
    target = int(SR * dur)
    if len(track) >= target:
        return track[:target]
    return track + [0.0] * (target - len(track))


def ghost_wail(dur=1.3):
    out = []
    phase = 0.0
    noise_y = 0.0
    random.seed(7)
    for i in range(int(SR * dur)):
        t = i / SR
        vib = 5.0 * math.sin(2.0 * math.pi * 5.5 * t)
        freq = 180.0 + 40.0 * math.sin(2.0 * math.pi * 0.7 * t) + vib
        phase += 2.0 * math.pi * freq / SR
        noise_y += 0.08 * (random.uniform(-1.0, 1.0) - noise_y)
        swell = math.sin(math.pi * t / dur)
        out.append((math.sin(phase) * 0.35 + noise_y * 0.15) * swell)
    return out


SOUNDS = {
    "step": lambda: mix(noise(0.07, vol=0.5, cutoff=0.12, release=0.05), tone(110, 0.07, "sine", 0.25)),
    "pickup": lambda: sweep(660, 990, 0.12, "square", 0.3),
    "coin": lambda: mix(sweep(990, 1320, 0.07, "square", 0.28), pad(sweep(1320, 1760, 0.09, "square", 0.25), 0.16)),
    "denied": lambda: sweep(240, 150, 0.2, "saw", 0.3),
    "alert": lambda: pad(tone(880, 0.11, "square", 0.32), 0.13) + tone(660, 0.11, "square", 0.32),
    "caught": lambda: sweep(440, 90, 0.7, "saw", 0.4, release=0.3),
    "smoke": lambda: noise(0.4, vol=0.55, cutoff=0.06, release=0.3),
    "escape": lambda: pad(tone(523, 0.1, "square", 0.3), 0.11)
    + pad(tone(659, 0.1, "square", 0.3), 0.11)
    + pad(tone(784, 0.1, "square", 0.3), 0.11)
    + tone(1047, 0.28, "square", 0.32, release=0.2),
    "ghost": ghost_wail,
    "blip": lambda: tone(1250, 0.035, "square", 0.16, attack=0.002, release=0.02),
}


def main():
    os.makedirs(OUT, exist_ok=True)
    random.seed(42)
    for name, gen in SOUNDS.items():
        samples = gen()
        path = os.path.join(OUT, name + ".wav")
        with wave.open(path, "w") as w:
            w.setnchannels(1)
            w.setsampwidth(2)
            w.setframerate(SR)
            frames = b"".join(
                struct.pack("<h", max(-32767, min(32767, int(s * 32767)))) for s in samples
            )
            w.writeframes(frames)
        print("  wrote", name + ".wav", "%.2fs" % (len(samples) / SR))


if __name__ == "__main__":
    main()
