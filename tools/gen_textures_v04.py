"""Texturas v0.4: folhas mapeadas (portas, porta do trem, barris) e tecidos/acabamentos para
personagens e armas. Tudo sintetizado do zero (ruído + desenho vetorial), sem assets de terceiros.
Uso: python3 tools/gen_textures_v04.py [nomes...]
"""
import sys, os
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
_argv = sys.argv
sys.argv = [sys.argv[0], "__nenhum__"]
sys.path.insert(0, os.path.dirname(__file__))
import gen_textures as G  # noqa: E402  (reaproveita ruído/normal/ORM)
sys.argv = _argv
N, OUT, tn, colorize = G.N, G.OUT, G.tile_noise, G.colorize


def save_any(name, alb, h, rough, metal, nstrength=4.0):
    alb = np.clip(alb, 0, 1)
    ao = np.clip(0.55 + h * 0.45, 0, 1)
    Image.fromarray((alb * 255).astype(np.uint8)).save(f"{OUT}/{name}_albedo.png")
    Image.fromarray(G.normal_from_height(h, nstrength)).save(f"{OUT}/{name}_normal.png")
    orm = np.stack([ao, np.clip(rough, 0, 1), np.clip(metal, 0, 1)], -1)
    Image.fromarray((orm * 255).astype(np.uint8)).save(f"{OUT}/{name}_orm.png")
    print("ok", name, alb.shape)


def tall(freq, oct, pers, seed):
    """Ruído 512x1024 (duas camadas tileáveis empilhadas e suavizadas na junção)."""
    a, b = tn(freq, oct, pers, seed), tn(freq, oct, pers, seed + 1)
    out = np.vstack([a, b])
    return out


def mask_from_draw(w, h, fn, blur=0):
    im = Image.new("L", (w, h), 0)
    fn(ImageDraw.Draw(im))
    if blur:
        im = im.filter(ImageFilter.GaussianBlur(blur))
    return np.asarray(im, dtype=np.float64) / 255.0


def font(sz, bold=True):
    p = "/usr/share/fonts/truetype/dejavu/DejaVuSans%s.ttf" % ("-Bold" if bold else "")
    try:
        return ImageFont.truetype(p, sz)
    except Exception:
        return ImageFont.load_default()


