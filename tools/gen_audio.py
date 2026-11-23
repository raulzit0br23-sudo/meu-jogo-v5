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


# ---------------- ARMAS ----------------
def gunshot(d, body_hz, crack_fc, decay, tail_room, name):
    n = noise(d)
    crack = hp(n, crack_fc) * env(d, 0.0005, decay * 0.25)
    body = lp(n, 1800) * env(d, 0.001, decay)
    thump = np.sin(2 * np.pi * body_hz * t(d) * np.exp(-t(d) * 8)) * env(d, 0.001, decay * 0.6)
    x = crack * 0.8 + body * 1.0 + thump * 1.2
    x = np.tanh(x * 2.5)
    write(f"sfx/{name}.wav", reverb(x, tail_room, 0.25))

gunshot(0.6, 140, 3000, 0.08, 0.35, "pistol_fire")
gunshot(0.45, 110, 2500, 0.06, 0.3, "smg_fire")
gunshot(1.0, 70, 1500, 0.18, 0.5, "shotgun_fire")
gunshot(0.9, 90, 4000, 0.12, 0.45, "rifle_fire")
# rifle do Domínio: pulso elétrico
tt = t(0.5)
zap = np.sin(2 * np.pi * (900 * np.exp(-tt * 9) + 120) * tt) * env(0.5, 0.001, 0.12)
zap += bp(noise(0.5), 2000, 7000) * env(0.5, 0.001, 0.05) * 0.6
write("sfx/pulse_fire.wav", reverb(np.tanh(zap * 2), 0.3, 0.3))


def click(freq=3000, d=0.04, amp=1.0):
    return bp(noise(d), freq * 0.6, freq * 1.4) * env(d, 0.0003, 0.008) * amp


def seq(parts, total):
    out = np.zeros(int(total * SR))
    for start, s in parts:
        i = int(start * SR)
        out[i : i + len(s)] += s[: len(out) - i]
    return out

write("sfx/reload_pistol.wav", seq([(0.0, click(2500)), (0.35, click(1800, 0.06)), (0.8, click(3500)), (0.95, click(2200))], 1.2))
write("sfx/reload_smg.wav", seq([(0.0, click(2000)), (0.5, click(1500, 0.07)), (1.1, click(3000)), (1.4, click(2600)), (1.55, click(2000))], 1.8))
write("sfx/shotgun_shell.wav", seq([(0.0, click(1400, 0.08)), (0.12, click(900, 0.05))], 0.3))
write("sfx/shotgun_pump.wav", seq([(0.0, click(1200, 0.1)), (0.18, click(1600, 0.1))], 0.4))
write("sfx/dry_fire.wav", click(4000, 0.05))
write("sfx/weapon_draw.wav", seq([(0.0, click(1000, 0.12, 0.5)), (0.15, click(2800))], 0.4))

# ---------------- PASSOS (material) ----------------
for mat, fc, dec, ring in (("concrete", 900, 0.04, 0), ("metal", 2200, 0.09, 380), ("wood", 600, 0.06, 140), ("gravel", 3000, 0.07, 0), ("water", 1500, 0.15, 0)):
    for i in range(4):
        d = 0.3
        n = noise(d)
        x = lp(n, fc + i * 80) * env(d, 0.002, dec)
        if ring:
            x += np.sin(2 * np.pi * (ring + i * 23) * t(d)) * env(d, 0.001, dec * 1.5) * 0.4
        if mat == "gravel":
            x = x * (0.5 + 0.5 * (rng.random(len(x)) > 0.7))
        if mat == "water":
            x = bp(n, 400, 2500) * env(d, 0.01, 0.1) * (1 + np.sin(2 * np.pi * 30 * t(d)))
        write(f"sfx/step_{mat}_{i}.wav", x)

# ---------------- IMPACTOS E FÍSICA ----------------
def impact(name, fc, ring_hz, dec, ring_amp, d=0.6):
    n = noise(d)
    x = lp(n, fc) * env(d, 0.001, dec)
    for k, h in enumerate((1, 2.76, 5.4)):
        x += np.sin(2 * np.pi * ring_hz * h * t(d)) * env(d, 0.001, dec * (3 - k)) * ring_amp / (k + 1)
    write(f"sfx/{name}.wav", x)

