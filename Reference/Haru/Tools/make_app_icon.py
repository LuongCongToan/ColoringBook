"""Ve icon app va ghi vao ca hai asset catalog.

  python -E -P Tools/make_app_icon.py     (can Pillow: pip install pillow)

Hinh la chu 하 - am tiet dau cua 하루, "mot ngay" - dung tu net hinh hoc chu khong
lay tu font nao, nen khong vuong giay phep font. Vong tron cua ㅎ to mau vang am:
no vua la mot net chu, vua la mat troi cua mot ngay.

Nhung quy tac cua Apple ma script nay giu:

  - Mot anh goc 1024x1024 cho moi nen tang; he thong tu sinh cac co con lai.
  - KHONG co kenh alpha. Anh co alpha bi tu choi luc tai len App Store.
  - Goc VUONG, ve tran le. He thong tu cat: squircle tren iOS, hinh tron tren
    watchOS. Tu bo goc la thanh hai lop bo chong len nhau.
  - Noi dung chinh nam gon trong vong tron giua anh, vi watchOS cat thanh hinh
    tron va iOS doi khi phong to icon. Script tu kiem dieu nay.
  - iOS 18+ nhan them ban toi va ban nhuom mau. Ban nhuom mau phai la anh xam:
    he thong lay do sang cua tung diem roi phu mau nguoi dung chon len.
"""
import json, os, sys

from PIL import Image, ImageDraw

sys.stdout.reconfigure(encoding='utf-8')

SIZE = 1024
SCALE = 4                     # ve o 4096 roi thu nho: net cong min ma khong can thu vien ve vector
BIG = SIZE * SCALE

MINT = (61, 219, 150)         # Theme.accent - cung mau nhan voi Tinnitus Relief
SUN = (247, 204, 107)         # Theme.hard - mau cua chuoi ngay trong app
STROKE = 62

# Hinh chu, toa do tren khung 1024, tam (512, 512).
ZOOM = 1.12


def at(x, y):
    """Phong hinh quanh tam anh va doi sang he toa do 4096."""
    return ((512 + (x - 512) * ZOOM) * SCALE, (512 + (y - 512) * ZOOM) * SCALE)


LINES = [
    ((355, 298), (445, 298)),     # ㅎ: net ngan tren cung
    ((285, 400), (515, 400)),     # ㅎ: net ngang
    ((655, 262), (655, 742)),     # ㅏ: net doc
    ((655, 502), (752, 502)),     # ㅏ: net ngang ngan
]
RING_CENTRE, RING_RADIUS = (400, 588), 104

# Ban kinh, tinh tu tam, ma moi net phai nam gon ben trong. Hinh tron cua watchOS
# co ban kinh 512; giu noi dung trong 72% cua no la con le rong rai.
SAFE_RADIUS = 512 * 0.72


def gradient(inner, outer):
    """Nen toa tu tam ra. Den phang trong nhu mot cai lo tren man hinh chinh toi."""
    small = 256
    image = Image.new('RGB', (small, small))
    pixels = image.load()
    centre = (small - 1) / 2
    # Tam sang lech len tren mot chut, nhu anh sang roi tu phia tren.
    for y in range(small):
        for x in range(small):
            distance = (((x - centre) ** 2 + (y - centre * 0.86) ** 2) ** 0.5) / (centre * 1.25)
            t = min(1.0, distance) ** 1.35
            pixels[x, y] = tuple(round(inner[i] + (outer[i] - inner[i]) * t) for i in range(3))
    return image.resize((BIG, BIG), Image.BICUBIC)


def draw_mark(image, stroke_colour, ring_colour):
    draw = ImageDraw.Draw(image)
    width = STROKE * ZOOM * SCALE
    half = width / 2
    for start, end in LINES:
        (x0, y0), (x1, y1) = at(*start), at(*end)
        # Moi net la mot hinh chu nhat bo tron het co. Ve bang line() roi dap
        # them hai hinh tron o dau thi lech nhau nua diem anh va de lai go.
        draw.rounded_rectangle([min(x0, x1) - half, min(y0, y1) - half,
                                max(x0, x1) + half, max(y0, y1) + half],
                               radius=half, fill=stroke_colour)
    cx, cy = at(*RING_CENTRE)
    radius = RING_RADIUS * ZOOM * SCALE
    draw.ellipse([cx - radius, cy - radius, cx + radius, cy + radius],
                 outline=ring_colour, width=round(width))


