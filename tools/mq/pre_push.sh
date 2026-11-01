#!/bin/bash
# git pre-push body, installed by `make setup` (tools/mq/install_hooks.sh).
# Only pushes to lead/ready-* branches are checked: a ready branch that adds a
# script or shader without its .uid is rejected by the queue, so stop it here.
set -u
here=$(cd "$(dirname "$0")" && pwd)
zero=0000000000000000000000000000000000000000
fail=0
while read -r lref lsha rref rsha; do
	case "$rref" in refs/heads/lead/ready-*) ;; *) continue ;; esac
	[ "$lsha" = "$zero" ] && continue
	if git rev-parse --verify -q origin/main >/dev/null; then
		base=$(git merge-base "$lsha" origin/main 2>/dev/null) || base=""
	else
		base=""
	fi
	if [ -n "$base" ]; then out=$("$here/check_uids.sh" --added-since "$base" "$lsha" 2>&1)
	else out=$("$here/check_uids.sh" "$lsha" 2>&1); fi
	rc=$?
	if [ "$rc" != 0 ]; then
		echo "pre-push: refusing ${rref#refs/heads/}: the queue would reject it for missing .uid files." >&2
		printf '%s\n' "$out" >&2
		fail=1
	fi
done
exit $fail
