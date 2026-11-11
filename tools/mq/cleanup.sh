#!/bin/bash
# Frees disk. It acts only on marks: producers (the build lane when an entry
# merges or is rejected, pull_ready.sh when it answers, lane.sh when a lane moves
# on) write a small file in .git/mq/cleanup/marks/ naming a finished thing and the
# earliest time it may go (tools/mq/mark.sh). Nothing here scans and guesses.
#   cleanup.sh             act on the marks that are due
#   cleanup.sh --dry-run   say what a pass would do
#   cleanup.sh --backfill  one-time: mark what old runs left behind, then act
#                          (with --dry-run: only list)
#   cleanup.sh --loop      a pass every MQ_CLEANUP_SECS (default 5 minutes)
# Hard rules: a branch goes only when its content is already in main (proved by
# `git merge-tree --write-tree` giving main's own tree) or the cloud was answered
# with a merged/ or rejected/ tag; never when queued or newer than its mark's time.
# Never `worktree remove --force`, never untracked files. Every deletion is a
# CLEANUP event. A mark that is refused is dropped, with the reason logged.
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

REMOTE=$(mq_config MQ_REMOTE); : "${REMOTE:=origin}"
DRY=0
# A branch this new may be a cloud session that has just started from main:
# it would pass the tree test with nothing on it yet.
MIN_AGE=$(mq_config_or MQ_CLEANUP_MIN_AGE 21600)
KEEP_LOG_DAYS=$(mq_config_or MQ_CLEANUP_LOG_DAYS 14)
# Lanes above LANE_KEEP go once idle this long: removing one throws away its
# .godot import cache, which the next task there rebuilds, so the low lanes stay.
LANE_IDLE=$(mq_config_or MQ_LANE_IDLE_SECS 7200)
LANE_KEEP=$(mq_config_or MQ_LANES_KEEP 4)   # lanes 1..N are never removed
SHOTS_KEEP=$(mq_config_or MQ_SHOTS_KEEP_SECS 259200)

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
	local f
	for f in $(grep -ls "^sha=$1\$" "$MQ_DIR"/ready/signals/* 2>/dev/null); do
		[ "$(kv_get "$f" state)" = done ] || return 0   # answered ones are not live
	done
	return 1
}

MARKS="$MQ_DIR/cleanup/marks"
ANSWERS=""   # refs/tags/merged|rejected/* on the remote, read once a pass

load_answers() {
	[ "$(mq_config_or MQ_PUSH 1)" = 1 ] || return 0
	mq_timeout 120 git fetch -q --prune "$REMOTE" || return 1
	ANSWERS=$(mq_timeout 120 git ls-remote "$REMOTE" 'refs/tags/merged/*' 'refs/tags/rejected/*' 2>/dev/null | awk '{print $2}' | grep -v '\^{}$')
	return 0
}

# lead/ready-K is answered when merged/K or rejected/K exists; shots/req-K and
# shots/res-K when the shots listener recorded K as done.
answered() { # branch
	local k
	case "$1" in
		lead/ready-*) k=${1#lead/ready-}
			printf '%s\n' "$ANSWERS" | grep -qx -e "refs/tags/merged/$k" -e "refs/tags/rejected/$k" ;;
		shots/req-*|shots/res-*) k=${1#shots/re?-}; [ -f "$MQ_DIR/shots/done/$k" ] ;;
		*) return 1 ;;
	esac
}

drop() { rm -f "$1"; }

do_remote_branch() { # mark-file branch -> log and drop
	local f="$1" b="$2" sha
	[ "$(mq_config_or MQ_PUSH 1)" = 1 ] || return 1   # MQ_PUSH=0: nothing writes the remote; keep the mark
	sha=$(git rev-parse -q --verify "refs/remotes/$REMOTE/$b" 2>/dev/null) || { drop "$f"; return 0; }
	if [ "$b" = main ] || { ! answered "$b" && ! content_in_main "refs/remotes/$REMOTE/$b"; }; then
		say "keep remote branch $b: not in main and not answered"; drop "$f"; return 0
	fi
	if in_use "$sha"; then say "keep remote branch $b: its commit is queued"; drop "$f"; return 0; fi
	say "delete remote branch $b ${sha:0:9} ($(kv_get "$f" why))"
	[ "$DRY" = 1 ] && return 0
	# The lease stops this if the branch moved since we checked it.
	mq_timeout 120 git push -q --force-with-lease="refs/heads/$b:$sha" "$REMOTE" ":refs/heads/$b" && git update-ref -d "refs/remotes/$REMOTE/$b"
	drop "$f"
}

do_local_branch() {
	local f="$1" b="$2" sha
	sha=$(git rev-parse -q --verify "refs/heads/$b" 2>/dev/null) || { drop "$f"; return 0; }
	if [ -n "$(git for-each-ref --format='%(worktreepath)' "refs/heads/$b")" ]; then return 0; fi  # still checked out: try later
	if ! content_in_main "$b"; then say "keep local branch $b: not in main"; drop "$f"; return 0; fi
	if in_use "$sha"; then say "keep local branch $b: its commit is queued"; drop "$f"; return 0; fi
	say "delete local branch $b ${sha:0:9} ($(kv_get "$f" why))"
	[ "$DRY" = 1 ] || { git branch -q -D "$b"; drop "$f"; }
}

do_dir() { # only scratch under /tmp/<project>-*
	local f="$1" d="$2"
	case "$d" in /tmp/"$MQ_PROJECT"-*/T*) ;; *) say "keep $d: not a scratch directory"; drop "$f"; return 0 ;; esac
	if [ -d "$d" ]; then
		say "delete scratch $d"
		[ "$DRY" = 1 ] && return 0
		rm -rf "$d"
	fi
	drop "$f"
}

