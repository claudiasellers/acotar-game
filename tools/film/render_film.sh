#!/bin/bash
# Offline film render (lane L33): plays a film through Godot's Movie Maker
# (every frame rendered at full quality on a fixed clock, however long each
# frame takes), then finishes it in ffmpeg: halation on the highlights, a
# little film grain and a soft vignette, H.264 with the film's score.
#
#   tools/film/render_film.sh opening <out.mp4> [fps=24] [until=<s>] [from=<s>]
#
# Works in the cloud (Vulkan through Mesa's lavapipe: apt install
# mesa-vulkan-drivers; about 1-3 s a frame at 1080p) and on the Mac (Metal).
# Needs the generated world (tools/mq/levels.sh ensure) for the cottage half.
# Frames go to a scratch folder next to the output and are removed after.
set -euo pipefail

film="${1:?film id (opening)}"
out="${2:?output .mp4}"
shift 2
fps=24
until=""
from=0
for a in "$@"; do
	case "$a" in
	fps=*) fps="${a#fps=}" ;;
	until=*) until="${a#until=}" ;;
	from=*) from="${a#from=}" ;;
	*) echo "unknown argument $a" >&2; exit 2 ;;
	esac
done

root="$(cd "$(dirname "$0")/../.." && pwd)"
godot="${GODOT:-$(command -v godot || echo /root/tools/godot)}"
case "$film" in
opening)
	scene="res://tools/film/opening_film_shot.tscn"
	score="$root/audio/music/opening_film.ogg"
	until="${until:-190}"
	;;
*) echo "no offline render set up for $film" >&2; exit 2 ;;
esac

work="$(dirname "$out")/.render_$(basename "$out" .mp4)"
rm -rf "$work"
mkdir -p "$work/frames"

run=("$godot" --path "$root" --audio-driver Dummy --rendering-method forward_plus
	--resolution 1920x1080 --write-movie "$work/frames/f.png" --fixed-fps "$fps")
if [ "$(uname -s)" != Darwin ]; then
	export VK_ICD_FILENAMES="${VK_ICD_FILENAMES:-/usr/share/vulkan/icd.d/lvp_icd.json}"
	run=(xvfb-run -a -s "-screen 0 1920x1080x24" "${run[@]}" --rendering-driver vulkan)
fi
HOME="$work/home" "${run[@]}" "$scene" -- "$work/capture" noclip "until=$until" >"$work/godot.log" 2>&1 || true
n=$(find "$work/frames" -name 'f*.png' | wc -l)
[ "$n" -gt 0 ] || { echo "no frames rendered; see $work/godot.log" >&2; exit 1; }

# Finishing: halation (the brightest light bleeds a warm glow), grain that
# moves every frame, a soft vignette, a touch of contrast.
grade="split[a][b];[b]curves=all='0/0 0.62/0 1/1',gblur=sigma=14,colorchannelmixer=rr=1:gg=0.82:bb=0.62[h];"
grade+="[a][h]blend=all_mode=screen:all_opacity=0.32,eq=contrast=1.02:brightness=0.01:saturation=1.05,"
grade+="vignette=angle=PI/8:mode=forward,noise=c0s=5:c0f=t+u,format=yuv420p"
start=$(printf '%08d' $((from * fps)))
audio=()
[ -f "$score" ] && audio=(-ss "$from" -i "$score" -map 0:v -map 1:a -c:a aac -b:a 192k -shortest)
ffmpeg -v error -y -framerate "$fps" -start_number "$start" -i "$work/frames/f%08d.png" "${audio[@]}" \
	-vf "$grade" -c:v libx264 -preset slow -crf 17 -pix_fmt yuv420p -movflags +faststart "$out"
rm -rf "$work"
echo "$out: $n frames at $fps fps"
