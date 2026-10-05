#!/usr/bin/env python3
"""Plays each mode through simulated rooms (a dense echo tail, RT60 0.5 s) at several
direct-to-echo ratios and counts how many messages the receiver gets right.
A few feet from a Mac in an ordinary room the echo is about as loud as the sound itself
(0 dB) or louder (-5 dB). Run by test/run_linux.sh; needs numpy."""
import sys, subprocess, wave, numpy as np
B = sys.argv[1]                      # where render and analyze were built
rng = np.random.default_rng(1)
msg = "meet me at the corner in ten minutes"
def rd(p):
    w = wave.open(p); return np.frombuffer(w.readframes(w.getnframes()), dtype=np.int16) / 32768.0
def wr(p, x):
    w = wave.open(p, "wb"); w.setnchannels(1); w.setsampwidth(2); w.setframerate(48000)
    w.writeframes((np.clip(x, -1, 1) * 32767).astype(np.int16).tobytes()); w.close()
def room(x, drr_db, rt60=0.5, snr_db=25):
    n = int(rt60 * 48000); t = np.arange(n) / 48000
    h = rng.standard_normal(n) * np.exp(-6.91 * t / rt60); h[:96] = 0
    h *= np.sqrt(10 ** (-drr_db / 10) / np.sum(h ** 2)); h[0] += 1
    L = len(x) + n
    y = np.fft.irfft(np.fft.rfft(x, L) * np.fft.rfft(h, L))[:L]
    y = np.concatenate([np.zeros(5000), y, np.zeros(5000)])
    y += rng.standard_normal(len(y)) * np.sqrt(np.mean(y ** 2) / 10 ** (snr_db / 10))
    return y * 0.3 / np.max(np.abs(y))
need = {"piano": {0: 6, -5: 6}, "chirp": {0: 7, -5: 6}, "fast": {0: 6}, "silent": {0: 7, -5: 6}, "duet": {5: 7}}
N = 8
fails = 0
for m, name in enumerate(["piano", "chirp", "fast", "silent", "duet"]):
    subprocess.run([B + "/render", str(m), msg, B + "/clean.wav"], check=True)
    x = rd(B + "/clean.wav")
    for drr, want in need[name].items():
        ok = 0
        for _ in range(N):
            wr(B + "/room.wav", room(x, drr))
            out = subprocess.run([B + "/analyze", B + "/room.wav"], capture_output=True, text=True).stdout
            ok += msg in out
        good = ok >= want
        fails += not good
        print("%s  %s in a room with the echo %+d dB against the sound: %d of %d heard" %
              ("PASS" if good else "FAIL", name, drr, ok, N), flush=True)
sys.exit(1 if fails else 0)