do_entry() {
	local f="$1" id="$2" e
	e="$MQ_DIR/done/merged/$id.entry"; [ -f "$e" ] || e="$MQ_DIR/done/rejected/$id.entry"
	if [ -f "$e" ]; then
		say "forget finished entry $id"
		[ "$DRY" = 1 ] && return 0
		git update-ref -d "refs/mq/sub/$id" 2>/dev/null
		rm -f "$e" "${e%.entry}.log"
	fi
	drop "$f"
}

# A lane above LANE_KEEP, released only if everything says it is finished.
lane_blocker() { # lane worktree: why it must stay, empty when it may go
	local lane="$1" wt="$2" m s head gd newest mt
	newest=0
	for m in "$MQ_DIR"/tasks/*/meta; do
		[ -f "$m" ] || continue
		[ "$(kv_get "$m" lane)" = "$lane" ] || continue
		s=$(kv_get "$m" status)
		case "$s" in merged|dropped) ;; *) echo "task $(kv_get "$m" id) is $s"; return ;; esac
		mt=$(stat -f %m "$m"); [ "$mt" -gt "$newest" ] && newest=$mt
	done
	if [ -n "$(git -C "$wt" status --porcelain 2>/dev/null)" ]; then echo "uncommitted changes"; return; fi
	head=$(git -C "$wt" rev-parse HEAD 2>/dev/null) || { echo "unreadable"; return; }
	if ! git merge-base --is-ancestor "$head" "$MQ_MAIN" 2>/dev/null && ! content_in_main "$head"; then
		echo "commits ${head:0:9} not in main"; return
	fi
	in_use "$head" && { echo "commits ${head:0:9} still queued"; return; }
	gd=$(git -C "$wt" rev-parse --absolute-git-dir)
	for m in "$gd/HEAD" "$gd/logs/HEAD"; do
		[ -e "$m" ] || continue
		mt=$(stat -f %m "$m"); [ "$mt" -gt "$newest" ] && newest=$mt
	done
	[ $(( $(date +%s) - newest )) -ge "$LANE_IDLE" ] || { echo "busy again"; return; }
	if lsof -a -d cwd -Fn 2>/dev/null | grep -q "^n$wt\(/.*\)\{0,1\}$"; then echo "a process is running in it"; return; fi
}

do_lane() {
	local f="$1" lane="$2" wt why kb n
	wt="$MQ_LANES_DIR/$lane"; n=${lane#lane}
	case "$n" in ""|*[!0-9]*) drop "$f"; return 0 ;; esac
	if [ "$n" -le "$LANE_KEEP" ] || [ ! -e "$wt/.git" ]; then drop "$f"; return 0; fi
	why=$(lane_blocker "$lane" "$wt")
	if [ -n "$why" ]; then
		# Not logged as a deletion; the next task to end there marks the lane again. A lane
		# that only looks busy keeps its mark, renewed, so it is looked at again later.
		[ "$why" = "busy again" ] && [ "$DRY" = 0 ] && MQ_MARKS="$MARKS" "$here/mark.sh" lane "$lane"
		say "keep lane worktree $lane: $why"
		[ "$why" = "busy again" ] || drop "$f"; return 0
	fi
	kb=$(du -sk "$wt" 2>/dev/null | cut -f1)
	say "remove lane worktree $lane (idle $((LANE_IDLE / 60)) min, merged, clean; frees $(( ${kb:-0} / 1024 )) MB)"
	[ "$DRY" = 1 ] && return 0
	git worktree unlock "$wt" 2>/dev/null
	if git worktree remove "$wt" 2>/dev/null; then
		git worktree prune 2>/dev/null
	else
		git worktree lock --reason "mq: $lane" "$wt" 2>/dev/null
		say "keep lane worktree $lane: git worktree remove refused"
	fi
	drop "$f"
}

# A plain file a producer marked: an old log or a gate baseline, only inside .git/mq.
# The baseline for main itself is never taken: the next gate needs it.
do_file() {
	local f="$1" t="$2" base
	case "$t" in
		"$MQ_DIR"/logs/*|"$MQ_DIR"/idlegate/logs/*|"$MQ_DIR"/baseline/*) ;;
		*) say "keep $t: not a log or baseline"; drop "$f"; return 0 ;;
	esac
	case "$t" in *..*) drop "$f"; return 0 ;; esac
	case "$t" in
		"$MQ_DIR"/baseline/*)
			base=$(basename "$t")
			if [ "$base" = "$(git rev-parse -q --verify "$MQ_MAIN" 2>/dev/null)" ]; then
				say "keep baseline ${base:0:9}: it is main's"; drop "$f"; return 0
			fi ;;
	esac
	if [ -f "$t" ]; then
		say "delete $(basename "$t") ($(kv_get "$f" why))"
		[ "$DRY" = 1 ] && return 0
		rm -f "$t"
	fi
	drop "$f"
}

# A superseded level build: target is <name>/<fingerprint> in the level cache. Never one that
# any worktree's stamp still names (the terrain bake in use, main's, a lane's), one being
# built, or the newest for its name.
do_level() {
	local f="$1" t="$2" name fp d s newest
	name=${t%%/*}; fp=${t#*/}
	case "$name$fp" in ""|*/*|*..*|.*) drop "$f"; return 0 ;; esac
	d="$MQ_LEVELCACHE/$name/$fp"
	[ -d "$d" ] || { drop "$f"; return 0; }
	for s in "$MQ_GIT/mq-levels/$name" "$MQ_GIT"/worktrees/*/mq-levels/"$name"; do
		if [ -f "$s" ] && [ "$(cat "$s" 2>/dev/null)" = "$fp" ]; then say "keep level $name $fp: a worktree still uses it"; drop "$f"; return 0; fi
	done
	if [ -d "$d.lock" ]; then return 0; fi
	newest=$(ls -t "$MQ_LEVELCACHE/$name" 2>/dev/null | grep -vE '\.(lock|tmp)|^\.' | head -1)
	if [ "$newest" = "$fp" ]; then say "keep level $name $fp: newest build"; drop "$f"; return 0; fi
	say "delete level build $name $fp ($(kv_get "$f" why))"
	[ "$DRY" = 1 ] && return 0
	rm -rf "$d"; drop "$f"
}

