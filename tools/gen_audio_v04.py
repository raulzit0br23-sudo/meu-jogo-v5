"""Sintetiza efeitos sonoros, ambiências e música originais (WAV 44.1kHz mono 16-bit).
Toda a síntese é feita aqui; nenhum som de terceiros é utilizado.
"""
import numpy as np, os, wave
from scipy import signal

SR = 44100
BASE = os.path.join(os.path.dirname(__file__), "..", "assets", "audio")
rng = np.random.default_rng(7)


def write(path, x, sr=SR):
    full = os.path.join(BASE, path)
    os.makedirs(os.path.dirname(full), exist_ok=True)
    x = np.asarray(x, dtype=np.float64)
    peak = np.max(np.abs(x)) + 1e-9
    x = x / peak * 0.89
    with wave.open(full, "wb") as w:
        w.setnchannels(1); w.setsampwidth(2); w.setframerate(sr)
        w.writeframes((x * 32767).astype(np.int16).tobytes())
    print("ok", path, f"{len(x)/sr:.2f}s")


def t(d):
    return np.arange(int(d * SR)) / SR


def env(d, a=0.002, decay=0.2):
    tt = t(d)
    e = np.minimum(tt / a, 1.0) * np.exp(-tt / decay)
    return e


def noise(d):
    return rng.standard_normal(int(d * SR))


def lp(x, fc, order=4):
    b, a = signal.butter(order, min(fc / (SR / 2), 0.99), "low")
    return signal.lfilter(b, a, x)


def hp(x, fc, order=2):
    b, a = signal.butter(order, fc / (SR / 2), "high")
    return signal.lfilter(b, a, x)


def bp(x, lo, hi, order=2):
    b, a = signal.butter(order, [lo / (SR / 2), hi / (SR / 2)], "band")
    return signal.lfilter(b, a, x)


