#!/bin/bash
# Queues a commit. The lane is free the moment this returns.
#   tools/mq/submit.sh HEAD T001
# pull_ready.sh uses the same door for cloud work, with MQ_SUBMIT_SOURCE=cloud.
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"
mq_require_home

[ "$#" -eq 2 ] || { echo "usage: submit.sh <commit> <task>" >&2; exit 2; }
sha=$(git rev-parse --verify "$1^{commit}") || exit 1
task="$2"
source="${MQ_SUBMIT_SOURCE:-lane}"
refuse() { echo "mq: REFUSED: $*" >&2; mq_event REFUSED "$task ${sha:0:9} $*"; exit 1; }

if git merge-base --is-ancestor "$sha" "$MQ_MAIN" 2>/dev/null; then
	refuse "commit is already in main"
fi
if entry=$(mq_queued_entry "$sha"); then
	refuse "commit is already queued as $(basename "$entry")"
fi
base=$(git merge-base "$sha" "$MQ_MAIN")
files=$(git diff --name-only --diff-filter=ACMR "$base" "$sha")

# Conflict markers in the commit's own version of any text file it changed.
markers=$(git diff "$base" "$sha" --diff-filter=ACMR -- . | grep -E '^\+(<<<<<<< |>>>>>>> |=======$)' | head -3)
[ -z "$markers" ] || refuse "merge-conflict markers in the change"

# Godot gives every .gd, .gdshader and .gdshaderinc a .uid sidecar on import, and
# the sidecar is tracked. A script that lands without one makes every later import
# create an untracked file, and lane.sh then refuses the lane. Checked against the
# commit's tree, not the disk: cloud commits aren't checked out.
nouid=""
for f in $(git diff --no-renames --name-only --diff-filter=A "$base" "$sha" | grep -E '\.(gd|gdshader|gdshaderinc)$' | grep -vE '^(tools/mq/|addons/)'); do
	git cat-file -e "$sha:$f.uid" 2>/dev/null || nouid="$nouid $f"
done
[ -z "$nouid" ] || refuse "new script without its .uid file:$nouid. Run tools/mq/godot.sh --import (or open the project in Godot) so it writes <script>.uid next to each new script, then commit those .uid files with the scripts. Never write a uid by hand."

conf="$MQ_BIN/generated.conf"
[ -f tools/mq/generated.conf ] && conf=tools/mq/generated.conf
hits=$(printf '%s\n' "$files" | mq_generated_hits "$conf")
if [ -n "$hits" ]; then
	refuse "the change adds or edits built files; change the recipe instead and let levels.sh build them: $(printf '%s' "$hits" | cut -f1 | head -3 | tr '\n' ' ')"
fi

# The parse check needs the commit on disk. Cloud commits aren't, so their
# parse runs in the gate.
if [ "$source" = lane ] && [ "$(git rev-parse HEAD)" = "$sha" ]; then
	scripts=$(printf '%s\n' "$files" | grep '\.gd$' | grep -v '^tools/mq/')
	if [ -n "$scripts" ]; then
		# shellcheck disable=SC2086
		out=$("$here/parse.sh" $scripts 2>&1); rc=$?
		[ "$rc" = 125 ] && refuse "no engine for the parse check"
		[ "$rc" = 0 ] || refuse "parse check failed: $(printf '%s\n' "$out" | grep -E 'FAIL|ERROR' | head -5)"
	fi
fi

id=$(printf '%010d-%05d-%s' "$(date +%s)" "$$" "$task")
git update-ref "refs/mq/sub/$id" "$sha"
mkdir -p "$MQ_DIR/tmp" "$MQ_DIR/pending"
tmp="$MQ_DIR/tmp/$id"
{
	echo "id=$id"
	echo "task=$task"
	echo "sha=$sha"
	echo "branch=$(git symbolic-ref -q --short HEAD)"
	echo "source=$source"
	echo "submitted=$(mq_now)"
	echo "subject=$(git log -1 --format=%s "$sha")"
} > "$tmp"
mv "$tmp" "$MQ_DIR/pending/$id.entry"
[ -d "$MQ_DIR/tasks/$task" ] && kv_set "$MQ_DIR/tasks/$task/meta" status submitted
mq_event SUBMITTED "$task ${sha:0:9} $(git log -1 --format=%s "$sha" | cut -c1-70)"
echo "$id"

if ! mq_buildlane_pid >/dev/null && [ "$(mq_config MQ_SUBMIT_NO_START)" != 1 ]; then
	"$here/setup_lanes.sh" --start
fi
