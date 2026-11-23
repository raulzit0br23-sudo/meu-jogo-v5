"""Texturas v0.5: face de caixa de madeira (todas as 6 faces usam a mesma folha 0..1) e tampas de
barril (azul / vermelho explosivo). Sintetizadas do zero, sem assets de terceiros."""
import sys, os
import numpy as np
from PIL import Image, ImageDraw
sys.path.insert(0, os.path.dirname(__file__))
_argv = sys.argv; sys.argv = [sys.argv[0], "__nenhum__"]
import gen_textures_v04 as V  # noqa
sys.argv = _argv
G, tn, colorize, save_any, mask, font = V.G, V.tn, V.colorize, V.save_any, V.mask_from_draw, V.font
S = 512


def crate():
    yy, xx = np.mgrid[0:S, 0:S] / S
    g0 = tn(24, 5, 0.55, 500)
    gi = Image.fromarray((np.clip(g0, 0, 1) * 255).astype(np.uint8)).resize((S // 16, S), Image.BILINEAR).resize((S, S), Image.BICUBIC)
    grain = np.asarray(gi, dtype=np.float64) / 255.0
    streak = tn(64, 3, 0.5, 501)
    # tábuas horizontais internas (5) + moldura de 4 tábuas + travessa diagonal
    plank_id = np.floor(yy * 5)
    jitter = (np.sin(plank_id * 12.9898) * 43758.5453) % 1.0
    wood = colorize(np.clip(grain * 0.5 + np.sin((yy * 5 * 7 + streak * 3 + jitter * 9) * 3.0) * 0.25 + 0.5, 0, 1),
                    (0.36, 0.24, 0.13), (0.72, 0.53, 0.32))
    wood *= (0.85 + jitter * 0.25)[..., None]
    h = 0.55 + grain * 0.2
    gaps = np.abs((yy * 5) % 1.0 - 0.5) > 0.485
    m = 0.12
    frame = (xx < m) | (xx > 1 - m) | (yy < m) | (yy > 1 - m)
    d = np.abs(xx - yy) < 0.075
    fr_w = colorize(tn(10, 5, 0.55, 502), (0.42, 0.29, 0.16), (0.78, 0.6, 0.38))
    alb = wood.copy()
    alb[d & ~frame] = fr_w[d & ~frame] * 1.04
    h = np.where(d & ~frame, 0.8, h)
    alb[frame] = fr_w[frame]
    h = np.where(frame, 0.9, h)
    edge = (np.abs(xx - m) < 0.006) | (np.abs(xx - (1 - m)) < 0.006) | (np.abs(yy - m) < 0.006) | (np.abs(yy - (1 - m)) < 0.006)
    dedge = (np.abs(np.abs(xx - yy) - 0.075) < 0.005) & ~frame
    for msk in (gaps & ~frame & ~d, edge, dedge):
        alb[msk] *= 0.35; h = np.where(msk, 0.15, h)
    # pregos
    nails = mask(S, S, lambda dr: [dr.ellipse([cx - 6, cy - 6, cx + 6, cy + 6], fill=255)
                                   for cx in (30, S - 30) for cy in (30, S // 2, S - 30)] +
                 [dr.ellipse([cx - 6, cy - 6, cx + 6, cy + 6], fill=255) for cx in (S // 2,) for cy in (30, S - 30)])
    alb = alb * (1 - nails[..., None]) + np.array([0.3, 0.3, 0.32]) * nails[..., None]
    h = h + nails * 0.3
    # estêncil
    st = mask(S, S, lambda dr: (dr.text((S * 0.5, S * 0.36), "SUPRIMENTOS", font=font(38), anchor="mm", fill=255),
                                dr.text((S * 0.5, S * 0.66), "C-17  ▲  14", font=font(44), anchor="mm", fill=255)))
    st *= np.clip(tn(30, 3, 0.5, 503) * 1.6 - 0.1, 0, 1)
    alb = alb * (1 - st[..., None] * 0.75) + np.array([0.08, 0.07, 0.06]) * st[..., None] * 0.75
    dirt = np.clip(tn(4, 5, 0.6, 504) - 0.45, 0, 1) * 1.2
    alb *= (1 - dirt * 0.4)[..., None]
    save_any("crate", alb, h, 0.85 + grain * 0.1, np.zeros_like(h) + nails * 0.8, 5.0)


def lid(name, paint, hazard):
    yy, xx = np.mgrid[0:S, 0:S] / S
    r = np.hypot(xx - 0.5, yy - 0.5) * 2
    n = tn(14, 4, 0.5, 520)
    paint_c = colorize(n, np.array(paint) * 0.75, np.array(paint) * 1.05)
    h = np.full((S, S), 0.5)
    # aro externo, sulcos concêntricos
    rim = (r > 0.9)
    groove = (np.abs(r - 0.84) < 0.015) | (np.abs(r - 0.55) < 0.008)
    h = np.where(rim, 0.95, h); h = np.where(groove, 0.15, h)
    bung = mask(S, S, lambda dr: (dr.ellipse([S * 0.22 - 34, S * 0.5 - 34, S * 0.22 + 34, S * 0.5 + 34], fill=255),
                                  dr.ellipse([S * 0.78 - 22, S * 0.5 - 22, S * 0.78 + 22, S * 0.5 + 22], fill=255)))
    bung_in = mask(S, S, lambda dr: (dr.regular_polygon((S * 0.22, S * 0.5, 22), 6, fill=255),
                                     dr.regular_polygon((S * 0.78, S * 0.5, 13), 6, fill=255)))
    h = h + bung * 0.3 + bung_in * 0.2
    chips = np.clip((tn(8, 6, 0.6, 521) + np.clip(r - 0.8, 0, 1) * 1.5 - 0.8) * 6, 0, 1)
    rust_c = colorize(tn(40, 3, 0.5, 522), (0.22, 0.1, 0.04), (0.5, 0.27, 0.1))
    alb = paint_c * (1 - chips[..., None]) + rust_c * chips[..., None]
    alb[groove] *= 0.45
    alb = alb * (1 - bung[..., None] * 0.35) + np.array([0.45, 0.45, 0.45]) * bung[..., None] * 0.35
    if hazard:
        sym = mask(S, S, lambda dr: (dr.regular_polygon((S * 0.5, S * 0.5, 80), 3, fill=255),))
        inner = mask(S, S, lambda dr: (dr.regular_polygon((S * 0.5, S * 0.52, 58), 3, fill=255),))
        mark = mask(S, S, lambda dr: (dr.text((S * 0.5, S * 0.53), "!", font=font(70), anchor="mm", fill=255),))
        alb = alb * (1 - sym[..., None]) + np.array([0.05, 0.05, 0.05]) * sym[..., None]
        alb = alb * (1 - inner[..., None]) + np.array([0.95, 0.78, 0.1]) * inner[..., None]
        alb = alb * (1 - mark[..., None]) + np.array([0.05, 0.05, 0.05]) * mark[..., None]
    else:
        st = mask(S, S, lambda dr: dr.text((S * 0.5, S * 0.3), "RES. 4", font=font(40), anchor="mm", fill=255))
        alb = alb * (1 - st[..., None] * 0.8) + 0.9 * st[..., None] * 0.8
    alb[r > 1.0] = alb[r > 1.0] * 0.6
    save_any(name, alb, h, 0.55 + chips * 0.35, 0.3 + chips * 0.2 + bung * 0.5, 6.0)


crate()
lid("barrel_lid_blue", (0.16, 0.36, 0.7), False)
lid("barrel_lid_red", (0.72, 0.1, 0.07), True)
