"""Gera conjuntos PBR originais (albedo, normal, ORM) proceduralmente.
Tudo é sintetizado do zero com ruído; nenhum asset de terceiros é usado.
Saída: assets/textures/<nome>_{albedo,normal,orm}.png  (512x512, tileável)
ORM = R: oclusão, G: rugosidade, B: metalicidade (padrão glTF / Godot ORM).
"""
import numpy as np
from PIL import Image
import os, sys

N = 512
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
os.makedirs(OUT, exist_ok=True)
rng = np.random.default_rng(1337)


def tile_noise(freq, octaves=5, persistence=0.5, seed=0):
    """Ruído fractal tileável via FFT (espectro 1/f filtrado)."""
    r = np.random.default_rng(seed)
    acc = np.zeros((N, N))
    amp, total = 1.0, 0.0
    for o in range(octaves):
        f = freq * (2 ** o)
        g = r.standard_normal((N, N))
        F = np.fft.fft2(g)
        ky = np.fft.fftfreq(N)[:, None] * N
        kx = np.fft.fftfreq(N)[None, :] * N
        k = np.sqrt(kx ** 2 + ky ** 2)
        mask = np.exp(-((k / max(f, 1e-3)) ** 2))
        layer = np.real(np.fft.ifft2(F * mask))
        layer = (layer - layer.mean()) / (layer.std() + 1e-9)
        acc += layer * amp
        total += amp
        amp *= persistence
    acc /= total
    acc = (acc - acc.min()) / (acc.max() - acc.min() + 1e-9)
    return acc


def normal_from_height(h, strength=4.0):
    dx = (np.roll(h, -1, 1) - np.roll(h, 1, 1)) * strength
    dy = (np.roll(h, -1, 0) - np.roll(h, 1, 0)) * strength
    nz = np.ones_like(h)
    l = np.sqrt(dx ** 2 + dy ** 2 + nz ** 2)
    n = np.stack([-dx / l, dy / l, nz / l], -1)  # OpenGL-style (Godot)
    return ((n * 0.5 + 0.5) * 255).astype(np.uint8)


def save(name, albedo, height, rough, metal, ao=None, nstrength=4.0):
    albedo = np.clip(albedo, 0, 1)
    if ao is None:
        ao = np.clip(0.55 + height * 0.45, 0, 1)
    Image.fromarray((albedo * 255).astype(np.uint8)).save(f"{OUT}/{name}_albedo.png")
    Image.fromarray(normal_from_height(height, nstrength)).save(f"{OUT}/{name}_normal.png")
    orm = np.stack([ao, np.clip(rough, 0, 1), np.clip(metal, 0, 1)], -1)
    Image.fromarray((orm * 255).astype(np.uint8)).save(f"{OUT}/{name}_orm.png")
    print("ok", name)


def colorize(t, c0, c1):
    c0, c1 = np.array(c0), np.array(c1)
    return c0[None, None] * (1 - t[..., None]) + c1[None, None] * t[..., None]


yy, xx = np.mgrid[0:N, 0:N] / N

# 1. Concreto brutalista com marcas de forma (painéis) e manchas de escorrimento
def concrete():
    base = tile_noise(6, 6, 0.55, 1)
    fine = tile_noise(60, 3, 0.5, 2)
    stains = tile_noise(3, 4, 0.6, 3)
    # escorrimento vertical: ruído esticado em Y
    drip = np.repeat(tile_noise(40, 2, 0.5, 4)[:1, :], N, 0) * (0.4 + 0.6 * yy)
    seams = ((np.abs((xx * 2) % 1 - 0.5) > 0.495) | (np.abs((yy * 2) % 1 - 0.5) > 0.495)).astype(float)
    holes = np.zeros((N, N))
    for cx in (0.25, 0.75):
        for cy in (0.25, 0.75):
            d = np.sqrt(((xx - cx + 0.5) % 1 - 0.5) ** 2 + ((yy - cy + 0.5) % 1 - 0.5) ** 2)
            holes += (d < 0.012).astype(float)
    t = base * 0.5 + fine * 0.3 + stains * 0.2
    alb = colorize(t, (0.36, 0.37, 0.38), (0.58, 0.58, 0.57))
    alb *= (1 - 0.25 * drip[..., None] * (stains[..., None] > 0.45))
    alb *= (1 - 0.35 * seams[..., None]) * (1 - 0.5 * holes[..., None])
    h = fine * 0.5 + base * 0.3 - seams * 0.6 - holes * 0.8
    save("concrete", alb, h, 0.85 + fine * 0.15, np.zeros((N, N)))

