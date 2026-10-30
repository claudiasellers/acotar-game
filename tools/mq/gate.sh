#!/bin/bash
# Runs the gate in the current worktree.
#   gate.sh --out DIR [--base SHA] [--known FILE] [--only NAME] [--all]
# --base   lines marked when: are judged against the change since SHA
# --known  names already red on main: they run, but can't fail the gate
# --only   the `first:` lines, then just NAME (a NAME not in the plan passes)
# --all    don't stop at the first failure; every failure goes in DIR/failed
# Exit: 0 pass, 1 fail (name in DIR/failed), 3 couldn't test.
set -u
here=$(cd "$(dirname "$0")" && pwd)
. "$here/common.sh"

out=""; base=""; known=/dev/null; only=""; all=0
while [ "$#" -gt 0 ]; do
	case "$1" in
		--out) out="$2"; shift 2 ;;
		--base) base="$2"; shift 2 ;;
		--known) known="$2"; shift 2 ;;
		--only) only="$2"; shift 2 ;;
		--all) all=1; shift ;;
		*) echo "gate: unknown $1" >&2; exit 2 ;;
	esac
done
[ -n "$out" ] || { echo "gate: --out is required" >&2; exit 2; }
mkdir -p "$out/logs" "$out/scratch"
: > "$out/results.txt"; : > "$out/plan.txt"; : > "$out/failed"

JOBS=$(mq_config_or MQ_JOBS 4)
LINE_TIMEOUT=$(mq_config_or MQ_LINE_TIMEOUT 1800)
DURATIONS="$MQ_DIR/durations"
CONF=tools/mq/gate.conf
[ -f "$CONF" ] || CONF="$here/gate.conf"

mq_engine >/dev/null || { echo "gate: no engine" >&2; exit 3; }

changed=""
[ -n "$base" ] && changed=$(git diff --name-only "$base" HEAD)
export MQ_GATE_BASE="$base"

slug() { printf '%s' "$1" | tr '/: ' '___'; }

matches() { # matches "a/*,*.x": true when the change touches a match
	local pats="$1" p f
	[ -n "$base" ] || return 0
	local IFS=,
	for p in $pats; do
		IFS='
'
		for f in $changed; do
			# shellcheck disable=SC2254
			case "$f" in $p) return 0 ;; esac
		done
		IFS=,
	done
	return 1
}

first_names=(); first_cmds=(); names=(); cmds=()
add() { # add first|rest name command
	if [ "$1" = first ]; then
		first_names[${#first_names[@]}]="$2"; first_cmds[${#first_cmds[@]}]="$3"
	else
		names[${#names[@]}]="$2"; cmds[${#cmds[@]}]="$3"
	fi
	echo "RUN  $2" >> "$out/plan.txt"
}

while IFS= read -r line; do
	case "$line" in ''|\#*) continue ;; esac
	if [ "${line%% *}" = "@gut" ]; then
		for t in $(find "${line#* }" -name 'test_*.gd' 2>/dev/null | sort); do
			[ -n "$only" ] && [ "$only" != "gut:$t" ] && continue
			add rest "gut:$t" "\"\$MQ_BIN/godot.sh\" -s addons/gut/gut_cmdln.gd -gconfig= -gexit -gtest=res://$t"
		done
		continue
	fi
	stage=rest; cond=""; gfx=0
	while :; do
		case "$line" in
			first:\ *) stage=first; line="${line#first: }" ;;
			gfx:\ *) gfx=1; line="${line#gfx: }" ;;
			when:*) cond="${line%% *}"; cond="${cond#when:}"; line="${line#* }" ;;
			*) break ;;
		esac
	done
	name="${line%% = *}"; cmd="${line#* = }"
	if [ "$gfx" = 1 ]; then echo "SKIP $name (needs a real window)" >> "$out/plan.txt"; continue; fi
	if [ -n "$cond" ] && ! matches "$cond"; then echo "SKIP $name (change touches no $cond)" >> "$out/plan.txt"; continue; fi
	[ "$stage" = rest ] && [ -n "$only" ] && [ "$only" != "$name" ] && continue
	add "$stage" "$name" "$cmd"
done < "$CONF"

is_known() { grep -qxF "$1" "$known" 2>/dev/null; }
record() { echo "$2 $1 ${3:-0}s" >> "$out/results.txt"; }

