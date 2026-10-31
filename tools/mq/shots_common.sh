# Shared helpers for the Mac shot listener (tools/mq/shots.sh) and the cloud
# request/fetch helpers. Sourced, never run. Stock bash 3.2 and BSD tools:
# no timeout, flock, mapfile, associative arrays or GNU-only flags.
# Contract: docs/contracts/shots.md.

SHOTS_NAME_RE='^[A-Za-z0-9][A-Za-z0-9._]*(-[A-Za-z0-9._]+)*$'
SHOTS_REQ_PREFIX='refs/heads/shots/req-'
SHOTS_RES_PREFIX='refs/heads/shots/res-'

shots_die() { echo "shots: $*" >&2; exit 1; }

shots_now() { date -u +%Y-%m-%dT%H:%M:%SZ; }

shots_epoch() { date +%s; }

# Absolute shared git dir, the same from every worktree.
shots_git_common() {
	local d
	d=$(git rev-parse --git-common-dir 2>/dev/null) || return 1
	(cd "$d" && pwd -P)
}

# Valid "<ID>-<n>" key? ID: letters, digits, . _ - ; n: a number.
shots_valid_key() {
	case "$1" in *-[0-9]*) ;; *) return 1 ;; esac
	local id="${1%-*}" n="${1##*-}"
	case "$n" in '' | *[!0-9]*) return 1 ;; esac
	[ ${#1} -le 80 ] || return 1
	echo "$id" | grep -Eq "$SHOTS_NAME_RE"
}

# key=value config file, read only from the file (never the environment).
shots_conf_get() { # file key default
	local v=""
	[ -f "$1" ] && v=$(grep -E "^$2=" "$1" 2>/dev/null | tail -1 | cut -d= -f2-)
	[ -n "$v" ] && echo "$v" || echo "$3"
}

shots_mtime() { stat -c %Y "$1" 2>/dev/null || stat -f %m "$1" 2>/dev/null || echo 0; }

shots_size() { wc -c <"$1" 2>/dev/null | tr -d ' '; }

# Any live process left in this process group? A zombie doesn't count.
shots_group_alive() { # pgid
	ps -A -o pgid=,stat= 2>/dev/null | awk -v g="$1" '$1 == g && $2 !~ /^Z/ { f = 1 } END { exit !f }'
}

# TERM to a whole process group, KILL for anything still there after 5 seconds.
shots_stop_group() { # pgid
	local i=0
	shots_group_alive "$1" || return 0
	kill -TERM -- "-$1" 2>/dev/null
	while [ "$i" -lt 25 ] && shots_group_alive "$1"; do sleep 0.2; i=$((i + 1)); done
	kill -KILL -- "-$1" 2>/dev/null
	return 0
}

# Run "$@" with a time limit, output appended to a log. Returns the command's
# exit code, or 124 when it was stopped for running too long. The command gets
# its own process group (set -m), so Godot goes down with the shell that started
# it and nothing is left running afterwards, however the command ended.
# shots_run_limited <seconds> <logfile> <cmd...>
shots_run_limited() {
	local secs="$1" log="$2" pid w rc wrc
	shift 2
	set -m
	"$@" >>"$log" 2>&1 </dev/null &
	pid=$!
	set +m
	[ -n "${SHOTS_CHILD_FILE:-}" ] && echo "$pid" >"$SHOTS_CHILD_FILE"
	(
		fired=0
		trap 'exit $fired' TERM
		n=0
		while [ "$n" -lt "$secs" ]; do sleep 1; n=$((n + 1)); done
		fired=124
		kill -TERM -- "-$pid" 2>/dev/null
		sleep 5
		kill -KILL -- "-$pid" 2>/dev/null
		exit 124
	) >/dev/null 2>&1 &
	w=$!
	wait "$pid"
	rc=$?
	kill -TERM "$w" 2>/dev/null
	wait "$w" 2>/dev/null
	wrc=$?
	shots_stop_group "$pid"
	[ -n "${SHOTS_CHILD_FILE:-}" ] && rm -f "$SHOTS_CHILD_FILE"
	[ "$wrc" = 124 ] && return 124
	return "$rc"
}

# git with retries for network errors (2s, 4s, 8s, 16s).
shots_git_retry() {
	local delay=2 i=0
	while :; do
		git "$@" && return 0
		i=$((i + 1))
		[ "$i" -ge 5 ] && return 1
		sleep "$delay"
		delay=$((delay * 2))
	done
}

# Lists "<sha> <key>" for every request (or result) branch on the remote.
# shots_ls_remote <remote> req|res
shots_ls_remote() {
	local prefix="$SHOTS_REQ_PREFIX"
	[ "$2" = res ] && prefix="$SHOTS_RES_PREFIX"
	git ls-remote "$1" "${prefix}*" 2>/dev/null | while read -r sha ref; do
		echo "$sha ${ref#"$prefix"}"
	done
}
