#!/bin/bash
# Mac shot listener: renders screenshot requests from cloud lanes on this
# machine's real GPU and pushes the pictures back. A plain script, no AI.
#
#   tools/mq/shots.sh --start    start the listener in the background
#   tools/mq/shots.sh --stop     stop it (and any render it is running)
#   tools/mq/shots.sh --status   one-screen picture
#   tools/mq/shots.sh --check    is this machine ready (mark, Godot, push access)?
#   tools/mq/shots.sh --once     one poll and every waiting request, in the foreground
#
# Requests are branches shots/req-<ID>-<n> (the lane's commit plus
# .shots/probes.txt or .shots/request.json); answers are orphan branches
# shots/res-<ID>-<n>. It reads requests and writes results, nothing else: it
# never touches main, the play folder or the owner's save, and never deletes a
# ref a cloud session pushed. Contract: docs/contracts/shots.md.
#
# Runs only where .git/mq/config has the line MQ_HOME_MACHINE=1.
# Optional lines in .git/mq/config (defaults shown):
#   SHOTS_POLL=60            seconds between polls of origin (git ls-remote only)
#   SHOTS_GODOT=             Godot binary (else .tools/godot-*/ from make, PATH, /Applications)
#   SHOTS_POSITION=40,40     corner the render window opens at
#   SHOTS_WAIT_FOR_PLAY=1    hold requests while the owner's game is running
#   SHOTS_PUSH=1             0 = render and keep results locally only
#   SHOTS_KEEP_DAYS=1        delete this machine's own result branches after this
#   SHOTS_LAYOUT_WIDTH=1280  "quality layout" pictures: JPEG this wide ...
#   SHOTS_LAYOUT_JPEG=80     ... at this JPEG quality ("quality look" stays lossless PNG)
#   SHOTS_REMOTE=origin

set -u

SHOTS_SELF_DIR=$(cd "$(dirname "$0")" && pwd -P)
# shellcheck source=tools/mq/shots_common.sh
. "$SHOTS_SELF_DIR/shots_common.sh"

G=$(shots_git_common) || shots_die "not inside a git repository"
REPO=$(cd "$G/.." && pwd -P)
MQ="$G/mq"
CONF="$MQ/config"
S="$MQ/shots"
WT="$REPO/.lanes/shots"
EVENTS="$S/events.log"
LOCK="$S/lock"
SHOTS_CHILD_FILE="$S/child.pid"

conf() { shots_conf_get "$CONF" "$1" "$2"; }

REMOTE=$(conf SHOTS_REMOTE origin)
POLL=$(conf SHOTS_POLL 60)
POSITION=$(conf SHOTS_POSITION 40,40)
WAIT_FOR_PLAY=$(conf SHOTS_WAIT_FOR_PLAY 1)
PLAY_PATTERN=$(conf SHOTS_PLAY_PATTERN '(--path|--remote-debug)')
PUSH=$(conf SHOTS_PUSH 1)
KEEP_DAYS=$(conf SHOTS_KEEP_DAYS 1)
LAYOUT_WIDTH=$(conf SHOTS_LAYOUT_WIDTH 1280)
LAYOUT_JPEG=$(conf SHOTS_LAYOUT_JPEG 80)

event() {
	mkdir -p "$S"
	echo "$(shots_now) $*" >>"$EVENTS"
	[ -n "${SHOTS_VERBOSE:-}" ] && echo "$*" >&2
	return 0
}

home_machine() { [ "$(conf MQ_HOME_MACHINE 0)" = 1 ]; }

refuse_unless_home() {
	home_machine && return 0
	echo "SHOT LISTENER REFUSED: this is not the home machine." >&2
	echo "Only the machine whose $CONF has the line MQ_HOME_MACHINE=1 renders shots." >&2
	exit 2
}

find_godot() {
	local g
	g=$(conf SHOTS_GODOT "")
	if [ -n "$g" ]; then [ -x "$g" ] && echo "$g" && return 0; return 1; fi
	for g in "$REPO"/.tools/godot-*/Godot.app/Contents/MacOS/Godot "$REPO"/.tools/godot-*/godot; do
		[ -x "$g" ] && echo "$g" && return 0
	done
	g=$(command -v godot 2>/dev/null) && [ -n "$g" ] && echo "$g" && return 0
	g=/Applications/Godot.app/Contents/MacOS/Godot
	[ -x "$g" ] && echo "$g" && return 0
	return 1
}

# ---- lock with heartbeat ---------------------------------------------------

lock_pid() { cat "$LOCK/pid" 2>/dev/null; }

listener_running() {
	local p
	p=$(lock_pid)
	[ -n "$p" ] && kill -0 "$p" 2>/dev/null
}

take_lock() {
	mkdir -p "$S"
	if mkdir "$LOCK" 2>/dev/null; then echo $$ >"$LOCK/pid"; return 0; fi
	if listener_running && [ "$(lock_pid)" != $$ ]; then return 1; fi
	rm -rf "${LOCK:?}"
	mkdir "$LOCK" 2>/dev/null || return 1
	echo $$ >"$LOCK/pid"
}