def furthest_reach():
    """Diem xa tam nhat cua hinh chu, tren khung 1024."""
    half = STROKE * ZOOM / 2
    reach = 0.0
    points = [p for line in LINES for p in line]
    for x, y in points:
        px, py = 512 + (x - 512) * ZOOM, 512 + (y - 512) * ZOOM
        reach = max(reach, ((px - 512) ** 2 + (py - 512) ** 2) ** 0.5 + half)
    rx, ry = 512 + (RING_CENTRE[0] - 512) * ZOOM, 512 + (RING_CENTRE[1] - 512) * ZOOM
    reach = max(reach, ((rx - 512) ** 2 + (ry - 512) ** 2) ** 0.5 + RING_RADIUS * ZOOM + half)
    return reach


def render(inner, outer, stroke_colour, ring_colour, grey=False):
    image = gradient(inner, outer)
    draw_mark(image, stroke_colour, ring_colour)
    image = image.resize((SIZE, SIZE), Image.LANCZOS)
    if grey:
        image = image.convert('L')
    # RGB, khong bao gio RGBA: kenh alpha bi tu choi luc tai len.
    return image.convert('RGB')


def write(path, image):
    os.makedirs(os.path.dirname(path), exist_ok=True)
    image.save(path, 'PNG', optimize=True)
    check = Image.open(path)
    assert check.size == (SIZE, SIZE), check.size
    assert check.mode == 'RGB', 'icon co kenh alpha: %s' % check.mode
    print('viet %-62s %dx%d %s  %d KB' % (path, check.size[0], check.size[1], check.mode,
                                         os.path.getsize(path) // 1024))


def main():
    reach = furthest_reach()
    assert reach <= SAFE_RADIUS, 'hinh chu tran ra ngoai vung an toan: %.0f > %.0f' % (reach, SAFE_RADIUS)
    print('vung an toan: hinh chu vuon toi %.0f px tu tam, gioi han %.0f px' % (reach, SAFE_RADIUS))

    # Nen den ngả xanh, net chu mau nhan: cung ho voi icon Tinnitus Relief.
    light = render((20, 70, 52), (5, 16, 12), MINT, SUN)
    dark = render((11, 38, 29), (2, 6, 5), MINT, SUN)
    # Anh xam: net sang nhat, vong mat troi diu hon mot bac de van tach khoi net chu.
    tinted = render((26, 26, 26), (0, 0, 0), (240, 240, 240), (168, 168, 168), grey=True)
    # Watch rieng, nen sang hon va khong toi dan ra ria: mat dong ho la nen den,
    # icon nen gan den thi mat vien tron. App #1 bi tu choi vi icon Watch nen den
    # (Guideline 4). Ria cu khoang #071611, gio khoang #164e3a.
    watch_icon = render((34, 110, 82), (22, 78, 58), MINT, SUN)

    ios = 'Haru/Assets.xcassets/AppIcon.appiconset'
    watch = 'Watch/Assets.xcassets/AppIcon.appiconset'
    write(ios + '/AppIcon-1024.png', light)
    write(ios + '/AppIcon-1024-dark.png', dark)
    write(ios + '/AppIcon-1024-tinted.png', tinted)
    write(watch + '/AppIcon-1024.png', watch_icon)

    info = {'author': 'xcode', 'version': 1}

    def appearance(value):
        return [{'appearance': 'luminosity', 'value': value}]

    catalogs = {
        ios: {'images': [
            {'filename': 'AppIcon-1024.png', 'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'},
            {'appearances': appearance('dark'), 'filename': 'AppIcon-1024-dark.png',
             'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'},
            {'appearances': appearance('tinted'), 'filename': 'AppIcon-1024-tinted.png',
             'idiom': 'universal', 'platform': 'ios', 'size': '1024x1024'},
        ], 'info': info},
        watch: {'images': [
            {'filename': 'AppIcon-1024.png', 'idiom': 'universal', 'platform': 'watchos', 'size': '1024x1024'},
        ], 'info': info},
    }
    for folder, contents in catalogs.items():
        with open(folder + '/Contents.json', 'w', encoding='utf-8', newline='\n') as fh:
            fh.write(json.dumps(contents, indent=2) + '\n')
    print('cap nhat Contents.json cua hai catalog')


main()
