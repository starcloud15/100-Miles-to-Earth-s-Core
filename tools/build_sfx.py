"""The game's sound effects, synthesised (no samples, no licences), written as
OGG into assets/audio/sfx/ for Starport (group "sounds" -> Assets.sounds.<Name>).

    python tools/build_sfx.py            (all)
    ONLY=Pop,Mine python tools/build_sfx.py

Each sound is built from noise, oscillators and envelopes, then filtered,
normalised and faded so it loops or ends cleanly.
"""

import os
import subprocess
import tempfile

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio", "sfx")
rng = np.random.default_rng(7)


def t(sec):
    return np.arange(int(sec * SR)) / SR


def noise(sec):
    return rng.uniform(-1, 1, int(sec * SR))


def lp(x, hz, order=4):
    return sosfilt(butter(order, hz, "low", fs=SR, output="sos"), x)


def hp(x, hz, order=4):
    return sosfilt(butter(order, hz, "high", fs=SR, output="sos"), x)


def bp(x, lo, hi, order=4):
    return sosfilt(butter(order, [lo, hi], "band", fs=SR, output="sos"), x)


def env(n, attack, decay, sustain=0.0, curve=4.0):
    """attack seconds, then an exponential fall over the rest (to `sustain`)."""
    a = int(attack * SR)
    out = np.ones(n)
    if a > 0:
        out[:a] = np.linspace(0, 1, a)
    rest = np.arange(n - a) / SR
    out[a:] = sustain + (1 - sustain) * np.exp(-rest * curve / max(decay, 1e-3))
    return out


def tone(freqs, sec, amps=None, glide=None):
    tt = t(sec)
    out = np.zeros_like(tt)
    for i, f in enumerate(freqs):
        fr = f if glide is None else np.linspace(f, f * glide, len(tt))
        phase = 2 * np.pi * np.cumsum(fr) / SR
        out += (amps[i] if amps else 1) * np.sin(phase)
    return out


def fit(*parts):
    n = max(len(p) for p in parts)
    return [np.pad(p, (0, n - len(p))) for p in parts]


def finish(x, peak=0.9, fade=0.01, loop=False):
    x = x - np.mean(x)
    if loop:
        # crossfade the tail into the head so it loops without a click
        f = int(0.25 * SR)
        head, tail = x[:f].copy(), x[-f:].copy()
        w = np.linspace(0, 1, f)
        x = x[:-f]
        x[:f] = head * w + tail * (1 - w)
    else:
        f = int(fade * SR)
        x[:f] *= np.linspace(0, 1, f)
        x[-f * 4:] *= np.linspace(1, 0, f * 4)
    m = np.max(np.abs(x)) or 1
    return (x / m * peak).astype(np.float32)


# --- the sounds --------------------------------------------------------------------

def mine():
    # a pickaxe biting crystal: a bright clink over a rocky thud and grit
    n = int(0.55 * SR)
    clink = tone([1870, 2630, 3910], 0.55, [1, 0.6, 0.35]) * env(n, 0.001, 0.12)
    thud = lp(noise(0.55), 260) * env(n, 0.001, 0.09) * 3
    grit = bp(noise(0.55), 1500, 6000) * env(n, 0.002, 0.18) * 0.5
    return finish(clink * 0.7 + thud + grit)


def pop():
    # an item popping out / into the Bag: a quick rising bubble
    n = int(0.18 * SR)
    return finish(tone([520], 0.18, glide=2.2) * env(n, 0.003, 0.05) + tone([1040], 0.18, [0.3], glide=2.2) * env(n, 0.003, 0.04))


def collect():
    # into the Bag: two soft rising notes
    a = tone([880, 1760], 0.09, [1, 0.3]) * env(int(0.09 * SR), 0.003, 0.05)
    b = tone([1318, 2636], 0.16, [1, 0.3]) * env(int(0.16 * SR), 0.003, 0.08)
    return finish(np.concatenate([a, b]) * 0.8)


