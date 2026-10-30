#!/bin/bash
# Cloud sessions can't reach this machine, so git carries the messages. Picks up
# ready signals from origin, queues them, and answers with result tags.
# Signals: lead/ready-<ID>-<n> branches (the main form) or ready/<ID>-<n> tags.
# Answers: tags merged/<ID>-<n> and rejected/<ID>-<n> on the same commit.
# Safe to run by hand any number of times. Pushes only result tags, never moves
# or deletes anything a cloud session pushed.
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"
mq_require_home

REMOTE=$(mq_config MQ_REMOTE); : "${REMOTE:=origin}"
NET=$(mq_config_or MQ_FETCH_TIMEOUT 120)
SIG="$MQ_DIR/ready/signals"
mkdir -p "$SIG"
mq_short_lock ready || exit 0
trap 'mq_lock_release "$MQ_DIR/locks/ready"' EXIT

remote=$(mq_timeout "$NET" git ls-remote "$REMOTE" 'refs/tags/ready/*' 'refs/tags/merged/*' 'refs/tags/rejected/*' 'refs/heads/lead/ready-*') || {
	echo "pull_ready: ls-remote failed; will retry" >&2; exit 0; }

has_result() { printf '%s\n' "$remote" | grep -qE "refs/tags/(merged|rejected)/$1(\^\{\})?\$"; }

# The commit a name points at; for an annotated tag, the peeled line wins.
sha_of() {
	local p
	p=$(printf '%s\n' "$remote" | awk -v r="$1^{}" '$2==r {print $1}')
	[ -n "$p" ] || p=$(printf '%s\n' "$remote" | awk -v r="$1" '$2==r {print $1}')
	echo "$p"
}

take_signal() { # ref key
	local ref="$1" key="$2" sha sigf task out id entry
	sha=$(sha_of "$ref"); sigf="$SIG/$key"; task=${key%-*}
	if has_result "$key"; then
		[ -f "$sigf" ] && kv_set "$sigf" state done
		return
	fi
	if [ -f "$sigf" ]; then
		if [ "$(kv_get "$sigf" sha)" != "$sha" ] && [ -z "$(kv_get "$sigf" moved)" ]; then
			kv_set "$sigf" moved 1
			mq_event READY "$key moved after it was first seen; ignored"
		fi
		return
	fi
	if ! mq_timeout "$NET" git fetch -q --no-tags "$REMOTE" "+$ref:refs/mq/ready/$key"; then
		echo "pull_ready: fetch of $key failed; will retry" >&2; return
	fi
	[ "$(git rev-parse "refs/mq/ready/$key^{commit}")" = "$sha" ] || return
	state=queued; id=""; reason=""
	if git merge-base --is-ancestor "$sha" "$MQ_MAIN"; then
		:
	elif entry=$(mq_queued_entry "$sha"); then
		id=$(basename "$entry" .entry)
	else
		if out=$(MQ_SUBMIT_SOURCE=cloud "$here/submit.sh" "$sha" "$task" 2>&1); then
			id=$(printf '%s\n' "$out" | head -1)
		else
			state=refused; reason=$(printf '%s\n' "$out" | grep REFUSED | head -1 | sed 's/^mq: REFUSED: //')
		fi
	fi
	# Written only now: an interrupted run sees nothing and tries again.
	{
		echo "key=$key"; echo "ref=$ref"; echo "sha=$sha"; echo "state=$state"
		echo "entry=$id"; echo "reason=$reason"
	} > "$sigf.tmp"
	mv "$sigf.tmp" "$sigf"
	mq_event READY "$key ${sha:0:9} $state"
}

push_result() { # sigf tagname message
	local sigf="$1" tag="$2" msg="$3" sha
	sha=$(kv_get "$sigf" sha)
	[ "$(mq_config_or MQ_PUSH 1)" = 1 ] || return 0
	git rev-parse -q --verify "refs/tags/$tag" >/dev/null || git tag -a -m "$msg" "$tag" "$sha" || return 0
	if mq_timeout "$NET" git push -q "$REMOTE" "refs/tags/$tag"; then
		kv_set "$sigf" state done
		mq_event RESULT "$tag"
	elif [ -z "$(kv_get "$sigf" pushfail)" ]; then
		# Never undoes a merge. Logged once, retried on the next pass.
		kv_set "$sigf" pushfail 1
		mq_event PUSHFAIL "$tag; retrying"
	fi
}

answer() { # sigf
	local f="$1" key sha st entry msg
	st=$(kv_get "$f" state)
	key=$(kv_get "$f" key); sha=$(kv_get "$f" sha); entry=$(kv_get "$f" entry)
	case "$st" in
		done) return ;;
		refused)
			push_result "$f" "rejected/$key" "Refused before queueing: $(kv_get "$f" reason)
Fix it and push ready-$key with the next number."
			return ;;
	esac
	if git rev-parse -q --verify "$REMOTE/main" >/dev/null && git merge-base --is-ancestor "$sha" "$REMOTE/main"; then
		push_result "$f" "merged/$key" "In $REMOTE/main."
	elif [ -n "$entry" ] && [ -f "$MQ_DIR/done/rejected/$entry.entry" ]; then
		msg="$(kv_get "$MQ_DIR/done/rejected/$entry.entry" reason)
Merge origin/main, fix it, and push the next number; tags are never reused."
		if [ -f "$MQ_DIR/done/rejected/$entry.log" ]; then
			msg="$msg

End of the failing test's log:
$(tail -30 "$MQ_DIR/done/rejected/$entry.log")"
		fi
		push_result "$f" "rejected/$key" "$msg"
	fi
}

KEY_RE='^[A-Za-z0-9_.]+(-[A-Za-z0-9_.]+)*-[0-9]+$'
for ref in $(printf '%s\n' "$remote" | awk '{print $2}' | grep -E '^refs/(tags/ready/|heads/lead/ready-)' | grep -v '\^{}$' | sort -u); do
	key=${ref#refs/tags/ready/}; key=${key#refs/heads/lead/ready-}
	if ! printf '%s\n' "$key" | grep -qE "$KEY_RE"; then continue; fi
	take_signal "$ref" "$key"
done

mq_timeout "$NET" git fetch -q "$REMOTE" main:"refs/remotes/$REMOTE/main" 2>/dev/null
for f in "$SIG"/*; do
	[ -f "$f" ] && answer "$f"
done
exit 0