impact("impact_concrete", 2500, 0, 0.05, 0)
impact("impact_metal", 5000, 620, 0.08, 0.9)
impact("impact_metal_heavy", 1500, 140, 0.2, 1.0, 1.2)
impact("impact_wood", 1200, 220, 0.05, 0.4)
impact("impact_flesh", 700, 0, 0.06, 0)
impact("impact_glass", 8000, 2300, 0.05, 0.6)
impact("barrel_hit", 900, 95, 0.25, 1.2, 1.0)
# vidro quebrando
gb = np.zeros(int(SR * 1.2))
for k in range(40):
    s = click(rng.uniform(3000, 9000), 0.05, rng.uniform(0.2, 1))
    i = int(rng.uniform(0, 0.6) ** 1.5 * SR)
    gb[i : i + len(s)] += s
write("sfx/glass_break.wav", gb)
# madeira quebrando
wb = lp(noise(0.8), 1500) * env(0.8, 0.002, 0.15) + seq([(rng.uniform(0, 0.3), click(800, 0.05)) for _ in range(12)], 0.8)
write("sfx/wood_break.wav", wb)
# explosão
d = 3.0
ex = lp(noise(d), 600) * env(d, 0.003, 0.6) * 1.5 + lp(noise(d), 120) * env(d, 0.01, 1.0) * 2 + hp(noise(d), 2000) * env(d, 0.0005, 0.05)
write("sfx/explosion.wav", reverb(np.tanh(ex * 2), 0.8, 0.35))

# ---------------- MANIPULADOR (ferramenta física original) ----------------
tt = t(1.2)
hum = np.sin(2 * np.pi * 70 * tt) * 0.6 + np.sin(2 * np.pi * 140.5 * tt) * 0.3 + bp(noise(1.2), 300, 900) * 0.2
write("sfx/manip_hold_loop.wav", hum * (0.8 + 0.2 * np.sin(2 * np.pi * 3 * tt)))
pick = np.sin(2 * np.pi * (200 + 600 * t(0.3) / 0.3) * t(0.3)) * env(0.3, 0.01, 0.15)
write("sfx/manip_pickup.wav", pick)
punt = np.tanh((np.sin(2 * np.pi * (500 * np.exp(-t(0.6) * 6) + 60) * t(0.6)) + lp(noise(0.6), 3000) * 0.8) * env(0.6, 0.001, 0.15) * 3)
write("sfx/manip_launch.wav", reverb(punt, 0.4, 0.3))
write("sfx/manip_deny.wav", np.sign(np.sin(2 * np.pi * 180 * t(0.25))) * env(0.25, 0.005, 0.08) * 0.4)

# ---------------- UI / JOGADOR ----------------
write("sfx/ui_move.wav", np.sin(2 * np.pi * 1200 * t(0.06)) * env(0.06, 0.001, 0.02))
write("sfx/ui_accept.wav", seq([(0, np.sin(2 * np.pi * 900 * t(0.08)) * env(0.08, 0.001, 0.03)), (0.07, np.sin(2 * np.pi * 1350 * t(0.1)) * env(0.1, 0.001, 0.04))], 0.25))
write("sfx/ui_back.wav", np.sin(2 * np.pi * 600 * t(0.1)) * env(0.1, 0.001, 0.04))
write("sfx/pickup_item.wav", seq([(0, np.sin(2 * np.pi * 700 * t(0.1)) * env(0.1, 0.001, 0.05)), (0.08, np.sin(2 * np.pi * 1050 * t(0.15)) * env(0.15, 0.001, 0.06))], 0.3))
write("sfx/pickup_health.wav", np.sin(2 * np.pi * (500 + 700 * t(0.5)) * t(0.5)) * env(0.5, 0.01, 0.2))
write("sfx/player_hurt.wav", lp(noise(0.4), 500) * env(0.4, 0.005, 0.1) + np.sin(2 * np.pi * 80 * t(0.4)) * env(0.4, 0.002, 0.1))
write("sfx/heartbeat.wav", seq([(0, np.sin(2 * np.pi * 55 * t(0.15)) * env(0.15, 0.005, 0.05)), (0.22, np.sin(2 * np.pi * 50 * t(0.15)) * env(0.15, 0.005, 0.05) * 0.7)], 0.9))
write("sfx/mask_breath.wav", bp(noise(3.0), 300, 2500) * (np.sin(np.pi * t(3.0) / 3.0) ** 2) * (0.5 + 0.5 * np.sin(2 * np.pi * 0.66 * t(3.0)) ** 8))
write("sfx/jump_land.wav", lp(noise(0.3), 400) * env(0.3, 0.002, 0.06))