heartbeat() { [ -d "$LOCK" ] && touch "$LOCK/heartbeat"; }

release_lock() { [ "$(lock_pid)" = $$ ] && rm -rf "${LOCK:?}"; }

# ---- keep the Mac awake ----------------------------------------------------

keep_awake() {
	command -v caffeinate >/dev/null 2>&1 || return 0
	[ "$(conf MQ_CAFFEINATE 1)" = 0 ] && return 0
	local p
	p=$(cat "$S/caffeinate.pid" 2>/dev/null)
	if [ -n "$p" ] && kill -0 "$p" 2>/dev/null; then return 0; fi
	caffeinate -i -w $$ >/dev/null 2>&1 &
	echo $! >"$S/caffeinate.pid"
	event "AWAKE caffeinate pid $! for listener $$"
}

# ---- the owner's game comes first -----------------------------------------

# True when a Godot game the listener didn't start is running (make play, or
# Play from the editor). The editor or project manager alone doesn't count.
owner_playing() {
	[ "$WAIT_FOR_PLAY" = 1 ] || return 1
	ps -A -o command= 2>/dev/null | grep -i 'godot' | grep -v grep | grep -v "$WT" |
		grep -Ev -- '(--editor| -e( |$))' | grep -Eq -- "$PLAY_PATTERN"
}

# ---- the worktree that renders ----------------------------------------------

ensure_worktree() {
	mkdir -p "$REPO/.lanes"
	[ -f "$REPO/.lanes/.gdignore" ] || : >"$REPO/.lanes/.gdignore"
	grep -qx '/.lanes/' "$G/info/exclude" 2>/dev/null || { mkdir -p "$G/info"; echo '/.lanes/' >>"$G/info/exclude"; }
	if [ ! -e "$WT/.git" ]; then
		git -C "$REPO" worktree add -q --detach "$WT" "$1" >>"$S/listener.log" 2>&1 || return 1
		git -C "$REPO" worktree lock --reason "shot listener" "$WT" >/dev/null 2>&1
		# Start from the play folder's import cache instead of importing everything.
		if [ -d "$REPO/.godot" ]; then
			clone_copy "$REPO/.godot" "$WT/.godot" && event "SEEDED the render worktree's import cache from the play folder"
		fi
	fi
	return 0
}

# Copy that costs no disk on a Mac (APFS clone), a plain copy elsewhere.
clone_copy() { # src dest
	mkdir -p "$(dirname "$2")"
	if [ "$(uname -s)" = Darwin ]; then cp -cR "$1" "$2" 2>/dev/null && return 0; fi
	cp -R "$1" "$2"
}

checkout_request() { # sha
	ensure_worktree "$1" || return 1
	git -C "$WT" checkout -q -f --detach "$1" >>"$S/listener.log" 2>&1 || return 1
	# Keep Godot's import cache between requests; everything else is fresh.
	git -C "$WT" clean -ffdxq -e /.godot/ >>"$S/listener.log" 2>&1 || return 1
}

# ---- one request -----------------------------------------------------------

GODOT=""
GODOT_VERSION=""
OUT=""
RES=""
SCRATCH=""

note() { echo "note $*" >>"$RES/result.txt"; }

# Every Godot run gets a scratch user:// so the owner's save is never seen or
# touched: macOS Godot puts user:// under $HOME/Library/Application Support,
# Linux under $XDG_DATA_HOME. The scratch is wiped before each run except for
# shader caches, which only make later renders faster.
godot_env() {
	find "$SCRATCH" -type f ! -path '*shader_cache*' ! -path '*/Library/Caches/*' -exec rm -f {} + 2>/dev/null
	mkdir -p "$SCRATCH/home" "$SCRATCH/config" "$SCRATCH/data" "$SCRATCH/cache"
	HOME="$SCRATCH/home" XDG_CONFIG_HOME="$SCRATCH/config" XDG_DATA_HOME="$SCRATCH/data" \
		XDG_CACHE_HOME="$SCRATCH/cache" SHOTS_OUT="$OUT" SHOTS_QUALITY="$QUALITY" "$@"
}

# Linux without a display (the cloud self-test) renders through xvfb-run.
DISP=()
if [ "$(uname -s)" != Darwin ] && [ -z "${DISPLAY:-}" ] && command -v xvfb-run >/dev/null 2>&1; then
	DISP=(xvfb-run -a -s "-screen 0 1920x1080x24")
fi

godot_headless() { # log limit godot-args...
	local log="$1" limit="$2"
	shift 2
	shots_run_limited "$limit" "$log" godot_env "$GODOT" --headless --audio-driver Dummy --path "$WT" "$@"
}

