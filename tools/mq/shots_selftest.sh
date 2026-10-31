#!/bin/bash
# Proves the shot listener in throwaway repos with a stand-in Godot and a
# throwaway origin. Safe anywhere: touches nothing outside its temp folder.
#   tools/mq/shots_selftest.sh            (prints PASS/FAIL per scenario)
set -u
HERE=$(cd "$(dirname "$0")" && pwd -P)
# Physical path: on a Mac $TMPDIR is /var/... but git reports /private/var/...
T=$(cd "$(mktemp -d "${TMPDIR:-/tmp}/shots-selftest.XXXXXX")" && pwd -P)
trap 'pkill -f "$T" 2>/dev/null; rm -rf "$T"' EXIT
export GIT_AUTHOR_NAME=t GIT_AUTHOR_EMAIL=t@t GIT_COMMITTER_NAME=t GIT_COMMITTER_EMAIL=t@t
export GIT_CONFIG_GLOBAL=/dev/null GIT_CONFIG_NOSYSTEM=1
unset DISPLAY
FAILS=0 PASSES=0
pass() { echo "PASS $*"; PASSES=$((PASSES + 1)); }
fail() { echo "FAIL $*"; FAILS=$((FAILS + 1)); }
check() { if eval "$2"; then pass "$1"; else fail "$1"; fi; }
jpeg_is_1280_wide() { # stdin
	cat >"$T/check.jpg"
	if command -v sips >/dev/null 2>&1; then
		[ "$(sips -g pixelWidth "$T/check.jpg" | awk '/pixelWidth/ {print $2}')" = 1280 ]
	else
		python3 -I -c "import sys; from PIL import Image; sys.exit(Image.open(sys.argv[1]).size != (1280, 26))" "$T/check.jpg"
	fi
}

# ---- stand-in Godot: logs every call; user args choose what a probe does
mkdir -p "$T/bin"
cat >"$T/bin/godot" <<'G'
#!/bin/bash
echo "CALL $* | HOME=$HOME XDG_DATA_HOME=${XDG_DATA_HOME:-}" >>"$FAKE_LOG"
[ "$1" = --version ] && { echo 4.7.2.stable.fake; exit 0; }
path="" prev=""
for a in "$@"; do [ "$prev" = --path ] && path="$a"; prev="$a"; done
for a in "$@"; do [ "$a" = --import ] && { mkdir -p "$path/.godot"; exit 0; }; done
user=() seen=0
for a in "$@"; do [ "$seen" = 1 ] && user+=("$a"); [ "$a" = -- ] && seen=1; done
[ "$seen" = 0 ] && exit 0   # generator / prep run
[ -f "$XDG_DATA_HOME/godot/app_userdata/game/save.cfg" ] && { echo "stale save from an earlier run"; exit 9; }
mkdir -p "$XDG_DATA_HOME/godot/app_userdata/game/shader_cache" && echo save >"$XDG_DATA_HOME/godot/app_userdata/game/save.cfg"
echo c >>"$XDG_DATA_HOME/godot/app_userdata/game/shader_cache/c"
case "${user[0]:-}" in
ok) { base64 --decode <"$FAKE_PNG" 2>/dev/null || base64 -D <"$FAKE_PNG"; } >"${user[1]}"; echo "SHOT ok draw_calls 12" ;;
two) printf '\211PNG' >"${user[1]}/one.png"; printf '\211PNG' >"${user[1]}/two.png"; echo '{"n":2}' >"${user[1]}/stats.json" ;;
fail) echo "SCRIPT ERROR: boom"; exit 1 ;;
hang) echo $$ >"$FAKE_HANG"; exec sleep 300 ;;
stubborn) trap '' TERM; sleep 300 & echo $! >"$FAKE_HANG"; wait ;;
slow) # true for ever more than one at a time, as two listeners would be
	mkdir "$FAKE_BUSY" 2>/dev/null || echo "COLLISION" >>"$FAKE_LOG"
	echo $$ >"$FAKE_HANG"; sleep "${user[1]}"; rmdir "$FAKE_BUSY" 2>/dev/null ;;
