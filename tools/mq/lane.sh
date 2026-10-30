#!/bin/bash
# Fresh branch for a task, from origin's main.
#   tools/mq/lane.sh lane2 short-name T001
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

[ "$#" -eq 3 ] || { echo "usage: lane.sh <lane> <short-name> <task>" >&2; exit 2; }
lane="$1"; name="$2"; task="$3"
wt="$MQ_LANES_DIR/$lane"
branch="$lane/$name"

[ -d "$wt" ] || { echo "mq: no worktree $wt (run setup_lanes.sh)" >&2; exit 1; }
[ -d "$MQ_DIR/tasks/$task" ] || { echo "mq: no task $task" >&2; exit 1; }
if [ -n "$(git -C "$wt" status --porcelain)" ]; then
	echo "mq: REFUSED: $lane has uncommitted work:" >&2
	git -C "$wt" status --short >&2
	exit 1
fi
mq_fetch_main
if git -C "$wt" symbolic-ref -q HEAD >/dev/null && ! git -C "$wt" merge-base --is-ancestor HEAD "$MQ_MAIN"; then
	head=$(git -C "$wt" rev-parse HEAD)
	if ! mq_queued_entry "$head" >/dev/null; then
		echo "mq: REFUSED: $lane's branch has commits that are neither in main nor queued." >&2
		exit 1
	fi
fi
git -C "$wt" checkout -q --no-track -b "$branch" "$MQ_MAIN" || exit 1
"$here/task.sh" start "$task" "$lane"
"$here/task.sh" set "$task" branch "$branch"
scratch="/tmp/$MQ_PROJECT-$lane/$task"
mkdir -p "$scratch"
# Built files for this tree, if the cache has them. A bake never blocks a lane.
( cd "$wt" && "$here/levels.sh" ensure --cached-only ) || true
mq_event LANE "$lane $task $branch"
echo "$lane on $branch   scratch: $scratch"