# Import (only when art changed since the last import), then generated content
# through the build queue's own levels.sh: the same recipes (generated.conf) and
# the same machine-wide cache (.git/levelcache) the gate uses, so anything the
# build lane or an earlier request built is copied in, never rebuilt. Then the
# request's own prep lines.
IMPORTABLE='\.(png|jpe?g|webp|svg|tga|bmp|exr|hdr|glb|gltf|bin|obj|fbx|blend|dae|wav|ogg|mp3|ttf|otf|woff2?|import|csv|ktx2?|dds)$'
prepare() {
	local log=$RES/logs/prep.log t0 t1 rc g sha last steps="" gens=""
	t0=$(shots_epoch)
	sha=$(git -C "$WT" rev-parse HEAD)
	last=$(cat "$S/imported_commit" 2>/dev/null)
	if [ -d "$WT/.godot" ] && [ -n "$last" ] && git cat-file -e "$last^{commit}" 2>/dev/null &&
		! git diff --name-only "$last" "$sha" | grep -Eq "$IMPORTABLE"; then
		steps="import skipped (no art changed)"
	else
		t1=$(shots_epoch)
		echo "== import" >>"$log"
		godot_headless "$log" 1800 --import
		rc=$?
		[ "$rc" = 124 ] && { echo "prep timeout import $(($(shots_epoch) - t0))s" >>"$RES/result.txt"; return 1; }
		echo "$sha" >"$S/imported_commit"
		steps="import $(($(shots_epoch) - t1))s"
	fi
	if [ -f "$WT/tools/mq/levels.sh" ]; then
		t1=$(shots_epoch)
		echo "== levels.sh ensure" >>"$log"
		(cd "$WT" && shots_run_limited 3600 "$log" bash tools/mq/levels.sh ensure)
		rc=$?
		[ "$rc" = 0 ] || { echo "prep fail levels.sh ensure exit=$rc $(($(shots_epoch) - t0))s" >>"$RES/result.txt"; return 1; }
		steps="$steps, generated content $(($(shots_epoch) - t1))s (levels.sh)"
	else
		gens="$WT/tools/generators/*.gd" # an older commit without the queue: build uncached
	fi
	for g in $gens $PREPS; do
		case "$g" in "$WT"/*) g="res://${g#"$WT"/}" ;; esac
		[ -f "$WT/${g#res://}" ] || continue
		t1=$(shots_epoch)
		echo "== $g" >>"$log"
		if [ "${g%.gd}" != "$g" ]; then godot_headless "$log" 900 -s "$g"; else godot_headless "$log" 900 "$g"; fi
		rc=$?
		[ "$rc" = 0 ] || { echo "prep fail $g exit=$rc $(($(shots_epoch) - t0))s" >>"$RES/result.txt"; return 1; }
		steps="$steps, $(basename "$g") ran $(($(shots_epoch) - t1))s"
	done
	echo "prep ok $(($(shots_epoch) - t0))s: $steps" >>"$RES/result.txt"
}

render_args() { # common windowed args for a render run
	local a="--audio-driver Dummy --windowed --resolution $SIZE --position $POSITION --always-on-top"
	[ -n "$METHOD" ] && a="$a --rendering-method $METHOD"
	echo "$a"
}

# "quality layout": a lossy JPEG about LAYOUT_WIDTH wide. Returns 1 when no
# converter is available, and the PNG is kept as it is.
to_jpeg() { # in out
	if command -v sips >/dev/null 2>&1; then
		local w
		w=$(sips -g pixelWidth "$1" 2>/dev/null | awk '/pixelWidth/ {print $2}')
		if [ -n "$w" ] && [ "$w" -gt "$LAYOUT_WIDTH" ]; then
			sips -s format jpeg -s formatOptions "$LAYOUT_JPEG" --resampleWidth "$LAYOUT_WIDTH" "$1" --out "$2" >/dev/null 2>&1 && return 0
		else
			sips -s format jpeg -s formatOptions "$LAYOUT_JPEG" "$1" --out "$2" >/dev/null 2>&1 && return 0
		fi
	fi
	command -v python3 >/dev/null 2>&1 && python3 -I - "$1" "$2" "$LAYOUT_WIDTH" "$LAYOUT_JPEG" >/dev/null 2>&1 <<'PY' && return 0
import sys
from PIL import Image
im = Image.open(sys.argv[1]).convert("RGB")
w = int(sys.argv[3])
if im.width > w:
    im = im.resize((w, round(im.height * w / im.width)), Image.LANCZOS)
im.save(sys.argv[2], "JPEG", quality=int(sys.argv[4]), optimize=True)
PY
	return 1
}

collect() { # label dir -> RES/out/label, skipping big or unknown files
	local label="$1" dir="$2" f n=0 sz total
	[ -d "$dir" ] || { echo 0; return; }
	mkdir -p "$RES/out/$label"
	total=$(du -sk "$RES/out" 2>/dev/null | cut -f1)
	for f in $(cd "$dir" && find . -type f \( -name '*.png' -o -name '*.jpg' -o -name '*.webp' -o -name '*.txt' -o -name '*.json' -o -name '*.csv' \) | sort | head -200); do
		sz=$(shots_size "$dir/$f")
		if [ "$sz" -gt 15728640 ]; then note "skipped $label/$f: over 15 MB"; continue; fi
		if [ $((total + sz / 1024)) -gt 61440 ]; then note "skipped $label/$f: result over 60 MB"; continue; fi
		mkdir -p "$RES/out/$label/$(dirname "$f")"
		if [ "$QUALITY" = layout ] && [ "${f%.png}" != "$f" ] && to_jpeg "$dir/$f" "$RES/out/$label/${f%.png}.jpg"; then
			sz=$(shots_size "$RES/out/$label/${f%.png}.jpg")
		else
			cp "$dir/$f" "$RES/out/$label/$f"
		fi
		total=$((total + sz / 1024))
		n=$((n + 1))
	done
	echo "$n"
}

run_probe_line() { # label path args...
	local label="$1" path="$2" t0 rc dir log status files a
	shift 2
	dir="$OUT/$label"
	log="$RES/logs/$label.log"
	mkdir -p "$dir"
	set -- $(for a in "$@"; do echo "$a" | sed "s#{out}#$dir#g"; done)
	t0=$(shots_epoch)
	if [ "${path%.gd}" != "$path" ]; then
		shots_run_limited "$TIMEOUT" "$log" godot_env ${DISP[@]+"${DISP[@]}"} "$GODOT" --path "$WT" $(render_args) -s "$path" -- "$@"
	else
		shots_run_limited "$TIMEOUT" "$log" godot_env ${DISP[@]+"${DISP[@]}"} "$GODOT" --path "$WT" $(render_args) "$path" -- "$@"
	fi
	rc=$?
	files=$(collect "$label" "$dir")
	status=ok
	[ "$rc" != 0 ] && status=fail
	[ "$rc" = 124 ] && status=timeout
	echo "shot $label $status exit=$rc $(($(shots_epoch) - t0))s files=$files" >>"$RES/result.txt"
	[ "$status" = ok ]
}

run_json() { # the layout-shots runner owns request.json; we just run its wrapper
	local log="$RES/logs/request.log" t0 rc files status
	if [ ! -f "$WT/tools/shots/take_shots.sh" ]; then
		echo "shot request fail exit=127 0s files=0" >>"$RES/result.txt"
		note "request.json needs tools/shots/take_shots.sh in the lane's commit"
		return 1
	fi
	mkdir -p "$OUT/request"
	t0=$(shots_epoch)
	(
		cd "$WT" || exit 1
		SHOTS_GODOT_ARGS=$(render_args)
		export GODOT SHOTS_GODOT_ARGS
		shots_run_limited "$JSON_TIMEOUT" "$log" godot_env ${DISP[@]+"${DISP[@]}"} bash tools/shots/take_shots.sh .shots/request.json "$OUT/request"
	)
	rc=$?
	files=$(collect request "$OUT/request")
	status=ok
	[ "$rc" != 0 ] && status=fail
	[ "$rc" = 124 ] && status=timeout
	echo "shot request $status exit=$rc $(($(shots_epoch) - t0))s files=$files" >>"$RES/result.txt"
	[ "$status" = ok ]
}

# Parses .shots/probes.txt into globals and $RES/plan.txt; prints the first
# problem and returns 1 when the request is malformed.
SIZE=1920x1080
QUALITY=look
METHOD=""
TIMEOUT=300
JSON_TIMEOUT=1800
PREPS=""
parse_probes() {
	local f="$WT/.shots/probes.txt" kw a b n=0 labels=" " line
	SIZE=1920x1080 METHOD="" TIMEOUT=300 PREPS="" QUALITY=look
	: >"$RES/plan.txt"
	while IFS= read -r line || [ -n "$line" ]; do
		line=$(echo "$line" | sed 's/[[:space:]]*$//')
		case "$line" in '' | '#'*) continue ;; esac
		if echo "$line" | grep -q '[^A-Za-z0-9_.,:=/+@{} -]'; then
			echo "unsupported character in: $line"; return 1
		fi
		set -- $line
		kw="$1"; shift
		case "$kw" in
		from) ;;
		quality)
			case "${1:-}" in look | layout) QUALITY="$1" ;; *) echo "bad quality: ${1:-} (look or layout)"; return 1 ;; esac ;;
		size)
			echo "$1" | grep -Eq '^[0-9]{3,4}x[0-9]{3,4}$' || { echo "bad size: $1"; return 1; } ;;
		renderer)
			case "$1" in
			forward_plus | mobile | gl_compatibility) METHOD="$1" ;;
			compatibility) METHOD=gl_compatibility ;;
			*) echo "bad renderer: $1"; return 1 ;;
			esac ;;
		timeout)
			case "$1" in '' | *[!0-9]*) echo "bad timeout: $1"; return 1 ;; esac
			TIMEOUT=$1
			[ "$TIMEOUT" -gt 1200 ] && TIMEOUT=1200 ;;
		prep)
			echo "$1" | grep -Eq '^res://[A-Za-z0-9_./-]+\.(gd|tscn)$' || { echo "bad prep path: $1"; return 1; }
			PREPS="$PREPS $1" ;;
		shot)
			a="${1:-}"; b="${2:-}"
			echo "$a" | grep -Eq '^[A-Za-z0-9_.-]{1,40}$' || { echo "bad shot label: $a"; return 1; }
			case "$labels" in *" $a "*) echo "duplicate shot label: $a"; return 1 ;; esac
			labels="$labels$a "
			echo "$b" | grep -Eq '^res://[A-Za-z0-9_./-]+\.(gd|tscn)$' || { echo "bad shot path: $b"; return 1; }
			[ -f "$WT/${b#res://}" ] || { echo "no such file in the commit: $b"; return 1; }
			echo "$line" >>"$RES/plan.txt"
			n=$((n + 1)) ;;
		*) echo "unknown line: $kw"; return 1 ;;
		esac
		[ "$kw" = size ] && SIZE="$1"
	done <"$f"
	[ "$n" -ge 1 ] || { echo "no shot lines"; return 1; }
	[ "$n" -le 40 ] || { echo "more than 40 shot lines"; return 1; }
	# A look shot is the real thing: the project's own Forward+, at 1080p or more.
	if [ "$QUALITY" = look ]; then
		[ -n "$METHOD" ] && [ "$METHOD" != forward_plus ] && { echo "quality look renders with the project's Forward+; drop the renderer line or use quality layout"; return 1; }
		METHOD=""
		[ "${SIZE%x*}" -lt 1920 ] && { echo "quality look renders at 1920x1080 or larger; use quality layout for small shots"; return 1; }
	fi
	return 0
}

# Writes RES as an orphan commit and pushes it to shots/res-<key>.
publish() { # key status
	local key="$1" status="$2" idx tree commit f blob
	idx=$(mktemp "${TMPDIR:-/tmp}/shots-idx.XXXXXX")
	rm -f "$idx"
	(cd "$RES" && find . -type f | sed 's#^\./##' | sort) >"$S/work/$key/files"
	while read -r f; do
		blob=$(git hash-object -w "$RES/$f") &&
			GIT_INDEX_FILE="$idx" git update-index --add --cacheinfo "100644,$blob,$f" || { rm -f "$idx"; return 1; }
	done <"$S/work/$key/files"
	tree=$(GIT_INDEX_FILE="$idx" git write-tree) || { rm -f "$idx"; return 1; }
	rm -f "$idx"
	commit=$(GIT_AUTHOR_NAME="ACOTAR shot listener" GIT_AUTHOR_EMAIL="shots@localhost" \
		GIT_COMMITTER_NAME="ACOTAR shot listener" GIT_COMMITTER_EMAIL="shots@localhost" \
		git commit-tree "$tree" -m "shots res $key: $status") || return 1
	git update-ref "refs/mq/shots/res/$key" "$commit"
	[ "$PUSH" = 1 ] || { event "KEPT $key $status ${commit:0:9} (SHOTS_PUSH=0)"; return 0; }
	shots_git_retry push -q "$REMOTE" "$commit:${SHOTS_RES_PREFIX}$key" >>"$S/listener.log" 2>&1
}

# A request that stalls 5 times is given up on, so it can't block the queue.
stalled() { # key reason
	local n
	mkdir -p "$S/tries"
	n=$(($(cat "$S/tries/$1" 2>/dev/null || echo 0) + 1))
	echo "$n" >"$S/tries/$1"
	if [ "$n" -ge 5 ]; then
		mkdir -p "$S/done"
		echo "$2 gave-up $(shots_epoch)" >"$S/done/$1"
		event "GAVE UP $1 after 5 tries: $3"
	else
		event "STALLED $1: $3; retrying next poll"
	fi
	return 1
}

# Handles one request. 0 answered, 1 failed to answer (retry later), 75 deferred.
handle() { # key sha
	local key="$1" sha="$2" status=ok err="" t0
	if owner_playing; then
		[ -f "$S/deferring" ] || event "WAITING the owner's game is running; $key and later requests wait"
		touch "$S/deferring"
		return 75
	fi
	rm -f "$S/deferring"
	t0=$(shots_epoch)
	event "RENDERING $key ${sha:0:9}"
	shots_run_limited 900 "$S/listener.log" git fetch -q "$REMOTE" "+${SHOTS_REQ_PREFIX}$key:refs/mq/shots/req/$key"
	if [ "$(git rev-parse -q --verify "refs/mq/shots/req/$key^{commit}")" != "$sha" ]; then
		stalled "$key" "$sha" "fetch failed or the branch moved"
		return 1
	fi
	RES="$S/work/$key/res"
	OUT="$S/work/$key/out"
	SCRATCH="$S/userdir"
	rm -rf "${S:?}/work/${key:?}"
	mkdir -p "$RES/logs" "$OUT"
	{
		echo "status PENDING"
		echo "request $key"
		echo "commit $sha"
		echo "machine $(hostname -s 2>/dev/null || echo mac)"
		echo "godot $GODOT_VERSION"
	} >"$RES/result.txt"
	# The same code and the same request were answered before: send that again.
	local tree prev
	tree=$(git rev-parse "$sha^{tree}")
	prev=$(cat "$S/bytree/$tree" 2>/dev/null)
	if [ -n "$prev" ] && git rev-parse -q --verify "refs/mq/shots/res/$prev" >/dev/null && republish "$key" "$sha" "$prev"; then
		mkdir -p "$S/done"
		echo "$sha reused $(shots_epoch)" >"$S/done/$key"
		rm -rf "${S:?}/work/${key:?}"
		event "ANSWERED $key from $prev (same code and request)"
		return 0
	fi
	if ! checkout_request "$sha"; then
		stalled "$key" "$sha" "checkout failed"
		return 1
	fi
	if [ -f "$WT/.shots/request.json" ]; then
		echo "route request.json" >>"$RES/result.txt"
		cp "$WT/.shots/request.json" "$RES/request.json"
		# shot_request.md: "quality":"full" is a look request, anything else is layout.
		# The runner picks its own renderer, so no --rendering-method from here.
		QUALITY=layout METHOD="" SIZE=1920x1080 PREPS=""
		grep -Eq '"quality"[[:space:]]*:[[:space:]]*"full"' "$WT/.shots/request.json" && QUALITY=look
		echo "quality $QUALITY" >>"$RES/result.txt"
		if ! prepare; then status=error; err="prep failed"
		elif ! run_json; then status=fail; fi
	elif [ -f "$WT/.shots/probes.txt" ]; then
		cp "$WT/.shots/probes.txt" "$RES/probes.txt"
		if ! parse_probes >"$RES/parse.err"; then status=error; err=$(cat "$RES/parse.err")
		else
			echo "quality $QUALITY" >>"$RES/result.txt"
			echo "size $SIZE" >>"$RES/result.txt"
			echo "renderer ${METHOD:-project default}" >>"$RES/result.txt"
			if ! prepare; then status=error; err="prep failed"
			else
				local n_ok=0 n_bad=0 line
				while IFS= read -r line; do
					set -- $line
					shift
					if run_probe_line "$@"; then n_ok=$((n_ok + 1)); else n_bad=$((n_bad + 1)); fi
					heartbeat
				done <"$RES/plan.txt"
				[ "$n_bad" -gt 0 ] && status=partial
				[ "$n_ok" = 0 ] && status=fail
			fi
		fi
	else
		status=error
		err="the request commit has neither .shots/probes.txt nor .shots/request.json"
	fi
	[ -n "$err" ] && note "$err"
	echo "answered $(shots_now) after $(($(shots_epoch) - t0))s" >>"$RES/result.txt"
	sed "s/^status PENDING$/status $status/" "$RES/result.txt" >"$RES/result.tmp" && mv "$RES/result.tmp" "$RES/result.txt"
	rm -f "$RES/plan.txt" "$RES/parse.err"
	if ! publish "$key" "$status"; then
		stalled "$key" "$sha" "could not push the answer"
		return 1
	fi
	mkdir -p "$S/done" "$S/bytree"
	echo "$sha $status $(shots_epoch)" >"$S/done/$key"
	[ "$status" = ok ] && echo "$key" >"$S/bytree/$tree"
	rm -rf "${S:?}/work/${key:?}"
	event "ANSWERED $key $status in $(($(shots_epoch) - t0))s"
	return 0
}

# Answers <key> with the pictures of an earlier answer <prev>; only result.txt changes.
republish() { # key sha prev
	local idx tree blob commit
	idx=$(mktemp "${TMPDIR:-/tmp}/shots-idx.XXXXXX")
	rm -f "$idx"
	GIT_INDEX_FILE="$idx" git read-tree "refs/mq/shots/res/$3" || return 1
	blob=$(git show "refs/mq/shots/res/$3:result.txt" |
		sed -e "s/^request .*/request $1/" -e "s/^commit .*/commit $2/" -e "s/^answered .*/answered $(shots_now), reused from $3 (same code and request)/" |
		git hash-object -w --stdin) || return 1
	GIT_INDEX_FILE="$idx" git update-index --cacheinfo "100644,$blob,result.txt" || return 1
	tree=$(GIT_INDEX_FILE="$idx" git write-tree)
	rm -f "$idx"
	commit=$(GIT_AUTHOR_NAME="ACOTAR shot listener" GIT_AUTHOR_EMAIL="shots@localhost" \
		GIT_COMMITTER_NAME="ACOTAR shot listener" GIT_COMMITTER_EMAIL="shots@localhost" \
		git commit-tree "$tree" -m "shots res $1: reused $3") || return 1
	git update-ref "refs/mq/shots/res/$1" "$commit"
	[ "$PUSH" = 1 ] || return 0
	shots_git_retry push -q "$REMOTE" "$commit:${SHOTS_RES_PREFIX}$1" >>"$S/listener.log" 2>&1
}

