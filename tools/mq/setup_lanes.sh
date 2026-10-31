#!/bin/bash
# Creates anything missing and starts the standing lanes: build, cleanup, shots.
# Safe to run any time.
#   tools/mq/setup_lanes.sh           create what's missing, start everything
#   tools/mq/setup_lanes.sh --start   start the loops, replacing any on old code or in
#                                     the wrong folder (shots reloads itself)
#   tools/mq/setup_lanes.sh --stop    stop the loops (a batch under test goes
#                                     back in the queue on the next start)
#   tools/mq/setup_lanes.sh --home    mark this computer as the home machine
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

NLANES=$(mq_config_or MQ_LANES 4)

# Standing lanes: a long-running loop keeps a folder of its own, never the play
# folder. Worktrees only because git needs one to run in; nothing is built there.
CLEANUP_WT="$MQ_LANES_DIR/cleanup"
SHOTS_WT="$MQ_LANES_DIR/shots-lane"  # shots.sh renders in .lanes/shots

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
	if [ ! -d "$MQ_BUILD" ]; then
		git -C "$MQ_REPO" worktree add -q --detach "$MQ_BUILD" "$MQ_MAIN"
		git -C "$MQ_REPO" worktree lock --reason "mq: build lane" "$MQ_BUILD"
		seed_worktree "$MQ_BUILD"
	fi
	i=1
	while [ "$i" -le "$NLANES" ]; do
		wt="$MQ_LANES_DIR/lane$i"
		if [ ! -d "$wt" ]; then
			git -C "$MQ_REPO" worktree add -q --detach "$wt" "$MQ_MAIN"
		fi
		git -C "$MQ_REPO" worktree lock --reason "mq: lane$i" "$wt" 2>/dev/null
		seed_worktree "$wt"
		i=$((i + 1))
	done
}

standing_worktree() { # path commit name
	if [ ! -e "$1/.git" ]; then
		git -C "$MQ_REPO" worktree add -q --detach "$1" "$2" || return 1
	fi
	git -C "$MQ_REPO" worktree lock --reason "mq: $3" "$1" 2>/dev/null
	return 0
}

standing_worktrees() {
	standing_worktree "$CLEANUP_WT" "$MQ_MAIN" cleanup
	standing_worktree "$SHOTS_WT" "$MQ_MAIN" shots
}

# True unless the pid is known to sit in another folder.
in_folder() { # pid folder
	local cwd; cwd=$(mq_pid_cwd "$1")
	[ -z "$cwd" ] || [ "$cwd" = "$(cd "$2" 2>/dev/null && pwd -P)" ]
}

# cleanup.sh only re-execs on its hourly wake, so a start replaces a loop on old
# code or in the wrong folder. Waits for it to go, so its exit can't remove the
# pid file of the one that replaces it; one still busy is left for the next start.
start_cleanup() {
	local pid sum i=0
	[ "$(mq_config MQ_CLEANUP_OFF)" = 1 ] && return 0
	[ -e "$CLEANUP_WT/.git" ] || { echo "mq: no $CLEANUP_WT; cleanup stays off" >&2; return 0; }
	sum=$(cat "$MQ_BIN/common.sh" "$MQ_BIN/cleanup.sh" | cksum)
	if pid=$(mq_cleanup_pid); then
		[ "$sum" = "$(cat "$MQ_DIR/cleanup.sum" 2>/dev/null)" ] && in_folder "$pid" "$CLEANUP_WT" && return 0
		kill "$pid" 2>/dev/null
		while mq_cleanup_pid >/dev/null && [ "$i" -lt 150 ]; do
			perl -e 'select(undef,undef,undef,0.1)'; i=$((i + 1))
		done
		mq_cleanup_pid >/dev/null && return 0
	fi
	rm -f "$MQ_DIR/cleanup.pid"
	echo "$sum" > "$MQ_DIR/cleanup.sum"
	mq_detach "$MQ_DIR/buildlane.log" /bin/bash -c "cd '$CLEANUP_WT' && exec /bin/bash '$MQ_BIN/cleanup.sh' --loop"
	i=0
	while [ ! -s "$MQ_DIR/cleanup.pid" ] && [ "$i" -lt 50 ]; do
		perl -e 'select(undef,undef,undef,0.1)'; i=$((i + 1))
	done
}

shots_stop() {
	local s="$MQ_DIR/shots/bin/shots.sh"
	[ -f "$s" ] || return 0
	( cd "$MQ_BUILD" && /bin/bash "$s" --stop )
	return 0
}

# Shots listener hook: shots.sh (docs/SHOTS.md) renders cloud screenshot requests
# on this GPU. It keeps its own lock and state in .git/mq/shots/. Does nothing
# until that file has reached bin/; a reload then starts it. A running listener
# is left alone: it moves onto a newer bin/ copy by itself between renders, and
# stopping it here would kill a render or run two at once.
shots_start() {
	# The listener pushes its results, so MQ_PUSH=0 keeps it off.
	if [ "$(mq_config_or MQ_PUSH 1)" != 1 ]; then shots_stop; return 0; fi
	[ -f "$MQ_BIN/shots.sh" ] && [ -d "$SHOTS_WT" ] || return 0
	mq_shots_pid >/dev/null && return 0
	( cd "$SHOTS_WT" && /bin/bash "$MQ_BIN/shots.sh" --start )
	return 0
}

start_loops() {
	mq_is_home || { echo "mq: not the home machine; the build lane stays off here." >&2; return 0; }
	# Only a first install. After that bin/ changes only from merged main, so a
	# lane's unmerged tools/mq can never become the running build lane.
	[ -f "$MQ_BIN/buildlane.sh" ] || install_bin
	# The build lane runs this too as it comes up: one start at a time.
	mq_short_lock start || return 0
	standing_worktrees
	if ! mq_buildlane_pid >/dev/null; then
		mq_detach "$MQ_DIR/buildlane.log" /bin/bash -c "cd '$MQ_BUILD' && exec /bin/bash '$MQ_BIN/buildlane.sh'"
		mq_event START "build lane started"
	fi
	start_cleanup
	shots_start
	mq_lock_release "$MQ_DIR/locks/start"
}

stop_loops() {
	local pid
	shots_stop
	pid=$(mq_cleanup_pid) && kill "$pid" 2>/dev/null
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
