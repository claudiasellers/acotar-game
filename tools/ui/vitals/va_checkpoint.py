"""Checkpoint renders (plan §15 H): a contact sheet of every icon, and mock HUD frames
over real game captures. Review images only; nothing here ships in the game.

Backplates are game captures named spring_day.png, spring_dusk.png and
human_winter.png in $VITALS_BACKPLATES (default: the project share).
"""
import math
import os

import numpy as np
from PIL import Image, ImageChops, ImageDraw, ImageEnhance, ImageFilter, ImageFont

import va_pictos
from va_common import HORROR, HUMAN, SPRING, hex_rgb

H = HORROR
HERE = os.path.dirname(os.path.abspath(__file__))
FONT_DIR = os.path.normpath(os.path.join(HERE, "..", "..", "..", "ui", "title", "fonts"))
PLATES = os.environ.get("VITALS_BACKPLATES", "/mnt/project-files/ui/feyre-vitals/backplates")
ART = ""
PAL = {"spring": SPRING, "human": HUMAN}


def font(size, style="SemiBold"):
    return ImageFont.truetype(os.path.join(FONT_DIR, f"EBGaramond-{style}.ttf"), size)


def load(name, size=None):
    path = os.path.join(ART, name)
    img = Image.open(path + (".webp" if os.path.exists(path + ".webp") else ".png"))
    img = img.convert("RGBA") if img.mode != "L" else img
    if size:
        img = img.resize(size if isinstance(size, tuple) else (size, size), Image.LANCZOS)
    return img


def tint(img, col):
    r, g, b = hex_rgb(col)
    return ImageChops.multiply(img, Image.new("RGBA", img.size, (r, g, b, 255)))


def stack(*layers):
    out = Image.new("RGBA", layers[0].size, (0, 0, 0, 0))
    for layer in layers:
        if layer is not None:
            out = Image.alpha_composite(out, layer)
    return out


def fade(img, a):
    out = img.copy()
    out.putalpha(out.getchannel("A").point(lambda v: int(v * a)))
    return out


def sweep(img, frac, start=0.0):
    """Keep a clockwise sweep of `frac` of the image, from the top."""
    w, h = img.size
    yy, xx = np.mgrid[0:h, 0:w]
    ang = (np.degrees(np.arctan2(xx - w / 2 + 0.5, -(yy - h / 2 + 0.5))) - start) % 360
    out = img.copy()
    a = np.asarray(img.getchannel("A"), dtype=np.float32) * (ang <= frac * 360)
    out.putalpha(Image.fromarray(a.astype(np.uint8)))
    return out


def crop_x(img, x0, x1):
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img.crop((x0, 0, x1, img.height)), (x0, 0))
    return out


def crop_up(img, frac):
    y = int(img.height * (1 - frac))
    out = Image.new("RGBA", img.size, (0, 0, 0, 0))
    out.paste(img.crop((0, y, img.width, img.height)), (0, y))
    return out


BUFF = {tag: (bid, col) for bid, tag, _, col in va_pictos.BUFFS}
DEBUFF = {tag: (bid, col) for bid, tag, _, col in va_pictos.DEBUFFS}


def medallion(tag, skin="spring", timer=None, creep=None):
    p = PAL[skin]
    if tag in BUFF:
        bid, col = BUFF[tag]
        frame = "medallion/base_giddy_frame_spring" if tag == "giddy" and skin == "spring" else f"medallion/base_buff_frame_{skin}"
        img = stack(tint(load("medallion/base_buff_fill"), p[col]), load(f"medallion/picto_{bid}_{tag}_{skin}"), load(frame))
        ring_col = p["gold"]
    else:
        bid, col = DEBUFF[tag]
        if tag == "chilled" and skin == "human":
            col, pic = "#3E5878", "medallion/picto_b17_chilled_human"
        else:
            pic = f"medallion/picto_{bid}_{tag}"
        img = stack(tint(load("medallion/base_debuff_fill"), col), load(pic), load(f"medallion/base_debuff_frame_{skin}"))
        ring_col = H["bone"]
    if timer is not None:
        ring = tint(load("medallion/timer_ring"), ring_col)
        img = stack(img, fade(ring, 0.28), sweep(ring, timer))
    if creep is not None:
        ring = tint(load("medallion/creep_ring"), "#1A2410")
        img = stack(img, fade(tint(load("medallion/creep_ring"), H["bone"]), 0.25), crop_up(ring, creep))
    return img


