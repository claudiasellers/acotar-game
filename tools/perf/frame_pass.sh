#!/bin/bash
# Frame budget pass over the canonical shots (program brief T1).
#   tools/perf/frame_pass.sh [name ...]      (make perf; no names = every shot)
# Writes tools/perf/out/<UTC date>-<host>.csv (git-ignored), one row per shot,
# via tools/perf/frame_probe.tscn. Each shot is a fresh Godot process.
# Mac: runs the real game look on the GPU; frame_ms/gpu_ms are the budget numbers.
# Linux cloud: xvfb + Mesa lavapipe; frame times are meaningless there, but draw
# calls, primitives, objects and material counts are exact.
# Env: GODOT (binary; default: tools/mq engine lookup), PERF_TIMEOUT (s per shot, 900).
# Mac: the same quiet window as the shot listener (T087, tools/mq/shots_common.sh):
# a small unfocused window in the corner, the frame still rendered at 1920x1080
# through a temporary override.cfg, removed on exit.
set -u
cd "$(dirname "$0")/../.." || exit 1
. tools/mq/common.sh
. tools/mq/shots_common.sh
godot="${GODOT:-$(mq_engine)}" || { echo "perf: no Godot $MQ_GODOT_VERSION found" >&2; exit 125; }
list=tools/shots/canonical.txt
outdir=tools/perf/out
mkdir -p "$outdir"
csv="${PERF_CSV:-$PWD/$outdir/$(date -u +%Y-%m-%d)-$(hostname -s).csv}"
scratch=$(mktemp -d "${TMPDIR:-/tmp}/perf.XXXXXX")
export PERF_CSV="$csv" PERF_COMMIT="$(git rev-parse --short HEAD)"
export HOME="$scratch/home" XDG_DATA_HOME="$scratch/home" XDG_CONFIG_HOME="$scratch/home" XDG_CACHE_HOME="$scratch/home"
mkdir -p "$HOME"
wrap=()
win=(--resolution 1920x1080)
if [ "$(uname)" = "Darwin" ]; then
	if [ -f override.cfg ] && ! grep -q 'quiet render (T087)' override.cfg; then
		echo "perf: an override.cfg that isn't ours is here; move it first" >&2; exit 1
	fi
	trap 'rm -f override.cfg' EXIT
	trap 'exit 130' INT TERM
	shots_render_cfg . 1920x1080 tools/perf/frame_pass.sh
	read -r -a win <<<"$(shots_window_args 1920x1080 40,40)"
	export __CFBundleIdentifier="$(shots_bundle_id "$godot")"
else
	export LP_NUM_THREADS="${LP_NUM_THREADS:-$(nproc)}" WORLD_SHOT_REGION_CAP="${WORLD_SHOT_REGION_CAP:-900}"
	[ -z "${DISPLAY:-}" ] && wrap=(xvfb-run -a -s "-screen 0 1920x1080x24")
fi
want=" $* "
fails=0
while IFS='|' read -r name scene args; do
	name=$(echo "$name" | tr -d ' ')
	case "$name" in ''|\#*) continue ;; esac
	[ $# -gt 0 ] && case "$want" in *" $name "*) ;; *) continue ;; esac
	scene=$(echo "$scene" | tr -d ' ')
	out="$scratch/$name"; mkdir -p "$out"
	args=${args//\{out\}/$out}
	echo "perf: $name ($scene)"
	t0=$(date +%s)
	# shellcheck disable=SC2086
	PERF_NAME="$name" PERF_SCENE="$scene" ${wrap[@]+"${wrap[@]}"} "$godot" --audio-driver Dummy --path . \
		"${win[@]}" res://tools/perf/frame_probe.tscn -- $args </dev/null > "$scratch/$name.log" 2>&1
	rc=$?
	echo "perf: $name exit $rc in $(( $(date +%s) - t0 )) s"
	[ $rc -eq 0 ] || { fails=$((fails + 1)); tail -5 "$scratch/$name.log"; }
done < "$list"
echo "perf: wrote $csv ($fails failed); logs in $scratch"
[ $fails -eq 0 ]
