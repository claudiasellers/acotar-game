#!/bin/bash
# Built files. Only the recipe lives in git (generated.conf); output is rebuilt
# from it and shared between worktrees through .git/levelcache/.
#   levels.sh ensure [--cached-only] [name]   bring this worktree up to date
#   levels.sh check                           every builder listed, every output ignored
#   levels.sh fingerprint <name>
#   levels.sh seed <name> <folder-with-outputs>   put an existing build in the cache
# ensure, in order: same fingerprint here with every output on disk, nothing to
# do; in the cache, copy it in; otherwise build it once for the machine, while
# other worktrees wait. The stamp lives in the git dir, so a git clean or a
# deleted output leaves it behind: it only counts if the outputs are still there.
# MQ_LEVELS_SKIP=name leaves one out, for the gate to build as its own line. It's
# an environment setting so that a gate.conf using it still works under an older
# installed copy of this script, which just builds everything.
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

# A shared cache between machines that cannot see each other's .git (cloud
# lanes: /mnt/project-files/cache/levelcache). MQ_LEVELCACHE_SHARED overrides;
# empty or missing turns it off. Entries are <name>/<fingerprint>.tar, so a
# fresh lane copies a build instead of paying for it (terrain: ~15 min).
SHARED="${MQ_LEVELCACHE_SHARED-/mnt/project-files/cache/levelcache}"
[ -n "$SHARED" ] && [ -d "$(dirname "$SHARED")" ] || SHARED=""
shared_fetch() {
	local name="$1" fp="$2" tar tmp
	[ -n "$SHARED" ] || return 1
	tar="$SHARED/$name/$fp.tar"
	[ -f "$tar" ] || return 1
	tmp="$MQ_LEVELCACHE/$name/.fetch.$$"
	rm -rf "$tmp"; mkdir -p "$tmp"
	if tar -xf "$tar" -C "$tmp"; then
		mv "$tmp" "$MQ_LEVELCACHE/$name/$fp" 2>/dev/null || rm -rf "$tmp"
		echo "levels: $name $fp restored from the shared cache" >&2
		return 0
	fi
	rm -rf "$tmp"
	return 1
}
shared_publish() {
	local name="$1" fp="$2" tmp
	[ -n "$SHARED" ] || return 0
	[ -f "$SHARED/$name/$fp.tar" ] && return 0
	mkdir -p "$SHARED/$name" 2>/dev/null || return 0
	tmp="$SHARED/$name/.$fp.tar.$$"
	tar -cf "$tmp" -C "$MQ_LEVELCACHE/$name/$fp" . 2>/dev/null && mv "$tmp" "$SHARED/$name/$fp.tar" || rm -f "$tmp"
}
outputs_present() {
	local o
	for o in $1; do [ -e "$o" ] || return 1; done
}

ensure_one() {
	local name="$1" outs="$2" cmd="$3" inputs="$4" fp stamp lockd log rc
	fp=$(fingerprint_of "$cmd" "$inputs")
	stamp="$GITDIR/mq-levels/$name"
	[ "$(cat "$stamp" 2>/dev/null)" = "$fp" ] && outputs_present "$outs" && return 0
	mkdir -p "$MQ_LEVELCACHE/$name" "$GITDIR/mq-levels"
	lockd="$MQ_LEVELCACHE/$name/$fp.lock"
	[ -d "$MQ_LEVELCACHE/$name/$fp" ] || shared_fetch "$name" "$fp" || true
	while :; do
		if [ -d "$MQ_LEVELCACHE/$name/$fp" ]; then
			# No stamp until it's whole: a gate can kill this part way through.
			rm -f "$stamp"
			copy_in "$MQ_LEVELCACHE/$name/$fp" "$outs"
			echo "$fp" > "$stamp"
			return 0
		fi
		[ "$CACHED_ONLY" = 1 ] && { echo "levels: $name not built for this tree yet; skipped" >&2; return 0; }
		if mq_lock_try "$lockd"; then break; fi
		sleep 5
	done
	rm -f "$stamp"
	mq_event BUILD "$name $fp"
	# One plain line on stderr, so a person at make play sees why it is busy.
	case "$name" in
		terrain) echo "Building $name (no saved copy yet; this takes about 14 minutes)..." >&2 ;;
		*) echo "Building $name (no saved copy yet; this can take a few minutes)..." >&2 ;;
	esac
	ensure_import || { mq_lock_release "$lockd"; return 1; }
	log="$MQ_DIR/logs/build-$name-$fp.log"
	mkdir -p "$MQ_DIR/logs"
	: > "$log"
	# perl itself in the background (not the mq_timeout function, whose
	# subshell would be what $! names): stopping $pid takes the build down.
	/usr/bin/perl "$here/mqtimeout.pl" "$BUILD_TIMEOUT" /bin/bash -c "$cmd" > "$log" 2>&1 &
	local pid=$! broken=0
	# Stopped (a gate gave up on it): take the build down too.
	trap 'kill -TERM "$pid" 2>/dev/null; exit 143' TERM INT
	# A builder whose script fails to parse never quits (F42): stop it at once.
	# (Sleep first: a TERM before mqtimeout.pl has set its handler would
	# leave the builder running.)
	while kill -0 "$pid" 2>/dev/null; do
		sleep 2
		if grep -qE "$BROKEN_SCRIPT" "$log" 2>/dev/null; then
			broken=1
			kill -TERM "$pid" 2>/dev/null
			break
		fi
	done
	wait "$pid"
	rc=$?
	trap - TERM INT
	grep -qE "$BROKEN_SCRIPT" "$log" 2>/dev/null && broken=1
	[ "$broken" = 1 ] && rc=65
	if [ "$rc" = 0 ]; then
		store "$name" "$fp" "$outs" && shared_publish "$name" "$fp" || rc=1
	fi
	mq_lock_release "$lockd"
	if [ "$rc" != 0 ]; then
		if [ "$broken" = 1 ]; then
			echo "levels: build of $name stopped: a script failed to parse (exit $rc); log: $log" >&2
			grep -E "$BROKEN_SCRIPT" "$log" | head -8 >&2
			echo "levels: if those classes exist, the import cache is stale: run make import, then make generate" >&2
		else
			echo "levels: build of $name failed (exit $rc); log: $log" >&2
			tail -20 "$log" >&2
		fi
		return 1
	fi
	echo "$fp" > "$stamp"
	mark_superseded "$name" "$fp" "$log"
}

