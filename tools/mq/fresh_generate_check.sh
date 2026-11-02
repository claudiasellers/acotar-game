#!/bin/bash
# F42: what a fresh checkout does. In a scratch worktree of HEAD, runs
# `make clean` then `make generate` (the order `make update` uses: generate
# before import), then checks every output in generated.conf is there and no
# builder log has a parse error.
#   tools/mq/fresh_generate_check.sh            empty level cache: every builder
#                                               runs (the terrain bake alone is ~14 min)
#   tools/mq/fresh_generate_check.sh --cached   share .git/levelcache: quick, only
#                                               what isn't cached is built
# Exit 0 when clean; the scratch worktree is removed either way (--keep keeps it).
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"
CACHED=0; KEEP=0
for a in "$@"; do
	case "$a" in --cached) CACHED=1 ;; --keep) KEEP=1 ;; *) echo "usage: $0 [--cached] [--keep]" >&2; exit 2 ;; esac
done
engine=$(mq_engine) || { echo "fresh: no Godot $MQ_GODOT_VERSION found" >&2; exit 125; }
scratch=$(mktemp -d "${TMPDIR:-/tmp}/fresh-generate.XXXXXX")
wt="$scratch/tree"
git worktree add -q --detach "$wt" HEAD || exit 1
finish() {
	if [ "$KEEP" = 1 ]; then echo "fresh: kept $scratch"; return; fi
	git worktree remove --force "$wt" 2>/dev/null
	rm -rf "$scratch"
}
trap finish EXIT
[ "$CACHED" = 1 ] || export MQ_LEVELCACHE="$scratch/levelcache"
# Its own logs, so only this run's builders are read.
export MQ_BIN="$here"
out="$scratch/generate.log"
start="$scratch/start"; touch "$start"
(
	cd "$wt" || exit 1
	# -o godot: the engine is already here (on Linux too); GODOT for make import.
	make --no-print-directory -o godot GODOT="$engine" clean generate
) > "$out" 2>&1
rc=$?
fail=0
[ "$rc" = 0 ] || { echo "fresh: make clean generate failed (exit $rc)"; tail -20 "$out"; fail=1; }
grep -q 'importing first' "$out" && echo "fresh: note: levels.sh imported (make generate should have)"
CONF="$wt/tools/mq/generated.conf"
while IFS='|' read -r name outs rest; do
	name=$(echo "$name" | tr -d ' ')
	case "$name" in ''|\#*) continue ;; esac
	for o in $outs; do
		if [ ! -e "$wt/$o" ]; then echo "fresh: $name: missing $o"; fail=1
		elif [ -d "$wt/$o" ] && [ -z "$(ls -A "$wt/$o")" ]; then echo "fresh: $name: $o is empty"; fail=1; fi
	done
done < "$CONF"
# A parse error means a builder couldn't see a class (the F42 failure). Other
# script errors are listed, not failed: every -s builder logs a compile error
# for any autoload it reaches (WorldStreamer), and still builds.
logs=$(find "$MQ_DIR/logs" -name 'build-*.log' -newer "$start" 2>/dev/null)
for f in $logs "$out"; do
	if grep -q 'SCRIPT ERROR: Parse Error' "$f"; then
		echo "fresh: parse errors in $(basename "$f"):"; grep 'SCRIPT ERROR: Parse Error' "$f" | sort | uniq -c | head -8
		fail=1
	elif grep -q 'SCRIPT ERROR' "$f"; then
		echo "fresh: note, other script errors in $(basename "$f"):"; grep 'SCRIPT ERROR' "$f" | sort | uniq -c | head -4
	fi
done
built=$(echo "$logs" | grep -c . )
[ "$fail" = 0 ] && echo "fresh: clean ($built builders ran, every output present, no parse errors)"
exit "$fail"
