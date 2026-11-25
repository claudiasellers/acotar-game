#!/bin/bash
# The note a rejection carries: what kind of failure it was and what to do, from
# cheap git checks, so a lane can fix it in one try.
#   diagnose.sh note <kind> <sha> <task> <detail>   prints the block (about 10 lines)
#       kind: conflict (detail = files), gate (detail = gate line name),
#             built (detail = files)
#   diagnose.sh clean <logfile>                      the log with colour codes gone,
#       cut to the Failed assert lines (file:line), SCRIPT ERROR lines and summary
#   diagnose.sh class <kind> <sha> <task> <detail>   just the one-word class
# Compares against origin/main (MQ_MAIN).
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"
main="${MQ_MAIN:-refs/remotes/origin/main}"
mode="${1:-}"; shift || true

strip_ansi() { sed $'s/\x1b\\[[0-9;]*[A-Za-z]//g' | tr -d '\r'; }

if [ "$mode" = clean ]; then
	[ -f "${1:-}" ] || exit 0
	all=$(strip_ansi < "$1")
	keep=$(printf '%s\n' "$all" | grep -E '\[Failed\]|^[[:space:]]+at line|^[[:space:]]*at: |SCRIPT ERROR|^res://.*\.gd[[:space:]]*$|^\* test_|passed|[Ff]ailing|Totals|Asserts|^FAIL|parse' | head -30)
	[ -n "$keep" ] || keep=$(printf '%s\n' "$all" | grep -v '^[[:space:]]*$' | tail -15)
	printf '%s\n' "$keep"
	exit 0
fi

kind="${1:-}"; sha="${2:-}"; task="${3:-}"; detail="${4:-}"

# Task ids that have unmerged commits in this branch: they are in another
# task's ready branch and not in main.
carried() {
	local own r id key out="" c
	own=$(git rev-list "$sha" "^$main" 2>/dev/null | sort)
	[ -n "$own" ] || return 0
	for r in $(git for-each-ref --format='%(refname)' refs/mq/ready refs/remotes/origin/lead 2>/dev/null); do
		key=${r##*/}; key=${key#ready-}
		id=${key%-*}
		[ "$id" = "$task" ] && continue
		[ -n "$id" ] || continue
		# A later slice built on this one contains it; that is the normal stack, not carried work.
		git merge-base --is-ancestor "$sha" "$r" 2>/dev/null && continue
		c=$(git rev-list "$r" "^$main" 2>/dev/null | sort | comm -12 - <(printf '%s\n' "$own") | head -1)
		[ -n "$c" ] && case " $out " in *" $id "*) ;; *) out="$out $id" ;; esac
	done
	printf '%s' "${out# }"
}

classify() {
	case "$kind" in
		conflict) echo conflict ;;
		built) echo generated-file ;;
		gate)
			local nm="$detail" t
			case "$nm" in
				gut:*)
					t=${nm#gut:}
					if git cat-file -e "$main:$t" 2>/dev/null; then echo existing-test; else echo own-new-test; fi ;;
				parse|levels-check|levels|terrain) echo precheck ;;
				*) echo gate ;;
			esac ;;
		*) echo other ;;
	esac
}

cls=$(classify)
[ "$mode" = class ] && { echo "$cls"; exit 0; }

base=$(git merge-base "$sha" "$main" 2>/dev/null || echo "$main")
case "$cls" in
	own-new-test)
		echo "WHY: your new test fails ($detail). The feature doesn't do what your test says yet."
		echo "DO:  run that one test locally, fix the feature (or the test if it asserts the wrong thing), then push the next number." ;;
	existing-test)
		echo "WHY: an existing test on main fails ($detail)."
		echo "DO:  if you changed this behaviour on purpose, update this test in your branch (tests check outcomes, not today's details); otherwise it's a regression, so fix your code."
		if git diff --name-only "$base" "$sha" 2>/dev/null | grep -qx "${detail#gut:}"; then
			echo "     (your branch edits this test file itself.)"
		fi ;;
	conflict)
		echo "WHY: your branch conflicts with main in: $detail"
		echo "DO:  merge origin/main into your branch and resolve those files; if a file was deleted on main by a cleanup task, accept the deletion unless you're rewriting it." ;;
	generated-file)
		echo "WHY: the change adds or edits built files: $detail"
		echo "DO:  drop them from the change; they are rebuilt from tools/mq/generated.conf (change the recipe or its inputs instead). Run tools/mq/precheck.sh before pushing." ;;
	precheck)
		uid=$("$here/check_uids.sh" --added-since "$base" "$sha" 2>/dev/null | sed 's/^missing \.uid: //' | head -3 | tr '\n' ' ')
		if [ -n "$uid" ]; then
			echo "WHY: new script(s) have no .uid file: $uid"
			echo "DO:  run tools/mq/godot.sh --import so Godot writes the .uid next to each, and commit them. Run tools/mq/precheck.sh before pushing."
		elif git diff "$base" "$sha" 2>/dev/null | grep -qE '^\+(<<<<<<< |>>>>>>> |=======$)'; then
			echo "WHY: merge-conflict markers are left in the change."
			echo "DO:  remove them (git grep -n '^<<<<<<<'). Run tools/mq/precheck.sh before pushing."
		else
			echo "WHY: the '$detail' check failed (parse error, stale generated file or similar); the file is named in the log below."
			echo "DO:  fix that file; tools/mq/parse.sh <file> checks one. Run tools/mq/precheck.sh before pushing."
		fi ;;
	gate)
		echo "WHY: gate line '$detail' failed; the log below says why."
		echo "DO:  fix it, merge origin/main, and push the next number." ;;
	*)
		echo "DO:  merge origin/main, fix it, and push the next number." ;;
esac
cr=$(carried)
[ -n "$cr" ] && echo "WARNING: this branch includes unmerged work from $cr (commits in their lead/ready branches, not in main). Merge only origin/main, not other branches."
exit 0