# Marks, never deletes: the log after its retention, and every older build of this
# recipe after a week. cleanup.sh re-checks that no worktree's stamp still names one.
mark_superseded() { # name fp log
	local d
	local mk="$MQ_BIN/mark.sh"; [ -x "$mk" ] || mk="$here/mark.sh"
	[ -f "$3" ] && "$mk" add file "$3" $(( $(mq_config_or MQ_CLEANUP_LOG_DAYS 14) * 86400 )) "build log" || true
	for d in "$MQ_LEVELCACHE/$1"/*/; do
		d=$(basename "$d")
		[ "$d" = "$2" ] || [ "$d" = '*' ] && continue
		case "$d" in *.lock|.*) continue ;; esac
		"$mk" add level "$1/$d" "$(mq_config_or MQ_LEVEL_KEEP_SECS 604800)" "superseded by $2" || true
	done
}

# What a builder's log says when it can't see a project class: a missing or
# stale class cache (F42). Not every compile error: a -s builder always logs
# one for any autoload it reaches (WorldStreamer) and still builds fine.
BROKEN_SCRIPT='Parse Error: Identifier "[A-Za-z0-9_]+" not declared|Could not find type "|Could not resolve class "'

# Builders find each other's classes through Godot's class cache, which only
# an import writes. A fresh checkout or a make clean has none (F42), and a
# cache from before a class was added lacks it (F47): import once, before the
# first build, whenever the cache is missing a class.
IMPORTED=0
ensure_import() {
	[ "$IMPORTED" = 1 ] && return 0
	IMPORTED=1
	"$MQ_BIN/class_cache.sh" stale >/dev/null && return 0
	echo "Godot's class cache is missing or out of date: importing first (a minute or two)..." >&2
	mq_timeout "$BUILD_TIMEOUT" "$MQ_BIN/godot.sh" --import > "$MQ_DIR/logs/import-before-build.log" 2>&1
	local missing
	if ! missing=$("$MQ_BIN/class_cache.sh" stale); then
		echo "levels: after importing, the class cache still lacks:" >&2
		echo "$missing" | head -10 >&2
		echo "levels: log: $MQ_DIR/logs/import-before-build.log" >&2
		return 1
	fi
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

# Said with every "builder not in generated.conf" failure, here and in precheck.sh.
RECIPE_HELP='Add one recipe line to tools/mq/generated.conf: name | git-ignored output folder(s) | build command | inputs. Example: world_map | ui/map/_generated | "$MQ_BIN/godot.sh" -s tools/generators/world_map.gd | tools/generators/world_map.gd :(glob)ui/map/** . Put the output folder in .gitignore and never commit its files.'

CACHED_ONLY=0
case "${1:-}" in
	ensure)
		shift
		only=""
		for a in "$@"; do
			case "$a" in --cached-only) CACHED_ONLY=1 ;; *) only="$a" ;; esac
		done
		visit() {
			[ -z "$only" ] || [ "$only" = "$1" ] || return 0
			[ "${MQ_LEVELS_SKIP:-}" = "$1" ] && return 0
			ensure_one "$@"
		}
		each_line visit ;;
	check)
		CHECK_FAILED=0
		each_line check_one
		for g in tools/generators/*.gd; do
			[ -f "$g" ] || continue
			grep -q "$g" "$CONF" || { echo "levels: builder $g is not in generated.conf. $RECIPE_HELP" >&2; CHECK_FAILED=1; }
		done
		# Only World loads the bake, so a test that loads it must wait for the build.
		for t in $(grep -rlE 'world/shared/world/world\.tscn|load.*act1_game\.tscn' tests 2>/dev/null); do
			grep -qE '^#* *gate: needs:terrain' "$t" || { echo "levels: $t loads the world: add a '# gate: needs:terrain' line" >&2; CHECK_FAILED=1; }
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
