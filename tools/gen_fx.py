"""Texturas de efeitos e sinalização (originais): furos de bala, queimadura, fumaça, clarão, cartazes."""
import numpy as np
from PIL import Image, ImageDraw, ImageFont, ImageFilter
import os
OUT = os.path.join(os.path.dirname(__file__), "..", "assets", "textures")
r = np.random.default_rng(3)
def radial(n):
    y, x = np.mgrid[0:n, 0:n] / (n - 1) * 2 - 1
    return np.sqrt(x**2 + y**2), np.arctan2(y, x)
# furo de bala
n = 128; d, a = radial(n)
ragged = 0.22 + 0.06 * np.sin(a * 7 + 1) + 0.04 * np.sin(a * 13)
hole = d < ragged * 0.55
ring = (d < ragged * 1.8) & ~hole
img = np.zeros((n, n, 4))
img[ring] = [0.18, 0.17, 0.16, 0.0]
img[..., 3] = np.clip((ragged * 1.8 - d) * 4, 0, 0.8) * ring
img[hole] = [0.03, 0.03, 0.03, 1.0]
Image.fromarray((img * 255).astype(np.uint8), "RGBA").save(f"{OUT}/fx_bullet_hole.png")
# queimadura
n = 256; d, a = radial(n)
noise = r.random((n, n)); noise = np.array(Image.fromarray((noise * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(6))) / 255
al = np.clip((1 - d) * 1.6 - 0.2 + (noise - 0.5) * 1.5, 0, 1) * 0.92
img = np.stack([np.full((n, n), 0.04), np.full((n, n), 0.035), np.full((n, n), 0.03), al], -1)
Image.fromarray((img * 255).astype(np.uint8), "RGBA").save(f"{OUT}/fx_scorch.png")
# fumaça
n = 128; d, a = radial(n)
noise = r.random((n, n)); noise = np.array(Image.fromarray((noise * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(5))) / 255
al = np.clip((1 - d) * 1.3 * (0.6 + noise * 0.8), 0, 1) ** 1.5
img = np.stack([np.ones((n, n))] * 3 + [al], -1)
Image.fromarray((img * 255).astype(np.uint8), "RGBA").save(f"{OUT}/fx_smoke.png")
# clarão do cano
n = 128; d, a = radial(n)
star = np.clip(1 - d * (1.2 + 1.5 * np.abs(np.sin(a * 3))), 0, 1)
core = np.clip(1 - d * 3, 0, 1)
v = np.clip(star + core, 0, 1)
img = np.stack([v, v * 0.85, v * 0.6, v], -1)
Image.fromarray((img * 255).astype(np.uint8), "RGBA").save(f"{OUT}/fx_muzzle.png")
# cartazes de propaganda do Regente (texto original)
def font(sz):
    for p in ["/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", "/usr/share/fonts/truetype/liberation/LiberationSans-Bold.ttf"]:
        if os.path.exists(p): return ImageFont.truetype(p, sz)
    return ImageFont.load_default()
for i, (title, sub, col) in enumerate([("AR PURO", "É UM PRIVILÉGIO", (40, 70, 66)), ("RESPIRE", "OBEDEÇA", (90, 30, 20)), ("SETOR 9", "REALOCAÇÃO É PROGRESSO", (32, 40, 52))]):
    W, H = 512, 768
    im = Image.new("RGB", (W, H), col); dr = ImageDraw.Draw(im)
    # emblema: anel com traço (símbolo original do Domínio)
    dr.ellipse((136, 90, 376, 330), outline=(210, 200, 170), width=18)
    dr.rectangle((246, 60, 266, 360), fill=(210, 200, 170))
    dr.polygon([(256, 150), (310, 210), (256, 270), (202, 210)], outline=(210, 200, 170), width=10)
    f1, f2 = font(96), font(34)
    tw = dr.textlength(title, font=f1); dr.text(((W - tw) / 2, 420), title, font=f1, fill=(225, 215, 190))
    tw = dr.textlength(sub, font=f2); dr.text(((W - tw) / 2, 545), sub, font=f2, fill=(200, 190, 165))
    dr.text((30, 700), "ADMINISTRAÇÃO DO REGENTE · CIDADE NOVE", font=font(20), fill=(170, 160, 140))
    arr = np.array(im).astype(float) / 255
    grime = r.random((H, W)); grime = np.array(Image.fromarray((grime * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(12))) / 255
    arr *= (0.65 + 0.35 * grime[..., None]) ** 1.3
    tear = np.zeros((H, W)); tear[:int(H * 0.12), int(W * 0.7):] = 1
    arr[tear > 0] *= 0.35
    Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8)).save(f"{OUT}/poster_{i}.png")
# tela do Regente (rosto estilizado sintético, silhueta)
W, H = 512, 288
im = Image.new("RGB", (W, H), (10, 30, 34)); dr = ImageDraw.Draw(im)
for y in range(0, H, 3): dr.line((0, y, W, y), fill=(14, 40, 44))
dr.ellipse((196, 40, 316, 190), fill=(120, 170, 160)); dr.rectangle((150, 180, 362, 288), fill=(60, 100, 96))
dr.rectangle((236, 175, 276, 200), fill=(120, 170, 160))
dr.ellipse((222, 95, 242, 110), fill=(20, 40, 40)); dr.ellipse((270, 95, 290, 110), fill=(20, 40, 40))
dr.line((236, 150, 276, 150), fill=(30, 60, 60), width=4)
dr.text((14, 12), "TRANSMISSÃO DO REGENTE", font=font(20), fill=(170, 230, 215))
im.save(f"{OUT}/screen_regent.png")
# placas de sinalização
for i, txt in enumerate(["PLATAFORMA 3", "SAÍDA", "INSPEÇÃO", "SERVIÇO - PROIBIDO", "PÁTIO B"]):
    im = Image.new("RGB", (512, 128), (28, 34, 36)); dr = ImageDraw.Draw(im)
    dr.rectangle((6, 6, 505, 121), outline=(200, 190, 160), width=4)
    f = font(56); tw = dr.textlength(txt, font=f); dr.text(((512 - tw) / 2, 30), txt, font=f, fill=(220, 210, 180))
    im.save(f"{OUT}/sign_{i}.png")
print("fx ok")
