#!/bin/bash
# The build lane: a plain loop, on the home machine only. Takes everything
# pending as one batch, merges it in a staging tree, gates it, and moves main.
# Only ever moved by this script. The rules are in CLAUDE.md and the handoff.
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

if ! mq_is_home; then
	echo "mq: REFUSED: not the home machine (no MQ_HOME_MACHINE=1 in $MQ_DIR/config)" >&2
	mq_event REFUSED "build lane: not the home machine"
	exit 3
fi
mq_lock_try "$MQ_DIR/lock" || { echo "mq: build lane already running" >&2; exit 0; }

STALL_SECS=$(mq_config_or MQ_STALL_SECS 300)
POLL=$(mq_config_or MQ_POLL 2)
REMOTE=$(mq_config MQ_REMOTE); : "${REMOTE:=origin}"
FETCH_TIMEOUT=$(mq_config_or MQ_FETCH_TIMEOUT 120)
stopping=0; gate_pid=""; caffeine=""; heart=""; stalled_until=0; last_ready=0
idle_pid=""; idle_out="$MQ_DIR/idlegate"
FULL_MERGES=$(mq_config_or MQ_FULLGATE_MERGES 10)
FULL_SECS=$(mq_config_or MQ_FULLGATE_SECS 86400)

note() { echo "$(mq_now) $*"; }
state() { echo "$*" > "$MQ_DIR/state"; }

cleanup_exit() {
	[ -n "$gate_pid" ] && kill "$gate_pid" 2>/dev/null
	[ -n "$heart" ] && kill "$heart" 2>/dev/null
	[ -n "$caffeine" ] && kill "$caffeine" 2>/dev/null
	state stopped
	mq_lock_release "$MQ_DIR/lock"
}
trap 'stopping=1; [ -n "$gate_pid" ] && kill "$gate_pid" 2>/dev/null; [ -n "$idle_pid" ] && kill "$idle_pid" 2>/dev/null' TERM INT
trap cleanup_exit EXIT

( while kill -0 $$ 2>/dev/null; do touch "$MQ_DIR/lock/heartbeat" 2>/dev/null; sleep 10; done ) &
heart=$!

keep_awake() {
	command -v caffeinate >/dev/null || return 0
	if [ -z "$caffeine" ] || ! kill -0 "$caffeine" 2>/dev/null; then
		caffeinate -i -w $$ & caffeine=$!
	fi
}

wt() { git -C "$MQ_BUILD" "$@"; }

# Puts the build worktree exactly at a commit. Ignored caches stay.
goto() {
	wt checkout -q -f --detach "$1" && wt clean -fdq
}

push_main() {
	[ "$(mq_config_or MQ_PUSH 1)" = 1 ] || return 0
	git rev-parse -q --verify "refs/remotes/$REMOTE/main" >/dev/null || return 0
	git merge-base --is-ancestor main "$REMOTE/main" && return 0
	if mq_timeout "$FETCH_TIMEOUT" git -C "$MQ_BUILD" push -q "$REMOTE" main:main 2>>"$MQ_DIR/buildlane.log"; then
		git fetch -q "$REMOTE" main:"refs/remotes/$REMOTE/main" 2>/dev/null
		rm -f "$MQ_DIR/push-failing"
		mq_event PUSHED "main $(git rev-parse --short main)"
	elif [ ! -f "$MQ_DIR/push-failing" ]; then
		touch "$MQ_DIR/push-failing"
		mq_event PUSHFAIL "main $(git rev-parse --short main); retrying"
	fi
}

kick_ready() {
	[ "$(mq_config MQ_CLOUD)" = 1 ] || return 0
	[ -x "$here/pull_ready.sh" ] || return 0
	( cd "$MQ_REPO" && mq_timeout 600 /bin/bash "$here/pull_ready.sh" >>"$MQ_DIR/buildlane.log" 2>&1 ) &
}

done_merged() { # entry-file
	local e="$1" task; task=$(kv_get "$e" task)
	mv "$e" "$MQ_DIR/done/merged/"
	[ -d "$MQ_DIR/tasks/$task" ] && kv_set "$MQ_DIR/tasks/$task/meta" status merged
	mq_event MERGED "$task ${2:-} $(kv_get "$MQ_DIR/done/merged/$(basename "$e")" subject | cut -c1-70)"
}