esac
exit 0
G
chmod +x "$T/bin/godot"
export FAKE_LOG="$T/fake.log" FAKE_PNG="$T/fake.png.b64" FAKE_HANG="$T/hang.pid" FAKE_BUSY="$T/busy"
echo "iVBORw0KGgoAAAANSUhEUgAAB9AAAAAoCAIAAAApPPbUAAABY0lEQVR42u3YQQEAEADAQPSPI4lChLDnXYQ9N+8+AwAAAAAA+LMkAAAAAACAf4Y7AAAAAAAEDHcAAAAAAAgY7gAAAAAAEDDcAQAAAAAgYLgDAAAAAEDAcAcAAAAAgIDhDgAAAAAAAcMdAAAAAAAChjsAAAAAAAQMdwAAAAAACBjuAAAAAAAQMNwBAAAAACBguAMAAAAAQMBwBwAAAACAgOEOAAAAAAABwx0AAAAAAAKGOwAAAAAABAx3AAAAAAAIGO4AAAAAABAw3AEAAAAAIGC4AwAAAABAwHAHAAAAAICA4Q4AAAAAAAHDHQAAAAAAAoY7AAAAAAAEDHcAAAAAAAgY7gAAAAAAEDDcAQAAAAAgYLgDAAAAAEDAcAcAAAAAgIDhDgAAAAAAAcMdAAAAAAAChjsAAAAAAAQMdwAAAAAACBjuAAAAAAAQMNwBAAAAACBguAMAAAAAQMBwBwAAAACAwAMukgLVabod5gAAAABJRU5ErkJggg==" >"$FAKE_PNG"   # a real 2000x40 PNG
: >"$FAKE_LOG"

# ---- a tiny game repo with the scripts under test, and its origin
git init -q --bare "$T/origin.git" && git --git-dir="$T/origin.git" symbolic-ref HEAD refs/heads/main
git init -q -b main "$T/src"
mkdir -p "$T/src/tools/mq" "$T/src/tools/generators" "$T/src/probe"
cp "$HERE"/shots*.sh "$T/src/tools/mq/"
echo '[application]' >"$T/src/project.godot"
echo 'extends SceneTree' >"$T/src/tools/generators/gen.gd"
mkdir -p "$T/src/gen" && echo v1 >"$T/src/gen/input.txt" && echo 'extends SceneTree' >"$T/src/gen/make.gd"
echo '_generated/' >"$T/src/.gitignore"
# Stand-in for the build queue's levels.sh (its own selftest covers the cache).
cat >"$T/src/tools/mq/levels.sh" <<'L'
echo "LEVELS ensure in $PWD" >>"$FAKE_LOG"
mkdir -p gen/_generated && cat gen/input.txt >gen/_generated/out.res
L
echo png >"$T/src/probe/art.png"
echo '[gd_scene format=3]' >"$T/src/probe/shot.tscn"
echo 'extends SceneTree' >"$T/src/probe/check.gd"
(cd "$T/src" && git add -A && git commit -qm init && git remote add origin "$T/origin.git" && git push -q origin main)

git clone -q "$T/origin.git" "$T/mac"
git clone -q "$T/origin.git" "$T/cloud"
git clone -q "$T/origin.git" "$T/other"
mkdir -p "$T/mac/.git/mq"
printf 'MQ_HOME_MACHINE=1\nSHOTS_GODOT=%s\nMQ_CAFFEINATE=0\nSHOTS_POLL=10\n' "$T/bin/godot" >"$T/mac/.git/mq/config"
MAC="$T/mac/tools/mq/shots.sh"
REQ="$T/cloud/tools/mq/shots_request.sh"
FETCH="$T/cloud/tools/mq/shots_fetch.sh"
once() { (cd "$T/mac" && bash "$MAC" --once) >>"$T/mac.out" 2>&1; }
res() { git --git-dir="$T/origin.git" rev-parse -q --verify "refs/heads/shots/res-$1" >/dev/null; }
result() { git --git-dir="$T/origin.git" show "refs/heads/shots/res-$1:result.txt" 2>/dev/null; }
request() { # key-id n body
	printf '%b' "$3" >"$T/req.txt"
	(cd "$T/cloud" && bash "$REQ" "$1" "$2" "$T/req.txt") >>"$T/cloud.out" 2>&1
}

