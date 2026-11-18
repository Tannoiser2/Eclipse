#!/usr/bin/env python3
"""Riscrive in italiano le scritte stampate sulle plance delle civiltà (assets/plance/*.jpg):
nomi delle navi, nomi delle parti nelle caselle dei progetti, tracciati delle tecnologie, orbitale e
monolito, nome della civiltà e "commercio". Il testo inglese viene cancellato con l'inpainting di OpenCV
(solo i pixel chiari delle scritte) e al suo posto si scrive il nome italiano.
Uso: python3 tools/traduci_plance.py <cartella con le plance originali, una <specie>.png per civiltà>"""
import os, re, glob, sys
import numpy as np, cv2
from PIL import Image, ImageDraw, ImageFont

R = os.path.join(os.path.dirname(__file__), '..')
src = open(R + '/scripts/data/ec_data.gd', encoding='utf-8').read()
PART = dict(re.findall(r'^\t"(\w+)": \{"name": "([^"]+)", "en"', src, re.M))
FACTION = dict(re.findall(r'^\t"(\w+)": \{"faction": "([^"]+)"', src, re.M))
F_HEAD = R + '/assets/fonts/Orbitron.ttf'
F_COND = R + '/assets/fonts/Rajdhani-Bold.ttf'
K = 1.024   # misure prese su 2000 punti, immagini larghe 2048

INT_STD = [(100, 257), (230, 155), (230, 290), (360, 257)]
CRU_STD = [(560, 215), (690, 155), (820, 215), (560, 345), (690, 290), (820, 345)]
DRE_STD = [(1035, 215), (1165, 155), (1292, 155), (1420, 215), (1035, 345), (1165, 290), (1292, 290), (1420, 345)]
SB_STD = [(1620, 155), (1748, 215), (1875, 155), (1620, 290), (1875, 290)]
LAYOUT = {
    'std': {'int': INT_STD, 'cru': CRU_STD, 'dre': DRE_STD, 'sb': SB_STD},
    'orion': {'int': INT_STD, 'cru': CRU_STD, 'dre': DRE_STD, 'sb': SB_STD},
    'planta': {'int': [(100, 257), (230, 155), (360, 257)],
               'cru': [(560, 215), (690, 155), (820, 215), (690, 290), (820, 345)],
               'dre': [(1035, 215), (1165, 155), (1292, 155), (1420, 215), (1165, 290), (1292, 290), (1420, 345)],
               'sb': [(1620, 155), (1748, 238), (1875, 155), (1875, 290)]},
    'exiles': {'int': INT_STD, 'cru': CRU_STD, 'dre': DRE_STD, 'orb': [(1620, 290), (1748, 238), (1875, 160)]},
    'rho': {'int': INT_STD, 'sb': SB_STD, 'cru': [(870, 215), (1000, 155), (1130, 215), (870, 345), (1000, 290), (1130, 345)]},
}
BPS = {}
for kind in ['STD', 'ORION', 'PLANTA', 'EXILES', 'RHO']:
    m = re.search(r'^const BP_%s := \{(.*?)^\}' % kind, src, re.M | re.S)
    BPS[kind.lower()] = {k: re.findall(r'"(\w*)"', v) for k, v in re.findall(r'"(\w+)": (\[[^\]]*\])', m.group(1))}
SP_BP = {'planta': 'planta', 'orion': 'orion', 'exiles': 'exiles', 'rho': 'rho'}
HEAD_X = {'int': 203, 'cru': 635, 'dre': 1112, 'sb': 1676, 'orb': 1666}
HEAD_X_RHO = {'int': 203, 'cru': 945, 'sb': 1676}
SHIP = {'int': 'INTERCETTORE', 'cru': 'INCROCIATORE', 'dre': 'CORAZZATA', 'sb': 'BASE STELLARE', 'orb': 'ORBITALE'}
HEAD_W = {'int': 225, 'cru': 190, 'dre': 250, 'sb': 210, 'orb': 160}


def P(x):
    return int(round(x * K))


