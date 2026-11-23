"""Sons v0.5: armas do HL2 final recriadas (.357, AR2, besta, isca) e Physgun. Síntese 100% original."""
import numpy as np, os
src = open(os.path.join(os.path.dirname(__file__), "gen_audio_v04.py")).read().split("# ===== Sons novos")[0]
G = {"__file__": os.path.join(os.path.dirname(os.path.abspath(__file__)), "gen_audio_v04.py")}
exec(src, G)
write, t, env, noise, lp, hp, bp, reverb, click, seq, loopify, SR = (G[k] for k in
    ("write", "t", "env", "noise", "lp", "hp", "bp", "reverb", "click", "seq", "loopify", "SR"))
rng = np.random.default_rng(2005)


def gunshot(d, body_hz, crack_fc, decay, room, mech=0.0):
    n = noise(d)
    crack = hp(n, crack_fc) * env(d, 0.0005, decay * 0.25)
    body = lp(n, 1800) * env(d, 0.001, decay)
    thump = np.sin(2 * np.pi * body_hz * t(d) * np.exp(-t(d) * 8)) * env(d, 0.001, decay * 0.6)
    x = np.tanh((crack * 0.8 + body + thump * 1.2) * 2.5)
    if mech:
        x = x + seq([(0.03, click(2500, 0.03, mech))], d)
    return reverb(x, room, 0.25)


# .357: estampido pesado com cauda longa
write("sfx/magnum_fire.wav", gunshot(1.4, 60, 1800, 0.2, 0.9, 0.2))
# recarga do revólver: abrir tambor, cápsulas caindo, fechar
d = 2.8
parts = [(0.1, click(1800, 0.05, 1.0)), (0.5, click(5000, 0.03, 0.6))]
for i in range(6):
    parts.append((0.7 + i * 0.07 + rng.random() * 0.03, bp(noise(0.05), 4000, 9000) * env(0.05, 0.0005, 0.012) * 0.7))
for i in range(6):
    parts.append((1.5 + i * 0.12, click(3200, 0.03, 0.5)))
parts.append((2.5, click(1500, 0.06, 1.2)))
write("sfx/magnum_reload.wav", seq(parts, d))
# AR2: pulso elétrico (crack + zumbido descendente)
d = 0.45
tt = t(d)
zap = np.sin(2 * np.pi * (900 * np.exp(-tt * 18) + 140) * tt) * env(d, 0.0005, 0.05)
write("sfx/ar2_fire.wav", reverb(np.tanh((hp(noise(d), 2500) * env(d, 0.0003, 0.02) + zap * 1.2 + lp(noise(d), 900) * env(d, 0.001, 0.06)) * 2), 0.35, 0.25))
# recarga AR2: trava, carregador energizado subindo de tom
d = 1.6
tt = t(0.5)
whine = np.sin(2 * np.pi * (300 + 900 * tt / 0.5) * tt) * np.minimum(tt / 0.05, 1) * np.exp(-tt * 2) * 0.4
write("sfx/ar2_reload.wav", seq([(0.1, click(2000, 0.05, 1.0)), (0.6, click(3000, 0.04, 0.8)), (0.9, whine), (1.4, click(1400, 0.06, 1.0))], d))
# carga da esfera de energia
d = 0.6
tt = t(d)
x = np.sin(2 * np.pi * (120 + 700 * (tt / d) ** 2) * tt) * (tt / d) + bp(noise(d), 1500, 6000) * (tt / d) * 0.3
write("sfx/ar2_charge.wav", x)
d = 1.2
tt = t(d)
x = np.tanh((lp(noise(d), 600) * env(d, 0.002, 0.25) * 1.5 + np.sin(2 * np.pi * 70 * tt) * env(d, 0.002, 0.3) + np.sin(2 * np.pi * (1600 * np.exp(-tt * 5) + 200) * tt) * env(d, 0.001, 0.2) * 0.6) * 2)
write("sfx/ar2_ball.wav", reverb(x, 0.7, 0.35))
d = 2.0
tt = t(d)
hum = np.sin(2 * np.pi * 90 * tt) * 0.5 + np.sin(2 * np.pi * 181 * tt + np.sin(2 * np.pi * 3 * tt)) * 0.3 + bp(noise(d), 800, 3000) * 0.15
write("sfx/ar2_ball_loop.wav", hum)
d = 0.6
tt = t(d)
write("sfx/ar2_ball_bounce.wav", reverb(np.tanh((bp(noise(d), 800, 6000) * env(d, 0.0005, 0.06) + np.sin(2 * np.pi * (500 * np.exp(-tt * 9) + 120) * tt) * env(d, 0.001, 0.12)) * 2.5), 0.5, 0.3))
# besta: estalo do cabo + zunido do vergalhão
d = 0.9
tt = t(d)
twang = np.sin(2 * np.pi * 180 * tt) * np.exp(-tt * 9) + np.sin(2 * np.pi * 361 * tt) * np.exp(-tt * 12) * 0.5
write("sfx/crossbow_fire.wav", reverb(np.tanh(seq([(0, click(2200, 0.05, 2.0))], d) + twang * 0.9 + hp(noise(d), 3000) * env(d, 0.001, 0.08) * 0.5), 0.4, 0.2))
d = 1.8
tt = t(0.9)
sizzle = bp(noise(0.9), 3000, 9000) * np.minimum(tt / 0.1, 1) * 0.4 + np.sin(2 * np.pi * (200 + 400 * tt) * tt) * 0.15
write("sfx/crossbow_reload.wav", seq([(0.1, click(1500, 0.08, 1.2)), (0.5, click(2500, 0.05, 0.8)), (0.7, sizzle), (1.6, click(1800, 0.05, 1.0))], d))
d = 0.5
write("sfx/crossbow_hit.wav", reverb(np.tanh(seq([(0, click(1800, 0.06, 2.0))], d) + bp(noise(d), 2000, 8000) * env(d, 0.001, 0.04)), 0.3, 0.2))
# isca: esguicho orgânico úmido
d = 0.7
x = lp(noise(d), 1500) * env(d, 0.002, 0.12) + bp(noise(d), 300, 1200) * env(d, 0.01, 0.2) * 0.8
write("sfx/bugbait_splat.wav", reverb(x, 0.3, 0.2))
d = 0.6
tt = t(d)
x = bp(noise(d), 400, 2500) * np.sin(np.pi * tt / d) * (0.6 + 0.4 * np.sin(2 * np.pi * 14 * tt))
write("sfx/bugbait_squeeze.wav", x)
# Physgun: zumbido elétrico estável com batimento, pegar e fixar
d = 2.0
tt = t(d)
x = np.sin(2 * np.pi * 220 * tt) * 0.4 + np.sin(2 * np.pi * 223 * tt) * 0.4 + np.sin(2 * np.pi * 660 * tt) * 0.12 + bp(noise(d), 2000, 7000) * 0.06
write("sfx/physgun_loop.wav", x)
d = 0.4
tt = t(d)
write("sfx/physgun_grab.wav", np.sin(2 * np.pi * (300 + 500 * tt / d) * tt) * env(d, 0.002, 0.15) + seq([(0, click(4000, 0.03, 0.6))], d))
d = 0.7
tt = t(d)
write("sfx/physgun_freeze.wav", reverb(np.sin(2 * np.pi * (900 * np.exp(-tt * 6) + 200) * tt) * env(d, 0.001, 0.2) + seq([(0, click(2500, 0.05, 1.2))], d), 0.5, 0.3))