# 2. Metal pintado descascado e enferrujado (Domínio / trens)
def rusted_paint():
    rust_mask = tile_noise(5, 6, 0.6, 10)
    streak = tile_noise(2, 3, 0.5, 14) * 0.25
    edge = np.clip((rust_mask + streak - 0.72) * 10, 0, 1)
    paint = colorize(tile_noise(20, 3, 0.5, 11), (0.17, 0.24, 0.26), (0.24, 0.31, 0.33))
    rust = colorize(tile_noise(30, 4, 0.6, 12), (0.25, 0.12, 0.05), (0.52, 0.27, 0.11))
    alb = paint * (1 - edge[..., None]) + rust * edge[..., None]
    h = tile_noise(50, 3, 0.5, 13) * 0.3 + (1 - edge) * 0.4
    rough = 0.55 + edge * 0.4
    metal = (1 - edge) * 0.35
    save("rusted_paint", alb, h, rough, metal, nstrength=6)

# 3. Aço industrial escovado (Trocador Atmosférico)
def steel():
    brushed = np.repeat(tile_noise(80, 3, 0.5, 20)[:, :1], N, 1)
    brushed = 0.7 * brushed + 0.3 * tile_noise(10, 3, 0.5, 21)
    dirt = tile_noise(4, 5, 0.6, 22)
    alb = colorize(brushed, (0.42, 0.44, 0.46), (0.62, 0.63, 0.65)) * (1 - 0.4 * dirt[..., None] ** 2)
    # rebites em grade
    gx, gy = (xx * 8) % 1, (yy * 8) % 1
    rivet = (np.sqrt((gx - 0.5) ** 2 + (gy - 0.08) ** 2) < 0.05).astype(float)
    h = brushed * 0.2 + rivet * 0.8
    save("steel", alb, h, 0.35 + dirt * 0.4, np.full((N, N), 0.9) - dirt * 0.3)

# 4. Azulejos cerâmicos sujos (estações, laboratórios — inspiração interior cerâmico 2000-02)
def tiles():
    tx, ty = (xx * 8) % 1, (yy * 8) % 1
    grout = ((tx < 0.05) | (ty < 0.05)).astype(float)
    tid = (np.floor(xx * 8) * 13 + np.floor(yy * 8) * 7) % 5 / 5
    dirt = tile_noise(5, 5, 0.6, 30)
    crack = (np.abs(tile_noise(25, 4, 0.5, 31) - 0.5) < 0.008).astype(float)
    alb = colorize(np.full((N, N), 0.5), (0.55, 0.62, 0.58), (0.55, 0.62, 0.58)) * (0.9 + 0.1 * tid[..., None])
    alb = alb * (1 - grout[..., None] * 0.55) * (1 - 0.45 * dirt[..., None] ** 1.5) * (1 - 0.6 * crack[..., None])
    h = 1 - grout - crack * 0.5
    save("tiles", alb, h, 0.25 + grout * 0.6 + dirt * 0.3, np.zeros((N, N)), nstrength=3)

# 5. Asfalto / piso de pátio molhado
def asphalt():
    grain = tile_noise(120, 2, 0.5, 40)
    patches = tile_noise(4, 4, 0.6, 41)
    wet = (patches > 0.6).astype(float)
    alb = colorize(grain * 0.6 + patches * 0.4, (0.10, 0.10, 0.11), (0.25, 0.25, 0.26))
    alb *= (1 - 0.3 * wet[..., None])
    save("asphalt", alb, grain, 0.9 - wet * 0.7, np.zeros((N, N)))

# 6. Tijolo envelhecido (Cidade Nove — bairro antigo)
def brick():
    row = np.floor(yy * 16)
    off = (row % 2) * 0.5
    bx = ((xx * 8 + off) % 1)
    by = (yy * 16) % 1
    mortar = ((bx < 0.06) | (by < 0.1)).astype(float)
    bid = (np.floor(xx * 8 + off) * 31 + row * 17) % 7 / 7
    soot = tile_noise(3, 5, 0.6, 50)
    alb = colorize(tile_noise(40, 3, 0.5, 51), (0.30, 0.15, 0.11), (0.45, 0.24, 0.17)) * (0.8 + 0.25 * bid[..., None])
    alb = alb * (1 - mortar[..., None]) + mortar[..., None] * np.array([0.38, 0.36, 0.33])
    alb *= (1 - 0.5 * soot[..., None] ** 2)
    h = (1 - mortar) * 0.8 + tile_noise(60, 2, 0.5, 52) * 0.2
    save("brick", alb, h, 0.9 * np.ones((N, N)), np.zeros((N, N)))