def erase(img, box, thr=150, sat_max=90, dil=3):
    """Cancella i pixel chiari e poco saturi (le scritte) dentro box (in punti 2000)."""
    x0, y0, x1, y1 = [P(v) for v in box]
    sub = img[y0:y1, x0:x1]
    hsv = cv2.cvtColor(sub, cv2.COLOR_BGR2HSV)
    m = ((hsv[:, :, 2] > thr) & (hsv[:, :, 1] < sat_max)).astype(np.uint8) * 255
    m = cv2.dilate(m, np.ones((dil, dil), np.uint8), iterations=2)
    mask = np.zeros(img.shape[:2], np.uint8)
    mask[y0:y1, x0:x1] = m
    return cv2.inpaint(img, mask, 5, cv2.INPAINT_TELEA)


def fit(d, text, font, w, h, start):
    s = start
    while s > 8:
        f = ImageFont.truetype(font, s)
        if d.textlength(text, font=f) <= w and s * 0.9 <= h:
            return f
        s -= 1
    return ImageFont.truetype(font, 8)


def lines_for(name, d, font, w, h, start):
    name = name.upper()
    f1 = fit(d, name, font, w, h, start)
    if ' ' not in name:
        return [name], f1
    words = name.split(' ')
    best = None
    for i in range(1, len(words)):
        a, b = ' '.join(words[:i]), ' '.join(words[i:])
        cand = [a, b]
        f = fit(d, max(cand, key=lambda t: d.textlength(t, font=ImageFont.truetype(font, 20))), font, w, h / 2, start)
        if best is None or f.size > best[1].size:
            best = (cand, f)
    if best[1].size > f1.size * 1.15:
        return best
    return [name], f1


def text_at(pil, x, y, lines, f, col=(240, 244, 250), stroke=0):
    d = ImageDraw.Draw(pil)
    lh = f.size * 0.92
    for i, l in enumerate(lines):
        d.text((P(x), P(y) + i * lh), l, font=f, fill=col, stroke_width=stroke, stroke_fill=(10, 14, 22))


def head_start(img, x_guess, y0=38, y1=70):
    """Trova dove inizia la scritta del nome della nave, dopo la sagoma bianca."""
    band = cv2.cvtColor(img[P(y0):P(y1)], cv2.COLOR_BGR2GRAY)
    x = P(x_guess) - P(40)
    bright = lambda c: band[:, c].max() > 170
    # salta la sagoma (se c'è), poi il buio, e prendi la prima colonna chiara
    while x < P(x_guess) + P(30) and bright(x):
        x += 1
    while x < P(x_guess) + P(60) and not bright(x):
        x += 1
    return x / K


