#!/usr/bin/env python3
"""Estrae dal modulo di Tabletop Simulator di Eclipse (file .ttsmod, che è uno zip già scompattato)
le immagini e i modelli usati dalla versione digitale.

Uso: python3 tools/estrai_materiale.py <cartella Mods> <cartella del progetto>

Produce:
  assets/settori/<numero>.jpg        tessere settore (anche il retro di ogni anello: retro_1/2/3)
  assets/tecnologie/<id>.jpg         tessere tecnologia (lato del vassoio)
  assets/parti/<id>.jpg              tessere parte di nave
  assets/scoperte/<chiave>.jpg       tessere scoperta (fronte) e retro.jpg (2 PV)
  assets/progetti/<id>.jpg           progetti di Antichi, Guardiani e SDCG (base e avanzati)
  assets/reputazione/<valore>.jpg    tessere reputazione
  assets/modelli/<nome>.obj          modelli 3D delle navi, del disco influenza e della Luna nera (SDCG)
"""
import json, os, re, sys, glob, shutil
from PIL import Image

MODS, OUT = sys.argv[1], sys.argv[2]
d = json.load(open(glob.glob(MODS + '/Workshop/*.json')[0]))
files = {}
for sub in ['Images', 'Models']:
    for f in glob.glob(MODS + '/' + sub + '/*'):
        files[os.path.splitext(os.path.basename(f))[0]] = f


def loc(url):
    if not url:
        return None
    k = re.sub(r'[^A-Za-z0-9]', '', url)
    return files.get(k)


def tutti():
    out = []
    def w(o, path):
        out.append((path, o))
        for c in o.get('ContainedObjects', []):
            w(c, path + [o.get('Nickname') or o['Name']])
    for o in d['ObjectStates']:
        w(o, [])
    return out


def salva(img, path, size=None, q=86):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    img = img.convert('RGB')
    if size:
        img.thumbnail((size, size), Image.LANCZOS)
    img.save(path, quality=q)


def slug(s):
    s = s.lower().replace(' - ', '_').replace(' ', '_').replace('-', '_')
    return re.sub(r'[^a-z0-9_]', '', s)


SPECIE = {'Terran Directorate': 'terran_directorate', 'Terran Federation': 'terran_federation', 'Terran Union': 'terran_union',
          'Terran Republic': 'terran_republic', 'Terran Conglomerate': 'terran_conglomerate', 'Terran Alliance': 'terran_alliance',
          'Eridani Empire': 'eridani', 'Hydran Progress': 'hydran', 'Planta': 'planta', 'Descendants of Draco': 'draco',
          'Mechanema': 'mechanema', 'Orion Hegemony': 'orion'}
dischi = {}
for path, o in tutti():
    nick = (o.get('Nickname') or '').strip()
    desc = (o.get('Description') or '').strip()
    bag = path[-1] if path else ''
    ci = o.get('CustomImage', {})
    cm = o.get('CustomMesh', {})
    # settori
    if nick.startswith('Sector') or nick.startswith('Homeworld') or nick in ('Galactic Center', 'Guardian Sector'):
        num = desc.split()[-1] if desc else ''
        if num.isdigit() and int(num) < 390 and loc(ci.get('ImageURL')):
            salva(Image.open(loc(ci['ImageURL'])), f'{OUT}/assets/settori/{int(num)}.jpg', 512)
            if num in ('101', '201', '301') and loc(ci.get('ImageSecondaryURL')):
                salva(Image.open(loc(ci['ImageSecondaryURL'])), f'{OUT}/assets/settori/retro_{num[0]}.jpg', 512)
    elif bag == 'Technology Tiles' and cm:
        f = loc(cm.get('DiffuseURL'))
        if f:
            im = Image.open(f)
            w, h = im.size
            salva(im.crop((0, h // 2, w // 2, h)), f'{OUT}/assets/tecnologie/{slug(nick.split(" - ")[1])}.jpg', 256, 90)
    elif bag.endswith('Parts') and o['Name'] == 'Custom_Tile':
        salva(Image.open(loc(ci['ImageURL'])), f'{OUT}/assets/parti/{slug(nick)}.jpg', 192, 90)
    elif bag == 'Discovery Tiles' and cm:
        f = loc(cm.get('DiffuseURL'))
        im = Image.open(f)
        w, h = im.size
        key = os.path.basename(f)[-12:-4].lower()
        salva(im.crop((0, 0, w // 2, h // 2)), f'{OUT}/assets/scoperte/{key}.jpg', 192, 90)
        salva(im.crop((0, h // 2, w // 2, h)), f'{OUT}/assets/scoperte/retro.jpg', 192, 90)
    elif bag in ('Bag of Ancient Tiles', 'Bag of GCDS Tiles', 'Bag of Guardian Tiles', 'Ancients', 'Guardians', 'Advanced Ancient', 'Advanced Guardian') and cm:
        f = loc(cm.get('DiffuseURL'))
        im = Image.open(f)
        w, h = im.size
        key = slug(nick) + '_' + os.path.basename(f)[-12:-4].lower()
        salva(im.crop((0, 0, w // 2, h // 2)), f'{OUT}/assets/progetti/{key}.jpg', 256, 90)
    elif bag == 'Reputation Tiles' and cm:
        f = loc(cm.get('DiffuseURL'))
        im = Image.open(f)
        w, h = im.size
        dischi[os.path.basename(f)] = im
    elif nick == 'Player Board' and ci and desc in SPECIE:

# reputazione: il valore si legge dal nome noto della trama
VALORI = {'62DCEDBD': 3, '68EDF601': 2, 'EDD46A4E': 4, 'F7A74CD8': 1}
for nome, im in dischi.items():
    k = nome[-12:-4].upper()
    if k in VALORI:
        w, h = im.size
        salva(im.crop((w // 2, 0, w, h // 2)), f'{OUT}/assets/reputazione/{VALORI[k]}.jpg', 160, 90)

# modelli 3D
MODELLI = {'Interceptor': 'intercettore', 'Cruiser': 'incrociatore', 'Dreadnought': 'corazzata', 'Starbase': 'base_stellare',
           'Deathmoon': 'sdcg', 'Influence Disc': 'disco'}
os.makedirs(f'{OUT}/assets/modelli', exist_ok=True)
for path, o in tutti():
    nick = (o.get('Nickname') or '').strip()
    if nick in MODELLI and o.get('CustomMesh') and not path:
        f = loc(o['CustomMesh']['MeshURL'])
        if f:
            shutil.copy(f, f'{OUT}/assets/modelli/{MODELLI[nick]}.obj')
print('fatto')
