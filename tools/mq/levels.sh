#!/bin/bash
# Built files. Only the recipe lives in git (generated.conf); output is rebuilt
# from it and shared between worktrees through .git/levelcache/.
#   levels.sh ensure [--cached-only] [name]   bring this worktree up to date
#   levels.sh check                           every builder listed, every output ignored
#   levels.sh fingerprint <name>
#   levels.sh seed <name> <folder-with-outputs>   put an existing build in the cache
# ensure, in order: same fingerprint here, nothing to do; in the cache, copy it
# in; otherwise build it once for the machine, while other worktrees wait.
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"
# A tree without the .git/mq/bin copy (a fresh play folder) uses its own scripts.
[ -x "$MQ_BIN/godot.sh" ] || { MQ_BIN="$here"; export MQ_BIN; }

CONF=tools/mq/generated.conf
[ -f "$CONF" ] || CONF="$MQ_BIN/generated.conf"
GITDIR=$(git rev-parse --absolute-git-dir)
BUILD_TIMEOUT=$(mq_config_or MQ_BUILD_TIMEOUT 3600)

# Calls `visit name outputs command inputs` for each line of the conf.
each_line() {
	local name outs cmd inputs
	[ -f "$CONF" ] || return 0
	while IFS='|' read -r name outs cmd inputs; do
		name=$(echo "$name" | tr -d ' ')
		case "$name" in ''|\#*) continue ;; esac
		"$1" "$name" "$(echo "$outs")" "$(echo "$cmd")" "$(echo "$inputs")" || return 1
	done < "$CONF"
}

# Hashes each committed input and the recipe. Uses content, not mtimes, so
# every worktree agrees.
fingerprint_of() {
	local cmd="$1" inputs="$2" list
	# shellcheck disable=SC2086
	list=$(set -f; git ls-files -- $inputs)
	{
		echo "$cmd"
		echo "$MQ_GODOT_VERSION"
		printf '%s\n' "$list" | while IFS= read -r f; do
			[ -f "$f" ] && printf '%s %s\n' "$(git hash-object "$f")" "$f"
		done
	} | shasum -a 256 | cut -c1-16
}

copy_in() {
	local src="$1" outs="$2" o
	for o in $outs; do
		[ -e "$src/$o" ] || continue
		rm -rf "./$o"
		mkdir -p "$(dirname "$o")"
		cp -cR "$src/$o" "./$o" 2>/dev/null || cp -R "$src/$o" "./$o"
	done
}

store() {
	local name="$1" fp="$2" outs="$3" from="${4:-.}" tmp o
	tmp="$MQ_LEVELCACHE/$name/.tmp.$$"
	rm -rf "$tmp"; mkdir -p "$tmp"
	for o in $outs; do
		[ -e "$from/$o" ] || { rm -rf "$tmp"; echo "levels: $name: expected output $o is missing" >&2; return 1; }
		mkdir -p "$tmp/$(dirname "$o")"
		cp -cR "$from/$o" "$tmp/$o" 2>/dev/null || cp -R "$from/$o" "$tmp/$o"
	done
	mv "$tmp" "$MQ_LEVELCACHE/$name/$fp"
}

ensure_one() {
	local name="$1" outs="$2" cmd="$3" inputs="$4" fp stamp lockd log rc
	fp=$(fingerprint_of "$cmd" "$inputs")
	stamp="$GITDIR/mq-levels/$name"
	[ "$(cat "$stamp" 2>/dev/null)" = "$fp" ] && return 0
	mkdir -p "$MQ_LEVELCACHE/$name" "$GITDIR/mq-levels"
	lockd="$MQ_LEVELCACHE/$name/$fp.lock"
	while :; do
		if [ -d "$MQ_LEVELCACHE/$name/$fp" ]; then
			copy_in "$MQ_LEVELCACHE/$name/$fp" "$outs"
			echo "$fp" > "$stamp"
			return 0
		fi
		[ "$CACHED_ONLY" = 1 ] && { echo "levels: $name not built for this tree yet; skipped" >&2; return 0; }
		if mq_lock_try "$lockd"; then break; fi
		sleep 5
	done
	mq_event BUILD "$name $fp"
	log="$MQ_DIR/logs/build-$name-$fp.log"
	mkdir -p "$MQ_DIR/logs"
	mq_timeout "$BUILD_TIMEOUT" /bin/bash -c "$cmd" > "$log" 2>&1
	rc=$?
	if [ "$rc" = 0 ]; then
		store "$name" "$fp" "$outs" || rc=1
	fi
	mq_lock_release "$lockd"
	if [ "$rc" != 0 ]; then
		echo "levels: build of $name failed (exit $rc); log: $log" >&2
		tail -20 "$log" >&2
		return 1
	fi
	echo "$fp" > "$stamp"
}

check_one() {
	local name="$1" outs="$2" o
	for o in $outs; do
		mkdir -p "$(dirname "$o")" 2>/dev/null
		if ! git check-ignore -q "$o/x" && ! git check-ignore -q "$o"; then
			echo "levels: $name output $o is not ignored by git" >&2
			CHECK_FAILED=1
		fi
	done
}

CACHED_ONLY=0
case "${1:-}" in
	ensure)
		shift
		only=""
		for a in "$@"; do
			case "$a" in --cached-only) CACHED_ONLY=1 ;; *) only="$a" ;; esac
		done
		visit() { [ -z "$only" ] || [ "$only" = "$1" ] || return 0; ensure_one "$@"; }
		each_line visit ;;
	check)
		CHECK_FAILED=0
		each_line check_one
		for g in tools/generators/*.gd; do
			[ -f "$g" ] || continue
			grep -q "$g" "$CONF" || { echo "levels: builder $g is not in generated.conf" >&2; CHECK_FAILED=1; }
		done
		[ "$CHECK_FAILED" = 0 ] ;;
	fingerprint)
		visit() { [ "$1" = "$only" ] && fingerprint_of "$3" "$4"; return 0; }
		only="$2"; each_line visit ;;
	seed)
		visit() {
			[ "$1" = "$only" ] || return 0
			local fp; fp=$(fingerprint_of "$3" "$4")
			mkdir -p "$MQ_LEVELCACHE/$1"
			[ -d "$MQ_LEVELCACHE/$1/$fp" ] || store "$1" "$fp" "$2" "$from"
			echo "seeded $1 $fp"
		}
		only="$2"; from="$3"; each_line visit ;;
	*) echo "usage: levels.sh ensure|check|fingerprint|seed" >&2; exit 2 ;;
esac