# ---------------- MECANISMOS ----------------
dd = 2.0
creak = np.sin(2 * np.pi * (180 + 40 * np.sin(2 * np.pi * 1.3 * t(dd))) * t(dd)) * (0.5 + 0.5 * signal.sawtooth(2 * np.pi * 23 * t(dd))) * np.sin(np.pi * t(dd) / dd)
write("sfx/door_creak.wav", lp(creak, 3000))
write("sfx/door_slam.wav", reverb(lp(noise(0.8), 800) * env(0.8, 0.002, 0.12) + np.sin(2 * np.pi * 60 * t(0.8)) * env(0.8, 0.002, 0.2), 0.6, 0.35))
write("sfx/button_press.wav", seq([(0, click(1800, 0.05)), (0.05, np.sin(2 * np.pi * 440 * t(0.2)) * env(0.2, 0.002, 0.08) * 0.5)], 0.3))
write("sfx/lever.wav", seq([(0, click(700, 0.1)), (0.3, click(500, 0.15)), (0.32, lp(noise(0.3), 600) * env(0.3, 0.001, 0.08))], 0.7))
dd = 4.0
mach = sum(np.sin(2 * np.pi * f * t(dd)) / (k + 1) for k, f in enumerate((48, 96, 151, 202))) + lp(noise(dd), 300) * 0.5
write("sfx/gate_motor.wav", mach * np.minimum(1, t(dd) * 2) * np.minimum(1, (dd - t(dd)) * 2))
write("sfx/alarm.wav", np.sign(np.sin(2 * np.pi * (600 + 200 * np.sign(np.sin(2 * np.pi * 1.5 * t(2.0)))) * t(2.0))) * 0.4)

# ---------------- INIMIGOS ----------------
# rádio do Vigilante (Domínio): bursts filtrados + bipes
for i in range(6):
    d = rng.uniform(1.0, 1.8)
    n = bp(noise(d), 500, 2800)
    gate = (lp(rng.standard_normal(int(d * SR)), 12) > -0.05).astype(float)
    syl = n * lp(gate, 30) * (1 + 0.6 * np.sin(2 * np.pi * rng.uniform(4, 8) * t(d)))
    beep = np.sin(2 * np.pi * 1700 * t(0.08)) * 0.5
    x = np.concatenate([beep, np.zeros(1500), syl, np.zeros(1500), beep * 0.7])
    write(f"sfx/radio_chatter_{i}.wav", np.tanh(x * 3))
write("sfx/enemy_alert.wav", seq([(0, np.sin(2 * np.pi * 1700 * t(0.1)) * 0.6), (0.12, np.sin(2 * np.pi * 2200 * t(0.18)) * 0.6), (0.3, bp(noise(0.5), 600, 3000) * env(0.5, 0.01, 0.2))], 0.9))
write("sfx/enemy_death.wav", seq([(0, np.sin(2 * np.pi * (1500 * np.exp(-t(1.0) * 3) + 200) * t(1.0)) * env(1.0, 0.002, 0.4) * 0.6), (0.0, bp(noise(1.0), 300, 2000) * env(1.0, 0.002, 0.25))], 1.2))
write("sfx/enemy_pain.wav", bp(noise(0.35), 400, 2400) * env(0.35, 0.002, 0.1) * (1 + np.sin(2 * np.pi * 40 * t(0.35))))
# criatura "rastejador" (original): estalos + chiado
dd = 1.2
cr = seq([(rng.uniform(0, 1.0), click(rng.uniform(400, 1500), 0.04)) for _ in range(20)], dd) + bp(noise(dd), 2000, 6000) * env(dd, 0.2, 0.5) * 0.4
write("sfx/crawler_idle.wav", cr)
write("sfx/crawler_attack.wav", np.tanh(bp(noise(0.6), 800, 5000) * env(0.6, 0.01, 0.2) * 4))

# ---------------- AMBIÊNCIAS (loops) ----------------
def loopify(x, xf=0.5):
    n = int(xf * SR)
    a = x[:n] * np.linspace(0, 1, n)
    b = x[-n:] * np.linspace(1, 0, n)
    y = x[n:-n].copy()
    y[:n] += 0  # mantém
    out = np.concatenate([a + b, y])
    return out

dd = 20.0
wind = lp(noise(dd), 400) * (0.6 + 0.4 * lp(rng.standard_normal(int(dd * SR)), 0.3) * 30)
wind += bp(noise(dd), 800, 1600) * 0.15 * (0.5 + 0.5 * np.sin(2 * np.pi * 0.07 * t(dd)))
write("ambience/wind_city.wav", loopify(wind))
tr = lp(noise(dd), 150) * 2 + sum(np.sin(2 * np.pi * f * t(dd)) * 0.2 for f in (31, 47, 63))
clack = np.zeros(int(dd * SR))
for k in np.arange(0, dd - 0.2, 0.9):
    for off in (0, 0.12):
        s = lp(click(500, 0.08), 1500)
        i = int((k + off) * SR); clack[i : i + len(s)] += s * 3
