#!/bin/bash
# Names the test that leaks into another, for a shard that was red together but
# green test by test. Never rejects anything: it only logs and makes a task.
#   bisect.sh OUT SHARD "gut:a gut:b ..." [KEPT-LOG [COMMIT]]
# The victim is the first test that failed in the shared run (its log). The
# tests before it, in shard order, are halved until one leaker is left; every
# rerun is one shared engine that ends with the victim.
# The reruns happen in a throwaway detached worktree at COMMIT (the build
# worktree has moved on by now), with the import cache cloned in and its own
# scratch data folder. It is removed on the way out.
# Cap: MQ_BISECT_SECS (default 240) of wall clock, about log2(n)+1 reruns.
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"
out="$1"; shard="$2"; members="$3"; kept="${4:-}"; sha="${5:-}"
if [ -n "${MQ_EVENTS:-}" ]; then
	mq_event() { local k="$1"; shift; printf '%s %s %s\n' "$(mq_now)" "$k" "$*" >> "$MQ_EVENTS"; }
fi
budget=${MQ_BISECT_SECS:-240}
deadline=$(( $(date +%s) + budget ))
slug=$(printf '%s' "$shard" | tr '/: ' '___')
log="$out/logs/$slug.log"

# The result also goes at the end of the kept log, so one file tells the story.
note() { [ -n "$kept" ] && [ -f "$kept" ] && printf '\n== bisect: %s\n' "$*" >> "$kept"; return 0; }
gave_up() { note "could not isolate the leaker ($1)"; mq_event FLAKY "$shard could not isolate the leaker ($1); failing log: ${kept:-$log}"; exit 0; }

# The first test file with a [Failed] line under it. Real GUT output (checked
# with a failing test): a script header is a line that is only `res://x.gd`
# (colour codes on the lines around it), and a failure is
# `    [Failed]:  <message>` under it. An engine error line that only mentions
# a res:// path is not a header.
victim=""
if [ -f "$log" ]; then
	esc=$(printf '\033')
	cur=""
	while IFS= read -r line; do
		line=$(printf '%s' "$line" | sed "s/${esc}\[[0-9;]*m//g")
		case "$line" in
			res://*.gd) case "$line" in *" "*) ;; *) cur="gut:${line#res://}" ;; esac ;;
			*"[Failed]"*) [ -n "$cur" ] && { victim=$cur; break; } ;;
		esac
	done < "$log"
fi
[ -n "$victim" ] || gave_up "no failing test named in the shared log"
case " $members " in *" $victim "*) ;; *) gave_up "$victim is not in the shard" ;; esac

cands=""
for m in $members; do
	[ "$m" = "$victim" ] && break
	cands="$cands $m"
done
cands="${cands# }"
[ -n "$cands" ] || gave_up "$victim failed first, nothing ran before it"

# A worktree of its own at the shard's commit: the build worktree moves on.
wt=""; data=""
cleanup() {
	[ -n "$wt" ] && { git -C "$MQ_REPO" worktree remove --force "$wt" 2>/dev/null; rm -rf "$wt"; }
	[ -n "$data" ] && rm -rf "$data"
}
trap cleanup EXIT
trap 'exit 143' TERM INT
if [ -n "$sha" ]; then
	wt="$MQ_DIR/bisect/$slug-$$"; data="$wt-data"
	mkdir -p "$MQ_DIR/bisect"
	git -C "$MQ_REPO" worktree add -q --detach "$wt" "$sha" 2>/dev/null || { wt=""; gave_up "could not check out $sha"; }
	# Copy-on-write clone of the import cache, as lane.sh does, so there is no reimport.
	if [ -d "$MQ_REPO/.godot" ]; then
		cp -cR "$MQ_REPO/.godot" "$wt/.godot" 2>/dev/null || cp -R "$MQ_REPO/.godot" "$wt/.godot"
	fi
	( cd "$wt" && "$here/levels.sh" ensure --cached-only ) >/dev/null 2>&1 || true
else
	data="$out/scratch/bisect"
fi

red() { # red "<tests>": true when those tests plus the victim go red together
	local list="" t left rc=0
	for t in $1 $victim; do list="$list,res://${t#gut:}"; done
	left=$(( deadline - $(date +%s) ))
	[ "$left" -gt 5 ] || gave_up "out of time ($budget s)"
	( cd "${wt:-.}" && MQ_SCRATCH="${data:-$out/scratch/bisect}" /usr/bin/perl "$here/mqtimeout.pl" "$left" /bin/bash -c \
		"\"\$MQ_BIN/godot.sh\" -s addons/gut/gut_cmdln.gd -gconfig= -gexit -gtest=${list#,}" \
		> "$out/logs/${slug}_bisect.log" 2>&1 )
	rc=$?
	[ "$rc" != 125 ] || gave_up "engine vanished"
	[ "$rc" != 124 ] || gave_up "a rerun timed out"
	[ "$rc" != 0 ]
}

red "$cands" || gave_up "the tests before $victim did not break it again; may be timing"
while [ "$(echo $cands | wc -w)" -gt 1 ]; do
	set -- $cands
	half=$(( $# / 2 ))
	first=""; rest=""; i=0
	for t in "$@"; do
		i=$((i + 1))
		if [ "$i" -le "$half" ]; then first="$first $t"; else rest="$rest $t"; fi
	done
	first="${first# }"; rest="${rest# }"
	if red "$first"; then cands=$first
	elif red "$rest"; then cands=$rest
	else gave_up "it takes more than one of them together"
	fi
done

"$here/task.sh" add "Fix test leak: $cands leaks state that breaks $victim when they share an engine (gate shard $shard went red together, green alone). Make $cands clean up after itself (autoloads, statics, globals, scene state), or mark it '# gate: alone'. Failing log: ${kept:-$log}" >/dev/null || echo "bisect: could not make the task" >&2
note "leaker $cands breaks $victim"
mq_event FLAKY "$shard leaker $cands breaks $victim; failing log: ${kept:-$log}"
