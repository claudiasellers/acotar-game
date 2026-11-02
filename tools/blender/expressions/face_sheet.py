"""Tile render_faces.py frames into one labelled sheet (system python + Pillow).

    python3 tools/blender/expressions/face_sheet.py FRAMES_DIR OUT.png "Title" [cols]
"""

import glob
import os
import sys

from PIL import Image, ImageDraw, ImageFont

src, out, title = sys.argv[1], sys.argv[2], sys.argv[3]
cols = int(sys.argv[4]) if len(sys.argv) > 4 else 4
files = sorted(glob.glob(os.path.join(src, "*.png")))
ims = [Image.open(f).convert("RGB") for f in files]
w, h = ims[0].size
pad, lab, top = 8, 26, 40
rows = (len(ims) + cols - 1) // cols
sheet = Image.new("RGB", (cols * (w + pad) + pad, top + rows * (h + lab + pad) + pad), (250, 240, 246))
dr = ImageDraw.Draw(sheet)
try:
    font = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf", 17)
    big = ImageFont.truetype("/usr/share/fonts/truetype/dejavu/DejaVuSans-Bold.ttf", 22)
except OSError:
    font = big = ImageFont.load_default()
dr.text((pad, 8), title, fill=(90, 50, 80), font=big)
for i, (f, im) in enumerate(zip(files, ims)):
    r, c = divmod(i, cols)
    x, y = pad + c * (w + pad), top + r * (h + lab + pad)
    sheet.paste(im, (x, y))
    name = os.path.basename(f)[3:-4].replace("_", " ")
    dr.text((x + 4, y + h + 3), name + ("  (rest)" if i == 0 else ""), fill=(70, 40, 60), font=font)
sheet.save(out)
print("wrote", out, sheet.size)