def wheel(skin="spring", frac=0.6, petals=0, state="spend"):
    p = PAL[skin]
    col = {"spend": p["rose"], "low": p["coral"], "winded": "#C9C6CC"}[state]
    fill = tint(load("wheel/wheel_fill"), col)
    layers = [load("wheel/wheel_back"), sweep(fill, frac), load("wheel/wheel_gloss")]
    if state == "winded":
        layers.append(load("wheel/wheel_winded_cracks"))
    layers.append(load(f"wheel/wheel_frame_{skin}"))
    pet = stack(tint(load("wheel/petal_fill"), p["rose"]), load(f"wheel/petal_frame_{skin}"))
    for k in range(petals):
        layers.append(pet.rotate(-72 * k, Image.BICUBIC))
    return stack(*layers)


BX0, BX1 = 70, 658


def ribbon(skin="spring", frac=0.62, lag=None, notch=None, frame=None, venom=False, sheen=None, fill_col=None):
    p = PAL[skin]
    fill = load("ribbon/ribbon_fill")
    x = lambda t: int(BX0 + (BX1 - BX0) * t)
    layers = [load("ribbon/ribbon_back")]
    if lag:
        layers.append(crop_x(tint(fill, p["pearl"]), BX0, x(lag)))
    layers.append(crop_x(tint(fill, fill_col or p["rose"]), BX0, x(frac)))
    if venom:
        layers.append(crop_x(load("ribbon/ribbon_venom_veins"), BX0, x(frac)))
    if sheen is not None:
        sh = Image.new("RGBA", fill.size, (0, 0, 0, 0))
        sh.paste(tint(load("ribbon/ribbon_heal_sheen"), p["mint"]), (x(sheen) - 80, 0))
        sh.putalpha(ImageChops.multiply(sh.getchannel("A"), crop_x(fill, BX0, x(frac)).getchannel("A")))
        layers.append(sh)
    layers.append(crop_x(load("ribbon/ribbon_gloss"), BX0, x(frac)))
    layers.append(load(frame or f"ribbon/ribbon_frame_{skin}"))
    out = stack(*layers)
    if notch:
        out.alpha_composite(load("ribbon/regen_notch"), (x(notch) - 24, 0))
    return out


def tag(item, skin="spring", gem="#CDB4F0", timer=None):
    cid = {n: c for c, n, _ in va_pictos.SILS}[item]
    sil = load(f"imbue/item_{cid}_{item}_{skin}").resize((132, 132), Image.LANCZOS)
    img = stack(load(f"imbue/tag_base_{skin}"), tint(load("imbue/tag_gem"), gem))
    img.alpha_composite(sil, (62, 84))
    img = stack(img, tint(load("imbue/tag_gem"), gem))
    if timer is not None:
        ring = tint(load("medallion/timer_ring"), PAL[skin]["gold"])
        img = stack(img, fade(ring, 0.25), sweep(ring, timer))
    return img


def fit(img, size):
    return img.resize(size if isinstance(size, tuple) else (size, int(size * img.height / img.width)), Image.LANCZOS)


# ---------------------------------------------------------------- screen-edge shader, imitated

def reveal(name, strength, soft=36, size=(1920, 1080)):
    m = np.asarray(load(name).convert("L").resize(size, Image.LANCZOS), dtype=np.float32)
    return np.clip((strength * 255 - m) / soft, 0, 1)


def lay(img, alpha, col, opacity=1.0):
    a = (alpha * opacity)[..., None]
    arr = np.asarray(img.convert("RGB"), dtype=np.float32)
    arr = arr * (1 - a) + np.array(hex_rgb(col), dtype=np.float32) * a
    return Image.fromarray(arr.astype(np.uint8))


def vignette(size, inner=0.45, power=1.6):
    w, h = size
    yy, xx = np.mgrid[0:h, 0:w]
    d = np.sqrt(((xx - w / 2) / (w / 2)) ** 2 + ((yy - h / 2) / (h / 2)) ** 2) / math.sqrt(2)
    return np.clip((d - inner) / (1 - inner), 0, 1) ** power


def plate(name):
    return Image.open(os.path.join(PLATES, name)).convert("RGB").resize((1920, 1080), Image.LANCZOS)


def put(dst, img, xy, size=None):
    if size:
        img = fit(img, size)
    dst.paste(img, (int(xy[0]), int(xy[1])), img)


def hud_row(dst, items, x, y, gap=8):
    for it in items:
        if it == "dot":
            d = ImageDraw.Draw(dst)
            d.ellipse((x + 2, y + 30, x + 10, y + 38), fill=SPRING["gold"], outline=SPRING["gold_dk"])
            x += 12 + gap
            continue
        put(dst, it, (x, y))
        x += it.width + gap - 6
    return x


