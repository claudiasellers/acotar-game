#!/bin/bash
# F47: a class_name added after Godot's class cache was written must resolve
# after `make play`'s prelude. In a scratch worktree of HEAD: make play once
# (the game itself is stubbed out: only imports reach the engine), add a new
# class and a script that uses it, make play again, and check the cache lists
# it and the script runs.
#   tools/mq/class_cache_check.sh [--keep]
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"
engine=$(mq_engine) || { echo "classcheck: no Godot $MQ_GODOT_VERSION found" >&2; exit 125; }
scratch=$(mktemp -d "${TMPDIR:-/tmp}/class-cache-check.XXXXXX")
wt="$scratch/tree"
git worktree add -q --detach "$wt" HEAD || exit 1
finish() {
	if [ "${1:-}" = "--keep" ]; then echo "classcheck: kept $scratch"; return; fi
	git worktree remove --force "$wt" 2>/dev/null; rm -rf "$scratch"
}
trap 'finish ${KEEP:-}' EXIT
[ "${1:-}" = "--keep" ] && KEEP=--keep
cd "$wt" || exit 1
# Imports go to the real engine; anything else (starting the game) returns at once.
stub="$scratch/godot-stub"
printf '#!/bin/bash\ncase " $* " in *" --import "*) exec "%s" "$@" ;; esac\nexit 0\n' "$engine" > "$stub"
chmod +x "$stub"
# -o godot -o bake: the engine is here; generated content isn't what this checks.
mk() { make --no-print-directory -o godot -o bake GODOT="$stub" play; }
fail=0
mk > "$scratch/first.log" 2>&1 || { echo "classcheck: first make play failed"; cat "$scratch/first.log"; fail=1; }
mkdir -p tests/_classcheck
printf 'class_name ClassCacheProbe\nextends RefCounted\n\nstatic func ping() -> int:\n\treturn 7\n' > tests/_classcheck/probe.gd
printf 'extends SceneTree\n\nfunc _init() -> void:\n\tprint("PROBE %%d" %% ClassCacheProbe.ping())\n\tquit(0)\n' > tests/_classcheck/use_probe.gd
if tools/mq/class_cache.sh stale >/dev/null; then echo "classcheck: the stale check missed the new class"; fail=1; fi
mk > "$scratch/second.log" 2>&1 || { echo "classcheck: make play after adding a class failed"; cat "$scratch/second.log"; fail=1; }
grep -q '"class": &"ClassCacheProbe"' .godot/global_script_class_cache.cfg || { echo "classcheck: the new class is not in the cache"; fail=1; }
out=$(HOME="$scratch" "$engine" --headless --path . -s res://tests/_classcheck/use_probe.gd 2>&1)
echo "$out" | grep -q '^PROBE 7$' || { echo "classcheck: a script using the new class didn't run:"; echo "$out" | grep -E 'ERROR|PROBE' | head -5; fail=1; }
[ "$fail" = 0 ] && echo "classcheck: a class added after the cache resolves after make play"
exit "$fail"