write("ambience/train_interior.wav", loopify(tr + clack))
ind = sum(np.sin(2 * np.pi * f * t(dd) + rng.uniform(0, 6)) * a for f, a in ((50, 0.5), (100, 0.3), (150, 0.2), (233, 0.08))) + lp(noise(dd), 250) * 0.5
ind *= 1 + 0.2 * np.sin(2 * np.pi * 0.25 * t(dd))
write("ambience/industrial_hum.wav", loopify(ind))
dr = bp(noise(dd), 60, 200) * 2 + sum(np.sin(2 * np.pi * f * t(dd)) * 0.1 for f in (38.89, 41.2))
write("ambience/station_hall.wav", loopify(reverb(dr, 1.0, 0.6)[: int(dd * SR)]))
rain = hp(noise(dd), 1500) * 0.4 + seq([(rng.uniform(0, dd - 0.1), click(rng.uniform(2000, 6000), 0.02, rng.uniform(0.1, 0.5))) for _ in range(800)], dd)
write("ambience/rain.wav", loopify(rain))

# ---------------- MÚSICA (camadas dinâmicas) ----------------
# Tom: Ré menor, sintetizadores frios. Camada A (exploração), B (tensão), C (combate).
def pad(freqs, d, det=0.3):
    x = np.zeros(int(d * SR))
    for f in freqs:
        for dv in (-det, 0, det):
            x += signal.sawtooth(2 * np.pi * (f + dv) * t(d)) / 3
    return lp(x, 900)

bpm, bars = 80, 16
beat = 60 / bpm
dd = bars * 4 * beat
prog = [(146.83, 174.61, 220.0), (116.54, 146.83, 174.61), (130.81, 164.81, 196.0), (110.0, 138.59, 164.81)]
A = np.zeros(int(dd * SR))
for b in range(bars):
    ch = prog[(b // 2) % 4]
    seg = pad([f / 2 for f in ch], 4 * beat) * np.sin(np.pi * t(4 * beat) / (4 * beat)) ** 0.5
    i = int(b * 4 * beat * SR); A[i : i + len(seg)] += seg[: len(A) - i]
write("music/explore.wav", reverb(A, 1.2, 0.5)[: int(dd * SR)])
B = np.zeros(int(dd * SR))
for k in range(int(dd / (beat / 2))):
    f = [73.42, 73.42, 87.31, 73.42, 69.3, 73.42, 98.0, 87.31][k % 8]
    s = signal.square(2 * np.pi * f * t(beat / 2)) * env(beat / 2, 0.005, 0.12)
    i = int(k * beat / 2 * SR); B[i : i + len(s)] += lp(s, 600)[: len(B) - i]
write("music/tension.wav", B)
C = np.zeros(int(dd * SR))
for k in range(int(dd / (beat / 2))):
    if k % 4 == 0 or k % 8 == 6:
        s = np.sin(2 * np.pi * 55 * t(0.3) * np.exp(-t(0.3) * 10)) * env(0.3, 0.001, 0.1) * 1.5
        i = int(k * beat / 2 * SR); C[i : i + len(s)] += s[: len(C) - i]
    if k % 4 == 2:
        s = hp(noise(0.2), 1500) * env(0.2, 0.001, 0.05)
        i = int(k * beat / 2 * SR); C[i : i + len(s)] += s[: len(C) - i]
    s = hp(noise(0.05), 6000) * env(0.05, 0.001, 0.01) * 0.3
    i = int(k * beat / 2 * SR); C[i : i + len(s)] += s[: len(C) - i]
write("music/combat.wav", np.tanh(C * 1.5))
# Tema principal (menu): melodia sobre o pad
M = pad([73.42, 110.0, 146.83], 24, 0.4) * 0.6
mel = [(0, 293.66, 2), (2, 349.23, 1), (3, 329.63, 1), (4, 293.66, 3), (8, 261.63, 2), (10, 293.66, 1), (11, 220.0, 3), (16, 293.66, 2), (18, 440.0, 2), (20, 349.23, 4)]
for st, f, ln in mel:
    s = (np.sin(2 * np.pi * f * t(ln * 0.75)) + 0.3 * np.sin(2 * np.pi * f * 2 * t(ln * 0.75))) * env(ln * 0.75, 0.08, ln * 0.4)
    i = int(st * 0.75 * SR); M[i : i + len(s)] += s * 0.5
write("music/main_theme.wav", reverb(M, 1.5, 0.55)[: int(24 * SR)])