reject() { # entry-file reason [logfile]
	local e="$1" reason="$2" log="${3:-}" task id
	task=$(kv_get "$e" task); id=$(basename "$e" .entry)
	kv_set "$e" reason "$reason"
	[ -n "$log" ] && [ -f "$log" ] && tail -40 "$log" > "$MQ_DIR/done/rejected/$id.log"
	mv "$e" "$MQ_DIR/done/rejected/"
	[ -d "$MQ_DIR/tasks/$task" ] && kv_set "$MQ_DIR/tasks/$task/meta" status rejected
	mq_event REJECTED "$task $reason"
	kick_ready
}

# Back in the queue: nothing is lost and nobody is blamed.
stall() { # batch-dir reason
	local b="$1" e
	for e in "$b"/*.entry; do
		[ -f "$e" ] && mv "$e" "$MQ_DIR/pending/"
	done
	rm -rf "$b"
	mq_event STALLED "$2; retrying in ${STALL_SECS}s"
	stalled_until=$(( $(date +%s) + STALL_SECS ))
	state "stalled: $2"
}

# A batch left by a stop. Anything already on main finishes; the rest requeues.
recover() {
	local b e
	for b in "$MQ_DIR"/batches/*; do
		[ -d "$b" ] || continue
		for e in "$b"/*.entry; do
			[ -f "$e" ] || continue
			if git merge-base --is-ancestor "$(kv_get "$e" sha)" main; then
				done_merged "$e"
			else
				mv "$e" "$MQ_DIR/pending/"
			fi
		done
		rm -rf "$b"
		mq_event RECOVERED "unfinished batch $(basename "$b") went back in the queue"
	done
}

# Runs gate.sh in the background so a stop can reach it. Returns its exit code.
run_gate() {
	( cd "$MQ_BUILD" && exec /bin/bash "$here/gate.sh" "$@" ) >>"$MQ_DIR/buildlane.log" 2>&1 &
	gate_pid=$!
	wait "$gate_pid"; local rc=$?
	gate_pid=""
	[ "$stopping" = 1 ] && return 4
	return "$rc"
}

# Known red for a main we haven't seen: gate the main itself, without stopping.
ensure_baseline() { # sha batch-dir
	local sha="$1" b="$2" rc
	[ -f "$MQ_DIR/baseline/$sha" ] && return 0
	state "baseline run on ${sha:0:9}"
	goto "$sha" || return 3
	run_gate --out "$b/baseline" --all; rc=$?
	case "$rc" in 0|1) ;; *) return "$rc" ;; esac
	cp "$b/baseline/failed" "$MQ_DIR/baseline/$sha"
	mq_event BASELINE "${sha:0:9} $(wc -l < "$b/baseline/failed" | tr -d ' ') known red"
}

# Merges the surviving entries onto base. Fills chain[] with the tip after each
# entry. Conflicts reject right away. Returns 3 if it couldn't try.
build_chain() { # base batch-dir
	local base="$1" b="$2" e sha task hits conf i
	chain=(); entries=()
	goto "$base" || return 3
	for e in "$b"/*.entry; do
		[ -f "$e" ] || continue
		sha=$(kv_get "$e" sha); task=$(kv_get "$e" task)
		conf="$MQ_BUILD/tools/mq/generated.conf"; [ -f "$conf" ] || conf="$here/generated.conf"
		hits=$(git diff --name-only --diff-filter=ACMR "$(git merge-base "$sha" "$base")" "$sha" | mq_generated_hits "$conf")
		if [ -n "$hits" ]; then
			reject "$e" "changes built files ($(printf '%s' "$hits" | cut -f1 | head -3 | tr '\n' ' ')). Those are rebuilt from generated.conf: change the recipe or its inputs instead."
			continue
		fi
		if ! wt merge -q --no-edit -m "$task merge: $(kv_get "$e" subject | cut -c1-60)" "$sha" >>"$MQ_DIR/buildlane.log" 2>&1; then
			if [ -n "$(wt ls-files -u)" ]; then
				local paths; paths=$(wt ls-files -u | cut -f2 | sort -u | head -5 | tr '\n' ' ')
				wt merge --abort
				reject "$e" "conflicts with main in: $paths. Rebase on main, fix it, and submit again."
				continue
			fi
			wt merge --abort 2>/dev/null
			return 3
		fi
		i=${#entries[@]}
		entries[$i]="$e"; chain[$i]=$(wt rev-parse HEAD)
	done
	return 0
}

# Smallest prefix of the batch that turns NAME red. Sets culprit (index).
narrow() { # name base known batch-dir
	local name="$1" base="$2" known="$3" b="$4" lo=-1 hi=$(( ${#chain[@]} - 1 )) mid rc round=0
	# lo: last prefix known good (-1 is base); hi: first known bad.
	while [ $((hi - lo)) -gt 1 ]; do
		mid=$(( (lo + hi) / 2 ))
		round=$((round + 1))
		state "narrowing $name, run $round"
		goto "${chain[$mid]}" || return 3
		run_gate --out "$b/narrow-$round" --base "$base" --known "$known" --only "$name"; rc=$?
		case "$rc" in
			0) lo=$mid ;;
			1) hi=$mid ;;
			*) return "$rc" ;;
		esac
	done
	culprit=$hi
}

land() { # tip base batch-dir known
	local tip="$1" base="$2" b="$3" known="$4" e old merged_to
	old=$(git rev-parse main)
	wt checkout -q -f main || return 3
	wt merge -q --ff-only "$tip" || return 3
	merged_to=$(git rev-parse --short main)
	# Reds that are still red carry over; fixed ones drop off.
	grep -E '^KNOWNRED ' "$b/gate/results.txt" 2>/dev/null | cut -d' ' -f2 > "$MQ_DIR/baseline/$tip"
	for e in "$b"/*.entry; do
		[ -f "$e" ] && done_merged "$e" "$merged_to"
	done
	rm -rf "$b"
	kv_set "$MQ_DIR/fullgate" merges $(( $(kv_get "$MQ_DIR/fullgate" merges | sed 's/^$/0/') + 1 ))
	state idle
	push_main
	kick_ready
	# A batch can change this very script. Take it on between batches.
	if [ -n "$(git diff --name-only "$old" main -- tools/mq)" ]; then
		( cd "$MQ_BUILD" && /bin/bash tools/mq/setup_lanes.sh --install )
		mq_event RELOAD "build lane took in new tools/mq"
		kill "$heart" 2>/dev/null
		mq_lock_release "$MQ_DIR/lock"
		exec /bin/bash "$MQ_BIN/buildlane.sh"
	fi
}

run_batch() {
	local id b e base rc tip known name
	id=$(date +%s); b="$MQ_DIR/batches/$id"; mkdir -p "$b"
	for e in "$MQ_DIR"/pending/*.entry; do
		[ -f "$e" ] && mv "$e" "$b/"
	done
	mq_timeout "$FETCH_TIMEOUT" git -C "$MQ_BUILD" fetch -q "$REMOTE" main:"refs/remotes/$REMOTE/main" 2>>"$MQ_DIR/buildlane.log" \
		|| note "fetch failed; going on with the last known origin"
	# Never fork from origin: its work goes in first and is tested with the rest.
	base=$(git rev-parse main)
	if git rev-parse -q --verify "refs/remotes/$REMOTE/main" >/dev/null && \
			! git merge-base --is-ancestor "$REMOTE/main" main; then
		goto "$base" || { stall "$b" "checkout failed"; return; }
		if ! wt merge -q --no-edit -m "Take in origin/main" "$REMOTE/main" >>"$MQ_DIR/buildlane.log" 2>&1; then
			wt merge --abort 2>/dev/null
			stall "$b" "cannot merge origin/main into main"; return
		fi
		base=$(wt rev-parse HEAD)
	fi
	ensure_baseline "$base" "$b"; rc=$?
	[ "$rc" = 4 ] && return
	[ "$rc" = 0 ] || { stall "$b" "cannot run the gate on main"; return; }
	known="$MQ_DIR/baseline/$base"

	while :; do
		state "batch $id: merging"
		build_chain "$base" "$b"; rc=$?
		[ "$rc" = 0 ] || { stall "$b" "merge or checkout failed without a conflict"; return; }
		if [ "${#chain[@]}" = 0 ]; then
			if [ "$base" != "$(git rev-parse main)" ]; then land "$base" "$base" "$b" "$known"; else rm -rf "$b"; state idle; fi
			return
		fi
		tip=${chain[$(( ${#chain[@]} - 1 ))]}
		state "batch $id: gate on ${#chain[@]} change(s)"
		goto "$tip" || { stall "$b" "checkout failed"; return; }
		rm -rf "$b/gate"
		run_gate --out "$b/gate" --base "$base" --known "$known"; rc=$?
		case "$rc" in
			0) land "$tip" "$base" "$b" "$known" || stall "$b" "could not move main"; return ;;
			1) ;;
			4) return ;;
			*) stall "$b" "the gate could not run"; return ;;
		esac
		name=$(head -1 "$b/gate/failed")
		culprit=$(( ${#chain[@]} - 1 ))
		if [ "${#chain[@]}" -gt 1 ]; then
			narrow "$name" "$base" "$known" "$b"; rc=$?
			[ "$rc" = 4 ] && return
			[ "$rc" = 0 ] || { stall "$b" "could not narrow $name"; return; }
		fi
		log="$b/gate/logs/$(printf '%s' "$name" | tr '/: ' '___').log"
		reject "${entries[$culprit]}" "failed $name. Rebase on main, fix it, and submit again." "$log"
		# Every round removes one change, so this ends.
	done
}

# The full gate on main, the safety net for when: lines. Only while the queue is
# empty, at low priority. Killed with no result the moment anything is
# submitted. A failure blocks nothing: it becomes known red and a task.
idle_gate_due() {
	local at merges
	[ "$(mq_config MQ_FULLGATE_OFF)" = 1 ] && return 1
	at=$(kv_get "$MQ_DIR/fullgate" at)
	if [ -z "$at" ]; then kv_set "$MQ_DIR/fullgate" at "$(date +%s)"; return 1; fi
	merges=$(kv_get "$MQ_DIR/fullgate" merges)
	[ "${merges:-0}" -ge "$FULL_MERGES" ] || [ $(( $(date +%s) - at )) -ge "$FULL_SECS" ]
}

idle_gate_start() {
	local sha known
	sha=$(git rev-parse main); known="$MQ_DIR/baseline/$sha"
	[ -f "$known" ] || known=/dev/null
	wt checkout -q -f main || return
	rm -rf "$idle_out"
	echo "$sha" > "$MQ_DIR/idlegate.sha"
	( cd "$MQ_BUILD" && exec nice -n 19 /bin/bash "$here/gate.sh" --out "$idle_out" --known "$known" --all ) >>"$MQ_DIR/buildlane.log" 2>&1 &
	idle_pid=$!
	state "full gate on main ${sha:0:9}"
	mq_event FULLGATE "started on ${sha:0:9}"
}

idle_gate_kill() {
	kill "$idle_pid" 2>/dev/null
	wait "$idle_pid" 2>/dev/null
	idle_pid=""
	state idle
	mq_event FULLGATE "stopped: work arrived"
}

idle_gate_reap() {
	local rc sha name
	kill -0 "$idle_pid" 2>/dev/null && return 0
	wait "$idle_pid"; rc=$?
	idle_pid=""; state idle
	sha=$(cat "$MQ_DIR/idlegate.sha")
	case "$rc" in
		0|1) ;;
		*) mq_event FULLGATE "could not run; will try again"; return 0 ;;
	esac
	kv_set "$MQ_DIR/fullgate" at "$(date +%s)"
	kv_set "$MQ_DIR/fullgate" merges 0
	if [ "$rc" = 0 ]; then mq_event FULLGATE "passed on ${sha:0:9}"; return 0; fi
	while IFS= read -r name; do
		echo "$name" >> "$MQ_DIR/baseline/$sha"
		"$here/task.sh" add "Full gate on main found $name red at ${sha:0:9}; log in .git/mq/idlegate/logs" >/dev/null
		mq_event FULLGATE "$name is red on ${sha:0:9}; task made"
	done < "$idle_out/failed"
}

keep_awake
state idle
recover
"$here/setup_lanes.sh" --start  # the cleanup loop and shots listener, after a reboot or reload
note "build lane up, pid $$"
while [ "$stopping" = 0 ]; do
	now=$(date +%s)
	if [ $((now - last_ready)) -ge 60 ]; then kick_ready; push_main; last_ready=$now; fi
	work=0
	for e in "$MQ_DIR"/pending/*.entry; do
		[ -f "$e" ] && { work=1; break; }
	done
	if [ -n "$idle_pid" ]; then
		if [ "$work" = 1 ]; then idle_gate_kill; else idle_gate_reap; fi
	fi
	if [ "$work" = 1 ] && [ "$now" -ge "$stalled_until" ]; then
		keep_awake
		run_batch
	elif [ "$work" = 0 ] && [ -z "$idle_pid" ] && idle_gate_due; then
		keep_awake
		idle_gate_start
	fi
	sleep "$POLL"
done