# 1 refuses without the home-machine mark, even with the env var set
out=$(cd "$T/other" && MQ_HOME_MACHINE=1 bash tools/mq/shots.sh --once 2>&1); rc=$?
check "refuses without MQ_HOME_MACHINE=1 in .git/mq/config" '[ $rc = 2 ] && echo "$out" | grep -q REFUSED'

# 2 a good request is answered with pictures on an orphan branch
request A 1 'from selftest\nquality layout\nsize 640x360\nshot cottage res://probe/shot.tscn ok {out}/cottage.png\nshot many res://probe/check.gd two {out}\n'
once
check "answers a good request with status ok" 'result A-1 | grep -qx "status ok"'
files=$(git --git-dir="$T/origin.git" ls-tree -r --name-only refs/heads/shots/res-A-1)
check "result holds every picture and stats file" 'echo "$files" | grep -qx out/cottage/cottage.jpg && echo "$files" | grep -qx out/many/two.png && echo "$files" | grep -qx out/many/stats.json'
check "result is an orphan commit (no game files)" '[ -z "$(git --git-dir="$T/origin.git" rev-list --parents -1 refs/heads/shots/res-A-1 | cut -s -d" " -f2)" ] && ! echo "$files" | grep -q project.godot'
check "renders windowed in the corner, Dummy audio, request size" 'grep "probe/shot.tscn" "$FAKE_LOG" | grep -q -- "--audio-driver Dummy --windowed --resolution 640x360 --position 40,40 --always-on-top"'
check "script probes run with -s, args after --" 'grep -q -- "-s res://probe/check.gd -- two" "$FAKE_LOG"'
check "the import ran headless before the shots" 'grep -q -- "--headless --audio-driver Dummy --path .* --import" "$FAKE_LOG"'
check "generated content comes from the queue's levels.sh, run in the render worktree" 'grep -q "LEVELS ensure in $T/mac/.lanes/shots$" "$FAKE_LOG" && result A-1 | grep -q "generated content .*(levels.sh)" && [ "$(cat "$T/mac/.lanes/shots/gen/_generated/out.res")" = v1 ]'
check "with levels.sh, tools/generators are not run a second time" '! grep -q "res://tools/generators/gen.gd" "$FAKE_LOG"'
check "quality layout pictures come back as JPEG, 1280 wide" '! echo "$files" | grep -qx out/cottage/cottage.png && git --git-dir="$T/origin.git" show refs/heads/shots/res-A-1:out/cottage/cottage.jpg | jpeg_is_1280_wide'
check "user:// is a scratch folder, never the owner's" '! grep "probe/" "$FAKE_LOG" | grep -v "HOME=$T/mac/.git/mq/shots/userdir/" | grep -q . && [ ! -d "$HOME/.local/share/godot/app_userdata/game" ] && [ ! -d "$T/mac/.git/mq/shots/work/A-1" ]'
check "each run starts with an empty user:// but keeps the shader cache" '[ "$(wc -l <"$T/mac/.git/mq/shots/userdir/data/godot/app_userdata/game/shader_cache/c")" -ge 2 ]'
check "the play folder stays on main, untouched" '[ "$(git -C "$T/mac" rev-parse --abbrev-ref HEAD)" = main ] && [ -z "$(git -C "$T/mac" status --porcelain)" ]'

# 3 fetch from the cloud side
out=$(cd "$T/cloud" && bash "$FETCH" A 1 "$T/got" 2>&1)
check "shots_fetch unpacks the answer" '[ -s "$T/got/out/cottage/cottage.jpg" ] && echo "$out" | grep -q "status ok"'
out=$(cd "$T/cloud" && bash "$FETCH" Z 1 "$T/got2" 2>&1); rc=$?
check "shots_fetch says 'no request' and exits 3 for an unknown one" '[ $rc = 3 ] && echo "$out" | grep -q "no request"'

