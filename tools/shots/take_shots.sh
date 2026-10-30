#!/usr/bin/env bash
# Run one shot request (docs/contracts/shot_request.md) in one Godot process.
#   tools/shots/take_shots.sh <request.json> [out_dir]
# Env: GODOT (binary, default `godot`), SHOTS_GODOT_ARGS (word-split, placed
# right after the binary). Bash 3.2 and BSD-tool safe for the Mac listener.
# Linux without a display uses xvfb-run and Mesa's software Vulkan with every
# core. A request with no shots runs --headless (checks only). macOS never
# uses xvfb or --headless.
set -u
req="${1:?usage: take_shots.sh <request.json> [out_dir]}"
out="${2:-}"
case "$req" in /*) ;; *) req="$PWD/$req" ;; esac
case "$out" in /*|"") ;; *) out="$PWD/$out" ;; esac
cd "$(dirname "$0")/../.." || exit 1
godot="${GODOT:-godot}"

flat=$(tr -d '\n\r\t ' < "$req") || exit 1
# Renderer: explicit "compatibility" or "forward_plus" wins; otherwise
# layout requests use Compatibility (4x faster on lavapipe, full terrain)
# and full/look requests use the project's Forward+.
args=""
case "$flat" in
	*'"renderer":"compatibility"'*) args="--rendering-method gl_compatibility" ;;
	*'"renderer":"forward_plus"'*) ;;
	*'"quality":"full"'*) ;;
	*) args="--rendering-method gl_compatibility" ;;
esac

wrap=""
if [ "$(uname)" != "Darwin" ]; then
	case "$flat" in
		*'"shots":[{'*) ;;
		*) args="--headless" ;;
	esac
	if [ "$args" != "--headless" ] && [ -z "${DISPLAY:-}" ] && command -v xvfb-run >/dev/null 2>&1; then
		wrap=1
	fi
	if [ -z "${LP_NUM_THREADS:-}" ]; then
		LP_NUM_THREADS=$(nproc 2>/dev/null || echo 4)
		export LP_NUM_THREADS
	fi
fi

set --
[ -n "$out" ] && set -- "$out"
if [ -n "$wrap" ]; then
	# shellcheck disable=SC2086
	exec xvfb-run -a -s "-screen 0 1920x1080x24" "$godot" ${SHOTS_GODOT_ARGS:-} $args --audio-driver Dummy --path . \
		res://tools/shots/shot_runner.tscn -- "$req" "$@"
fi
# shellcheck disable=SC2086
exec "$godot" ${SHOTS_GODOT_ARGS:-} $args --audio-driver Dummy --path . res://tools/shots/shot_runner.tscn -- "$req" "$@"
