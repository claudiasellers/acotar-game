#!/bin/bash
# Cloud side: read the Mac's answer to a shot request.
#
#   tools/mq/shots_fetch.sh <ID> <n> [dest] [--wait <minutes>] [--done]
#
# Unpacks shots/res-<ID>-<n> into dest (default $TMPDIR/shots/<ID>-<n>),
# prints result.txt and lists the pictures. Exit 0 answered, 3 no answer yet
# (the Mac is busy, asleep or off; nothing is lost). --wait polls every 30 s
# up to that many minutes (max 30). --done deletes your request branch and
# its answer from origin once you have what you need.
set -u
. "$(cd "$(dirname "$0")" && pwd -P)/shots_common.sh"

id="" n="" dest="" wait_min=0 done_flag=0
while [ $# -gt 0 ]; do
	case "$1" in
	--wait) wait_min="${2:-0}"; shift ;;
	--done) done_flag=1 ;;
	*) if [ -z "$id" ]; then id="$1"; elif [ -z "$n" ]; then n="$1"; else dest="$1"; fi ;;
	esac
	shift
done
key="$id-$n"
shots_valid_key "$key" || shots_die "usage: shots_fetch.sh <ID> <n> [dest] [--wait <minutes>] [--done]"
[ "$wait_min" -gt 30 ] 2>/dev/null && wait_min=30
dest="${dest:-${TMPDIR:-/tmp}/shots/$key}"
remote=origin
ref="${SHOTS_RES_PREFIX}$key"

deadline=$(($(shots_epoch) + wait_min * 60))
while ! sha=$(git ls-remote --exit-code "$remote" "$ref" 2>/dev/null | cut -f1) || [ -z "$sha" ]; do
	if [ "$(shots_epoch)" -ge "$deadline" ]; then
		if git ls-remote --exit-code "$remote" "${SHOTS_REQ_PREFIX}$key" >/dev/null 2>&1; then
			echo "no answer yet for $key (the Mac is busy, asleep or off; the request waits)"
		else
			echo "no request shots/req-$key on $remote"
		fi
		exit 3
	fi
	sleep 30
done

shots_git_retry fetch -q "$remote" "$ref" || shots_die "fetch failed"
rm -rf "$dest" && mkdir -p "$dest"
git archive FETCH_HEAD | tar -x -C "$dest" || shots_die "unpack failed"
head -40 "$dest/result.txt"
echo "--- files in $dest"
(cd "$dest" && find out -type f 2>/dev/null | sort | head -60)

if [ "$done_flag" = 1 ]; then
	git push -q "$remote" ":${SHOTS_REQ_PREFIX}$key" ":$ref" 2>/dev/null &&
		echo "deleted shots/req-$key and shots/res-$key from $remote" ||
		echo "could not delete the branches (the Mac prunes its answers after a few days anyway)"
fi
