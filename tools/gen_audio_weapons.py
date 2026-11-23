"""Sons do arsenal 0.4 (armas inspiradas no arsenal cortado do HL2 beta). Síntese 100% original."""
import numpy as np, os, sys
sys.path.insert(0, os.path.dirname(__file__))
import importlib.util
spec = importlib.util.spec_from_file_location("ga", os.path.join(os.path.dirname(__file__), "gen_audio_v04.py"))
# só os utilitários: copia as funções sem executar a síntese do arquivo
src = open(os.path.join(os.path.dirname(__file__), "gen_audio_v04.py")).read().split("# ===== Sons novos")[0]
G = {"__file__": os.path.join(os.path.dirname(os.path.abspath(__file__)), "gen_audio_v04.py")}
exec(src, G)
write, t, env, noise, lp, hp, bp, reverb, click, seq, loopify, SR = (G[k] for k in
    ("write", "t", "env", "noise", "lp", "hp", "bp", "reverb", "click", "seq", "loopify", "SR"))
rng = np.random.default_rng(2002)


def gunshot(d, body_hz, crack_fc, decay, room, mech=0.0):
    n = noise(d)
    crack = hp(n, crack_fc) * env(d, 0.0005, decay * 0.25)
    body = lp(n, 1800) * env(d, 0.001, decay)
    thump = np.sin(2 * np.pi * body_hz * t(d) * np.exp(-t(d) * 8)) * env(d, 0.001, decay * 0.6)
    x = np.tanh((crack * 0.8 + body + thump * 1.2) * 2.5)
    if mech:
        x = x + seq([(0.03, click(2500, 0.03, mech))], d)
    return reverb(x, room, 0.25)


if "--rest" not in sys.argv: write("sfx/ar1_fire.wav", gunshot(0.8, 85, 2200, 0.13, 0.45, 0.3))          # 7,62: grave e áspero
write("sfx/oicw_fire.wav", gunshot(0.6, 120, 3500, 0.08, 0.4, 0.2))         # 5,56: estalado
write("sfx/smg1_fire.wav", gunshot(0.4, 130, 3000, 0.05, 0.28))
write("sfx/hmg_fire.wav", gunshot(0.7, 65, 1800, 0.12, 0.5, 0.4))
write("sfx/sniper_fire.wav", gunshot(1.6, 55, 2600, 0.25, 0.8))
# lançador 20 mm: "thump" + assobio
d = 0.6
x = np.sin(2 * np.pi * 70 * t(d) * np.exp(-t(d) * 5)) * env(d, 0.001, 0.08) * 1.5 + lp(noise(d), 900) * env(d, 0.001, 0.05)
write("sfx/oicw_grenade.wav", reverb(np.tanh(x * 2), 0.3, 0.2))
# sinalizadora: estampido abafado + chiado do pavio
d = 1.2
x = seq([(0, np.tanh(lp(noise(0.3), 1200) * env(0.3, 0.001, 0.06) * 3)), (0.05, bp(noise(1.1), 2500, 7000) * env(1.1, 0.02, 0.5) * 0.4)], d)
write("sfx/flare_fire.wav", x)
# míssil: ignição + jato
d = 1.4
x = seq([(0, np.tanh(lp(noise(0.4), 600) * env(0.4, 0.002, 0.1) * 3)), (0.08, bp(noise(1.3), 300, 4000) * env(1.3, 0.05, 0.7))], d)
write("sfx/rocket_fire.wav", reverb(x, 0.4, 0.2))
write("sfx/rocket_loop.wav", loopify(bp(noise(2.5), 250, 3500) * (1 + 0.1 * np.sin(2 * np.pi * 17 * t(2.5)))))
# imolador: jato de chama contínuo (rugido + crepitar)
d = 3.0
crack = np.zeros(int(d * SR))
for i in range(90):
    p = int(rng.random() * (len(crack) - 800))
    crack[p:p + 400] += hp(noise(400 / SR), 2000) * np.exp(-np.arange(400) / 60) * rng.random()
x = lp(noise(d), 700) * 1.2 + bp(noise(d), 800, 3000) * 0.4 + crack * 0.6
write("sfx/immolator_loop.wav", loopify(np.tanh(x)))
write("sfx/fire_loop.wav", loopify(np.tanh(lp(noise(3.0), 500) * 0.8 + crack * 0.5)))
d = 0.8
write("sfx/fire_ignite.wav", np.tanh(lp(noise(d), 1500) * env(d, 0.05, 0.25) * 2.5))
# rifle incendiário: disparo pneumático + chiado
d = 0.9
x = seq([(0, hp(noise(0.12), 1200) * env(0.12, 0.0005, 0.02) * 1.2), (0.02, bp(noise(0.8), 1500, 6000) * env(0.8, 0.01, 0.3) * 0.5),
         (0.0, np.sin(2 * np.pi * 180 * t(0.2) * np.exp(-t(0.2) * 12)) * env(0.2, 0.001, 0.05))], d)
