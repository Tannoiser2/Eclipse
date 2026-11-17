#!/usr/bin/env python3
"""Riscrive in italiano i titoli stampati sulle tessere (tecnologie, parti delle navi, parti antiche delle
scoperte): copre la fascia del titolo inglese con il suo colore e scrive il nome italiano.
Da lanciare dopo estrai_materiale.py. Uso: python3 tools/traduci_tessere.py
I nomi vengono da scripts/data/ec_data.gd."""
import os, re
from PIL import Image, ImageDraw, ImageFont, ImageFilter

R = os.path.join(os.path.dirname(__file__), '..')
src = open(R + '/scripts/data/ec_data.gd', encoding='utf-8').read()
TECH = dict(re.findall(r'^\t"(\w+)": \{"name": "([^"]+)", "cat"', src, re.M))
PARTS = {}
for m in re.finditer(r'^\t"(\w+)": \{"name": "([^"]+)", "en"[^\n]*?(?:"img": "(\w+)")?\}', src, re.M):
    PARTS[m.group(1)] = (m.group(2), m.group(3))
ARROW = {'soliton_missile', 'morph_shield', 'flux_shield', 'muon_source', 'axion_computer', 'conformal_drive', 'ion_disruptor'}
FONT = R + '/assets/fonts/Rajdhani-Bold.ttf'


def fit_font(draw, lines, w, h, start):
    size = start
    while size > 8:
        f = ImageFont.truetype(FONT, size)
        lh = size * 0.95
        if all(draw.textlength(l, font=f) <= w for l in lines) and lh * len(lines) <= h:
            return f, lh
        size -= 1
    return ImageFont.truetype(FONT, 8), 8


def split(name, two):
    if not two or ' ' not in name:
        return [name]
    words = name.split(' ')
    best = None
    for i in range(1, len(words)):
        a, b = ' '.join(words[:i]), ' '.join(words[i:])
        d = abs(len(a) - len(b))
        if best is None or d < best[0]:
            best = (d, [a, b])
    return best[1]


def retitle(path, name, box, sample, start, two):
    im = Image.open(path).convert('RGB')
    x0, y0, x1, y1 = box
    region = im.crop(box)
    col = region.filter(ImageFilter.MedianFilter(9)).resize((1, 1), Image.LANCZOS).getpixel((0, 0))
    col = im.getpixel(sample) if sample else col
    d = ImageDraw.Draw(im)
    d.rectangle(box, fill=col)
    lines = [l.upper() for l in split(name, two)]
    best = None
    for cand in ([lines] if len(lines) == 1 else [[name.upper()], lines]):
        f, lh = fit_font(d, cand, x1 - x0 - 4, y1 - y0 - 2, start)
        if best is None or f.size > best[1].size:
            best = (cand, f, lh)
    lines, f, lh = best
    y = y0 + (y1 - y0 - lh * len(lines)) / 2 - f.size * 0.08
    for l in lines:
        w = d.textlength(l, font=f)
        d.text((x0 + (x1 - x0 - w) / 2, y), l, font=f, fill=(245, 245, 245))
        y += lh
    im.save(path, quality=92)


for t, name in TECH.items():
    p = R + f'/assets/tecnologie/{t}.jpg'
    if os.path.exists(p):
        retitle(p, name, (4, 3, 252, 47), (4, 20), 30, True)
for pt, (name, img) in PARTS.items():
    if img:
        p = R + f'/assets/scoperte/{img}.jpg'
        if os.path.exists(p):
            right = 128 if pt in ARROW else 168
            retitle(p, name, (10, 12, right, 72), (6, 40), 26, True)
    else:
        p = R + f'/assets/parti/{pt}.jpg'
        if os.path.exists(p):
            retitle(p, name, (10, 14, 160, 66), (6, 40), 26, True)
print('fatto')


# settori: la parola «SECTOR» sotto il nome e il nome del Centro Galattico
def patch(im, box, text, size):
    pad = 6
    region = im.crop((box[0] - pad, box[1] - pad, box[2] + pad, box[3] + pad))
    px = [c for c in region.get_flattened_data() if sum(c) < 300]
    col = tuple(sum(c[i] for c in px) // max(1, len(px)) for i in range(3)) if px else (40, 36, 48)
    d = ImageDraw.Draw(im)
    d.rectangle(box, fill=col)
    f = ImageFont.truetype(FONT, size)
    lines = text.split('\n')
    y = box[1] + (box[3] - box[1] - size * 0.95 * len(lines)) / 2 - 1
    for l in lines:
        w = d.textlength(l, font=f)
        d.text(((box[0] + box[2]) / 2 - w / 2, y), l, font=f, fill=(238, 238, 238))
        y += size * 0.95


import glob
for p in glob.glob(R + '/assets/settori/*.jpg'):
    if 'retro' in p:
        continue
    im = Image.open(p).convert('RGB')
    s = im.size[0] / 512
    patch(im, tuple(int(v * s) for v in (396, 265, 438, 281)), 'SETTORE', int(11 * s))
    if os.path.basename(p) == '1.jpg':
        patch(im, tuple(int(v * s) for v in (387, 233, 444, 262)), 'CENTRO\nGALATTICO', int(12 * s))
    im.save(p, quality=90)
print('settori fatti')
