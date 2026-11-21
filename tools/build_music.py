"""The game's music, composed in code: three seamless loops written as OGG into
assets/audio/music/ for Starport (group "music" -> Assets.music.<Name>).

    python tools/build_music.py

  * Camp    - the lobby: warm and hopeful, an adventure about to start (88 bpm)
  * Descent - riding down: steady, curious, a little driving (100 bpm)
  * Night   - Lights Out at camp: hushed, low, with a heartbeat pulse (66 bpm)

Each is chords on a soft detuned pad, a plucked melody (Karplus-Strong), a bass
line and light percussion; the end is written to lead straight back to the start.
"""

import os
import subprocess
import tempfile

import numpy as np
from scipy.io import wavfile
from scipy.signal import butter, sosfilt

SR = 44100
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
OUT = os.path.join(ROOT, "assets", "audio", "music")
rng = np.random.default_rng(3)

NOTES = {"C": 0, "C#": 1, "D": 2, "D#": 3, "E": 4, "F": 5, "F#": 6, "G": 7, "G#": 8, "A": 9, "A#": 10, "B": 11}


def hz(name: str) -> float:
    """'A4' -> 440"""
    n, octave = name[:-1], int(name[-1])
    return 440.0 * 2 ** ((NOTES[n] + 12 * (octave - 4) - 9) / 12)


def lp(x, f, order=2):
    return sosfilt(butter(order, f, "low", fs=SR, output="sos"), x)


def adsr(n, a=0.01, d=0.1, s=0.7, r=0.2):
    e = np.full(n, s)
    ai, di, ri = int(a * SR), int(d * SR), int(r * SR)
    ai = min(ai, n)
    e[:ai] = np.linspace(0, 1, ai)
    if ai + di < n:
        e[ai:ai + di] = np.linspace(1, s, di)
    if 0 < ri < n:
        e[-ri:] *= np.linspace(1, 0, ri)
    return e


def pad(freqs, sec, bright=1800):
    tt = np.arange(int(sec * SR)) / SR
    out = np.zeros_like(tt)
    for f in freqs:
        for det in (-0.12, 0.0, 0.11):
            ph = 2 * np.pi * f * (1 + det / 100) * tt + rng.uniform(0, 6.28)
            # a soft saw (few harmonics)
            out += sum(np.sin(k * ph) / k for k in range(1, 6))
    out = lp(out, bright)
    return out * adsr(len(tt), 0.35, 0.4, 0.8, 0.5) / (len(freqs) * 3)


def pluck(f, sec, decay=0.996, bright=0.5):
    """Karplus-Strong string."""
    n = int(sec * SR)
    period = max(2, int(SR / f))
    buf = rng.uniform(-1, 1, period)
    buf = lp(lp(buf, 2600 * bright + 600), 2600 * bright + 600)  # (a soft, round pluck: no click)
    out = np.zeros(n)
    for i in range(n):
        out[i] = buf[i % period]
        j = i % period
        buf[j] = decay * 0.5 * (buf[j] + buf[(j + 1) % period])
    return out * adsr(n, 0.006, 0.05, 1.0, 0.08)


def bass(f, sec):
    tt = np.arange(int(sec * SR)) / SR
    x = np.sin(2 * np.pi * f * tt) + 0.3 * np.sin(4 * np.pi * f * tt)
    return x * adsr(len(tt), 0.01, 0.2, 0.6, 0.1)


def kick(sec=0.4):
    tt = np.arange(int(sec * SR)) / SR
    f = 110 * np.exp(-tt * 18) + 45
    return np.sin(2 * np.pi * np.cumsum(f) / SR) * np.exp(-tt * 9)


def shaker(sec=0.08):
    n = int(sec * SR)
    x = rng.uniform(-1, 1, n)
    x = lp(x - lp(x, 4000), 9000)
    return x * adsr(n, 0.004, 0.02, 1.0, 0.0) * np.exp(-np.arange(n) / SR * 50) * 0.18


def place(track, clip, at_sec, gain=1.0):
    i = int(at_sec * SR)
    j = min(len(track), i + len(clip))
    track[i:j] += clip[: j - i] * gain