process_marks() {
	local f kind target after now needs_net=0
	[ -d "$MARKS" ] || return 0
	now=$(date +%s)
	for f in "$MARKS"/*.mark; do [ -f "$f" ] && [ "$(kv_get "$f" kind)" = remote_branch ] && needs_net=1; done
	[ "$needs_net" = 1 ] && { load_answers || return 0; }
	for f in "$MARKS"/*.mark; do
		[ -f "$f" ] || continue
		after=$(kv_get "$f" after)
		[ "$now" -ge "${after:-0}" ] || continue   # retention: not yet
		kind=$(kv_get "$f" kind); target=$(kv_get "$f" target)
		case "$kind" in
			remote_branch) do_remote_branch "$f" "$target" ;;
			local_branch) do_local_branch "$f" "$target" ;;
			dir) do_dir "$f" "$target" ;;
			entry) do_entry "$f" "$target" ;;
			lane) do_lane "$f" "$target" ;;
			file) do_file "$f" "$target" ;;
			level) do_level "$f" "$target" ;;
			*) drop "$f" ;;
		esac
	done
}

# --- one-time backfill: mark what runs before marks left behind ---------------
# Same safety as everything else: only the marks' own checks decide a deletion;
# this just decides what to mark. Shots branches are marked only when answered
# (a req with its res, or a lone res) and older than SHOTS_KEEP.
backfill() {
	local n=0 b sha ct now ref
	now=$(date +%s)
	mq_timeout 120 git fetch -q --prune "$REMOTE" || return 0
	[ -n "$ANSWERS" ] || load_answers
	mkmark() { MQ_MARKS="$MARKS" "$here/mark.sh" add "$1" "$2" "$3" "$4"; }
	while read -r b sha; do
		ct=$(git log -1 --format=%ct "$sha" 2>/dev/null || echo "$now")
		case "$b" in
			lead/ready-*) mkmark remote_branch "$b" $(( ct + SHOTS_KEEP - now )) "backfill: old ready branch" ;;
			lane/*|lane[0-9]*/*) mkmark remote_branch "$b" $(( ct + MIN_AGE - now )) "backfill: old lane branch" ;;
			shots/re[qs]-*)
				# Answered only: the listener's own record, never a guess from the name.
				answered "$b" && mkmark remote_branch "$b" $(( ct + SHOTS_KEEP - now )) "backfill: answered shots branch" ;;
		esac
	done < <(git for-each-ref --format='%(refname:strip=3) %(objectname)' "refs/remotes/$REMOTE/lead/*" "refs/remotes/$REMOTE/lane/*" "refs/remotes/$REMOTE/lane[0-9]*/*" "refs/remotes/$REMOTE/shots/*")
	git for-each-ref --format='%(refname:strip=2)' 'refs/heads/lane/*' 'refs/heads/lane[0-9]*/*' | while read -r b; do
		mkmark local_branch "$b" 0 "backfill: old local lane branch"
	done
	for ref in "$MQ_DIR"/done/merged/*.entry "$MQ_DIR"/done/rejected/*.entry; do
		[ -f "$ref" ] || continue
		mkmark entry "$(basename "$ref" .entry)" $(( KEEP_LOG_DAYS * 86400 - $(mq_age "$ref") )) "backfill: finished entry"
	done
	for ref in /tmp/"$MQ_PROJECT"-lane*/T*; do
		[ -d "$ref" ] || continue
		case "$(kv_get "$MQ_DIR/tasks/$(basename "$ref")/meta" status)" in merged|dropped) mkmark dir "$ref" 0 "backfill: merged task scratch" ;; esac
	done
}