def crank():
    # the crank pump: a ratchet clatter and a metal groan
    sec = 0.4
    n = int(sec * SR)
    clicks = np.zeros(n)
    for i in range(6):
        s = int((0.02 + i * 0.045) * SR)
        k = bp(noise(0.02), 2000, 7000) * env(int(0.02 * SR), 0.0005, 0.008)
        clicks[s:s + len(k)] += k
    groan = tone([140, 210], sec, [1, 0.5], glide=1.3) * env(n, 0.03, 0.3) * 0.4
    return finish(clicks + groan)


def drill():
    # the rig's drill and treads, a loop: low engine, grinding rock, rattle
    sec = 3.0
    tt = t(sec)
    engine = (np.sin(2 * np.pi * 52 * tt) + 0.6 * np.sin(2 * np.pi * 104 * tt + 0.4) + 0.3 * np.sign(np.sin(2 * np.pi * 26 * tt))) * 0.45
    engine *= 1 + 0.15 * np.sin(2 * np.pi * 6 * tt)
    grind = bp(noise(sec), 180, 1400) * (0.6 + 0.4 * np.sin(2 * np.pi * 1.3 * tt) ** 2)
    rattle = hp(noise(sec), 3000) * 0.12 * (np.sin(2 * np.pi * 9 * tt) > 0.6)
    return finish(lp(engine, 400) + grind * 0.7 + rattle, peak=0.8, loop=True)


def cast():
    # the hook flying out: a whoosh, then a little tick
    n = int(0.5 * SR)
    sweep = np.linspace(400, 2400, n)
    w = np.zeros(n)
    x = noise(0.5)
    for i in range(0, n, 512):
        seg = x[i:i + 512]
        if len(seg) < 32:
            break
        w[i:i + len(seg)] = bp(seg, sweep[i] * 0.6, sweep[i] * 1.2, 2)
    w *= env(n, 0.15, 0.3, curve=3)
    tick = np.zeros(n)
    k = bp(noise(0.03), 1500, 5000) * env(int(0.03 * SR), 0.0005, 0.01)
    tick[int(0.42 * SR):int(0.42 * SR) + len(k)] = k
    return finish(w + tick * 0.6)


def bite():
    # the tug: a deep plunk and a bright "!" ping
    n = int(0.45 * SR)
    plunk = tone([180], 0.45, glide=0.6) * env(n, 0.002, 0.12)
    ping = tone([1568, 3136], 0.45, [1, 0.3]) * env(n, 0.002, 0.2)
    return finish(plunk + ping * 0.6)


def reel():
    # reeling in: a fast spinning ratchet
    sec = 0.6
    n = int(sec * SR)
    out = np.zeros(n)
    rate = np.linspace(0.03, 0.012, 30)
    pos = 0.0
    for r in rate:
        s = int(pos * SR)
        if s >= n:
            break
        k = bp(noise(0.012), 2500, 8000) * env(int(0.012 * SR), 0.0005, 0.004)
        out[s:s + len(k)] += k[: n - s]
        pos += r
    return finish(out + tone([300], sec, [0.15], glide=1.6) * env(n, 0.05, 0.5))


def eat():
    # a crunchy bite and a chew
    n = int(0.5 * SR)
    out = np.zeros(n)
    for start in (0.0, 0.22):
        s = int(start * SR)
        k = bp(noise(0.12), 900, 5000) * env(int(0.12 * SR), 0.002, 0.05)
        out[s:s + len(k)] += k
    return finish(out + lp(noise(0.5), 300) * env(n, 0.01, 0.2) * 0.6)


def hit():
    # the rig takes a hit: a heavy crash with metal
    n = int(0.9 * SR)
    boom = lp(noise(0.9), 180) * env(n, 0.002, 0.35) * 4
    metal = tone([310, 467, 723, 1130], 0.9, [1, 0.8, 0.6, 0.4]) * env(n, 0.002, 0.4)
    debris = bp(noise(0.9), 800, 5000) * env(n, 0.01, 0.5) * 0.6
    return finish(boom + metal * 0.5 + debris)


def spam():
    # each SPAM! click: a punchy thwack
    n = int(0.16 * SR)
    return finish(lp(noise(0.16), 1200) * env(n, 0.001, 0.05) * 2 + tone([220], 0.16, glide=0.5) * env(n, 0.001, 0.06))