# 4 answered once only
n=$(grep -vc -- "--version" "$FAKE_LOG"); once
check "an answered request is not rendered again" '[ "$(grep -vc -- "--version" "$FAKE_LOG")" = "$n" ]'
check "request names are never reused" '! (cd "$T/cloud" && bash "$REQ" A 1 "$T/req.txt" 2>/dev/null)'

# 5 partial, timeout, malformed
request B 1 'shot good res://probe/shot.tscn ok {out}/g.png\nshot bad res://probe/shot.tscn fail\n'
request C 1 'timeout 2\nshot slow res://probe/shot.tscn hang\n'
request C 2 'timeout 2\nsize 1920x1080\nshot stuck res://probe/shot.tscn stubborn\n'
request D 1 'shot x res://probe/shot.tscn ok\nexplode now\n'
request E 1 'shot x res://probe/missing.tscn ok\n'
once
check "one failing probe gives status partial with its exit code" 'result B-1 | grep -qx "status partial" && result B-1 | grep -q "^shot bad fail exit=1"'
check "the failing probe's log is in the answer" 'git --git-dir="$T/origin.git" show refs/heads/shots/res-B-1:logs/bad.log | grep -q "SCRIPT ERROR"'
check "a hung probe is stopped at its timeout" 'result C-1 | grep -q "^shot slow timeout exit=124"'
check "a child that ignores TERM is reported as a timeout and is gone" 'result C-2 | grep -q "^shot stuck timeout exit=124" && ! kill -0 "$(cat "$FAKE_HANG")" 2>/dev/null'
check "a malformed request is answered with the reason" 'result D-1 | grep -qx "status error" && result D-1 | grep -q "note unknown line: explode"'
check "a probe missing from the commit is named" 'result E-1 | grep -q "note no such file in the commit: res://probe/missing.tscn"'

# 6 request.json route
printf '{"id":"J","quality":"full"}' >"$T/req.json"
(cd "$T/cloud" && bash "$REQ" J 1 "$T/req.json") >>"$T/cloud.out" 2>&1
mkdir -p "$T/cloud/tools/shots"
cat >"$T/cloud/tools/shots/take_shots.sh" <<'W'
#!/bin/bash
"$GODOT" $SHOTS_GODOT_ARGS res://tools/shots/shot_runner.tscn -- ok "$2/layout.png" "$1"
echo '{"id":"J"}' >"$2/results.json"
W
(cd "$T/cloud" && git add -A && git commit -qm "runner" && git push -q origin HEAD:refs/heads/lane/x && bash "$REQ" J 2 "$T/req.json") >>"$T/cloud.out" 2>&1
once
check "request.json without the runner is answered with the reason" 'result J-1 | grep -q "note request.json needs tools/shots/take_shots.sh"'
check "request.json runs the commit's take_shots.sh with GODOT and SHOTS_GODOT_ARGS" 'result J-2 | grep -qx "status ok" && git --git-dir="$T/origin.git" ls-tree -r --name-only refs/heads/shots/res-J-2 | grep -qx out/request/layout.png && grep "shot_runner" "$FAKE_LOG" | grep -q -- "--audio-driver Dummy --windowed"'