def reverb(x, room=0.4, wet=0.3):
    ir_len = int(SR * (0.3 + room * 1.5))
    ir = rng.standard_normal(ir_len) * np.exp(-np.arange(ir_len) / (SR * room * 0.5))
    ir = lp(ir, 5000)
    y = signal.fftconvolve(x, ir)[: len(x) + ir_len // 2]
    y = y / (np.max(np.abs(y)) + 1e-9)
    xx = np.pad(x, (0, len(y) - len(x)))
    xx = xx / (np.max(np.abs(xx)) + 1e-9)
    return xx * (1 - wet) + y * wet


def click(freq=3000, d=0.04, amp=1.0):
    return bp(noise(d), freq * 0.6, freq * 1.4) * env(d, 0.0003, 0.008) * amp


def seq(parts, total):
    out = np.zeros(int(total * SR))
    for start, s in parts:
        i = int(start * SR)
        out[i : i + len(s)] += s[: len(out) - i]
    return out

def loopify(x, xf=0.5):
    n = int(xf * SR)
    a = x[:n] * np.linspace(0, 1, n)
    b = x[-n:] * np.linspace(1, 0, n)
    y = x[n:-n].copy()
    y[:n] += 0  # mantém
    out = np.concatenate([a + b, y])
    return out


# ===== Sons novos da 0.4 (capítulos 4–6). Síntese original, nenhum som de terceiros. =====
rng = np.random.default_rng(404)
# helicóptero-caçador: pás (pulsos de baixa frequência ~11 Hz) + turbina
dd = 6.0
tt = t(dd)
blade = (0.5 + 0.5 * np.sin(2 * np.pi * 11.0 * tt)) ** 6
rot = lp(noise(dd), 260) * (0.25 + 1.4 * blade)
turb = sum(np.sin(2 * np.pi * f * tt) * a for f, a in ((610, 0.05), (1220, 0.03), (93, 0.2)))
write("sfx/heli_rotor.wav", loopify(np.tanh((rot + turb) * 1.6)))
# metralhadora do helicóptero (rajada curta, grave)
dd = 0.35
x = (lp(noise(dd), 1400) * env(dd, 0.001, 0.05) + np.sin(2 * np.pi * 70 * t(dd)) * env(dd, 0.001, 0.07))
write("sfx/heli_gun.wav", reverb(np.tanh(x * 3), 0.5, 0.3))
# canhão antiaéreo
dd = 1.2
x = lp(noise(dd), 900) * env(dd, 0.001, 0.12) + np.sin(2 * np.pi * 48 * t(dd) * np.exp(-t(dd) * 2)) * env(dd, 0.001, 0.25) * 1.4
write("sfx/flak_fire.wav", reverb(np.tanh(x * 2.5), 0.9, 0.4))
# motor do barco (dois tempos) e do buggy (quatro cilindros), loops
dd = 4.0
tt = t(dd)
f0 = 38.0
ph = 2 * np.pi * f0 * tt
boat = np.sign(np.sin(ph)) * 0.3 + np.sin(ph * 2) * 0.4 + lp(noise(dd), 600) * 0.5 * (0.6 + 0.4 * np.sin(ph) ** 2)
boat += hp(noise(dd), 2500) * 0.05  # água no casco
write("sfx/engine_boat.wav", loopify(lp(np.tanh(boat * 1.5), 2200)))
f0 = 30.0
ph = 2 * np.pi * f0 * tt
bug = sum(np.sin(ph * k + rng.uniform(0, 6)) / k for k in range(1, 9)) * (0.7 + 0.3 * np.sin(ph * 0.5) ** 2)
bug += lp(noise(dd), 300) * 0.6
write("sfx/engine_buggy.wav", loopify(lp(np.tanh(bug * 1.2), 1800)))
# respingo / batida na água
dd = 0.9
write("sfx/splash.wav", bp(noise(dd), 300, 4000) * env(dd, 0.005, 0.18) + lp(noise(dd), 200) * env(dd, 0.002, 0.08))
# elevador de carga (loop de motor + correntes)
dd = 4.0
tt = t(dd)
el = sum(np.sin(2 * np.pi * f * tt) * a for f, a in ((55, 0.5), (110, 0.25), (165, 0.1))) + lp(noise(dd), 500) * 0.4
el += seq([(k, click(1800, 0.03, 0.4)) for k in np.arange(0, dd - 0.05, 0.23)], dd)
write("sfx/elevator_loop.wav", loopify(el))
# morte do rastejador
dd = 0.9
write("sfx/crawler_death.wav", np.tanh(bp(noise(dd), 500, 3500) * env(dd, 0.005, 0.25) * 3 + np.sin(2 * np.pi * (300 * np.exp(-t(dd) * 4) + 90) * t(dd)) * env(dd, 0.002, 0.3)))
# helicóptero abatido (explosão longa + metal)
dd = 3.5
x = lp(noise(dd), 600) * env(dd, 0.002, 0.8) * 1.5 + bp(noise(dd), 1500, 5000) * env(dd, 0.3, 0.6) * 0.4
write("sfx/heli_explode.wav", reverb(np.tanh(x * 2), 1.0, 0.4))
# bipe do farol de rota (Mar Seco)
write("sfx/beacon.wav", np.sin(2 * np.pi * 880 * t(0.25)) * env(0.25, 0.005, 0.08) * 0.6)

# ambiências
dd = 20.0
tt = t(dd)
sew = lp(noise(dd), 180) * 1.2 + seq([(rng.uniform(0, dd - 0.3), bp(noise(0.25), 600, 2600) * env(0.25, 0.002, 0.05) * rng.uniform(0.2, 0.8)) for _ in range(60)], dd)
write("ambience/sewer.wav", loopify(reverb(sew, 1.2, 0.5)[: int(dd * SR)]))
gust = 0.5 + 0.5 * lp(rng.standard_normal(int(dd * SR)), 0.4) * 40
storm = (lp(noise(dd), 900) * 1.0 + bp(noise(dd), 1500, 6000) * 0.35) * np.clip(gust, 0.2, 1.6)
write("ambience/storm.wav", loopify(storm))
canal = lp(noise(dd), 500) * 0.5 + bp(noise(dd), 200, 900) * 0.3 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.11 * tt))
write("ambience/canal.wav", loopify(canal))
junk = lp(noise(dd), 350) * 0.8 + seq([(rng.uniform(0, dd - 0.5), np.sin(2 * np.pi * rng.uniform(180, 520) * t(0.5)) * env(0.5, 0.01, 0.2) * 0.15) for _ in range(14)], dd)
write("ambience/junkyard.wav", loopify(junk))