def song(bpm, bars, chords, melody, bass_line, perc, pad_bright=1800, pluck_gain=0.35, swing=0.0):
    beat = 60 / bpm
    total = bars * 4 * beat
    tr = np.zeros(int(total * SR) + SR * 2)
    for bar, chord in enumerate(chords * (bars // len(chords))):
        place(tr, pad([hz(n) for n in chord], 4 * beat + 0.6, pad_bright), bar * 4 * beat, 0.8)
    for start, note, length in melody:
        if note:
            place(tr, pluck(hz(note), length * beat + 0.4), start * beat + (swing * beat if start % 1 else 0), pluck_gain)
    for start, note, length in bass_line:
        place(tr, bass(hz(note), length * beat), start * beat, 0.32)
    for start, kind in perc:
        if kind == "k":
            place(tr, kick(), start * beat, 0.5)
        else:
            place(tr, shaker(), start * beat, 0.4)
    # the tail rings into the start, so the loop is seamless
    n = int(total * SR)
    tail = tr[n:]
    tr = tr[:n]
    tr[: len(tail)] += tail
    tr = lp(tr, 7000, 4)
    return tr / (np.max(np.abs(tr)) or 1) * 0.85


def arp(chords, beats_per, pattern, octave_up=True):
    """a melody line out of the chords: pattern of chord-tone indexes per 8th note"""
    out = []
    for c_i, chord in enumerate(chords):
        tones = chord + ([n[:-1] + str(int(n[-1]) + 1) for n in chord] if octave_up else [])
        for k, idx in enumerate(pattern):
            if idx is None:
                continue
            out.append((c_i * beats_per + k * 0.5, tones[idx % len(tones)], 0.9))
    return out


def camp():
    chords = [["C4", "E4", "G4"], ["A3", "C4", "E4"], ["F3", "A3", "C4"], ["G3", "B3", "D4"]] * 2
    mel = arp(chords, 4, [0, 2, 4, 2, 3, None, 4, 5])
    # a singing top line over bars 5-8
    top = [(16, "E5", 1.5), (17.5, "D5", 0.5), (18, "C5", 2), (20, "E5", 1), (21, "G5", 1), (22, "A5", 2),
           (24, "F5", 1.5), (25.5, "E5", 0.5), (26, "C5", 2), (28, "D5", 1), (29, "B4", 1), (30, "G4", 2)]
    bl = [(b * 4, c[0][:-1] + "2", 3.5) for b, c in enumerate(chords)]
    perc = [(b + o, "k" if o == 0 else "s") for b in range(0, 32, 2) for o in (0, 1, 1.5)]
    return song(88, 8, chords, mel + top, bl, perc)


def descent():
    chords = [["D4", "F4", "A4"], ["A#3", "D4", "F4"], ["C4", "E4", "G4"], ["A3", "C#4", "E4"]] * 2
    mel = arp(chords, 4, [0, 2, 4, 3, 1, 4, 2, 5])
    top = [(16, "A5", 1), (17, "G5", 0.5), (17.5, "F5", 0.5), (18, "D5", 2), (20, "F5", 1), (21, "E5", 1), (22, "C5", 2),
           (24, "D5", 1), (25, "E5", 1), (26, "F5", 1), (27, "G5", 1), (28, "E5", 2), (30, "C#5", 2)]
    bl = []
    for b, c in enumerate(chords):
        root = c[0][:-1] + "2"
        bl += [(b * 4, root, 1.5), (b * 4 + 1.5, root, 0.5), (b * 4 + 2, root, 1.5), (b * 4 + 3.5, c[2][:-1] + "2", 0.5)]
    perc = [(x / 2, "k" if x % 4 == 0 else "s") for x in range(0, 64)]
    return song(100, 8, chords, mel + top, bl, perc, pad_bright=1500, pluck_gain=0.3)


def night():
    chords = [["A3", "C4", "E4"], ["F3", "A3", "C4"], ["D3", "F3", "A3"], ["E3", "G#3", "B3"]] * 2
    mel = [(b * 4 + 2, chords[b][2][:-1] + "5", 2) for b in range(0, 8, 2)] + [(b * 4 + 0.5, chords[b][1][:-1] + "5", 1.5) for b in range(1, 8, 2)]
    bl = [(b * 4, c[0][:-1] + "2", 4) for b, c in enumerate(chords)]
    # a slow heartbeat
    perc = [(b, "k") for b in range(0, 32, 2)] + [(b + 0.35, "k") for b in range(0, 32, 2)]
    return song(66, 8, chords, mel, bl, perc, pad_bright=900, pluck_gain=0.22)


def main():
    os.makedirs(OUT, exist_ok=True)
    with tempfile.TemporaryDirectory() as tmp:
        for name, fn in (("Camp", camp), ("Descent", descent), ("Night", night)):
            x = fn()
            st = np.stack([x, np.roll(x, 380)], axis=1)  # a touch of width
            wav = os.path.join(tmp, name + ".wav")
            wavfile.write(wav, SR, (st * 32767).astype(np.int16))
            subprocess.run(["ffmpeg", "-v", "error", "-y", "-i", wav, "-c:a", "libvorbis", "-q:a", "5", os.path.join(OUT, name + ".ogg")], check=True)
            print("music", name, "%.1fs" % (len(x) / SR))


if __name__ == "__main__":
    main()
