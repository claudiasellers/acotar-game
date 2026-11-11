#!/bin/bash
# Producers say what is finished; cleanup.sh acts on these marks and nothing else.
# A mark is a small file in .git/mq/cleanup/marks/ that names a thing, why, and the
# earliest time it may go. Writing one deletes nothing.
#   mark.sh add <kind> <target> <delay-secs> <why>
#   mark.sh done <entry-file> <merged|rejected>   everything a finished entry leaves
#   mark.sh lane <laneN>                          a lane worktree to release when idle
# kinds: remote_branch local_branch dir entry lane file level
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"
MARKS="${MQ_MARKS:-$MQ_DIR/cleanup/marks}"

add() { # kind target delay why
	local f
	mkdir -p "$MARKS"
	f="$MARKS/$1-$(printf '%s' "$2" | cksum | cut -d' ' -f1).mark"
	[ -f "$f" ] && return 0   # the first mark's time stands
	printf 'kind=%s\ntarget=%s\nafter=%s\nwhy=%s\n' "$1" "$2" "$(( $(date +%s) + ${3:-0} ))" "$4" > "$f.tmp" && mv "$f.tmp" "$f"
}

lane_mark() { # laneN: only lanes above MQ_LANES_KEEP ever go
	local n="${1#lane}"
	case "$n" in ""|*[!0-9]*) return 0 ;; esac
	[ "$n" -gt "$(mq_config_or MQ_LANES_KEEP 4)" ] || return 0
	# Refreshed, not deduped: a lane that took another task must wait its grace again from the
	# latest task end, or a stale mark meets a lane that merely looks busy and is dropped.
	rm -f "$MARKS/lane-$(printf '%s' "$1" | cksum | cut -d' ' -f1).mark"
	add lane "$1" "$(mq_config_or MQ_LANE_IDLE_SECS 7200)" "lane idle after its task ended"
}

case "${1:-}" in
	add) [ "$#" -ge 5 ] || exit 2; add "$2" "$3" "$4" "$5" ;;
	lane) lane_mark "$2" ;;
	done)
		e="$2"; outcome="${3:-merged}"
		id=$(basename "$e" .entry); task=$(kv_get "$e" task); br=$(kv_get "$e" branch)
		lane=$(kv_get "$MQ_DIR/tasks/$task/meta" lane)
		add entry "$id" $(( $(mq_config_or MQ_CLEANUP_LOG_DAYS 14) * 86400 )) "$outcome entry and its submission ref"
		case "$br" in
			lane[0-9]*/*)
				add local_branch "$br" 0 "$task $outcome"
				add remote_branch "$br" "$(mq_config_or MQ_CLEANUP_MIN_AGE 21600)" "$task $outcome" ;;
		esac
		[ "$outcome" = merged ] && [ -n "$lane" ] && add dir "/tmp/$MQ_PROJECT-$lane/$task" 0 "$task merged: screenshots and scratch"
		[ -n "$lane" ] && lane_mark "$lane"
		exit 0 ;;
	*) echo "usage: mark.sh add|done|lane" >&2; exit 2 ;;
esac
