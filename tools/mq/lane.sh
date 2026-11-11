#!/bin/bash
# Fresh branch for a task, from origin's main.
#   tools/mq/lane.sh lane2 short-name T001
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

# Lane worktrees come and go: cleanup.sh removes an idle one, this makes it
# again from origin/main. MQ_LANES is only the highest lane number.
make_lane() { # lane
	local lane="$1" wt="$MQ_LANES_DIR/$1" n
	n=${lane#lane}
	case "$lane:$n" in lane*:""|lane*:*[!0-9]*|[!l]*) echo "mq: bad lane name $lane" >&2; return 1 ;; esac
	[ "$n" -ge 1 ] && [ "$n" -le "$(mq_config_or MQ_LANES 4)" ] || { echo "mq: $lane is outside MQ_LANES" >&2; return 1; }
	[ -e "$wt/.git" ] && return 0
	[ -e "$wt" ] && { echo "mq: $wt exists but is not a worktree" >&2; return 1; }
	mkdir -p "$MQ_LANES_DIR"
	git worktree prune 2>/dev/null
	mq_fetch_main
	git worktree add -q --detach "$wt" "$MQ_MAIN" || return 1
	git worktree lock --reason "mq: $lane" "$wt" 2>/dev/null
	# Copy-on-write clone of the import cache, so the first run isn't a reimport.
	if [ -d "$MQ_REPO/.godot" ] && [ ! -d "$wt/.godot" ]; then
		cp -cR "$MQ_REPO/.godot" "$wt/.godot" 2>/dev/null || cp -R "$MQ_REPO/.godot" "$wt/.godot"
	fi
	mq_event LANE "$lane worktree created"
}

if [ "${1:-}" = "--make" ]; then
	[ "$#" -eq 2 ] || { echo "usage: lane.sh --make <lane>" >&2; exit 2; }
	make_lane "$2"; exit $?
fi
[ "$#" -eq 3 ] || { echo "usage: lane.sh <lane> <short-name> <task>" >&2; echo "       lane.sh --make <lane>" >&2; exit 2; }
lane="$1"; name="$2"; task="$3"
wt="$MQ_LANES_DIR/$lane"
branch="$lane/$name"

[ -d "$MQ_DIR/tasks/$task" ] || { echo "mq: no task $task" >&2; exit 1; }
make_lane "$lane" || exit 1
unmet=$("$here/task.sh" unmet "$task")
if [ -n "$unmet" ]; then
	echo "mq: REFUSED: $task waits on unmet deps: $unmet" >&2
	exit 1
fi
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
old=$(git -C "$wt" symbolic-ref -q --short HEAD)
git -C "$wt" checkout -q --no-track -b "$branch" "$MQ_MAIN" || exit 1
# The lane's last branch is finished: cleanup deletes it if it is in main.
[ -n "$old" ] && "$here/mark.sh" add local_branch "$old" 0 "lane moved on to $branch"
"$here/task.sh" start "$task" "$lane"
"$here/task.sh" set "$task" branch "$branch"
scratch="/tmp/$MQ_PROJECT-$lane/$task"
mkdir -p "$scratch"
# Built files for this tree, if the cache has them. A bake never blocks a lane.
( cd "$wt" && "$here/levels.sh" ensure --cached-only ) || true
mq_event LANE "$lane $task $branch"
echo "$lane on $branch   scratch: $scratch"
