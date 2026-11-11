#!/bin/bash
# The cheap checks the queue would otherwise reject a change for, runnable by
# anyone, including cloud sessions that can't run submit.sh. Run before pushing a
# lead/ready-* branch (or any time):
#   tools/mq/precheck.sh [commit]            everything below
#   tools/mq/precheck.sh --builders [commit] only the builder-in-generated.conf check
# Checks the commit against origin/main (default HEAD):
#   - conflict markers in the change
#   - a new .gd/.gdshader without its .uid
#   - built files (_generated/, generated.conf outputs) in the change
#   - every tools/generators/*.gd has a recipe line in tools/mq/generated.conf
#   - when the commit is checked out: levels.sh check (outputs ignored, world tests marked)
#   - when an engine is found: the parse check on changed scripts (else skipped)
# Reads the commit's tree, so it needs no home-machine setup. Exit 0 clean, 1 refused.
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"
builders_only=0
[ "${1:-}" = "--builders" ] && { builders_only=1; shift; }
sha=$(git rev-parse --verify "${1:-HEAD}^{commit}") || exit 2
fail=0
bad() { echo "precheck: $*" >&2; fail=1; }

# Same text levels.sh prints, so there is one place to fix it.
help=$(sed -n "s/^RECIPE_HELP='\(.*\)'$/\1/p" "$here/levels.sh")
conf=$(git show "$sha:tools/mq/generated.conf" 2>/dev/null)
for g in $(git ls-tree -r --name-only "$sha" -- tools/generators/ | grep '\.gd$'); do
	printf '%s\n' "$conf" | grep -q "$g" || bad "builder $g is not in generated.conf. $help"
done
[ "$builders_only" = 1 ] && exit $fail

if git rev-parse --verify -q origin/main >/dev/null; then base=$(git merge-base "$sha" origin/main); else base=""; fi
if [ -n "$base" ]; then
	files=$(git diff --name-only --diff-filter=ACMR "$base" "$sha")
	markers=$(git diff "$base" "$sha" --diff-filter=ACMR -- . | grep -E '^\+(<<<<<<< |>>>>>>> |=======$)' | head -3)
	[ -z "$markers" ] || bad "merge-conflict markers in the change"
	nouid=$("$here/check_uids.sh" --added-since "$base" "$sha" 2>/dev/null | sed 's/^missing \.uid: //')
	[ -z "$nouid" ] || bad "missing .uid for: $(printf '%s' "$nouid" | tr '\n' ' '). Run tools/mq/godot.sh --import so Godot writes them next to the scripts, and commit them."
	tmpconf=$(mktemp); printf '%s\n' "$conf" > "$tmpconf"
	hits=$(printf '%s\n' "$files" | mq_generated_hits "$tmpconf"); rm -f "$tmpconf"
	[ -z "$hits" ] || bad "the change adds or edits built files; change the recipe instead: $(printf '%s' "$hits" | cut -f1 | head -3 | tr '\n' ' ')"
else
	files=""
fi

if [ "$(git rev-parse HEAD)" = "$sha" ]; then
	"$here/levels.sh" check >&2 || fail=1
	scripts=$(printf '%s\n' "$files" | grep '\.gd$' | grep -v '^tools/mq/')
	if [ -n "$scripts" ]; then
		# shellcheck disable=SC2086
		out=$("$here/parse.sh" $scripts 2>&1); rc=$?
		if [ "$rc" = 125 ]; then echo "precheck: no engine here, parse check skipped (the gate runs it)" >&2
		elif [ "$rc" != 0 ]; then bad "parse check failed: $(printf '%s\n' "$out" | grep -E 'FAIL|ERROR' | head -5)"; fi
	fi
else
	echo "precheck: $sha is not checked out, so levels.sh check and the parse check were skipped" >&2
fi
[ "$fail" = 0 ] && echo "precheck: ok"
exit $fail
