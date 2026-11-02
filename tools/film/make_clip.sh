#!/bin/bash
# Turns a FilmCapture folder (clip_<k>.jpg atlases, timing.txt) into an mp4
# (lane L33), with the score under it when given:
#   tools/film/make_clip.sh <capture_dir> <out.mp4> [score.ogg]
set -e
dir="$1"; out="$2"; score="$3"
frames=$(mktemp -d)
trap 'rm -rf "$frames"' EXIT
fps=$(python3 - "$dir" "$frames" <<'PY'
import glob, os, re, sys
from PIL import Image
d, outd = sys.argv[1], sys.argv[2]
m = re.search(r"clip (\d+) frames at ([\d.]+) fps, (\d+)x(\d+), (\d+) to an atlas", open(os.path.join(d, "timing.txt")).read())
n, fps, w, h, per = int(m[1]), float(m[2]), int(m[3]), int(m[4]), int(m[5])
cols = 8
for i in range(n):
    a = Image.open(os.path.join(d, "clip_%02d.jpg" % (i // per)))
    k = i % per
    a.crop(((k % cols) * w, (k // cols) * h, (k % cols + 1) * w, (k // cols + 1) * h)).save(os.path.join(outd, "f_%04d.jpg" % i), quality=92)
print(fps)
PY
)
if [ -n "$score" ] && [ -f "$score" ]; then
	ffmpeg -y -loglevel error -framerate "$fps" -i "$frames/f_%04d.jpg" -i "$score" \
		-c:v libx264 -pix_fmt yuv420p -r 24 -c:a aac -b:a 128k -shortest "$out"
else
	ffmpeg -y -loglevel error -framerate "$fps" -i "$frames/f_%04d.jpg" -c:v libx264 -pix_fmt yuv420p -r 24 "$out"
fi
ls -la "$out"
