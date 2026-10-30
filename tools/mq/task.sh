#!/bin/bash
# The task list. Each task is a folder under .git/mq/tasks/<id>/ with a key=value
# `meta` and the owner's words in `request`.
#   task.sh add "<request>"       prints the next id
#   task.sh start <id> <lane>     mark it being worked on
#   task.sh set <id> <key> <val>  status, deps, branch...
#   task.sh next-lane             prints a free lane, or nothing
#   task.sh list                  open tasks; `list all` for everything
set -u
. "$(dirname "$0")/common.sh"

TASKS="$MQ_DIR/tasks"
mkdir -p "$TASKS"

# Highest T-number in the task folder or main's history.
highest() {
	{
		ls "$TASKS" 2>/dev/null
		git log "$MQ_MAIN" --format=%s 2>/dev/null | sed -n 's/^\(T[0-9][0-9]*\).*/\1/p'
	} | sed -n 's/^T0*\([0-9][0-9]*\)$/\1/p' | sort -n | tail -1
}

case "${1:-}" in
	add)
		[ "$#" -ge 2 ] || { echo "usage: task.sh add \"<request>\"" >&2; exit 2; }
		mq_short_lock task || { echo "mq: task lock busy" >&2; exit 1; }
		n=$(highest); id=$(printf 'T%03d' $(( ${n:-0} + 1 )))
		mkdir -p "$TASKS/$id"
		printf '%s\n' "$2" > "$TASKS/$id/request"
		printf 'id=%s\nstatus=open\ncreated=%s\n' "$id" "$(mq_now)" > "$TASKS/$id/meta"
		mq_lock_release "$MQ_DIR/locks/task"
		mq_event TASK "$id $(printf '%s' "$2" | head -1 | cut -c1-80)"
		echo "$id" ;;
	start)
		[ -d "$TASKS/${2:-}" ] || { echo "mq: no task ${2:-}" >&2; exit 1; }
		kv_set "$TASKS/$2/meta" status active
		kv_set "$TASKS/$2/meta" lane "$3" ;;
	set)
		[ -d "$TASKS/${2:-}" ] || { echo "mq: no task ${2:-}" >&2; exit 1; }
		kv_set "$TASKS/$2/meta" "$3" "$4" ;;
	next-lane)
		busy=" "
		for m in "$TASKS"/*/meta; do
			[ -f "$m" ] || continue
			[ "$(kv_get "$m" status)" = active ] && busy="$busy$(kv_get "$m" lane) "
		done
		i=1; n=$(mq_config_or MQ_LANES 4)
		while [ "$i" -le "$n" ]; do
			case "$busy" in *" lane$i "*) ;; *) echo "lane$i"; exit 0 ;; esac
			i=$((i + 1))
		done ;;
	list)
		for m in "$TASKS"/*/meta; do
			[ -f "$m" ] || continue
			s=$(kv_get "$m" status)
			if [ "${2:-}" != all ]; then
				case "$s" in merged|dropped) continue ;; esac
			fi
			id=$(kv_get "$m" id)
			printf '%-6s %-10s %-7s %s\n' "$id" "$s" "$(kv_get "$m" lane)" \
				"$(head -1 "$TASKS/$id/request" | cut -c1-70)"
		done ;;
	*) echo "usage: task.sh add|start|set|next-lane|list" >&2; exit 2 ;;
esac