start_line() { # sets started_pid
	local name="$1" cmd="$2" s; s=$(slug "$name")
	rm -rf "$out/scratch/$s"
	MQ_SCRATCH="$out/scratch/$s" /usr/bin/perl "$here/mqtimeout.pl" "$LINE_TIMEOUT" /bin/bash -c "$cmd" \
		> "$out/logs/$s.log" 2>&1 &
	started_pid=$!
}

running=""
kill_running() { local p; for p in $running; do kill "$p" 2>/dev/null; done; wait 2>/dev/null; }
trap 'kill_running; exit 143' TERM INT

# Decides a line that exited non-zero. Returns 0 if the gate carries on.
judge() { # judge name cmd rc secs
	local name="$1" cmd="$2" rc="$3" secs="$4"
	if [ "$rc" = 125 ]; then echo "gate: engine vanished during $name" >&2; kill_running; exit 3; fi
	if is_known "$name"; then record "$name" KNOWNRED "$secs"; return 0; fi
	# A failure is retried once, alone.
	start_line "$name" "$cmd"
	running="$started_pid"; wait "$started_pid"; local again=$?; running=""
	if [ "$again" = 0 ]; then
		record "$name" FLAKY "$secs"
		mq_event FLAKY "$name"
		return 0
	fi
	record "$name" FAIL "$secs"
	echo "$name" >> "$out/failed"
	[ "$all" = 1 ]
}

run_alone() {
	local t0 rc secs
	t0=$(date +%s)
	start_line "$1" "$2"; running="$started_pid"
	wait "$started_pid"; rc=$?; running=""
	secs=$(( $(date +%s) - t0 ))
	if [ "$rc" = 0 ]; then record "$1" PASS "$secs"; return 0; fi
	judge "$1" "$2" "$rc" "$secs"
}

i=0
while [ "$i" -lt "${#first_names[@]}" ]; do
	run_alone "${first_names[$i]}" "${first_cmds[$i]}" || exit 1
	i=$((i + 1))
done

# Longest first, by what the last runs took.
order=$(i=0; while [ "$i" -lt "${#names[@]}" ]; do
	d=$(kv_get "$DURATIONS" "$(slug "${names[$i]}")"); echo "${d:-999} $i"; i=$((i + 1))
done | sort -rn | cut -d' ' -f2)

pids=(); idxs=(); starts=(); failures=""; queue=" $(echo $order) "
failed_stop=0
while :; do
	# Launch.
	while [ "$failed_stop" = 0 ] && [ -n "$(echo $queue)" ] && [ "${#pids[@]}" -lt "$JOBS" ]; do
		set -- $queue; n=$1; shift; queue="$*"
		start_line "${names[$n]}" "${cmds[$n]}"
		pids[${#pids[@]}]=$started_pid; idxs[${#idxs[@]}]=$n; starts[${#starts[@]}]=$(date +%s)
	done
	running="${pids[*]:-}"
	[ "${#pids[@]}" = 0 ] && break
	# Reap.
	np=(); ni=(); ns=()
	for j in "${!pids[@]}"; do
		p=${pids[$j]}
		if kill -0 "$p" 2>/dev/null; then
			np[${#np[@]}]=$p; ni[${#ni[@]}]=${idxs[$j]}; ns[${#ns[@]}]=${starts[$j]}
			continue
		fi
		wait "$p"; rc=$?
		n=${idxs[$j]}; secs=$(( $(date +%s) - ${starts[$j]} ))
		if [ "$rc" = 0 ]; then
			record "${names[$n]}" PASS "$secs"
			kv_set "$DURATIONS" "$(slug "${names[$n]}")" "$secs"
		else
			failures="$failures $n:$rc:$secs"
			failed_stop=1
		fi
	done
	pids=(${np[@]+"${np[@]}"}); idxs=(${ni[@]+"${ni[@]}"}); starts=(${ns[@]+"${ns[@]}"})
	# Let what's running finish, then settle failures one at a time.
	if [ "$failed_stop" = 1 ] && [ "${#pids[@]}" = 0 ]; then
		for f in $failures; do
			n=${f%%:*}; r=${f#*:}; rc=${r%%:*}; secs=${r#*:}
			judge "${names[$n]}" "${cmds[$n]}" "$rc" "$secs" || exit 1
		done
		failures=""; failed_stop=0
		continue
	fi
	/usr/bin/perl -e 'select(undef,undef,undef,0.2)'
done

[ -s "$out/failed" ] && exit 1
exit 0