# ---------------------------------------------------------------- portas
def door_metal(name, paint, stencil=None):
    W, H = 512, 1024
    yy, xx = np.mgrid[0:H, 0:W] / np.array([H, W])[:, None, None]
    n1 = tall(18, 4, 0.5, 300)
    chips = tall(6, 6, 0.6, 310)
    rust_edge = np.clip(1 - np.minimum.reduce([xx, 1 - xx, yy * 2, (1 - yy) * 2]) * 9, 0, 1)
    bottom = np.clip((yy - 0.78) * 5, 0, 1)
    rust = np.clip((chips + rust_edge * 0.35 + bottom * 0.3 - 0.78) * 7, 0, 1)
    paint_c = colorize(n1, np.array(paint) * 0.82, np.array(paint) * 1.08)
    rust_c = colorize(tn(40, 3, 0.5, 311).repeat(2, 0), (0.22, 0.1, 0.04), (0.48, 0.25, 0.1))
    alb = paint_c * (1 - rust[..., None]) + rust_c * rust[..., None]
    # painéis estampados, chapa de chute, rebites, escorrido de sujeira
    def emb(d):
        d.rectangle([40, 60, 472, 460], outline=255, width=10)
        d.rectangle([40, 520, 472, 860], outline=255, width=10)
        for x in (24, 488):
            for y in range(40, 1000, 96):
                d.ellipse([x - 7, y - 7, x + 7, y + 7], fill=255)
    e = mask_from_draw(W, H, emb, 2)
    kick = ((yy > 0.9) & (yy < 0.985)).astype(float)
    grime = np.clip((tall(3, 4, 0.5, 320) - 0.4) * 1.4, 0, 1) * (0.3 + yy * 0.5)
    streak = np.clip(np.repeat(tn(60, 2, 0.5, 321)[:1, :], H, 0) * yy * 1.2 - 0.5, 0, 1)
    alb = alb * (1 - 0.35 * grime[..., None]) * (1 - 0.25 * streak[..., None])
    alb = alb * (1 - e[..., None] * 0.18) + e[..., None] * 0.04
    alb = alb * (1 - kick[..., None]) + kick[..., None] * colorize(tall(30, 3, 0.5, 322), (0.3, 0.3, 0.29), (0.45, 0.45, 0.43))
    if stencil:
        im = Image.fromarray((np.clip(alb, 0, 1) * 255).astype(np.uint8))
        d = ImageDraw.Draw(im)
        d.text((W // 2, 300), stencil, fill=(214, 206, 184), font=font(64), anchor="mm")
        alb = np.asarray(im, dtype=np.float64) / 255.0
    h = 0.5 + e * 0.35 - rust * 0.15 + kick * 0.1 + n1 * 0.05
    rough = 0.5 + rust * 0.4 + grime * 0.1
    metal = 0.25 * (1 - rust) + kick * 0.5
    save_any(name, alb, h, rough, metal, 5)


def door_wood():
    W, H = 512, 1024
    yy, xx = np.mgrid[0:H, 0:W] / np.array([H, W])[:, None, None]
    warp = tall(3, 3, 0.5, 340)
    grain = np.sin((xx * 26 + warp * 3 + tall(40, 2, 0.5, 341) * 0.4) * np.pi) * 0.5 + 0.5
    wood = colorize(grain * 0.5 + tall(80, 2, 0.5, 342) * 0.5, (0.26, 0.16, 0.09), (0.42, 0.28, 0.16))
    paint = colorize(tall(20, 3, 0.5, 343), (0.46, 0.5, 0.42), (0.55, 0.58, 0.5))
    peel = np.clip((tall(7, 6, 0.6, 344) - 0.66) * 9, 0, 1)
    alb = paint * (1 - peel[..., None]) + wood * peel[..., None]

    def panels(d):
        for (x0, y0, x1, y1) in ((60, 60, 236, 440), (276, 60, 452, 440), (60, 500, 236, 960), (276, 500, 452, 960)):
            d.rectangle([x0, y0, x1, y1], outline=255, width=14)
    pm = mask_from_draw(W, H, panels, 3)
    grime = np.clip((tall(4, 4, 0.5, 345) - 0.45) * 1.2, 0, 1)
    hand = np.exp(-(((xx - 0.86) / 0.08) ** 2 + ((yy - 0.5) / 0.06) ** 2))
    alb = alb * (1 - pm[..., None] * 0.28) * (1 - 0.3 * grime[..., None]) * (1 - 0.35 * hand[..., None])
    h = 0.5 + pm * 0.3 - peel * 0.12 + grain * 0.06
    save_any("door_wood", alb, h, 0.75 + peel * 0.15, np.zeros_like(h), 5)


def door_train():
    W, H = 512, 1024
    yy, xx = np.mgrid[0:H, 0:W] / np.array([H, W])[:, None, None]
    n1 = tall(16, 4, 0.5, 360)
    paint = colorize(n1, (0.46, 0.17, 0.12), (0.58, 0.22, 0.15))       # vermelho-ferrovia desbotado
    band = ((yy > 0.62) & (yy < 0.66)).astype(float)
    alb = paint * (1 - band[..., None]) + band[..., None] * np.array([0.78, 0.72, 0.5])
    # janela (topo): vidro escuro sujo + caixilho de borracha
    win = ((xx > 0.14) & (xx < 0.86) & (yy > 0.1) & (yy < 0.42)).astype(float)
    glass = colorize(tall(6, 4, 0.5, 361), (0.06, 0.08, 0.09), (0.18, 0.2, 0.2))
    rub = (((xx > 0.11) & (xx < 0.89) & (yy > 0.08) & (yy < 0.44)).astype(float) - win)
    alb = alb * (1 - win[..., None]) + glass * win[..., None]
    alb = alb * (1 - rub[..., None]) + rub[..., None] * 0.07
    chips = np.clip((tall(6, 6, 0.6, 362) - 0.76) * 8, 0, 1) * (1 - win)
    alb = alb * (1 - chips[..., None]) + chips[..., None] * colorize(tall(30, 3, 0.5, 363), (0.2, 0.1, 0.05), (0.4, 0.22, 0.1))
    grime = np.clip(yy - 0.55, 0, 1) * 1.6 * tall(3, 4, 0.5, 364)
    alb *= (1 - 0.5 * grime[..., None])
    im = Image.fromarray((np.clip(alb, 0, 1) * 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    d.text((W // 2, 760), "07", fill=(214, 200, 160), font=font(90), anchor="mm")
    d.text((W // 2, 850), "NÃO SE APOIE NA PORTA", fill=(200, 190, 150), font=font(24), anchor="mm")
    alb = np.asarray(im, dtype=np.float64) / 255.0
    h = 0.5 + rub * 0.25 - win * 0.2 - chips * 0.1 + band * 0.05
    rough = 0.5 + chips * 0.3 + grime * 0.2 - win * 0.35
    save_any("door_train", alb, h, rough, 0.2 * (1 - chips), 5)


# ---------------------------------------------------------------- barris (desdobrados: u = volta, v = altura)
def barrel(name, paint, label):
    W, H = 1024, 512
    yy, xx = np.mgrid[0:H, 0:W] / np.array([H, W])[:, None, None]
    n1 = np.hstack([tn(20, 4, 0.5, 380), tn(20, 4, 0.5, 381)])
    paint_c = colorize(n1, np.array(paint) * 0.8, np.array(paint) * 1.05)
    ribs = np.zeros((H, W))
    for v in (0.0, 0.27, 0.73, 1.0):
        ribs += np.exp(-((yy - v) / 0.018) ** 2)
    ribs = np.clip(ribs, 0, 1)
    wear = np.clip(ribs * 0.6 + np.hstack([tn(6, 6, 0.6, 382), tn(6, 6, 0.6, 383)]) - 0.85, 0, 1) * 6
    wear = np.clip(wear, 0, 1)
    drip = np.clip(np.repeat(np.hstack([tn(70, 2, 0.5, 384), tn(70, 2, 0.5, 385)])[:1, :], H, 0) * 1.6 - 1.0 + (1 - yy) * 0.0, 0, 1) * (yy > 0.3)
    rust_c = colorize(np.hstack([tn(40, 3, 0.5, 386)] * 2), (0.24, 0.11, 0.04), (0.5, 0.26, 0.1))
    alb = paint_c * (1 - wear[..., None]) + rust_c * wear[..., None]
    alb *= (1 - 0.35 * drip[..., None])
    alb *= (1 - 0.12 * ribs[..., None])
    im = Image.fromarray((np.clip(alb, 0, 1) * 255).astype(np.uint8))
    d = ImageDraw.Draw(im)
    for cx in (256, 768):
        if label == "fogo":
            d.rectangle([cx - 110, 170, cx + 110, 345], fill=(222, 208, 170))
            d.polygon([(cx, 190), (cx - 60, 295), (cx + 60, 295)], outline=(30, 25, 20), width=6)
            d.ellipse([cx - 16, 235, cx + 16, 282], fill=(30, 25, 20))
            d.text((cx, 322), "INFLAMÁVEL", fill=(30, 25, 20), font=font(28), anchor="mm")
        else:
            d.text((cx, 220), "RES. 4", fill=(210, 205, 180), font=font(48), anchor="mm")
            d.text((cx, 285), "ÓLEO TÉCNICO", fill=(210, 205, 180), font=font(28), anchor="mm")
    alb = np.asarray(im, dtype=np.float64) / 255.0
    h = 0.5 + ribs * 0.4 - wear * 0.1
    save_any(name, alb, h, 0.45 + wear * 0.4, 0.35 * (1 - wear), 5)


# ---------------------------------------------------------------- tecidos / acabamentos (tileáveis 512)
yy, xx = G.yy, G.xx


def fabric():
    """Sarja tingível (clara) — casacos, calças, macacões."""
    tw = (np.sin((xx * 160 + yy * 160) * np.pi) * 0.5 + 0.5) * 0.5 + (np.sin(xx * 320 * np.pi) * 0.5 + 0.5) * 0.2
    n = tn(8, 5, 0.6, 400)
    alb = colorize(tw * 0.35 + n * 0.65, (0.62, 0.62, 0.6), (0.86, 0.86, 0.84))
    seam = (np.abs((xx * 2) % 1 - 0.5) > 0.494).astype(float)
    alb *= (1 - seam[..., None] * 0.35)
    G.save("fabric", alb, tw * 0.5 + seam * 0.4, np.full((N, N), 0.92), np.zeros((N, N)), nstrength=3)


def camo_ow():
    """Camuflagem urbana azul-cinza com faixas (inspirada no soldado de 2002-03 — padrão original)."""
    a, b, c = tn(5, 4, 0.55, 410), tn(7, 4, 0.55, 411), tn(9, 4, 0.55, 412)
    base = np.array([0.32, 0.37, 0.42])
    alb = np.ones((N, N, 3)) * base
    alb = np.where((a > 0.55)[..., None], np.array([0.2, 0.24, 0.29]), alb)
    alb = np.where((b > 0.6)[..., None], np.array([0.48, 0.52, 0.55]), alb)
    alb = np.where((c > 0.66)[..., None], np.array([0.13, 0.15, 0.18]), alb)
    tw = (np.sin((xx * 200 + yy * 200) * np.pi) * 0.5 + 0.5)
    alb *= (0.9 + tw[..., None] * 0.1)
    G.save("camo_ow", alb, tw * 0.4 + a * 0.2, np.full((N, N), 0.85), np.zeros((N, N)), nstrength=3)


def leather():
    cells = G.voronoi_edges(900, 420)
    n = tn(10, 5, 0.6, 421)
    alb = colorize(n * 0.6 + cells * 0.4, (0.05, 0.045, 0.04), (0.14, 0.12, 0.1))
    G.save("leather", alb, cells * 0.6 + n * 0.3, 0.45 + n * 0.25, np.zeros((N, N)), nstrength=4)


def rubber():
    n = tn(40, 3, 0.5, 430)
    alb = colorize(n, (0.07, 0.075, 0.07), (0.12, 0.125, 0.115))
    G.save("rubber", alb, n * 0.3, np.full((N, N), 0.7), np.zeros((N, N)), nstrength=2)


def flak():
    """Colete antiestilhaço acolchoado (conscritos)."""
    q = np.abs(np.sin(yy * 10 * np.pi)) ** 0.5
    n = tn(10, 5, 0.6, 440)
    alb = colorize(n * 0.5 + q * 0.5, (0.22, 0.24, 0.16), (0.36, 0.38, 0.25))
    G.save("flak", alb, q * 0.8 + n * 0.2, np.full((N, N), 0.88), np.zeros((N, N)), nstrength=5)


def hazmat():
    """Traje de borracha verde dos cidadãos da era do Trocador de Ar (2001-02)."""
    n = tn(6, 5, 0.6, 450)
    creases = np.abs(tn(14, 3, 0.5, 451) - 0.5) < 0.02
    alb = colorize(n, (0.25, 0.32, 0.2), (0.36, 0.43, 0.28)) * (1 - creases[..., None] * 0.3)
    G.save("hazmat", alb, n * 0.4 + creases * 0.3, np.full((N, N), 0.55), np.zeros((N, N)), nstrength=3)


def gunmetal():
    """Aço fosfatizado com desgaste nas bordas (armas)."""
    n = tn(60, 3, 0.5, 460)
    wear = np.clip((tn(8, 6, 0.6, 461) - 0.72) * 6, 0, 1)
    alb = colorize(n, (0.09, 0.095, 0.1), (0.15, 0.155, 0.16))
    alb = alb * (1 - wear[..., None]) + wear[..., None] * np.array([0.42, 0.42, 0.42])
    G.save("gunmetal", alb, n * 0.2, 0.55 - wear * 0.25, 0.6 + wear * 0.4, nstrength=2)


def polymer():
    n = tn(90, 2, 0.5, 470)
    alb = colorize(n, (0.06, 0.06, 0.06), (0.1, 0.1, 0.1))
    G.save("polymer", alb, n * 0.5, np.full((N, N), 0.75), np.zeros((N, N)), nstrength=3)


def stock_wood():
    warp = tn(3, 3, 0.5, 480)
    rings = np.sin((yy * 30 + warp * 5) * np.pi) * 0.5 + 0.5
    alb = colorize(rings * 0.5 + tn(50, 2, 0.5, 481) * 0.5, (0.25, 0.12, 0.05), (0.46, 0.25, 0.11))
    G.save("stock_wood", alb, rings * 0.3, np.full((N, N), 0.5), np.zeros((N, N)), nstrength=2)


JOBS = {
    "door_metal_red": lambda: door_metal("door_metal_red", (0.5, 0.2, 0.15)),
    "door_metal_grey": lambda: door_metal("door_metal_grey", (0.42, 0.47, 0.46), "SERVIÇO"),
    "door_wood": door_wood, "door_train": door_train,
    "barrel_blue": lambda: barrel("barrel_blue", (0.18, 0.3, 0.42), "oleo"),
    "barrel_red": lambda: barrel("barrel_red", (0.62, 0.16, 0.1), "fogo"),
    "fabric": fabric, "camo_ow": camo_ow, "leather": leather, "rubber": rubber, "flak": flak,
    "hazmat": hazmat, "gunmetal": gunmetal, "polymer": polymer, "stock_wood": stock_wood,
}
only = sys.argv[1:]
for k, f in JOBS.items():
    if not only or k in only:
        f()
