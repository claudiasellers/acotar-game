#!/bin/bash
# Turns a FilmCapture clip folder into an mp4 (lane L33), with the score
# under it when given:  tools/film/make_clip.sh <capture_dir> <out.mp4> [score.ogg] [fps]
set -e
dir="$1"; out="$2"; score="$3"; fps="${4:-4}"
if [ -n "$score" ] && [ -f "$score" ]; then
	ffmpeg -y -loglevel error -framerate "$fps" -i "$dir/clip/f_%04d.jpg" -i "$score" \
		-c:v libx264 -pix_fmt yuv420p -r 24 -c:a aac -b:a 128k -shortest "$out"
else
	ffmpeg -y -loglevel error -framerate "$fps" -i "$dir/clip/f_%04d.jpg" \
		-c:v libx264 -pix_fmt yuv420p -r 24 "$out"
fi
ls -la "$out"