write("sfx/irifle_fire.wav", x)
# canhão do guarda: carga ascendente e disparo de energia escura
d = 1.2
tt = t(d)
f = 80 + 900 * (tt / d) ** 2
x = np.sin(2 * np.pi * np.cumsum(f) / SR) * (tt / d) * 0.7 + bp(noise(d), 2000, 6000) * (tt / d) ** 3 * 0.3
write("sfx/guard_charge.wav", x)
d = 1.6
tt = t(d)
x = np.sin(2 * np.pi * (2200 * np.exp(-tt * 14) + 40) * tt) * env(d, 0.001, 0.25) + lp(noise(d), 300) * env(d, 0.005, 0.5) * 1.4
write("sfx/guard_fire.wav", reverb(np.tanh(x * 2), 0.8, 0.35))
# bastão de choque: zap elétrico; machado: golpe; balanço (whoosh)
d = 0.5
tt = t(d)
buzz = np.sign(np.sin(2 * np.pi * 120 * tt)) * 0.3 + hp(noise(d), 3000) * (np.sin(2 * np.pi * 60 * tt) > 0.3)
write("sfx/stun_hit.wav", buzz * env(d, 0.002, 0.15))
write("sfx/stun_hum.wav", loopify(np.sign(np.sin(2 * np.pi * 120 * t(2.0))) * 0.08 + hp(noise(2.0), 5000) * 0.03))
d = 0.35
write("sfx/swing.wav", bp(noise(d), 400, 2500) * np.sin(np.pi * t(d) / d) ** 2)
# granada (quique), molotov (vidro + chama), hopwire (lançamento e cabos), S.L.A.M. (fixação e bipe)
write("sfx/grenade_bounce.wav", seq([(0, click(1800, 0.06, 1.0)), (0.0, np.sin(2 * np.pi * 900 * t(0.08)) * env(0.08, 0.0005, 0.02) * 0.5)], 0.12))
d = 1.0
glass = sum(np.sin(2 * np.pi * f * t(d)) * env(d, 0.0005, 0.05 + rng.random() * 0.1) * rng.random() for f in (2900, 3700, 4400, 5200, 6100))
write("sfx/molotov_break.wav", glass + hp(noise(d), 3000) * env(d, 0.0005, 0.05) + np.tanh(lp(noise(d), 1200) * env(d, 0.08, 0.3) * 2) * 0.8)
d = 0.6
write("sfx/hopwire_deploy.wav", np.sin(2 * np.pi * np.cumsum(300 + 1500 * t(d) / d) / SR) * env(d, 0.002, 0.25) + seq([(0, click(4000, 0.05))], d))
d = 0.5
tt = t(d)
twang = sum(np.sin(2 * np.pi * f * tt) * np.exp(-tt * k) for f, k in ((420, 9), (840, 12), (1270, 16)))
write("sfx/hopwire_wire.wav", twang * env(d, 0.0005, 0.3))
write("sfx/slam_place.wav", seq([(0, click(1500, 0.05, 1.0)), (0.06, click(2600, 0.04, 0.7))], 0.15))
write("sfx/slam_beep.wav", np.sin(2 * np.pi * 1850 * t(0.09)) * env(0.09, 0.002, 0.04))
write("sfx/throw.wav", bp(noise(0.3), 300, 1800) * np.sin(np.pi * t(0.3) / 0.3) ** 2)
# binóculo / mira: servo de zoom
d = 0.4
write("sfx/zoom.wav", np.sin(2 * np.pi * (500 + 300 * np.sin(2 * np.pi * 2 * t(d))) * t(d)) * 0.15 + bp(noise(d), 1500, 3000) * 0.05)
# recargas e seletor
write("sfx/reload_rifle.wav", seq([(0.1, click(1800, 0.05)), (0.55, click(2200, 0.04)), (0.95, click(1400, 0.06, 1.2)), (1.1, click(2600, 0.03))], 1.4))
write("sfx/reload_hmg.wav", seq([(0.1, click(1200, 0.06)), (0.7, lp(noise(0.5), 2500) * 0.3), (1.6, click(1600, 0.06, 1.2)), (2.0, click(2400, 0.04))], 2.3))
write("sfx/firemode.wav", click(3200, 0.03, 0.8))
write("sfx/sniper_bolt.wav", seq([(0, click(1500, 0.05)), (0.18, lp(noise(0.12), 3000) * 0.3), (0.35, click(2100, 0.05))], 0.5))
