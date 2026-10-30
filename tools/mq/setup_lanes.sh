#!/bin/bash
# Creates anything missing and starts the build lane. Safe to run any time.
#   tools/mq/setup_lanes.sh           create what's missing, start everything
#   tools/mq/setup_lanes.sh --start   just start the loops
#   tools/mq/setup_lanes.sh --stop    stop the loops (a batch under test goes
#                                     back in the queue on the next start)
#   tools/mq/setup_lanes.sh --home    mark this computer as the home machine
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

NLANES=$(mq_config_or MQ_LANES 4)

# Shots listener hook: tools/mq/shots.sh (docs/SHOTS.md) renders cloud screenshot
# requests on this GPU. It keeps its own lock and state in .git/mq/shots/.
# Does nothing until that file has reached bin/.
shots_listener() {
	local s="$MQ_BIN/shots.sh"
	[ -f "$s" ] || return 0
	# The listener pushes its results, so MQ_PUSH=0 keeps it off. Stopping always works.
	if [ "$1" = --start ] && [ "$(mq_config_or MQ_PUSH 1)" != 1 ]; then return 0; fi
	/bin/bash "$s" "$1"
	return 0
}

install_bin() {
	# Replaces each file with mv, so a running script keeps its old copy.
	local f tmp
	mkdir -p "$MQ_BIN"
	for f in "$here"/* "$here"/.gdignore; do
		[ -f "$f" ] || continue
		tmp="$MQ_BIN/.new.$$"
		cp "$f" "$tmp" && mv "$tmp" "$MQ_BIN/$(basename "$f")"
	done
}

make_state() {
	local d
	for d in pending batches done/merged done/rejected baseline tasks ready/signals logs; do
		mkdir -p "$MQ_DIR/$d"
	done
	mkdir -p "$MQ_LEVELCACHE"
	touch "$MQ_DIR/config" "$MQ_DIR/events.log" "$MQ_DIR/buildlane.log"
	[ -n "$(mq_config MQ_LANES)" ] || kv_set "$MQ_DIR/config" MQ_LANES 4
	[ -n "$(mq_config MQ_CLOUD)" ] || kv_set "$MQ_DIR/config" MQ_CLOUD 1
}

make_ignores() {
	mkdir -p "$MQ_LANES_DIR" "$MQ_GIT/info"
	touch "$MQ_LANES_DIR/.gdignore" "$MQ_GIT/info/exclude"
	grep -qx '.lanes/' "$MQ_GIT/info/exclude" || echo '.lanes/' >> "$MQ_GIT/info/exclude"
}

# Copy-on-write clones of the caches a fresh worktree needs, so its first run
# doesn't reimport everything. Never overwrites what is there.
seed_worktree() {
	local wt="$1"
	if [ -d "$MQ_REPO/.godot" ] && [ ! -d "$wt/.godot" ]; then
		cp -cR "$MQ_REPO/.godot" "$wt/.godot" 2>/dev/null || cp -R "$MQ_REPO/.godot" "$wt/.godot"
	fi
}

make_worktrees() {
	local i wt
	if ! git -C "$MQ_REPO" symbolic-ref -q HEAD >/dev/null || \
			[ "$(git -C "$MQ_REPO" symbolic-ref -q --short HEAD)" != "main" ]; then
		:
	else
		git -C "$MQ_REPO" checkout -q --detach
	fi
	if [ ! -d "$MQ_BUILD" ]; then
		git -C "$MQ_REPO" worktree add -q "$MQ_BUILD" main
		git -C "$MQ_REPO" worktree lock --reason "mq: build lane" "$MQ_BUILD"
		seed_worktree "$MQ_BUILD"
	fi
	i=1
	while [ "$i" -le "$NLANES" ]; do
		wt="$MQ_LANES_DIR/lane$i"
		if [ ! -d "$wt" ]; then
			git -C "$MQ_REPO" worktree add -q --detach "$wt" main
		fi
		git -C "$MQ_REPO" worktree lock --reason "mq: lane$i" "$wt" 2>/dev/null
		seed_worktree "$wt"
		i=$((i + 1))
	done
}

start_loops() {
	local pid
	mq_is_home || { echo "mq: not the home machine; the build lane stays off here." >&2; return 0; }
	# Only a first install. After that bin/ changes only from merged main, so a
	# lane's unmerged tools/mq can never become the running build lane.
	[ -f "$MQ_BIN/buildlane.sh" ] || install_bin
	if ! mq_buildlane_pid >/dev/null; then
		mq_detach "$MQ_DIR/buildlane.log" /bin/bash -c "cd '$MQ_REPO' && exec /bin/bash '$MQ_BIN/buildlane.sh'"
		mq_event START "build lane started"
	fi
	pid=$(cat "$MQ_DIR/cleanup.pid" 2>/dev/null)
	# Never `kill -0` an empty or zero pid: 0 means our own group and always succeeds.
	if [ -z "$pid" ] || ! kill -0 "$pid" 2>/dev/null; then
		mq_detach "$MQ_DIR/buildlane.log" /bin/bash -c "cd '$MQ_REPO' && exec /bin/bash '$MQ_BIN/cleanup.sh' --loop"
	fi
	shots_listener --start
}

stop_loops() {
	local pid
	shots_listener --stop
	pid=$(cat "$MQ_DIR/cleanup.pid" 2>/dev/null)
	[ -n "$pid" ] && kill "$pid" 2>/dev/null
	rm -f "$MQ_DIR/cleanup.pid"
	pid=$(mq_buildlane_pid) && kill "$pid" 2>/dev/null
	mq_event STOP "build lane stopped by setup_lanes"
}

case "${1:-}" in
	--home)
		mkdir -p "$MQ_DIR"; touch "$MQ_DIR/config"
		kv_set "$MQ_DIR/config" MQ_HOME_MACHINE 1
		echo "This computer is the home machine." ;;
	--install) install_bin ;;
	--start) start_loops ;;
	--stop) stop_loops ;;
	"")
		make_state; make_ignores; make_worktrees; start_loops
		echo "lanes: $NLANES   build: $MQ_BUILD" ;;
	*) echo "usage: setup_lanes.sh [--start|--stop|--home|--install]" >&2; exit 2 ;;
esac