# 7 moved and junk requests are ignored
request M 1 'shot x res://probe/shot.tscn ok {out}/x.png\n'
(cd "$T/mac" && bash "$MAC" --once >/dev/null 2>&1)  # answers M-1
(cd "$T/cloud" && git push -q origin HEAD:refs/heads/shots/req-N-1) # request without a request file
git --git-dir="$T/origin.git" update-ref refs/heads/shots/req-junk "$(git --git-dir="$T/origin.git" rev-parse main)"
git --git-dir="$T/origin.git" update-ref refs/heads/shots/req-P-1 "$(git --git-dir="$T/origin.git" rev-parse main)"
mkdir -p "$T/mac/.git/mq/shots/seen" && echo "0000000000000000000000000000000000000000 1" >"$T/mac/.git/mq/shots/seen/P-1"
once
check "a request without a request file is answered with the reason" 'result N-1 | grep -q "neither .shots/probes.txt nor .shots/request.json"'
check "a request that moved after it was seen is ignored, not rendered" '! res P-1 && grep -q "IGNORED P-1: moved" "$T/mac/.git/mq/shots/events.log"'
check "a branch not named <ID>-<n> is ignored" '! res junk && grep -q "IGNORED shots/req-junk" "$T/mac/.git/mq/shots/events.log"'
check "the listener never pushed anything but result branches" '[ -z "$(git --git-dir="$T/origin.git" for-each-ref --format="%(refname)" refs/heads | grep -v -e "^refs/heads/main$" -e "^refs/heads/lane/x$" -e "^refs/heads/shots/req-" -e "^refs/heads/shots/res-")" ] && [ "$(git --git-dir="$T/origin.git" rev-parse main)" = "$(git -C "$T/src" rev-parse main)" ]'

# 8 the owner's game comes first; a Godot anywhere else doesn't count
fake_game() { # cwd args...: a process that looks like Godot on the outside
	local d="$1"; shift
	(cd "$d" && exec bash -c "exec -a '/Applications/Godot.app/Contents/MacOS/Godot $*' sleep 60") &
	gp=$!
	sleep 1
}
fake_game "$T/other" --path "$T/other" --remote-debug tcp://127.0.0.1:6007
request O 1 'shot x res://probe/shot.tscn ok {out}/x.png\n'
once
kill $gp; wait $gp 2>/dev/null
check "a Godot in another folder doesn't hold requests" 'result O-1 | grep -qx "status ok"'
fake_game "$T/mac" --path . --headless
request O 2 'shot y res://probe/shot.tscn ok {out}/y.png\n'
once
kill $gp; wait $gp 2>/dev/null
check "nor does a headless one in the play folder" 'result O-2 | grep -qx "status ok"'
fake_game "$T/mac" --path .
request W 1 'shot x res://probe/shot.tscn ok {out}/w.png\n'
once
check "requests wait while the owner's game is running (make play)" '! res W-1 && grep -q "WAITING the owner" "$T/mac/.git/mq/shots/events.log"'
kill $gp; wait $gp 2>/dev/null
fake_game "$T" --path "$T/mac" --remote-debug tcp://127.0.0.1:6007
once
check "and for Play from the editor" '! res W-1'
kill $gp; wait $gp 2>/dev/null
once
check "and are rendered once it closes" 'result W-1 | grep -qx "status ok"'

