#!/bin/bash
# The one-screen picture.
set -u
. "$(dirname "$0")/common.sh"

if mq_is_home; then machine="home machine"; else machine="NOT the home machine: the build lane refuses to run here"; fi
echo "== $MQ_PROJECT queue ($machine)"
if pid=$(mq_buildlane_pid); then
	echo "build lane: running (pid $pid, heartbeat $(mq_age "$MQ_DIR/lock/heartbeat")s ago)  $(cat "$MQ_DIR/state" 2>/dev/null)"
else
	echo "build lane: STOPPED"
fi
echo "main: $(git log -1 --format='%h %s' main | cut -c1-70)"
ahead=$(git rev-list --count origin/main..main 2>/dev/null)
behind=$(git rev-list --count main..origin/main 2>/dev/null)
echo "origin/main: $ahead to push, $behind to take in (as of the last fetch)"

echo; echo "-- under test"
n=0
for b in "$MQ_DIR"/batches/*; do
	[ -d "$b" ] || continue
	for e in "$b"/*.entry; do
		[ -f "$e" ] || continue
		n=$((n + 1))
		printf '  %s %s %s\n' "$(basename "$b" | cut -c1-16)" "$(kv_get "$e" task)" "$(kv_get "$e" subject | cut -c1-55)"
	done
	[ -f "$b/progress" ] && echo "  gate: $(cat "$b/progress")"
done
[ "$n" = 0 ] && echo "  nothing"

echo "-- waiting"
n=0
for e in "$MQ_DIR"/pending/*; do
	[ -f "$e" ] || continue
	n=$((n + 1))
	printf '  %s %s\n' "$(kv_get "$e" task)" "$(kv_get "$e" subject | cut -c1-65)"
done
[ "$n" = 0 ] && echo "  nothing"

echo "-- lanes"
i=1
while [ "$i" -le "$(mq_config_or MQ_LANES 4)" ]; do
	lane="lane$i"; task=""
	for m in "$MQ_DIR"/tasks/*/meta; do
		[ -f "$m" ] || continue
		if [ "$(kv_get "$m" status)" = active ] && [ "$(kv_get "$m" lane)" = "$lane" ]; then task=$(kv_get "$m" id); fi
	done
	br=$(git -C "$MQ_LANES_DIR/$lane" symbolic-ref -q --short HEAD 2>/dev/null || echo "(free)")
	printf '  %-6s %-6s %s\n' "$lane" "${task:--}" "$br"
	i=$((i + 1))
done

echo "-- standing lanes"
standing() { # name pid-or-empty worktree
	local cwd
	if [ -n "$2" ]; then
		cwd=$(mq_pid_cwd "$2")
		printf '  %-8s running  pid %-6s %s\n' "$1" "$2" "${cwd:-$3}"
	else
		printf '  %-8s STOPPED  %-10s %s\n' "$1" - "$3"
	fi
}
standing build "$(mq_buildlane_pid)" "$MQ_BUILD"
standing cleanup "$(mq_cleanup_pid)" "$MQ_LANES_DIR/cleanup"
if [ -f "$MQ_BIN/shots.sh" ]; then
	standing shots "$(mq_shots_pid)" "$MQ_LANES_DIR/shots-lane"
else
	printf '  %-8s waiting for L05 (shots.sh not on main yet)\n' shots
fi

echo "-- recent"
tail -8 "$MQ_DIR/events.log" 2>/dev/null | cut -c1-100