def creature():
    # a creature lands on the deck: a raspy hiss with a low growl
    n = int(0.8 * SR)
    hiss = bp(noise(0.8), 2500, 9000) * env(n, 0.04, 0.5)
    growl = tone([95, 143], 0.8, [1, 0.5]) * (1 + 0.5 * np.sin(2 * np.pi * 23 * t(0.8))) * env(n, 0.05, 0.5)
    return finish(hiss * 0.7 + growl * 0.6)


def click():
    # a UI button
    n = int(0.06 * SR)
    return finish(tone([1200], 0.06) * env(n, 0.001, 0.015) + bp(noise(0.06), 2000, 6000) * env(n, 0.0005, 0.005) * 0.3, peak=0.7)


def fanfare():
    # a stop reached / zone complete: a bright rising arpeggio
    notes = [523.25, 659.25, 783.99, 1046.5]
    parts = []
    for i, f in enumerate(notes):
        d = 0.14 if i < 3 else 0.6
        parts.append(tone([f, f * 2, f * 3], d, [1, 0.35, 0.15]) * env(int(d * SR), 0.004, d * 0.8))
    return finish(np.concatenate(parts))


def night():
    # Lights Out: a low swell and a hollow tone
    sec = 2.2
    n = int(sec * SR)
    swell = lp(noise(sec), 400) * env(n, 0.8, 1.4, curve=2)
    hollow = tone([110, 164.8, 220], sec, [1, 0.6, 0.3]) * env(n, 0.6, 1.6, curve=2)
    return finish(swell * 0.8 + hollow * 0.6)


def downed():
    # downed: a falling sting
    sec = 1.0
    n = int(sec * SR)
    return finish(tone([440, 554], sec, [1, 0.6], glide=0.5) * env(n, 0.005, 0.6) + lp(noise(sec), 300) * env(n, 0.002, 0.2))


def fire():
    # the Beacon's campfire, a loop: crackles over a soft roar
    sec = 4.0
    n = int(sec * SR)
    roar = lp(noise(sec), 500) * 0.5
    crack = np.zeros(n)
    for _ in range(70):
        s = rng.integers(0, n - 2000)
        k = bp(noise(0.01), 1500, 8000) * env(int(0.01 * SR), 0.0002, 0.003) * rng.uniform(0.3, 1)
        crack[s:s + len(k)] += k
    return finish(roar + crack * 1.2, peak=0.7, loop=True)


def cave():
    # cavern ambience, a loop: a deep drone, air and distant drips
    sec = 8.0
    tt = t(sec)
    drone = (np.sin(2 * np.pi * 55 * tt) + 0.5 * np.sin(2 * np.pi * 82.4 * tt)) * (0.6 + 0.4 * np.sin(2 * np.pi * 0.125 * tt))
    air = lp(noise(sec), 700) * 0.6
    drips = np.zeros(len(tt))
    for s in (0.9, 2.7, 4.1, 6.3, 7.2):
        i = int(s * SR)
        d = tone([rng.uniform(1400, 2200)], 0.25, glide=1.4) * env(int(0.25 * SR), 0.001, 0.08)
        drips[i:i + len(d)] += d[: len(tt) - i] * 0.5
    return finish(lp(drone, 200) * 0.6 + air + drips, peak=0.6, loop=True)


SOUNDS = {
    "Mine": mine, "Pop": pop, "Collect": collect, "Crank": crank, "Drill": drill, "Cast": cast, "Bite": bite,
    "Reel": reel, "Eat": eat, "Hit": hit, "Spam": spam, "Creature": creature, "Click": click, "Fanfare": fanfare,
    "Night": night, "Downed": downed, "Fire": fire, "Cave": cave,
}


def main():
    os.makedirs(OUT, exist_ok=True)
    only = set(filter(None, os.environ.get("ONLY", "").split(",")))
    with tempfile.TemporaryDirectory() as tmp:
        for name, fn in SOUNDS.items():
            if only and name not in only:
                continue
            x = fn()
            wav = os.path.join(tmp, name + ".wav")
            wavfile.write(wav, SR, (x * 32767).astype(np.int16))
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", os.path.join(OUT, name + ".ogg")], check=True)
            print("sfx", name, "%.2fs" % (len(x) / SR))


if __name__ == "__main__":
    main()
