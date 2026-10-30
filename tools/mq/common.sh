#!/bin/bash
# Shared helpers for the build queue. Sourced by every tools/mq script.
# Stock macOS bash 3.2 and BSD tools only: no timeout, flock or wait -n.

MQ_GIT=$(git rev-parse --path-format=absolute --git-common-dir 2>/dev/null) || {
	echo "mq: not inside a git repository" >&2; exit 2; }
MQ_REPO=$(dirname "$MQ_GIT")
MQ_DIR="$MQ_GIT/mq"
MQ_BIN="$MQ_DIR/bin"
MQ_LANES_DIR="$MQ_REPO/.lanes"
MQ_BUILD="$MQ_LANES_DIR/build"
MQ_LEVELCACHE="$MQ_GIT/levelcache"
MQ_PROJECT=$(basename "$MQ_REPO")
MQ_GODOT_VERSION=4.7.2
export MQ_BIN

# The directory of the script being run, so a lane uses its own copy.
mq_self_dir() { cd "$(dirname "${BASH_SOURCE[1]}")" && pwd; }

# --- events and key=value files ---------------------------------------------

mq_now() { date '+%Y-%m-%d %H:%M:%S'; }

# mq_event KIND message...
mq_event() {
	local kind="$1"; shift
	mkdir -p "$MQ_DIR"
	printf '%s %s %s\n' "$(mq_now)" "$kind" "$*" >> "$MQ_DIR/events.log"
}

# kv_get FILE KEY: last value of KEY, empty when missing.
kv_get() {
	[ -f "$1" ] || return 0
	sed -n "s/^$2=//p" "$1" | tail -1
}

# kv_set FILE KEY VALUE: replaces KEY, atomically.
kv_set() {
	local tmp="$1.tmp.$$"
	{ [ -f "$1" ] && grep -v "^$2=" "$1"; printf '%s=%s\n' "$2" "$3"; } > "$tmp"
	mv "$tmp" "$1"
}

mq_config() { kv_get "$MQ_DIR/config" "$1"; }

# mq_config_or KEY DEFAULT
mq_config_or() {
	local v; v=$(mq_config "$1")
	if [ -n "$v" ]; then printf '%s\n' "$v"; else printf '%s\n' "$2"; fi
}

# --- the home machine --------------------------------------------------------

# Read from the file only, never the environment. The file isn't in the repo,
# so no clone or container can have it by accident.
mq_is_home() { [ "$(mq_config MQ_HOME_MACHINE)" = "1" ]; }

mq_require_home() {
	mq_is_home && return 0
	echo "mq: REFUSED: this is not the home machine (no MQ_HOME_MACHINE=1 in $MQ_DIR/config)." >&2
	echo "mq: Only the home machine runs the build lane or queues changes." >&2
	exit 3
}

# --- finding the engine ------------------------------------------------------

# Prints the engine path, or fails. MQ_ENGINE in the config wins (the selftest
# points it at a fake). Otherwise the pinned copy in the primary folder, then
# the app, then PATH. `godot` is only a zsh alias here, so PATH alone won't do.
mq_engine() {
	local e
	e=$(mq_config MQ_ENGINE)
	if [ -n "$e" ]; then [ -x "$e" ] && { echo "$e"; return 0; }; return 1; fi
	for e in "$MQ_REPO/.tools/godot-$MQ_GODOT_VERSION/Godot.app/Contents/MacOS/Godot" \
			/Applications/Godot.app/Contents/MacOS/Godot "$(command -v godot 2>/dev/null)"; do
		[ -n "$e" ] && [ -x "$e" ] || continue
		case "$("$e" --version 2>/dev/null)" in
			"$MQ_GODOT_VERSION".*) echo "$e"; return 0 ;;
		esac
	done
	return 1
}

# --- a timeout, a lock, detaching --------------------------------------------

# mq_timeout SECONDS command...: see mqtimeout.pl.
mq_timeout() { /usr/bin/perl "$(dirname "${BASH_SOURCE[0]}")/mqtimeout.pl" "$@"; }

# mq_detach LOG command...: runs it in a new session so it outlives this one.
mq_detach() {
	local log="$1"; shift
	/usr/bin/perl -e '
		use POSIX qw(setsid);
		my $log = shift;
		exit 0 if fork();
		setsid();
		open(STDIN, "<", "/dev/null");
		open(STDOUT, ">>", $log);
		open(STDERR, ">&", \*STDOUT);
		exec { $ARGV[0] } @ARGV;
	' "$log" "$@"
}

# mq_lock_try DIR: takes a lock folder holding our pid. A lock whose holder is
# dead is taken over.
mq_lock_try() {
	local dir="$1" pid
	if mkdir "$dir" 2>/dev/null; then
		echo $$ > "$dir/pid"; touch "$dir/heartbeat"; return 0
	fi
	pid=$(cat "$dir/pid" 2>/dev/null)
	if [ -n "$pid" ] && kill -0 "$pid" 2>/dev/null; then return 1; fi
	rm -rf "$dir"
	mkdir "$dir" 2>/dev/null || return 1
	echo $$ > "$dir/pid"; touch "$dir/heartbeat"
}

mq_lock_release() { rm -rf "$1"; }

# mq_short_lock NAME: a brief critical section (task numbering). Waits up to 30s.
mq_short_lock() {
	local dir="$MQ_DIR/locks/$1" i=0
	mkdir -p "$MQ_DIR/locks"
	while ! mq_lock_try "$dir"; do
		i=$((i + 1)); [ "$i" -gt 300 ] && return 1
		perl -e 'select(undef,undef,undef,0.1)'
	done
}

# Seconds since a file changed; 999999 when missing.
mq_age() {
	[ -e "$1" ] || { echo 999999; return; }
	echo $(( $(date +%s) - $(stat -f %m "$1") ))
}

# --- the queue ---------------------------------------------------------------

mq_buildlane_pid() {
	local pid
	pid=$(cat "$MQ_DIR/lock/pid" 2>/dev/null) || return 1
	[ -n "$pid" ] && kill -0 "$pid" 2>/dev/null && echo "$pid"
}

# mq_queued_entry SHA: prints the entry file holding SHA, if any.
mq_queued_entry() {
	local f
	for f in "$MQ_DIR"/pending/* "$MQ_DIR"/batches/*/*.entry; do
		[ -f "$f" ] || continue
		[ "$(kv_get "$f" sha)" = "$1" ] && { echo "$f"; return 0; }
	done
	return 1
}

# True when nothing is queued, batched, or under test.
mq_idle() {
	local f
	for f in "$MQ_DIR"/pending/* "$MQ_DIR"/batches/*; do
		[ -e "$f" ] && return 1
	done
	return 0
}

# mq_generated_hits NAMES: paths from stdin that are generated outputs, read
# from the given generated.conf. Output is "path<TAB>builder".
mq_generated_hits() {
	local conf="$1" path name outs o
	while IFS= read -r path; do
		case "$path" in
			*/_generated/*) printf '%s\t%s\n' "$path" "_generated"; continue ;;
		esac
		[ -f "$conf" ] || continue
		while IFS='|' read -r name outs _; do
			name=$(echo "$name" | tr -d ' ')
			case "$name" in ''|\#*) continue ;; esac
			for o in $outs; do
				# shellcheck disable=SC2254
				case "$path" in
					$o|$o/*) printf '%s\t%s\n' "$path" "$name" ;;
				esac
			done
		done < "$conf"
	done
}
