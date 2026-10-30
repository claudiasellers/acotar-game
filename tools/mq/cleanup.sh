#!/bin/bash
# Frees disk, only while the queue is idle. Its own loop, separate from the
# build lane, so it can never hold up a merge.
#   cleanup.sh            one pass
#   cleanup.sh --dry-run  say what a pass would do
#   cleanup.sh --loop     a pass every MQ_CLEANUP_SECS (default an hour)
# Hard rules: a branch goes only when its content is already in main, proved by
# `git merge-tree --write-tree` giving main's own tree. Never `worktree remove
# --force`. Never touches untracked files: it removes no worktrees at all, and
# only deletes files it owns under .git/mq, .git/levelcache and /tmp/<project>-*.
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

REMOTE=$(mq_config MQ_REMOTE); : "${REMOTE:=origin}"
DRY=0
# A branch this new may be a cloud session that has just started from main:
# it would pass the tree test with nothing on it yet.
MIN_AGE=$(mq_config_or MQ_CLEANUP_MIN_AGE 21600)
KEEP_LOG_DAYS=$(mq_config_or MQ_CLEANUP_LOG_DAYS 14)

say() { if [ "$DRY" = 1 ]; then echo "would $*"; else mq_event CLEANUP "$*"; fi; }

# True when merging ref into origin/main would change nothing.
content_in_main() {
	local t
	t=$(git merge-tree --write-tree "$REMOTE/main" "$1" 2>/dev/null) || return 1
	[ "$(printf '%s\n' "$t" | head -1)" = "$(git rev-parse "$REMOTE/main^{tree}")" ]
}

old_enough() { [ $(( $(date +%s) - $(git log -1 --format=%ct "$1") )) -ge "$MIN_AGE" ]; }

in_use() { # sha: queued, or a live ready signal
	mq_queued_entry "$1" >/dev/null && return 0
	grep -lqs "^sha=$1\$" "$MQ_DIR"/ready/signals/* 2>/dev/null
}

remote_branches() {
	local b sha
	# MQ_PUSH=0 means nothing on this machine writes to the remote.
	[ "$(mq_config_or MQ_PUSH 1)" = 1 ] || return 0
	mq_timeout 120 git fetch -q --prune "$REMOTE" || return 0
	git for-each-ref --format='%(refname:strip=3) %(objectname)' "refs/remotes/$REMOTE/lane/*" "refs/remotes/$REMOTE/lane[0-9]*/*" |
	while read -r b sha; do
		mq_idle || return 0
		content_in_main "$REMOTE/$b" || continue
		old_enough "$sha" || continue
		in_use "$sha" && continue
		say "delete remote branch $b ${sha:0:9}"
		[ "$DRY" = 1 ] && continue
		# The lease stops this if the branch moved since we checked it.
		mq_timeout 120 git push -q --force-with-lease="refs/heads/$b:$sha" "$REMOTE" ":refs/heads/$b"
	done
}

local_branches() {
	local b sha
	git for-each-ref --format='%(refname:strip=2) %(objectname) %(worktreepath)' 'refs/heads/lane/*' 'refs/heads/lane[0-9]*/*' |
	while read -r b sha path; do
		[ -n "${path:-}" ] && continue
		content_in_main "$b" || continue
		in_use "$sha" && continue
		say "delete local branch $b ${sha:0:9}"
		[ "$DRY" = 1 ] || git branch -q -D "$b"
	done
}

old_state() {
	local f id
	# Submission refs and records of finished work, once old.
	for f in "$MQ_DIR"/done/merged/*.entry "$MQ_DIR"/done/rejected/*.entry; do
		[ -f "$f" ] || continue
		[ "$(mq_age "$f")" -ge $((KEEP_LOG_DAYS * 86400)) ] || continue
		id=$(basename "$f" .entry)
		say "forget finished entry $id"
		[ "$DRY" = 1 ] && continue
		git update-ref -d "refs/mq/sub/$id" 2>/dev/null
		rm -f "$f" "${f%.entry}.log"
	done
	for f in "$MQ_DIR"/logs/*.log "$MQ_DIR"/baseline/*; do
		[ -f "$f" ] || continue
		[ "$(mq_age "$f")" -ge $((KEEP_LOG_DAYS * 86400)) ] || continue
		say "delete old log $(basename "$f")"
		[ "$DRY" = 1 ] || rm -f "$f"
	done
	# Keep logs from growing without end.
	f="$MQ_DIR/buildlane.log"
	if [ "$DRY" = 0 ] && [ -f "$f" ] && [ "$(stat -f %z "$f")" -gt 20000000 ]; then
		tail -c 2000000 "$f" > "$f.tmp" && cat "$f.tmp" > "$f" && rm -f "$f.tmp"
	fi
}

# Screenshots and scratch for tasks that have merged or been dropped.
task_scratch() {
	local d task s
	for d in /tmp/"$MQ_PROJECT"-lane*/T*; do
		[ -d "$d" ] || continue
		task=$(basename "$d")
		s=$(kv_get "$MQ_DIR/tasks/$task/meta" status)
		case "$s" in merged|dropped) ;; *) continue ;; esac
		say "delete scratch $d"
		[ "$DRY" = 1 ] || rm -rf "$d"
	done
}

# The newest three builds of each output stay.
old_builds() {
	local n d
	for n in "$MQ_LEVELCACHE"/*; do
		[ -d "$n" ] || continue
		ls -1dt "$n"/* 2>/dev/null | grep -v '\.lock$' | tail -n +4 | while read -r d; do
			say "delete old build $(basename "$n")/$(basename "$d")"
			[ "$DRY" = 1 ] || rm -rf "$d"
		done
	done
}

pass() {
	mq_is_home || return 0
	mq_idle || return 0
	remote_branches
	local_branches
	mq_idle || return 0
	old_state; task_scratch; old_builds
}

case "${1:-}" in
	--dry-run) DRY=1; pass ;;
	--loop)
		mq_is_home || exit 0
		[ "$(mq_config MQ_CLEANUP_OFF)" = 1 ] && exit 0
		echo $$ > "$MQ_DIR/cleanup.pid"
		trap 'rm -f "$MQ_DIR/cleanup.pid"; exit 0' TERM INT
		self_mtime=$(stat -f %m "$0")
		every=$(mq_config_or MQ_CLEANUP_SECS 3600)
		while :; do
			pass
			i=0
			while [ "$i" -lt "$every" ]; do
				sleep 10 & wait $!
				i=$((i + 10))
			done
			# A merged change to this script takes effect here.
			[ "$(stat -f %m "$0")" = "$self_mtime" ] || exec /bin/bash "$0" --loop
		done ;;
	"") pass ;;
	*) echo "usage: cleanup.sh [--dry-run|--loop]" >&2; exit 2 ;;
esac