# One poll: answer every new request, oldest first seen first.
poll() {
	local reqs ress key sha pinned rc
	reqs=$(mktemp "${TMPDIR:-/tmp}/shots-ls.XXXXXX")
	ress=$(mktemp "${TMPDIR:-/tmp}/shots-ls.XXXXXX")
	if ! shots_run_limited 60 "$reqs" git ls-remote "$REMOTE" "${SHOTS_REQ_PREFIX}*" "${SHOTS_RES_PREFIX}*"; then
		event "OFFLINE ls-remote failed; next poll in ${POLL}s"
		rm -f "$reqs" "$ress"
		return 1
	fi
	grep "	${SHOTS_RES_PREFIX}" "$reqs" | sed "s#.*	${SHOTS_RES_PREFIX}##" >"$ress"
	mkdir -p "$S/seen" "$S/done" "$S/ignored"
	grep "	${SHOTS_REQ_PREFIX}" "$reqs" | while read -r sha ref; do
		key="${ref#"$SHOTS_REQ_PREFIX"}"
		if ! shots_valid_key "$key"; then
			[ -f "$S/ignored/$(echo "$key" | tr -c 'A-Za-z0-9._-' _)" ] && continue
			: >"$S/ignored/$(echo "$key" | tr -c 'A-Za-z0-9._-' _)"
			event "IGNORED shots/req-$key: not <ID>-<n>"
			continue
		fi
		[ -f "$S/seen/$key" ] || echo "$sha $(shots_epoch)" >"$S/seen/$key"
		pinned=$(cut -d' ' -f1 "$S/seen/$key")
		[ -f "$S/done/$key" ] && continue
		if [ "$pinned" != "$sha" ]; then
			[ -f "$S/ignored/$key" ] || { : >"$S/ignored/$key"; event "IGNORED $key: moved after it was first seen; resubmit with the next number"; }
			continue
		fi
		if grep -qx "$key" "$ress"; then
			echo "$sha answered-elsewhere $(shots_epoch)" >"$S/done/$key"
			continue
		fi
		echo "$(cut -d' ' -f2 "$S/seen/$key") $key $sha"
	done | sort -n | while read -r _ key sha; do
		handle "$key" "$sha"
		rc=$?
		[ "$rc" = 75 ] && break
		keep_awake
		heartbeat
	done
	rm -f "$reqs" "$ress"
	return 0
}