def translate(sp, path_in, path_out):
    img = cv2.imread(path_in)
    img = cv2.resize(img, (2048, 1144), interpolation=cv2.INTER_AREA)
    bp = SP_BP.get(sp, 'std')
    lay = LAYOUT[bp]
    parts = BPS[bp]
    jobs = []
    # nomi delle navi
    hx = HEAD_X_RHO if bp == 'rho' else HEAD_X
    for s, pos in lay.items():
        x = head_start(img, hx[s])
        img = erase(img, (x - 4, 36, x + HEAD_W[s], 72))
        jobs.append(('head', s, x))
    # etichette delle parti nelle caselle
    for s, pos in lay.items():
        for i, (cx, cy) in enumerate(pos):
            pt = parts[s][i] if i < len(parts[s]) else ''
            if not pt:
                continue
            box = (cx - 60, cy - 58, cx + 46, cy - 19)
            img = erase(img, box, thr=140)
            jobs.append(('part', PART.get(pt, pt), box))
    # tracciati delle tecnologie (scritte verticali)
    for y0, y1, name in [(468, 612, 'MILITARI'), (642, 786, 'RETICOLO'), (817, 960, 'NANO')]:
        img = erase(img, (641, y0, 664, y1), thr=120, dil=2)
        jobs.append(('vert', name, (641, y0, 664, y1)))
    # orbitale e monolito
    if 'orb' not in lay:
        img = erase(img, (146, 393, 242, 430))
        jobs.append(('small', 'ORBITALE', (146, 393, 242, 430)))
        img = erase(img, (356, 393, 470, 430))
        jobs.append(('small', 'MONOLITO', (356, 393, 470, 430)))
    else:
        img = erase(img, (176, 393, 290, 430))
        jobs.append(('small', 'MONOLITO', (176, 393, 290, 430)))
    # nome della civiltà (il distintivo del commercio comincia sempre a 437 punti su 2048) e "TRADE"
    img = erase(img, (106, 486, 422, 546), thr=120, sat_max=256)
    jobs.append(('name', FACTION.get(sp, sp), (104, 486, 424, 546)))
    img = erase(img, (523, 497, 594, 530))
    jobs.append(('trade', 'SCAMBIO', (521, 497, 596, 530)))
    # sigle delle azioni nei cerchi in basso
    for x, t in [(75, 'ESP'), (177, 'RIC'), (281, 'POT'), (384, 'COS'), (488, 'MUO')]:
        img = erase(img, (x - 34, 962, x + 34, 1010), thr=160)
        jobs.append(('act', t, x))
    pil = Image.fromarray(cv2.cvtColor(img, cv2.COLOR_BGR2RGB))
    d = ImageDraw.Draw(pil)
    for j in jobs:
        if j[0] == 'head':
            s, x = j[1], j[2]
            f = fit(d, SHIP[s], F_HEAD, P(HEAD_W[s] - 4), P(30), P(30))
            d.text((P(x), P(54)), SHIP[s], font=f, fill=(245, 245, 250), anchor='lm')
        elif j[0] == 'part':
            x0, y0, x1, y1 = j[2]
            ls, f = lines_for(j[1], d, F_COND, P(x1 - x0 - 6), P(y1 - y0 - 2), P(19))
            lh = f.size * 0.92
            y = P(y0) + (P(y1 - y0) - lh * len(ls)) / 2 - f.size * 0.05
            for l in ls:
                d.text((P(x0 + 4), y), l, font=f, fill=(235, 240, 248))
                y += lh
        elif j[0] == 'vert':
            x0, y0, x1, y1 = j[2]
            f = fit(d, j[1], F_COND, P(y1 - y0 - 10), P(x1 - x0), P(17))
            w = int(d.textlength(j[1], font=f)) + 4
            t = Image.new('RGBA', (w, f.size + 4), (0, 0, 0, 0))
            ImageDraw.Draw(t).text((2, 0), j[1], font=f, fill=(225, 228, 236, 255))
            t = t.rotate(90, expand=True)
            pil.paste(t, (P((x0 + x1) / 2) - t.width // 2, P((y0 + y1) / 2) - t.height // 2), t)
        elif j[0] in ('small', 'trade'):
            x0, y0, x1, y1 = j[2]
            f = fit(d, j[1], F_COND if j[0] == 'small' else F_HEAD, P(x1 - x0 + (20 if j[0] == 'trade' else 10)), P(y1 - y0 - 4), P(30))
            d.text((P(x0), P((y0 + y1) / 2)), j[1], font=f, fill=(240, 240, 245), anchor='lm')
        elif j[0] == 'act':
            f = fit(d, j[1], F_HEAD, P(62), P(40), P(40))
            d.text((P(j[2]), P(986)), j[1], font=f, fill=(245, 245, 250), anchor='mm', stroke_width=1, stroke_fill=(245, 245, 250))
        elif j[0] == 'name':
            x0, y0, x1, y1 = j[2]
            f = fit(d, j[1].upper(), F_HEAD, P(x1 - x0 - 6), P(40), P(40))
            d.text((P(x0 + 4), P((y0 + y1) / 2)), j[1].upper(), font=f, fill=(245, 245, 250), anchor='lm')
    pil.save(path_out, quality=88)


if __name__ == '__main__':
    for f in sorted(glob.glob((sys.argv[1] if len(sys.argv) > 1 else '/tmp/plance_orig') + '/*.png')):
        sp = os.path.splitext(os.path.basename(f))[0]
        translate(sp, f, R + '/assets/plance/%s.jpg' % sp)
        print('tradotta', sp)