# 7. Painel do Domínio (tecnologia opressiva, azul-acinzentado com ranhuras)
def dominion():
    panel = ((np.abs((xx * 4) % 1 - 0.5) > 0.47) | (np.abs((yy * 2) % 1 - 0.5) > 0.48)).astype(float)
    groove = (np.abs((yy * 16) % 1 - 0.5) > 0.46).astype(float) * ((xx * 4) % 1 > 0.6)
    base = tile_noise(8, 4, 0.5, 60)
    alb = colorize(base, (0.10, 0.12, 0.15), (0.20, 0.23, 0.27)) * (1 - 0.5 * panel[..., None])
    h = 1 - panel - groove * 0.4
    save("dominion", alb, h, 0.3 + base * 0.2, np.full((N, N), 0.75), nstrength=5)

# 8. Terreno seco / leito marinho rachado (Mar Seco)
def voronoi_edges(n_pts, seed, warp=0.0):
    """Distância à borda de células de Voronoi (tileável, F2-F1)."""
    r = np.random.default_rng(seed)
    pts = r.random((n_pts, 2))
    u = (xx + (tile_noise(4, 3, 0.5, seed + 1) - 0.5) * warp) % 1.0
    v = (yy + (tile_noise(4, 3, 0.5, seed + 2) - 0.5) * warp) % 1.0
    d1 = np.full((N, N), 9.0); d2 = np.full((N, N), 9.0)
    for px, py in pts:
        dx = np.abs(u - px); dx = np.minimum(dx, 1 - dx)
        dy = np.abs(v - py); dy = np.minimum(dy, 1 - dy)
        d = np.sqrt(dx * dx + dy * dy)
        d2 = np.where(d < d1, d1, np.minimum(d2, d))
        d1 = np.minimum(d1, d)
    return d2 - d1

def cracked_earth():
    e = voronoi_edges(42, 70, 0.08)
    e2 = voronoi_edges(160, 72, 0.05)
    cr = np.clip(1 - e / 0.012, 0, 1) + np.clip(1 - e2 / 0.005, 0, 1) * 0.5
    cr = np.clip(cr, 0, 1)
    alb = colorize(tile_noise(20, 4, 0.5, 71), (0.38, 0.34, 0.27), (0.55, 0.50, 0.40)) * (1 - 0.6 * cr[..., None])
    save("cracked_earth", alb, 1 - cr, np.full((N, N), 0.95), np.zeros((N, N)))

# 9. Madeira velha (bancos, caixotes)
def wood():
    warp = tile_noise(3, 3, 0.5, 80)
    rings = (np.sin((xx * 40 + warp * 6) * np.pi) * 0.5 + 0.5)
    planks = (np.abs((yy * 4) % 1 - 0.5) > 0.48).astype(float)
    alb = colorize(rings * 0.6 + tile_noise(60, 2, 0.5, 81) * 0.4, (0.22, 0.15, 0.09), (0.40, 0.29, 0.18))
    alb *= (1 - planks[..., None] * 0.6)
    save("wood", alb, rings * 0.3 + (1 - planks) * 0.7, np.full((N, N), 0.8), np.zeros((N, N)))

# 10. Grade metálica de piso (passarelas)
def grate():
    gx, gy = (xx * 16) % 1, (yy * 16) % 1
    bar = ((gx < 0.22) | (gy < 0.22)).astype(float)
    dirt = tile_noise(6, 4, 0.5, 90)
    alb = colorize(dirt, (0.22, 0.22, 0.22), (0.36, 0.34, 0.32)) * (0.15 + 0.85 * bar[..., None])
    save("grate", alb, bar, 0.5 + dirt * 0.4, bar * 0.8, nstrength=8)

# 11. Cascalho de lastro ferroviário (pátio)
def gravel():
    e = voronoi_edges(900, 110, 0.0)
    stones = np.clip(e / 0.02, 0, 1)
    tone = tile_noise(40, 3, 0.5, 111)
    dirt = tile_noise(3, 4, 0.5, 112)
    alb = colorize(tone, (0.20, 0.19, 0.17), (0.36, 0.34, 0.31)) * (0.55 + 0.45 * stones[..., None])
    alb = alb * (1 - dirt[..., None] * 0.35) + np.array((0.16, 0.12, 0.08)) * dirt[..., None] * 0.35
    save("gravel", alb, stones * 0.8 + tone * 0.2, np.full((N, N), 0.92), np.zeros((N, N)), nstrength=6)


# 12. Areia/lodo do Mar Seco (dunas finas + conchas)
def sand():
    ripple = np.sin((yy * 22 + tile_noise(2, 3, 0.5, 120) * 3.0) * 2 * np.pi) * 0.5 + 0.5
    fine = tile_noise(90, 2, 0.5, 121)
    blot = tile_noise(4, 4, 0.5, 122)
    alb = colorize(blot * 0.6 + fine * 0.4, (0.46, 0.41, 0.33), (0.62, 0.56, 0.45)) * (0.88 + 0.12 * ripple[..., None])
    salt = (tile_noise(30, 3, 0.5, 123) > 0.78).astype(float)
    alb = alb * (1 - salt[..., None] * 0.3) + np.array((0.8, 0.78, 0.72)) * salt[..., None] * 0.3
    save("sand", alb, ripple * 0.5 + fine * 0.5, np.full((N, N), 0.97), np.zeros((N, N)), nstrength=3)