# Deletes this machine's own result branches after SHOTS_KEEP_DAYS. Only refs
# it pushed itself (recorded in done/ and still at the commit it pushed).
prune_results() {
	[ "$PUSH" = 1 ] || return 0
	local f key mine cutoff
	cutoff=$(($(shots_epoch) - KEEP_DAYS * 86400))
	[ -f "$S/last_prune" ] && [ $(($(shots_epoch) - $(shots_mtime "$S/last_prune"))) -lt 3600 ] && return 0
	touch "$S/last_prune"
	for f in "$S"/done/*; do
		[ -f "$f" ] || continue
		key=$(basename "$f")
		[ "$(cut -d' ' -f3 "$f")" -lt "$cutoff" ] 2>/dev/null || continue
		mine=$(git rev-parse -q --verify "refs/mq/shots/res/$key") || continue
		if git push -q "$REMOTE" --force-with-lease="${SHOTS_RES_PREFIX}$key:$mine" ":${SHOTS_RES_PREFIX}$key" >>"$S/listener.log" 2>&1; then
			git update-ref -d "refs/mq/shots/res/$key"
			git update-ref -d "refs/mq/shots/req/$key" 2>/dev/null
			event "PRUNED shots/res-$key"
		fi
	done
}

setup_run() {
	refuse_unless_home
	GODOT=$(find_godot) || { event "STALLED no Godot found (set SHOTS_GODOT in $CONF)"; shots_die "no Godot found; set SHOTS_GODOT=/path/to/Godot in $CONF"; }
	GODOT_VERSION=$("$GODOT" --version 2>/dev/null | head -1)
	cd_lane
}

# The listener's cwd is its own standing lane, never the play folder (that is for
# playing only). Without the lane (a bare repo, a selftest) it stays where it is.
LANE="$REPO/.lanes/shots-lane"
cd_lane() { if [ -d "$LANE" ]; then cd "$LANE" || exit 1; fi; }

# The loop runs from a copy of these scripts, so `make update` can rewrite the
# installed ones in .git/mq/bin (which only change when tools/mq merges, never the
# play folder's copy) can be updated safely; it re-execs onto the new copy when they change.
SRC_SUM=""
src_sum() { cat "$MQ/bin/shots.sh" "$MQ/bin/shots_common.sh" 2>/dev/null | cksum; }

loop() {
	setup_run
	take_lock || shots_die "another listener is running (pid $(lock_pid))"
	trap 'p=$(cat "$SHOTS_CHILD_FILE" 2>/dev/null); [ -n "$p" ] && kill -TERM "$p" 2>/dev/null; release_lock; event "STOPPED listener $$"; exit 0' TERM INT
	event "STARTED listener $$ ($GODOT_VERSION, poll ${POLL}s)"
	SRC_SUM=$(src_sum)
	while :; do
		heartbeat
		keep_awake
		poll
		prune_results
		if [ "$(src_sum)" != "$SRC_SUM" ]; then
			event "RESTARTING onto updated listener scripts"
			mkdir -p "$S/bin"
			cp "$MQ/bin/shots.sh" "$MQ/bin/shots_common.sh" "$S/bin/"
			exec bash "$S/bin/shots.sh" --loop-here
		fi
		local n=0
		while [ "$n" -lt "$POLL" ]; do sleep 10 & wait $!; n=$((n + 10)); heartbeat; done
	done
}

start() {
	refuse_unless_home
	find_godot >/dev/null || shots_die "no Godot found; run make update, or set SHOTS_GODOT=/path/to/Godot in $CONF"
	if listener_running; then echo "Shot listener already running (pid $(lock_pid))."; return 0; fi
	mkdir -p "$S/bin"
	cp "$SHOTS_SELF_DIR/shots.sh" "$SHOTS_SELF_DIR/shots_common.sh" "$S/bin/"
	(cd_lane && nohup bash "$S/bin/shots.sh" --loop-here </dev/null >>"$S/listener.log" 2>&1 &)
	local i=0
	while [ "$i" -lt 10 ] && ! listener_running; do sleep 1; i=$((i + 1)); done
	listener_running && echo "Shot listener started (pid $(lock_pid)). Log: $EVENTS" || shots_die "listener did not start; see $S/listener.log"
}

stop() {
	local p c
	p=$(lock_pid)
	if [ -z "$p" ] || ! kill -0 "$p" 2>/dev/null; then echo "Shot listener is not running."; rm -rf "${LOCK:?}"; return 0; fi
	c=$(cat "$SHOTS_CHILD_FILE" 2>/dev/null)
	[ -n "$c" ] && kill -TERM "$c" 2>/dev/null
	kill -TERM "$p"
	local i=0
	while [ "$i" -lt 20 ] && kill -0 "$p" 2>/dev/null; do sleep 1; i=$((i + 1)); done
	kill -0 "$p" 2>/dev/null && { kill -KILL "$p"; rm -rf "${LOCK:?}"; }
	echo "Shot listener stopped (pid $p)."
}

status() {
	echo "Shot listener"
	if ! home_machine; then echo "  not the home machine (no MQ_HOME_MACHINE=1 in $CONF): requests are rendered elsewhere"; fi
	if listener_running; then
		echo "  running, pid $(lock_pid), heartbeat $(($(shots_epoch) - $(shots_mtime "$LOCK/heartbeat")))s ago"
	else echo "  stopped"; fi
	echo "  answered: $(ls "$S/done" 2>/dev/null | wc -l | tr -d ' ')"
	[ -f "$S/deferring" ] && echo "  waiting: the owner's game is running"
	echo "  recent:"
	tail -8 "$EVENTS" 2>/dev/null | sed 's/^/    /'
}

check() {
	local ok=0 g
	if home_machine; then echo "ok   home machine mark"; else echo "FAIL no MQ_HOME_MACHINE=1 in $CONF"; ok=1; fi
	if g=$(find_godot); then echo "ok   Godot: $g ($("$g" --version 2>/dev/null | head -1))"; else echo "FAIL no Godot (make update, or SHOTS_GODOT= in $CONF)"; ok=1; fi
	if git ls-remote "$REMOTE" HEAD >/dev/null 2>&1; then echo "ok   can read $REMOTE"; else echo "FAIL cannot read $REMOTE"; ok=1; fi
	if git push --dry-run -q "$REMOTE" "$(git rev-parse HEAD):refs/heads/shots/res-check-0" >/dev/null 2>&1; then
		echo "ok   can push result branches"
	else echo "FAIL cannot push to $REMOTE (sign in: gh auth login, or a GitHub token in the keychain)"; ok=1; fi
	command -v caffeinate >/dev/null 2>&1 && echo "ok   caffeinate" || echo "info no caffeinate (not a Mac?)"
	return "$ok"
}

case "${1:-}" in
--start) start ;;
--stop) stop ;;
--status) status ;;
--check) check ;;
--once)
	setup_run
	take_lock || shots_die "the listener is running (pid $(lock_pid)); use --stop first"
	SHOTS_VERBOSE=1
	poll
	rm -f "$S/last_prune"
	prune_results
	release_lock ;;
--loop-here) loop ;;
*) sed -n '2,13p' "$0" | sed 's/^# \{0,1\}//'; exit 1 ;;
esac