# 9 background start, answer, stop
git -C "$T/mac" worktree add -q --detach "$T/mac/.lanes/shots-lane" HEAD >>"$T/mac.out" 2>&1
mkdir -p "$T/mac/.git/mq/bin" && cp "$T/mac/tools/mq/shots.sh" "$T/mac/tools/mq/shots_common.sh" "$T/mac/.git/mq/bin/"
(cd "$T/mac" && bash "$MAC" --start) >>"$T/mac.out" 2>&1
lp=$(cat "$T/mac/.git/mq/shots/lock/pid" 2>/dev/null)
check "the listener's cwd is .lanes/shots-lane, not the play folder" '[ "$(lsof -a -d cwd -p "$lp" -Fn 2>/dev/null | sed -n "s/^n//p")" = "$T/mac/.lanes/shots-lane" ]'
echo "# play folder edit" >>"$T/mac/tools/mq/shots.sh"
sleep 13
check "a change to the play folder's copy does not restart it" '! grep -q RESTARTING "$T/mac/.git/mq/shots/events.log"'
echo "# installed copy updated" >>"$T/mac/.git/mq/bin/shots.sh"
i=0; while [ $i -lt 30 ] && ! grep -q RESTARTING "$T/mac/.git/mq/shots/events.log"; do sleep 1; i=$((i + 1)); done
check "a change to the installed copy restarts it, still in .lanes/shots-lane" 'grep -q RESTARTING "$T/mac/.git/mq/shots/events.log" && sleep 2 && [ "$(lsof -a -d cwd -p "$(cat "$T/mac/.git/mq/shots/lock/pid")" -Fn 2>/dev/null | sed -n "s/^n//p")" = "$T/mac/.lanes/shots-lane" ]'
git -C "$T/mac" checkout -q tools/mq/shots.sh
request S 1 'shot x res://probe/shot.tscn ok {out}/x.png\n'
i=0; while [ $i -lt 40 ] && ! res S-1; do sleep 1; i=$((i + 1)); done
check "the background listener answers new requests" 'res S-1'
out=$(cd "$T/mac" && bash "$MAC" --status 2>&1)
check "--status shows it running" 'echo "$out" | grep -q "running, pid"'
# a merge arrives mid-render: the render finishes, then the listener moves
request R 1 'size 1920x1080\nshot long res://probe/shot.tscn slow 8\n'
i=0; while [ $i -lt 40 ] && ! grep -q "RENDERING R-1" "$T/mac/.git/mq/shots/events.log"; do sleep 1; i=$((i + 1)); done
i=0; while [ $i -lt 20 ] && [ ! -d "$FAKE_BUSY" ]; do sleep 1; i=$((i + 1)); done
n=$(grep -c RESTARTING "$T/mac/.git/mq/shots/events.log")
echo "# a merge" >>"$T/mac/.git/mq/bin/shots.sh"
sleep 2
check "a merge mid-render doesn't restart the listener" '[ -d "$FAKE_BUSY" ] && [ "$(grep -c RESTARTING "$T/mac/.git/mq/shots/events.log")" = "$n" ]'
i=0; while [ $i -lt 40 ] && [ "$(grep -c RESTARTING "$T/mac/.git/mq/shots/events.log")" = "$n" ]; do sleep 1; i=$((i + 1)); done
check "it finishes that render, then restarts, with one render at a time" 'result R-1 | grep -q "^shot long ok" && [ "$(grep -c RESTARTING "$T/mac/.git/mq/shots/events.log")" -gt "$n" ] && ! grep -q COLLISION "$FAKE_LOG"'
# --stop mid-render: the listener, its render and the child all go at once
request Q 1 'size 1920x1080\nshot long res://probe/shot.tscn slow 120\n'
i=0; while [ $i -lt 40 ] && [ ! -d "$FAKE_BUSY" ]; do sleep 1; i=$((i + 1)); done
hp=$(cat "$FAKE_HANG"); t0=$(date +%s)
(cd "$T/mac" && bash "$MAC" --stop) >>"$T/mac.out" 2>&1
rmdir "$FAKE_BUSY" 2>/dev/null
check "--stop stops it and frees the lock" '[ ! -d "$T/mac/.git/mq/shots/lock" ]'
check "--stop runs the listener's trap, not a kill -9" '[ $(($(date +%s) - t0)) -lt 15 ] && grep -q "STOPPED listener" "$T/mac/.git/mq/shots/events.log"'
check "--stop leaves no render behind" '! kill -0 "$hp" 2>/dev/null && [ -z "$(ps -A -o command= | grep -F -- "--path $T/mac/.lanes/shots " | grep -v grep)" ]'
# a render nobody owns (a listener killed outright) holds the queue, then --stop clears it
(exec bash -c "exec -a 'Godot --path $T/mac/.lanes/shots --windowed' sleep 120") &
gp=$!
sleep 1
once
check "a new listener won't render beside a render it doesn't own" '! res Q-1 && grep -q "WAITING a render is already running" "$T/mac/.git/mq/shots/events.log"'
out=$(cd "$T/mac" && bash "$MAC" --stop 2>&1)
wait $gp 2>/dev/null
check "--stop finds that leftover render and says so" '! kill -0 "$gp" 2>/dev/null && echo "$out" | grep -q "leftover render" && grep -q "STOPPED leftover render" "$T/mac/.git/mq/shots/events.log"'