# 13. Água turva do canal (normal de ondulação; albedo escuro esverdeado)
def water():
    h = tile_noise(8, 4, 0.55, 130) * 0.6 + tile_noise(24, 2, 0.5, 131) * 0.4
    alb = colorize(h, (0.06, 0.09, 0.08), (0.12, 0.16, 0.13))
    save("water", alb, h, np.full((N, N), 0.08), np.zeros((N, N)), ao=np.ones((N, N)), nstrength=5)

# 14. Chapa corrugada enferrujada (ferro-velho, barracos)
def corrugated():
    wave = np.sin(xx * 2 * np.pi * 16) * 0.5 + 0.5
    rust = tile_noise(6, 5, 0.55, 140)
    streak = tile_noise(1, 3, 0.5, 141)[:, :1].repeat(N, 1) * 0 + np.clip(np.abs(np.sin(xx * 37.0 * np.pi)) * tile_noise(2, 3, 0.5, 142), 0, 1)
    base = colorize(wave * 0.3 + 0.35, (0.30, 0.32, 0.31), (0.50, 0.52, 0.50))
    rc = colorize(rust, (0.30, 0.14, 0.06), (0.55, 0.30, 0.12))
    k = np.clip((rust - 0.42) * 3.0 + streak * 0.4, 0, 1)[..., None]
    alb = base * (1 - k) + rc * k
    save("corrugated", alb, wave * 0.85 + rust * 0.15, 0.5 + k[..., 0] * 0.4, 0.7 * (1 - k[..., 0]), nstrength=6)

def blueprint():
    from PIL import ImageDraw, ImageFont
    W, H = 1024, 720
    im = Image.new("RGB", (W, H), (22, 52, 96))
    d = ImageDraw.Draw(im)
    c = (190, 215, 240)
    for x in range(0, W, 32): d.line([(x, 0), (x, H)], fill=(34, 68, 118))
    for y in range(0, H, 32): d.line([(0, y), (W, y)], fill=(34, 68, 118))
    d.rectangle([20, 20, W - 20, H - 20], outline=c, width=3)
    # duto de troca de ar: torre em corte, ventiladores, câmaras
    d.rectangle([380, 90, 640, 600], outline=c, width=3)
    for i in range(5):
        y = 140 + i * 90
        d.ellipse([430, y, 590, y + 60], outline=c, width=2)
        d.line([(510, y), (510, y + 60)], fill=c, width=1); d.line([(430, y + 30), (590, y + 30)], fill=c, width=1)
    for s in (-1, 1):
        x0 = 380 if s < 0 else 640
        for i in range(4):
            y = 160 + i * 110
            d.line([(x0, y), (x0 + s * 220, y - 40)], fill=c, width=2)
            d.line([(x0, y + 30), (x0 + s * 220, y - 10)], fill=c, width=2)
            d.rectangle([x0 + s * 220 - 18, y - 52, x0 + s * 220 + 18, y], outline=c, width=2)
    d.polygon([(380, 90), (510, 40), (640, 90)], outline=c)
    for y in range(110, 600, 18):
        d.line([(660 + 200, y), (980, y)], fill=(120, 160, 200))
    try:
        f = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono-Bold.ttf", 26)
        f2 = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSansMono.ttf", 16)
    except Exception:
        f = f2 = ImageFont.load_default()
    d.text((40, 40), "TROCADOR DE AR — DUTO PRINCIPAL  REV. 4", fill=c, font=f)
    d.text((40, 640), "ENG. T. VARGA   ESCALA 1:500   CIDADE NOVE / SETOR LESTE", fill=c, font=f2)
    d.text((40, 665), "APROVADO: ______   NÃO REPRODUZIR", fill=c, font=f2)
    d.text((40, 100), "CORTE A-A", fill=c, font=f2)
    d.text((40, 130), "VAZÃO NOMINAL 4,2e6 m3/h", fill=c, font=f2)
    d.text((40, 160), "CÂMARAS DE FILTRAGEM x5", fill=c, font=f2)
    im.save(f"{OUT}/blueprint.png"); print("ok blueprint")

only = sys.argv[1:]
for f in (concrete, rusted_paint, steel, tiles, asphalt, brick, dominion, cracked_earth, wood, grate, gravel, sand, water, corrugated, blueprint):
    if not only or f.__name__ in only:
        f()