def inset(dst, box, xy, label, skin="spring", zoom=2):
    crop = dst.crop(box).resize(((box[2] - box[0]) * zoom, (box[3] - box[1]) * zoom), Image.LANCZOS)
    p = PAL[skin]
    d = ImageDraw.Draw(dst)
    x, y = xy
    d.rounded_rectangle((x - 6, y - 6, x + crop.width + 6, y + crop.height + 40), 14, fill=p["paper"], outline=p["gold"], width=3)
    dst.paste(crop, (x, y))
    d.text((x + 8, y + crop.height + 4), label, font=font(24, "MediumItalic"), fill=p["ink"])


def mock_spring_day():
    bg = plate("spring_day.png")
    hud = Image.new("RGBA", bg.size, (0, 0, 0, 0))
    put(hud, ribbon("spring", 0.58, lag=0.71, notch=0.8), (48, 48), (360, 56))
    row = [fit(medallion("steady", timer=0.7), 70), fit(medallion("well_rested", timer=0.92), 70), "dot", fit(tag("cloak", gem=SPRING["periwinkle"], timer=0.85), 62)]
    x = hud_row(hud, row, 52, 110)
    for i, n in enumerate(("full", "full", "empty")):
        put(hud, load(f"menu/effect_pip_{n}" + ""), (x + 10 + i * 20, 136), 16) if n == "empty" else put(
            hud, tint(load("menu/effect_pip_full"), SPRING["lilac"]), (x + 10 + i * 20, 136), 16)
    put(hud, wheel("spring", 0.6, petals=2), (1030, 520), 144)
    out = Image.alpha_composite(bg.convert("RGBA"), hud)
    inset(out, (36, 36, 440, 196), (40, 700), "2× detail: hurt, the pearl lag, the regen leaf, steady + well rested, hushed cloak", "spring")
    inset(out, (1030, 520, 1174, 664), (1560, 700), "2×: stamina 60%, two petals", "spring")
    return out.convert("RGB")