# 10 cleanup: --done from the cloud, and the Mac prunes its own old answers
(cd "$T/cloud" && bash "$FETCH" A 1 "$T/got" --done) >/dev/null 2>&1
check "shots_fetch --done deletes the request and its answer" '! res A-1 && ! git --git-dir="$T/origin.git" rev-parse -q --verify refs/heads/shots/req-A-1 >/dev/null'
echo "SHOTS_KEEP_DAYS=0" >>"$T/mac/.git/mq/config"
sleep 1; once
check "the Mac prunes its own old answers, and leaves requests alone" '! res B-1 && git --git-dir="$T/origin.git" rev-parse -q --verify refs/heads/shots/req-B-1 >/dev/null'

# 11 quality tiers, generated-content cache, import skipping, reuse
sed -i.bak '/SHOTS_KEEP_DAYS=0/d' "$T/mac/.git/mq/config"
request L 1 'size 640x360\nshot x res://probe/shot.tscn ok {out}/x.png\n'
request L 2 'renderer compatibility\nshot x res://probe/shot.tscn ok {out}/x.png\n'
request L 3 'size 2560x1440\nshot x res://probe/shot.tscn ok {out}/x.png\n'
once
check "quality look refuses a small or cheap render" 'result L-1 | grep -q "note quality look renders at 1920x1080 or larger" && result L-2 | grep -q "note quality look renders with the project"'
check "quality look keeps the lossless PNG at full size" 'result L-3 | grep -qx "quality look" && git --git-dir="$T/origin.git" ls-tree -r --name-only refs/heads/shots/res-L-3 | grep -qx out/x/x.png && grep "L-3" "$FAKE_LOG" >/dev/null; grep -q -- "--resolution 2560x1440" "$FAKE_LOG"'
check "no art changed since the last import: import skipped" 'result L-3 | grep -q "import skipped"'
(cd "$T/cloud" && echo v2 >gen/input.txt && echo png2 >probe/art.png && git commit -qam "gen input and art" && git push -q origin HEAD:refs/heads/lane/x) >>"$T/cloud.out" 2>&1
request G 1 'shot x res://probe/shot.tscn ok {out}/x.png\n'
once
check "the request's own inputs reach levels.sh" '[ "$(cat "$T/mac/.lanes/shots/gen/_generated/out.res")" = v2 ]'
check "changed art: import runs" 'result G-1 | grep -q "prep ok .*: import [0-9]"'
request G 2 'shot x res://probe/shot.tscn ok {out}/x.png\n'
n=$(grep -c "probe/shot.tscn" "$FAKE_LOG"); once
check "same code and request: the earlier answer is resent, nothing rendered" 'result G-2 | grep -q "reused from G-1" && result G-2 | grep -qx "request G-2" && [ "$(grep -c "probe/shot.tscn" "$FAKE_LOG")" = "$n" ]'
(cd "$T/cloud" && echo 'class_name Fresh' >probe/fresh.gd && git add -A && git commit -qm "new class" && git push -q origin HEAD:refs/heads/lane/x) >>"$T/cloud.out" 2>&1
request K 1 'shot x res://probe/shot.tscn ok {out}/x.png\n'
once
check "a new script: import runs, so its class_name is known" 'result K-1 | grep -q "prep ok .*: import [0-9]"'
(cd "$T/cloud" && git rm -q tools/mq/levels.sh && git commit -qm "no queue" && git push -q origin HEAD:refs/heads/lane/x) >>"$T/cloud.out" 2>&1
request G 3 'shot x res://probe/shot.tscn ok {out}/x.png\n'
once
check "a commit without levels.sh still runs tools/generators" 'result G-3 | grep -q "gen.gd ran"'


echo "---"
echo "$PASSES passed, $FAILS failed"
[ "$FAILS" = 0 ] || { echo "listener output:"; tail -20 "$T/mac.out"; tail -20 "$T/mac/.git/mq/shots/events.log"; }
[ "$FAILS" = 0 ]
