#!/bin/bash
# Puts a story slot at the start of a beat (T163), e.g. Story 1 at the beast at the door:
#   make jump BEAT=beast_door SLOT=1        (from the game folder; or tools/dev/jump_save.sh beast_door 1)
# SLOT is the title's Story number (1-3). Quit the game first.
#
# 1. Makes the save in a scratch data folder (tools/dev/jump_save.tscn, the real game headless).
# 2. Loads it there the way the title's Load does and checks the beat starts.
# 3. Only then: copies the slot's current save (and its .bak) to
#    <saves>/jump_backups/<date>-<time>-slot_N.json, and puts the new one in its place.
# Nothing in the real save folder changes unless 1 and 2 pass.
# JUMP_SAVES_DIR overrides the real saves folder (for testing this script).
set -euo pipefail

beat="${1:-}"
story="${2:-1}"
if [ -z "$beat" ]; then
	echo "usage: make jump BEAT=<beat> SLOT=<1-3>   e.g. make jump BEAT=beast_door SLOT=1" >&2
	exit 2
fi
case "$story" in 1|2|3) ;; *) echo "SLOT must be 1, 2 or 3 (Story 1-3 on the title), not '$story'" >&2; exit 2 ;; esac
slot="slot_$((story - 1))"

root=$(git -C "$(dirname "$0")" rev-parse --show-toplevel)
common=$(git -C "$root" rev-parse --git-common-dir)
case "$common" in /*) ;; *) common="$root/$common" ;; esac

# Godot's user:// for this project: app_userdata/<config/name, unsafe characters as '-'>.
name=$(sed -n 's/^config\/name="\(.*\)"$/\1/p' "$root/project.godot")
safe=$(printf '%s' "$name" | tr ':\\/*?"<>|' '---------')
if [ "$(uname)" = Darwin ]; then
	userdata="$HOME/Library/Application Support/Godot/app_userdata/$safe"
else
	userdata="${XDG_DATA_HOME:-$HOME/.local/share}/godot/app_userdata/$safe"
fi
saves="${JUMP_SAVES_DIR:-$userdata/saves}"

if pgrep -f "MacOS/Godot --path \.$" >/dev/null 2>&1; then
	echo "The game is running: quit it first, or it will save over the jump." >&2
	exit 1
fi

work=$(mktemp -d "${TMPDIR:-/tmp}/acotar-jump.XXXXXX")
[ -n "${JUMP_KEEP_WORK:-}" ] && echo "Work folder kept: $work" || trap 'rm -rf "$work"' EXIT
export MQ_SCRATCH="$work/data"
timeout=()
[ -f "$common/mq/bin/mqtimeout.pl" ] && timeout=(perl "$common/mq/bin/mqtimeout.pl" 600)

run() {   # run <log> <args...>
	local log="$1"; shift
	(cd "$root" && ${timeout[@]+"${timeout[@]}"} tools/mq/godot.sh --fixed-fps 60 res://tools/dev/jump_save.tscn -- "$@") >"$log" 2>&1 || true
}

echo "Making Story $story at '$beat' (the game loads headless; a minute or two)..."
run "$work/make.log" --beat="$beat" --slot="$slot"
made=$(sed -n 's/^JUMP_SAVE_WRITTEN //p' "$work/make.log" | tail -1)
if [ -z "$made" ] || [ ! -f "$made" ]; then
	echo "Making the save failed; nothing was changed. The end of its log:" >&2
	grep -E "JUMP_|SCRIPT ERROR|ERROR" "$work/make.log" | tail -15 >&2 || tail -15 "$work/make.log" >&2
	exit 1
fi
grep '^jump:' "$work/make.log" || true

echo "Checking it loads at '$beat'..."
run "$work/verify.log" --beat="$beat" --slot="$slot" --verify
if ! grep -q '^JUMP_VERIFY ok' "$work/verify.log"; then
	echo "The save didn't load at '$beat'; nothing was changed. The end of its log:" >&2
	grep -E "JUMP_|SCRIPT ERROR|ERROR" "$work/verify.log" | tail -15 >&2 || tail -15 "$work/verify.log" >&2
	exit 1
fi
grep -E '^(jump:|JUMP_VERIFY)' "$work/verify.log" || true

mkdir -p "$saves/jump_backups"
stamp=$(date +%Y%m%d-%H%M%S)
for f in "$slot.json" "$slot.json.bak"; do
	if [ -f "$saves/$f" ]; then
		cp -p "$saves/$f" "$saves/jump_backups/$stamp-$f"
		echo "Backed up: $saves/jump_backups/$stamp-$f"
	fi
done
cp "$made" "$saves/$slot.json.part"
mv -f "$saves/$slot.json.part" "$saves/$slot.json"
# The backup beside it is the new save too, so the old story can't stand in for it.
cp "$saves/$slot.json" "$saves/$slot.json.bak"
echo "Done: Story $story is at the start of '$beat' ($saves/$slot.json)."
echo "Open the game (make play), choose Load, then Story $story."