def mock_spring_night():
    bg = plate("spring_dusk.png")
    arr = np.asarray(bg, dtype=np.float32) / 255
    arr = arr ** 1.25 * np.array([0.30, 0.36, 0.60])  # night grade of a day capture
    grey = arr.mean(axis=2, keepdims=True)
    arr = grey + (arr - grey) * 0.4  # dread 0.7 drains the colour
    noise = np.asarray(load("edge/dread_noise").convert("L").resize((1024, 1024)), dtype=np.float32) / 255
    noise = np.tile(noise, (2, 2))[:1080, :1920]
    dark = vignette((1920, 1080), 0.22, 1.25) * (0.5 + 0.7 * noise)
    arr *= (1 - np.clip(dark, 0, 1) * 0.94)[..., None]
    img = Image.fromarray((np.clip(arr, 0, 1) * 255).astype(np.uint8))
    veins = reveal("edge/venom_veins", 0.4, 46)
    img = lay(img, np.clip(veins * 1.0, 0, 1), "#07060A", 0.96)
    halo = np.asarray(Image.fromarray((veins * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(5)), dtype=np.float32) / 255
    img = lay(img, np.clip(halo - veins, 0, 1), H["bile"], 0.35)
    img = img.convert("RGBA")
    for name, dy in (("edge/eyelid_top", -330), ("edge/eyelid_bottom", 870)):  # a drowsy half-blink
        lid = fade(load(name), 0.8)
        img.alpha_composite(lid, (0, max(dy, 0)), (0, max(-dy, 0)))
    hud = Image.new("RGBA", img.size, (0, 0, 0, 0))
    put(hud, ribbon("spring", 0.44, lag=None, venom=True, fill_col="#D9558A"), (48, 48), (360, 56))
    hud_row(hud, [fit(medallion("venom", creep=0.6), 70), fit(medallion("drowsy", timer=0.55), 70)], 52, 110)
    put(hud, wheel("spring", 0.3, petals=2, state="low"), (1050, 500), 144)
    out = Image.alpha_composite(img, hud)
    inset(out, (36, 36, 440, 196), (40, 700), "2× detail: venom in the ribbon; venom (creep ring) and drowsy", "spring")
    return out.convert("RGB")


def mock_human_winter():
    bg = plate("human_winter.png")
    arr = np.asarray(bg, dtype=np.float32)
    frost = reveal("edge/frost_human", 0.5, 60)
    img = lay(bg, frost, "#EAF6FF", 0.92)
    soft = np.asarray(Image.fromarray((frost * 255).astype(np.uint8)).filter(ImageFilter.GaussianBlur(26)), dtype=np.float32) / 255
    img = lay(img, np.clip(soft * 1.4, 0, 1), "#BFD6EA", 0.5)
    img = lay(img, reveal("edge/frost_human", 0.5, 60), "#F4FAFF", 0.9).convert("RGBA")
    hud = Image.new("RGBA", img.size, (0, 0, 0, 0))
    put(hud, ribbon("human", 0.36, lag=0.41), (48, 48), (360, 56))
    hud_row(hud, [fit(medallion("chilled", "human"), 70), fit(medallion("starving", "human"), 70)], 52, 110)
    put(hud, wheel("human", 0.45, petals=0), (880, 420), 144)
    out = Image.alpha_composite(img, hud)
    inset(out, (36, 36, 440, 196), (40, 560), "2× detail: human-realm skin; chilled and starving", "human")
    return out.convert("RGB")


# ---------------------------------------------------------------- contact sheet

def paper(w, h):
    rng = np.random.default_rng(1)
    base = np.array(hex_rgb(SPRING["paper"]), dtype=np.float32)
    n = rng.normal(0, 3.0, (h // 4, w // 4, 1)).astype(np.float32)
    n = np.asarray(Image.fromarray(np.clip(n[..., 0] * 8 + 128, 0, 255).astype(np.uint8)).resize((w, h), Image.BICUBIC), dtype=np.float32)[..., None] - 128
    return Image.fromarray(np.clip(base + n * 0.35, 0, 255).astype(np.uint8)).convert("RGBA")


def contact_sheet():
    Wd = 2400
    sh = paper(Wd, 5000)
    d = ImageDraw.Draw(sh)
    ink, soft = SPRING["ink"], SPRING["ink_soft"]
    y = 40

    def heading(t, sub=""):
        nonlocal y
        d.text((60, y), t, font=font(54), fill=ink)
        if sub:
            d.text((60 + d.textlength(t, font=font(54)) + 24, y + 22), sub, font=font(28, "MediumItalic"), fill=soft)
        d.line((60, y + 72, Wd - 60, y + 72), fill=SPRING["gold"], width=3)
        y += 92

    def label(x, yy, t, w, size=24):
        fnt = font(size, "Medium")
        d.text((x + (w - d.textlength(t, font=fnt)) / 2, yy), t, font=fnt, fill=ink)

    d.text((60, y), "Feyre's vitals: HUD and status art", font=font(76), fill=ink)
    d.text((62, y + 92), "Checkpoint sheet. Every texture is built by tools/ui/vitals; fills are tinted in-game, shown here in their default colours.",
           font=font(28, "MediumItalic"), fill=soft)
    y += 160

    heading("Status medallions", "B1–B19 · Spring skin, with timer rings")
    tags = [t for _, t, _, _ in va_pictos.BUFFS[:13]] + [t for _, t, _, _ in va_pictos.DEBUFFS] + ["stuffed"]
    cell = 228
    for i, t in enumerate(tags):
        cx, cy = 60 + (i % 10) * cell, y + (i // 10) * 262
        m = medallion(t, "spring", timer=0.72 if t != "venom" else None, creep=0.6 if t == "venom" else None)
        put(sh, m, (cx + 8, cy), 212)
        label(cx, cy + 214, t.replace("_", " "), cell)
    y += 2 * 262 + 6
    # True size, over light and dark.
    for k, (bgc, skin) in enumerate((("#9FD6A8", "spring"), ("#2A2438", "spring"), ("#DADDE2", "human"))):
        x0 = 60 + k * 770
        d.rounded_rectangle((x0, y, x0 + 740, y + 150), 18, fill=bgc)
        names = tags if skin == "spring" else ["steady", "swift", "warm", "well_fed", "quiet", "heal", "keen", "chilled", "starving", "venom"]
        for i, t in enumerate(names[:20]):
            m = medallion(t, skin, timer=0.6 if t != "venom" else None, creep=0.6 if t == "venom" else None)
            put(sh, m, (x0 + 12 + (i % 10) * 72, y + 6 + (i // 10) * 70), 69)
        label(x0, y + 154, ("true size (56 px) on day" if k == 0 else "true size on night" if k == 1 else "human-realm skin, true size"), 740, 24)
    y += 210

    heading("Meters", "A1 stamina rose wheel · A2 health ribbon · A3 grab prompt")
    wheels = [("spring", 0.6, 2, "spend", "spending, +2 petals"), ("spring", 0.2, 0, "low", "low (pulses)"), ("spring", 0.5, 5, "winded", "winded, all 5 petals"),
              ("human", 0.7, 1, "spend", "human realm")]
    for i, (sk, fr, pt, st, lb) in enumerate(wheels):
        put(sh, wheel(sk, fr, pt, st), (60 + i * 300, y), 288)
        label(60 + i * 300, y + 290, lb, 288)
    bloom = load("wheel/petal_bloom_sheet")
    for i in range(6):
        fr = bloom.crop((i * 384 + 72, 0, i * 384 + 312, 150))
        put(sh, fr, (60 + i * 200, y + 330))
    label(60, y + 484, "a petal earned: 6-frame bloom", 1200)
    rib = [(ribbon("spring", 0.58, lag=0.71, notch=0.8), "hurt: pearl lag fill, gold-leaf regen cap"), (ribbon("spring", 0.5, sheen=0.3), "healing: mint sheen"),
           (ribbon("spring", 0.2, frame="ribbon/ribbon_frame_low", fill_col="#A3202E"), "low health: thorns to ink, gold tarnishes"),
           (ribbon("spring", 0.5, venom=True, fill_col="#D9558A"), "venom: veins cross the fill"), (ribbon("human", 0.4, lag=0.48), "human realm: charcoal, twine, madder")]
    for i, (r, lb) in enumerate(rib):
        put(sh, r, (1290, y - 6 + i * 104), 720)
        d.text((2020, y + 30 + i * 104), lb, font=font(24, "Medium"), fill=ink)
    y += 530
    put(sh, load("grab/grab_ring_sheet"), (60, y), 1440)
    label(60, y + 244, "grab prompt: the thorn ring loosens with each press (tinted per attacker)", 1440)
    d.rounded_rectangle((1560, y + 10, 2340, y + 230), 18, fill="#2A2438")
    put(sh, tint(load("grab/grab_ring_sheet"), "#C96A6A").crop((0, 0, 720, 240)), (1580, y + 30), 620)
    y += 300

    heading("Imbue tags", "C0–C8 · gem takes the brew's colour")
    gems = [SPRING["periwinkle"], SPRING["mint"], SPRING["butter"], SPRING["rose"], SPRING["lilac"], SPRING["coral"]]
    for i, (_, n, _) in enumerate(va_pictos.SILS):
        put(sh, tag(n, "spring", gems[i], timer=0.8), (60 + i * 190, y), 190)
        label(60 + i * 190, y + 186, n, 190)
        put(sh, tag(n, "human", HUMAN["butter"]), (1240 + i * 100, y + 20), 100)
        put(sh, tag(n, "spring", gems[i]), (1240 + i * 66, y + 134), 60)
    label(1240, y + 196, "human skin · true size (48 px)", 600)
    put(sh, load("imbue/flourish_sheet").crop((512, 0, 2048, 256)), (1860, y - 6), 480)
    put(sh, load("imbue/fizz_sheet").crop((0, 80, 1536, 256)), (1860, y + 96), 480)
    label(1860, y + 196, "imbue flourish · expiry fizz", 480)
    y += 250

    heading("Perk badges", "F1 · 22 modifiers, for wardrobe cards and Her kit")
    for i, (n, _, _) in enumerate(va_pictos.BADGES):
        cx, cy = 60 + (i % 11) * 207, y + (i // 11) * 176
        put(sh, load(f"menu/perk_{n}_spring"), (cx + 39, cy))
        label(cx, cy + 130, n.replace("_", " "), 207, 22)
    y += 2 * 176 + 4
    d.rounded_rectangle((60, y, 1150, y + 56), 14, fill="#F3E9D8")
    d.rounded_rectangle((1190, y, 2280, y + 56), 14, fill=HUMAN["paper"])
    for i, (n, _, _) in enumerate(va_pictos.BADGES):
        put(sh, load(f"menu/perk_{n}_spring"), (76 + i * 48, y + 12), 32)
        put(sh, load(f"menu/perk_{n}_human"), (1206 + i * 48, y + 12), 32)
    label(60, y + 60, "true size (32 px)", 1090, 22)
    label(1190, y + 60, "human-realm skin, true size", 1090, 22)
    y += 120

    heading("Menus and world", "F2–F5 · E1–E3")
    x = 60
    for n, s, lb in (("menu/chevron_up", 80, "up"), ("menu/chevron_down", 80, "down"), ("menu/set_rosette_empty", 80, "set pip"), ("menu/set_rosette_filled", 80, "set pip, on"),
                     ("menu/effect_pip_empty", 64, "slot"), ("menu/effect_pip_full", 64, "slot, full"), ("menu/bait_mark", 128, "bait mark"), ("world/bundle_glint", 190, "dropped bundle"),
                     ("world/bundle_map_pictogram", 128, "bundle, map"), ("world/aware_curious", 128, "curious"), ("world/aware_alerted", 128, "alerted")):
        im = load(n)
        if n.endswith("pip_full"):
            im = tint(im, SPRING["lilac"])
        put(sh, im, (x + (190 - s) // 2, y + (190 - s) // 2), s)
        label(x, y + 196, lb, 190, 22)
        x += 196
    put(sh, load("menu/her_kit_header"), (60, y + 240), 1024)
    label(60, y + 372, "“Her kit” header ornament", 1024, 22)
    y += 420

    heading("Screen-edge effects", "D1–D12 · one shader; these are its maps, shown as they'd read at mid strength")
    day = plate("spring_day.png")
    night = Image.fromarray((np.asarray(plate("spring_dusk.png"), dtype=np.float32) * np.array([0.3, 0.34, 0.55])).astype(np.uint8))
    snow = plate("human_winter.png")
    iris = np.asarray(load("edge/iris_rose").convert("L").resize((1920, 1920)).crop((0, 420, 1920, 1500)), dtype=np.float32)
    dawn = np.asarray(load("edge/iris_dawn").convert("L").resize((1920, 1920)).crop((0, 420, 1920, 1500)), dtype=np.float32)
    tiles = [
        (lay(lay(day, vignette((1920, 1080), 0.3, 1.4), "#3A0A16", 0.75), reveal("edge/low_health_thorns", 0.7, 50), "#1A070C", 0.96), "low health: thorns"),
        (lay(night, reveal("edge/venom_veins", 0.72, 46), "#07060A", 0.96), "venom: veins"),
        (lay(day, reveal("edge/frost_spring", 0.75, 60), "#F1F0FF", 0.92), "cold, Spring: pearl rime"),
        (lay(snow, reveal("edge/frost_human", 0.75, 60), "#F4FAFF", 0.92), "cold, human realm"),
        (lay(day, np.clip((0.62 * 255 - iris) / 30, 0, 1), "#1E0A14", 1.0), "knockdown: rose iris"),
        (lay(day, np.clip((dawn - 0.45 * 255) / 60, 0, 1), "#FFF6DC", 1.0), "waking: dawn iris"),
    ]
    for i, (im, lb) in enumerate(tiles):
        cx, cy = 60 + (i % 3) * 770, y + (i // 3) * 470
        sh.paste(im.resize((740, 416), Image.LANCZOS), (cx, cy))
        label(cx, cy + 420, lb, 740)
    y += 2 * 470 + 10
    d.rounded_rectangle((60, y, 2340, y + 190), 18, fill="#2A2438")
    put(sh, load("edge/hit_bruise"), (90, y + 40))
    put(sh, load("fx/sparkle_sheet"), (640, y + 10), 640)
    put(sh, load("fx/seeing_stars_sheet"), (640, y + 100), 640)
    put(sh, load("fx/petals"), (1320, y + 16), 540)
    put(sh, load("fx/moth_dust"), (1330, y + 112), 384)
    put(sh, load("medallion/pop_in_sheet").crop((256, 0, 1280, 256)), (1900, y + 40), 420)
    label(60, y + 196, "hit-direction bruise · sparkle, seeing-stars, petals, moth dust, medallion pop-in", 2280)
    y += 250
    return sh.crop((0, 0, Wd, y)).convert("RGB")


def build(art_dir, out_dir):
    global ART
    ART = art_dir
    os.makedirs(out_dir, exist_ok=True)
    contact_sheet().save(os.path.join(out_dir, "1_contact_sheet.jpg"), quality=93)
    mock_spring_day().save(os.path.join(out_dir, "2_mock_spring_day.jpg"), quality=92)
    both = Image.new("RGB", (1920, 2176), "#1A1620")
    both.paste(mock_spring_night(), (0, 0))
    both.paste(mock_human_winter(), (0, 1096))
    both.save(os.path.join(out_dir, "3_mock_night_dread_venom_and_human_winter.jpg"), quality=92)
    print("checkpoint renders in", out_dir)
