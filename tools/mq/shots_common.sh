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
	local g=""
	if [ -n "${SHOTS_FOCUS_GUARD:-}" ] && command -v lsappinfo >/dev/null 2>&1; then
		shots_focus_guard "$pid" "$SHOTS_FOCUS_GUARD" "${SHOTS_FOCUS_LOG:-/dev/null}" </dev/null 2>/dev/null &
		g=$!
	fi
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
	[ -n "$g" ] && { kill -TERM "$g" 2>/dev/null; wait "$g" 2>/dev/null; }
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

# ---- quiet render windows (T087) --------------------------------------------
# A GPU render on the owner's Mac must never cover the screen or take focus.
# The window is small (SHOTS_WINDOW_W wide, the picture's aspect), in a corner
# and not on top; the picture still renders at the full requested size, because
# override.cfg puts the root viewport in "viewport" stretch at that size, so
# get_texture() is W×H whatever the window is. Godot 4.7's macOS build activates
# itself when it wasn't started by LaunchServices (its "unbundled window
# activation hack"); setting __CFBundleIdentifier to the app's own id, as
# LaunchServices would, skips that, so the app starts in the background. It
# still renders: the window is on screen, just not focused.
SHOTS_WINDOW_W=640

# shots_window_size <W>x<H> -> the small window, SHOTS_WINDOW_W wide, same aspect.
shots_window_size() {
	local w="${1%x*}" h="${1#*x}"
	echo "${SHOTS_WINDOW_W}x$(((SHOTS_WINDOW_W * h + w / 2) / w))"
}

# shots_window_args <W>x<H> <x,y> -> windowed, small, in the corner, not on top.
shots_window_args() {
	echo "--windowed --resolution $(shots_window_size "$1") --position $2"
}

# shots_render_cfg <project dir> <W>x<H> [who]: writes <dir>/override.cfg so the
# picture renders at W×H inside the small window. Never commit it (.gitignore).
shots_render_cfg() {
	cat >"$1/override.cfg" <<CFG
; Written by ${3:-tools/mq/shots.sh} for a quiet render (T087); delete it if it is still here.
[display]
window/size/viewport_width=${2%x*}
window/size/viewport_height=${2#*x}
window/stretch/mode="viewport"
window/stretch/aspect="keep"
CFG
}

# shots_bundle_id <godot binary> -> the .app's CFBundleIdentifier (macOS), or nothing.
shots_bundle_id() {
	local plist id
	plist="$(dirname "$(dirname "$1")")/Info.plist"
	[ "$(uname -s)" = Darwin ] || return 0
	[ -f "$plist" ] && id=$(/usr/libexec/PlistBuddy -c 'Print CFBundleIdentifier' "$plist" 2>/dev/null)
	echo "${id:-org.godotengine.godot}"
}

# ---- focus guard (T090) ----------------------------------------------------
# Godot 4.7 on macOS makes itself the frontmost app as it starts, whatever it is
# launched with (bundle id env, display/window/size/no_focus and open -g were all
# measured frontmost 0.3 s after launch), and then stays frontmost for the whole
# render. So while a render starts, the listener hands focus straight back: it
# polls the frontmost app every 0.1 s and, when that app is a process of this
# render (its process group), reopens the app that was frontmost just before.
# It acts only in the first <secs> seconds after launch, the self-activation;
# after that the owner can click into the Godot window and keep it.
# shots_focus_guard <pgid> <secs> <log>: runs until killed or <secs> pass.
shots_focus_ms() { perl -MTime::HiRes=time -e 'printf "%d", time * 1000' 2>/dev/null || echo $(($(date +%s) * 1000)); }

shots_front_info() { # -> "<pid> <bundle id or ->" of the frontmost app
	local asn pid bid
	asn=$(lsappinfo front 2>/dev/null) || return 1
	[ -n "$asn" ] || return 1
	pid=$(lsappinfo info -only pid "$asn" 2>/dev/null | sed -n 's/.*=\([0-9][0-9]*\).*/\1/p')
	bid=$(lsappinfo info -only bundleid "$asn" 2>/dev/null | sed -n 's/.*="\(.*\)"$/\1/p')
	[ -n "$pid" ] || return 1
	echo "$pid ${bid:--}"
}

shots_focus_guard() {
	local pgid="$1" secs="$2" log="$3" t0 now fpid fbid prev_bid="" grabbed=0 lost=0 since=0 hands=0 last=0
	t0=$(shots_focus_ms)
	trap 'shots_focus_report' TERM
	shots_focus_report() {
		[ "$grabbed" = 1 ] && lost=$((lost + $(shots_focus_ms) - since))
		[ "$hands" -gt 0 ] || [ "$lost" -gt 0 ] && echo "focus guard: handed focus back ${hands}x, render held it ${lost} ms" >>"$log"
		exit 0
	}
	while :; do
		now=$(shots_focus_ms)
		[ $((now - t0)) -ge $((secs * 1000)) ] && break
		if set -- $(shots_front_info); then
			fpid="$1" fbid="$2"
			if [ "$(ps -o pgid= -p "$fpid" 2>/dev/null | tr -d ' ')" = "$pgid" ]; then
				[ "$grabbed" = 0 ] && { grabbed=1; since=$now; }
				if [ -n "$prev_bid" ] && [ "$prev_bid" != - ] && [ $((now - last)) -ge 500 ]; then
					open -b "$prev_bid" >/dev/null 2>&1
					hands=$((hands + 1))
					last=$now
				fi
			else
				[ "$grabbed" = 1 ] && { lost=$((lost + now - since)); grabbed=0; }
				prev_bid="$fbid"
			fi
		fi
		sleep 0.1
	done
	shots_focus_report
}