# Idle clean lanes above LANE_KEEP that no producer marked (their task merged before marks
# existed, or the mark was dropped) get one. Dirty or active lanes are left alone, unlogged.
mark_idle_lanes() {
	local wt lane n why
	for wt in "$MQ_LANES_DIR"/lane[0-9]*; do
		[ -e "$wt/.git" ] || continue
		lane=$(basename "$wt"); n=${lane#lane}
		case "$n" in ""|*[!0-9]*) continue ;; esac
		[ "$n" -gt "$LANE_KEEP" ] || continue
		[ -f "$MARKS/lane-$(printf '%s' "$lane" | cksum | cut -d' ' -f1).mark" ] && continue
		why=$(lane_blocker "$lane" "$wt")
		case "$why" in ""|"busy again") [ "$DRY" = 1 ] || MQ_MARKS="$MARKS" "$here/mark.sh" lane "$lane" ;; esac
	done
}

pass() {
	mq_is_home || return 0
	mark_idle_lanes
	process_marks
}

# Logs and level builds past retention: rotation, not a scan for work to undo.
rotate() {
	local f="$MQ_DIR/buildlane.log"
	if [ "$DRY" = 0 ] && [ -f "$f" ] && [ "$(stat -f %z "$f")" -gt 20000000 ]; then
		tail -c 2000000 "$f" > "$f.tmp" && cat "$f.tmp" > "$f" && rm -f "$f.tmp"
	fi
}

case "${1:-}" in
	--dry-run) DRY=1; MARKS=$(mktemp -d); cp "$MQ_DIR"/cleanup/marks/*.mark "$MARKS/" 2>/dev/null
		[ "${2:-}" = --backfill ] && backfill; pass; rm -rf "$MARKS" ;;
	--backfill) [ "${2:-}" = --dry-run ] && { DRY=1; MARKS=$(mktemp -d); }; backfill; pass; [ "$DRY" = 1 ] && rm -rf "$MARKS" ;;
	--loop)
		mq_is_home || exit 0
		[ "$(mq_config MQ_CLEANUP_OFF)" = 1 ] && exit 0
		echo $$ > "$MQ_DIR/cleanup.pid"
		trap 'rm -f "$MQ_DIR/cleanup.pid"; exit 0' TERM INT
		self_mtime=$(stat -f %m "$0")
		every=$(mq_config_or MQ_CLEANUP_SECS 300)
		while :; do
			pass; rotate
			i=0
			while [ "$i" -lt "$every" ]; do
				sleep 10 & wait $!
				i=$((i + 10))
			done
			# A merged change to this script takes effect here.
			[ "$(stat -f %m "$0")" = "$self_mtime" ] || exec /bin/bash "$0" --loop
		done ;;
	"") pass ;;
	*) echo "usage: cleanup.sh [--dry-run [--backfill]|--backfill [--dry-run]|--loop]" >&2; exit 2 ;;
esac
