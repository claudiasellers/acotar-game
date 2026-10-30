#!/bin/bash
# Cloud side: ask the Mac to render shots of your current commit.
#
#   tools/mq/shots_request.sh <ID> <n> <probes.txt | request.json>
#
# Pushes shots/req-<ID>-<n>: your HEAD plus one commit that adds the request
# as .shots/probes.txt (any probe scene, see docs/contracts/shots.md) or
# .shots/request.json (the layout-shots runner, docs/contracts/shot_request.md).
# Your own branch is not changed. Uncommitted changes are not rendered.
# Never reuse a number: resubmit with n+1. Read the answer with shots_fetch.sh.
set -u
. "$(cd "$(dirname "$0")" && pwd -P)/shots_common.sh"

[ $# -eq 3 ] || shots_die "usage: shots_request.sh <ID> <n> <probes.txt|request.json>"
key="$1-$2"
shots_valid_key "$key" || shots_die "bad request name '$key': ID is letters, digits, . _ - ; n is a number"
[ -f "$3" ] || shots_die "no such file: $3"
case "$3" in *.json) dest=.shots/request.json ;; *) dest=.shots/probes.txt ;; esac
remote=origin

if git ls-remote --exit-code "$remote" "${SHOTS_REQ_PREFIX}$key" >/dev/null 2>&1; then
	shots_die "shots/req-$key already exists; requests are never reused, use $1-$(($2 + 1))"
fi
git diff --quiet HEAD 2>/dev/null || echo "shots: note: uncommitted changes are not part of the request" >&2

idx=$(mktemp "${TMPDIR:-/tmp}/shots-req.XXXXXX")
trap 'rm -f "$idx"' EXIT
GIT_INDEX_FILE="$idx" git read-tree HEAD || shots_die "cannot read HEAD"
blob=$(git hash-object -w "$3") || exit 1
GIT_INDEX_FILE="$idx" git update-index --add --cacheinfo "100644,$blob,$dest" || exit 1
tree=$(GIT_INDEX_FILE="$idx" git write-tree) || exit 1
commit=$(git commit-tree "$tree" -p HEAD -m "shots req $key") || exit 1

shots_git_retry push -q "$remote" "$commit:${SHOTS_REQ_PREFIX}$key" || shots_die "push failed"
echo "requested shots/req-$key at ${commit:0:9} (renders $(git rev-parse --short HEAD))"
echo "answer: tools/mq/shots_fetch.sh $1 $2"
