#!/bin/bash
# Proves the build lane works, in throwaway repos with a fake engine.
#   tools/mq/selftest.sh           everything
#   tools/mq/selftest.sh <name>    one scenario
# The fake engine passes or fails based on files in the tree: `check a` fails
# if fail_a exists, or if both pair_a and pair_b do.
set -u
unset GIT_DIR GIT_WORK_TREE GIT_INDEX_FILE MQ_SCRATCH
SRC=$(cd "$(dirname "$0")" && pwd)
ROOT=$(mktemp -d "${TMPDIR:-/tmp}/mq-selftest.XXXXXX")
PASSED=0; FAILED=0; ONLY="${1:-}"
# Scenarios each get their own repo, so they run side by side.
JOBS=${MQ_SELFTEST_JOBS:-6}
stop_repo() { # repo: kills the loops it started
	local f
	for f in lock/pid cleanup.pid shots/lock/pid; do
		[ -f "$1/.git/mq/$f" ] 2>/dev/null && kill "$(cat "$1/.git/mq/$f")" 2>/dev/null
	done
}
cleanup_all() {
	local r p
	for p in $(jobs -p); do kill "$p" 2>/dev/null; done
	for r in "$ROOT"/*/repo; do [ -d "$r" ] && stop_repo "$r"; done
	wait 2>/dev/null
	rm -rf "$ROOT"
}
REPO=""
trap cleanup_all EXIT

FAKE="$ROOT/fake-godot"
cat > "$FAKE" <<'EOF'
#!/bin/bash
[ "$1" = "--version" ] && { echo "4.7.2.stable.fake"; exit 0; }
while [ "$#" -gt 0 ]; do
	case "$1" in
		--path) cd "$2"; shift 2 ;;
		--import) mkdir -p .godot
			grep -rh '^class_name ' --include='*.gd' . 2>/dev/null | sed 's/^class_name \([A-Za-z0-9_]*\).*/"class": \&"\1"/' > .godot/global_script_class_cache.cfg
			exit 0 ;;
		-s) s="$2"; shift 2 ;;
		check) t="$2"; shift 2 ;;
		-gtest=*) g="${1#-gtest=}"; shift ;;
		*) shift ;;
	esac
done
# GUT: fail_<test> fails that test; clash fails any engine that runs two.
if [ -n "${g:-}" ]; then
	case "$g" in *,*) [ -f clash ] && { echo "tests clashed"; exit 1; } ;; esac
	for x in $(echo "$g" | tr , ' '); do
		x=$(basename "$x" .gd); [ -f "fail_$x" ] && { echo "fake $x failed"; exit 1; }
	done
fi
case "${s:-}" in *parse_check.gd) exit 0 ;; esac
[ -f slow ] && sleep 30
[ "${t:-}" = a ] && [ -f race_me ] && [ -x "$(dirname "$0")/race.sh" ] && "$(dirname "$0")/race.sh" >/dev/null 2>&1
[ -f fail_build ] && [ "${t:-}" = build ] && exit 1
if [ "${t:-}" = a ] && [ -f flaky ]; then
	c="$(dirname "$(git rev-parse --git-common-dir)")/../flaky.count"
	[ -f "$c" ] || { touch "$c"; exit 1; }
fi
# Red on every run but the third: the batch, its retry, then one good run.
if [ "${t:-}" = c ] && [ -f flaky_load ]; then
	c="$(dirname "$(git rev-parse --git-common-dir)")/../flaky_load.count"
	r=$(( $(cat "$c" 2>/dev/null || echo 0) + 1 )); echo "$r" > "$c"
	[ "$r" = 3 ] || { echo "fake test c too slow"; exit 1; }
fi
[ -n "${t:-}" ] && [ -f "fail_$t" ] && { echo "fake test $t failed"; exit 1; }
[ "${t:-}" = b ] && [ -f pair_a ] && [ -f pair_b ] && { echo "pair failed"; exit 1; }
exit 0
EOF
chmod +x "$FAKE"

newrepo() { # a fresh origin, repo and queue
	local d="$ROOT/$1"
	mkdir -p "$d"
	git init -q --bare -b main "$d/origin.git"
	git clone -q "$d/origin.git" "$d/repo" 2>/dev/null
	REPO="$d/repo"
	cd "$REPO" || exit 1
	git checkout -q -B main
	git config user.name selftest; git config user.email selftest@example.invalid
	mkdir -p tools/mq
	cp "$SRC"/* "$SRC"/.gdignore tools/mq/
	rm -f tools/mq/generated.conf tools/mq/shots*
	cat > tools/mq/gate.conf <<'EOF'
first: parse = "$MQ_BIN/parse.sh"
a = "$MQ_BIN/godot.sh" check a
b = "$MQ_BIN/godot.sh" check b
c = "$MQ_BIN/godot.sh" check c
EOF
	: > tools/mq/generated.conf
	[ -n "${2:-}" ] && { mkdir -p "$(dirname "$2")"; touch "$2"; }
	[ -n "${2:-}" ] && cp "$SRC/../../.gitattributes" .gitattributes 2>/dev/null
	git add -A; git commit -q -m "base"; git push -q origin main
	git checkout -q --detach
	tools/mq/setup_lanes.sh --home >/dev/null
	cat >> .git/mq/config <<EOF
MQ_ENGINE=$FAKE
MQ_LANES=1
MQ_POLL=1
MQ_STALL_SECS=2
MQ_JOBS=2
MQ_CLEANUP_OFF=1
MQ_SUBMIT_NO_START=1
MQ_CLOUD=1
MQ_FETCH_TIMEOUT=20
EOF
	tools/mq/setup_lanes.sh >/dev/null
	# The lane starts detached: wait for its lock, or the stop can miss it.
	local i=0
	while [ ! -f .git/mq/lock/pid ] && [ "$i" -lt 100 ]; do perl -e 'select(undef,undef,undef,0.1)'; i=$((i + 1)); done
	stop_lane
}

stop_lane() {
	local p i=0
	p=$(cat .git/mq/lock/pid 2>/dev/null)
	[ -n "$p" ] && kill "$p" 2>/dev/null
	while [ -d .git/mq/lock ] && [ "$i" -lt 100 ]; do perl -e 'select(undef,undef,undef,0.1)'; i=$((i + 1)); done
}

start_lane() { tools/mq/setup_lanes.sh --start >/dev/null; }

change() { # change name file...: a commit on a branch from main, printed
	local name="$1" f; shift
	git checkout -q --no-track -b "ch/$name" origin/main 2>/dev/null || git checkout -q "ch/$name"
	for f in "$@"; do echo "$name" >> "$f"; done
	git add -A; git commit -q -m "$name"
	git rev-parse HEAD
	git checkout -q --detach origin/main
}

queue() { # queue sha task
	MQ_SUBMIT_SOURCE=cloud tools/mq/submit.sh "$1" "$2" >/dev/null 2>&1
}

drain() { # wait for an empty queue
	local i=0
	while [ "$i" -lt 240 ]; do
		if ! ls .git/mq/pending/*.entry >/dev/null 2>&1 && ! ls -d .git/mq/batches/* >/dev/null 2>&1; then
			return 0
		fi
		perl -e 'select(undef,undef,undef,0.25)'; i=$((i + 1))
	done
	echo "  queue never drained"; tail -5 .git/mq/events.log; return 1
}

in_main() { git fetch -q origin; git merge-base --is-ancestor "$1" origin/main; }
rejected() { grep -q "REJECTED $1 " .git/mq/events.log; }
expect() { # description, then a command
	local d="$1"; shift
	if "$@"; then :; else echo "  FAIL: $d"; CASE_OK=0; fi
}
not() { ! "$@"; }

# Runs one scenario in a subshell of its own; its output goes to $ROOT/out.NAME
# and its exit says whether it passed.
scenario() {
	local name="$1" t0=$SECONDS
	CASE_OK=1
	cd "$ROOT" || exit 1
	trap '[ -n "$REPO" ] && stop_repo "$REPO"' EXIT
	"case_$name"
	stop_lane 2>/dev/null
	if [ "$CASE_OK" = 1 ]; then echo "ok   $name ($((SECONDS - t0))s)"; exit 0
	else echo "FAIL $name ($((SECONDS - t0))s)"; exit 1; fi
}

# Four changes with one bad: first, middle, last. Each batch must take two runs
# of the failing test to find it.
four() { # position of the bad one
	local bad="$1" i s shas=""
	newrepo "bad$bad"
	i=1
	while [ "$i" -le 4 ]; do
		if [ "$i" = "$bad" ]; then s=$(change "c$i" "file$i" fail_b); else s=$(change "c$i" "file$i"); fi
		shas="$shas $s"; queue "$s" "T$i"; i=$((i + 1))
	done
	start_lane; drain
	i=1
	for s in $shas; do
		if [ "$i" = "$bad" ]; then expect "c$i rejected" rejected "T$i"; expect "c$i not merged" not in_main "$s"
		else expect "c$i merged" in_main "$s"; fi
		i=$((i + 1))
	done
}
case_bad_first() { four 1; }
case_bad_middle() { four 3; }
case_bad_last() { four 4; }

case_two_bad() {
	newrepo two
	local a b c
	a=$(change a one fail_a); b=$(change b two); c=$(change c three fail_c)
	queue "$a" T1; queue "$b" T2; queue "$c" T3
	start_lane; drain
	expect "T1 rejected" rejected T1
	expect "T3 rejected" rejected T3
	expect "T2 merged" in_main "$b"
}

case_pair() {
	newrepo pair
	local a b
	a=$(change a pair_a); b=$(change b pair_b)
	queue "$a" T1; queue "$b" T2
	start_lane; drain
	expect "earlier merged" in_main "$a"
	expect "later rejected" rejected T2
	expect "later not merged" not in_main "$b"
}

case_known_red() {
	newrepo red fail_c
	local a
	a=$(change a one)
	queue "$a" T1
	start_lane; drain
	expect "not blamed" in_main "$a"
	expect "red recorded" grep -q '^c$' ".git/mq/baseline/$(git rev-parse "$a~0^{commit}" >/dev/null; git rev-list --max-parents=0 main | head -1)"
}

case_clean() {
	newrepo clean
	local a b
	a=$(change a one); b=$(change b two)
	queue "$a" T1; queue "$b" T2
	start_lane; drain
	expect "first merged" in_main "$a"
	expect "second merged" in_main "$b"
}

case_conflict() {
	newrepo conflict
	local a b
	a=$(change a same); b=$(change b same)
	queue "$a" T1; queue "$b" T2
	start_lane; drain
	expect "first merged" in_main "$a"
	expect "second rejected for conflict" grep -q 'REJECTED T2 conflicts' .git/mq/events.log
}

# A resubmission sitting on a rewritten copy of its own merged first slice, whose
# next slice edits the same line: printed. The copy has another committer date.
stacked() { # first-sha name new-line
	git checkout -q --no-track -B "ch/$2" "$1~1"
	GIT_COMMITTER_DATE="2001-01-01T00:00:00 +0000" git cherry-pick "$1" >/dev/null
	echo "$3" > x; git commit -q -am "$2"
	git rev-parse HEAD
	git checkout -q --detach origin/main
}

set_x() { # name line: a commit on main's tip setting x, printed
	git fetch -q origin; git checkout -q --no-track -B "ch/$1" origin/main
	echo "$2" > x; git commit -q -am "$1"
	git rev-parse HEAD
	git checkout -q --detach origin/main
}

case_restacked() {
	newrepo restack
	local a b landed
	a=$(change a x)
	queue "$a" T1; start_lane; drain; stop_lane
	b=$(stacked "$a" b b); git push -q origin "$b:refs/heads/lead/ready-T9-2"
	tools/mq/pull_ready.sh
	start_lane; drain; stop_lane
	tools/mq/pull_ready.sh
	expect "not rejected" not rejected T9
	expect "said so" grep -q "RESTACKED T9 ${b:0:9} dropped 1 commit" .git/mq/events.log
	landed=$(sed -n 's/^landed=//p' .git/mq/done/merged/*-T9.entry)
	expect "the rest landed" in_main "$landed"
	expect "with its change" test "$(git show origin/main:x)" = b
	expect "submitted sha kept on the entry" grep -q "^sha=$b" .git/mq/done/merged/*-T9.entry
	expect "MERGED names where it went" grep -q "MERGED T9 .*restacked: ${b:0:9} is in main as ${landed:0:9}" .git/mq/events.log
	expect "merged tag on the submitted commit" test "$(git ls-remote origin 'refs/tags/merged/T9-2^{}' | cut -f1)" = "$b"
	expect "tag says where" sh -c "git cat-file -p refs/tags/merged/T9-2 | grep -q 'as $landed'"
}

# Dropping the copy leaves a real conflict: still rejected, and the batch goes on.
case_restack_conflict() {
	newrepo restackconf
	local a b c d
	a=$(change a x)
	queue "$a" T1; start_lane; drain; stop_lane
	c=$(set_x c c); queue "$c" T3; start_lane; drain; stop_lane
	b=$(stacked "$a" b b); d=$(change d other)
	queue "$b" T2; queue "$d" T4
	start_lane; drain
	expect "rejected for conflict" grep -q 'REJECTED T2 conflicts' .git/mq/events.log
	expect "not restacked" not grep -q 'RESTACKED T2' .git/mq/events.log
	expect "main's line kept" test "$(git show origin/main:x)" = c
	expect "the next entry merged" in_main "$d"
}

case_flaky() {
	newrepo flaky
	local a
	a=$(change a one flaky)
	queue "$a" T1
	start_lane; drain
	expect "flaky merged" in_main "$a"
	expect "logged" grep -q 'FLAKY a' .git/mq/events.log
}

# The last entry is never reached by the search, so it gets a run of its own. It
# passes, so nobody is blamed, and the rest of the gate still runs before landing.
case_flaky_last() {
	newrepo flakylast
	local a b c
	a=$(change a one); b=$(change b two); c=$(change c three flaky_load)
	queue "$a" T1; queue "$b" T2; queue "$c" T3
	start_lane; drain
	expect "last entry not blamed" not rejected T3
	expect "last entry merged" in_main "$c"
	expect "the rest merged" in_main "$a"
	expect "logged" grep -q 'FLAKY c ' .git/mq/events.log
	expect "the gate ran again after the good run" test "$(cat "$ROOT/flakylast/flaky_load.count")" = 4
	expect "not carried as known red" not grep -qx c ".git/mq/baseline/$(git rev-parse origin/main)"
}

case_stop_mid_batch() {
	newrepo stopbatch
	local a i=0
	a=$(change a one slow)
	queue "$a" T1
	start_lane
	while ! ls .git/mq/batches/*/*.entry >/dev/null 2>&1 && [ "$i" -lt 80 ]; do
		perl -e 'select(undef,undef,undef,0.1)'; i=$((i + 1))
	done
	sleep 1
	stop_lane
	expect "nothing merged" not in_main "$a"
	mv .git/mq/batches/* "$ROOT/x" 2>/dev/null; mv "$ROOT/x" .git/mq/batches/left
	start_lane
	i=0
	while ! grep -q RECOVERED .git/mq/events.log && [ "$i" -lt 80 ]; do perl -e 'select(undef,undef,undef,0.1)'; i=$((i + 1)); done
	expect "batch came back" grep -q RECOVERED .git/mq/events.log
	stop_lane
	expect "entry is queued again" test -n "$(ls .git/mq/pending/*.entry .git/mq/batches/*/*.entry 2>/dev/null)"
}

case_stall_no_engine() {
	newrepo stall
	local a
	a=$(change a one)
	queue "$a" T1
	cp .git/mq/config .git/mq/config.good
	sed -i '' "s#^MQ_ENGINE=.*#MQ_ENGINE=$ROOT/no-such-engine#" .git/mq/config
	start_lane
	local i=0
	while ! grep -q STALLED .git/mq/events.log && [ "$i" -lt 80 ]; do perl -e 'select(undef,undef,undef,0.25)'; i=$((i + 1)); done
	expect "stalled" grep -q STALLED .git/mq/events.log
	expect "not rejected" not rejected T1
	stop_lane
	cp .git/mq/config.good .git/mq/config
	start_lane; drain
	expect "merged after the engine came back" in_main "$a"
}

case_origin_ahead() {
	newrepo ahead
	local other="$ROOT/ahead/other" a o
	git clone -q "$ROOT/ahead/origin.git" "$other" 2>/dev/null
	( cd "$other" && git config user.name x && git config user.email x@example.invalid && echo x > from_origin && git add -A && git commit -q -m origin && git push -q origin main )
	o=$(git ls-remote origin refs/heads/main | cut -f1)
	a=$(change a one)
	queue "$a" T1
	start_lane; drain
	expect "lane change merged" in_main "$a"
	git fetch -q origin
	expect "origin work taken in" in_main "$o"
	expect "origin not forked" git merge-base --is-ancestor "$o" origin/main
}

case_built_file() {
	newrepo built
	local a
	a=$(change a sub/_generated/out.res 2>/dev/null || true)
	mkdir -p sub/_generated
	git checkout -q --no-track -b gen origin/main; echo x > sub/_generated/out.res; git add -f sub; git commit -q -m gen
	a=$(git rev-parse HEAD); git checkout -q --detach origin/main
	expect "submit refuses" not queue "$a" T1
}

# Two lanes appending to the end of docs/program.md merge: .gitattributes says union.
case_union_log() {
	newrepo union docs/program.md
	local a b
	a=$(change a docs/program.md); b=$(change b docs/program.md)
	queue "$a" T1; queue "$b" T2
	start_lane; drain
	expect "first merged" in_main "$a"
	expect "second merged, not a conflict" in_main "$b"
	git fetch -q origin; git checkout -q --detach origin/main
	expect "both lines kept" sh -c 'grep -qx a docs/program.md && grep -qx b docs/program.md'
}

# T109: a merge that dies with no conflict ("fatal: stash failed", a stat race
# on this Mac) is tried once more, not a stall. A git shim fails the first entry
# merge in the build worktree exactly as git did. The build lane's git also
# ignores ctime.
case_merge_retry() {
	newrepo mretry
	local a b real shim="$ROOT/mretry/shim" oldpath="$PATH"
	real=$(command -v git)
	mkdir -p "$shim"
	cat > "$shim/git" <<EOF
#!/bin/bash
case " \$* " in *" merge -q --no-edit "*)
	if [ ! -f "$shim/failed" ]; then touch "$shim/failed"; echo "fatal: stash failed" >&2; exit 128; fi ;;
esac
case " \$* " in *" core.trustctime=false "*) touch "$shim/noctime" ;; esac
exec "$real" "\$@"
EOF
	chmod +x "$shim/git"
	a=$(change a one); b=$(change b two)
	queue "$a" T1; queue "$b" T2
	export PATH="$shim:$PATH"
	start_lane; drain
	export PATH="$oldpath"
	expect "the shim did fail a merge" test -f "$shim/failed"
	expect "first merged" in_main "$a"
	expect "second merged" in_main "$b"
	expect "no stall" not grep -q STALLED .git/mq/events.log
	expect "nobody rejected" not grep -q REJECTED .git/mq/events.log
	expect "the build lane's git ignores ctime" test -f "$shim/noctime"
}

# A new generator with no recipe line is refused, with the fix in the message;
# the same commit with its recipe is accepted. precheck.sh agrees.
case_builder_recipe() {
	newrepo builder
	local a b
	git checkout -q --no-track -b ch/gen origin/main
	mkdir -p tools/generators; echo 'extends SceneTree' > tools/generators/g.gd; echo 'uid://b1234567890ab' > tools/generators/g.gd.uid
	git add -A; git commit -q -m gen; a=$(git rev-parse HEAD)
	expect "precheck refuses" not tools/mq/precheck.sh "$a"
	expect "and says how to fix it" sh -c "tools/mq/precheck.sh $a 2>&1 | grep -q 'Add one recipe line'"
	echo 'gen | out/_g | "$MQ_BIN/godot.sh" -s tools/generators/g.gd | tools/generators/g.gd' >> tools/mq/generated.conf
	git add -A; git commit -q --amend -m genrecipe; b=$(git rev-parse HEAD)
	git checkout -q --detach origin/main
	expect "submit refuses a generator with no recipe" not queue "$a" T1
	expect "submit accepts it with the recipe" queue "$b" T2
}

case_ready_merged() {
	newrepo ready
	local a b
	a=$(change a one); git push -q origin "$a:refs/heads/lead/ready-T9-1"
	b=$(change b two fail_a); git push -q origin "$b:refs/heads/lead/ready-T9-2"
	tools/mq/pull_ready.sh; tools/mq/pull_ready.sh
	expect "queued once" test "$(ls .git/mq/pending | wc -l | tr -d ' ')" = 2
	start_lane; drain; stop_lane
	tools/mq/pull_ready.sh
	expect "merged tag on the commit" test "$(git ls-remote origin 'refs/tags/merged/T9-1^{}' | cut -f1)" = "$a"
	expect "rejected tag on the commit" test "$(git ls-remote origin 'refs/tags/rejected/T9-2^{}' | cut -f1)" = "$b"
	expect "says why" sh -c "git cat-file -p refs/tags/rejected/T9-2 | grep -q 'failed a'"
	expect "ready branch untouched" test "$(git ls-remote origin refs/heads/lead/ready-T9-1 | cut -f1)" = "$a"
}

case_ready_tag_and_moved() {
	newrepo readytag
	local a m n
	a=$(change a one); git tag -a -m hi ready/T8-1 "$a"; git push -q origin refs/tags/ready/T8-1
	m=$(change m two); git push -q origin "$m:refs/heads/lead/ready-T8-2"
	tools/mq/pull_ready.sh
	n=$(change n three); git push -q -f origin "$n:refs/heads/lead/ready-T8-2"
	tools/mq/pull_ready.sh
	expect "tag form queued" test -n "$(grep -l "sha=$a" .git/mq/pending/*.entry)"
	expect "moved branch ignored" grep -q 'T8-2 moved' .git/mq/events.log
	expect "moved commit not queued" test -z "$(grep -l "sha=$n" .git/mq/pending/*.entry)"
}

case_not_home() {
	newrepo home
	local clone="$ROOT/home/clone"
	git clone -q "$ROOT/home/origin.git" "$clone" 2>/dev/null
	cd "$clone" || return
	mkdir -p .git/mq
	MQ_HOME_MACHINE=1 bash tools/mq/buildlane.sh >/dev/null 2>&1
	expect "build lane refuses" test "$?" = 3
	MQ_HOME_MACHINE=1 bash tools/mq/submit.sh HEAD T1 >/dev/null 2>&1
	expect "submit refuses" test "$?" = 3
	MQ_HOME_MACHINE=1 bash tools/mq/pull_ready.sh >/dev/null 2>&1
	expect "pull_ready refuses" test "$?" = 3
	expect "status says so" sh -c "bash tools/mq/status.sh | grep -q 'NOT the home machine'"
	cd "$REPO" || return
}

case_idle_gate() {
	newrepo idle
	local a b i=0
	echo MQ_FULLGATE_MERGES=1 >> .git/mq/config
	git checkout -q --no-track -B red origin/main; echo x > fail_c; git add -A; git commit -q -m red
	a=$(change a one)
	queue "$a" T1
	start_lane; drain
	while ! grep -q 'FULLGATE passed' .git/mq/events.log && [ "$i" -lt 80 ]; do perl -e 'select(undef,undef,undef,0.25)'; i=$((i + 1)); done
	expect "full gate ran" grep -q 'FULLGATE passed' .git/mq/events.log
	stop_lane
	git worktree list >/dev/null
}

case_idle_gate_red_and_killed() {
	newrepo idlered
	local a b i=0
	echo MQ_FULLGATE_MERGES=1 >> .git/mq/config
	sed -i '' 's/^c = /when:never\/* c = /' tools/mq/gate.conf
	git add -A; git commit -q -m "c only on demand"; git push -q origin HEAD:main
	git -C .lanes/build reset -q --hard origin/main
	a=$(change a one fail_c)
	queue "$a" T1
	start_lane; drain
	expect "when: skipped it in the batch" in_main "$a"
	while ! grep -q 'c is red' .git/mq/events.log && [ "$i" -lt 80 ]; do perl -e 'select(undef,undef,undef,0.25)'; i=$((i + 1)); done
	expect "full gate found it" grep -q 'c is red' .git/mq/events.log
	expect "task made" sh -c "tools/mq/task.sh list | grep -q 'found c red'"
	stop_lane
	echo slow > .git/mq/slow_marker
	sed -i '' 's/^MQ_FULLGATE_MERGES=1/MQ_FULLGATE_MERGES=0/' .git/mq/config
	git -C .lanes/build checkout -q -f --detach origin/main
	touch .lanes/build/slow
	start_lane
	i=0
	while ! grep -q 'FULLGATE started' .git/mq/events.log && [ "$i" -lt 40 ]; do perl -e 'select(undef,undef,undef,0.25)'; i=$((i + 1)); done
	rm -f .lanes/build/slow
	b=$(change b two)
	queue "$b" T2
	i=0
	while ! grep -q 'FULLGATE stopped' .git/mq/events.log && [ "$i" -lt 60 ]; do perl -e 'select(undef,undef,undef,0.25)'; i=$((i + 1)); done
	expect "killed when work arrived" grep -q 'FULLGATE stopped' .git/mq/events.log
	drain
	expect "the work merged" in_main "$b"
}

case_cleanup() {
	newrepo clean2
	local a b
	a=$(change merged one); git push -q origin "$a:refs/heads/lane/merged"
	b=$(change open two); git push -q origin "$b:refs/heads/lane/open"
	git push -q origin "$b:refs/heads/lead/ready-T7-1"
	git push -q origin "$b:refs/heads/vendor/keep"
	queue "$a" T1; start_lane; drain; stop_lane
	echo keep > untracked_file
	kv="MQ_CLEANUP_MIN_AGE=0"; echo "$kv" >> .git/mq/config
	tools/mq/cleanup.sh
	expect "merged lane branch gone" test -z "$(git ls-remote origin refs/heads/lane/merged)"
	expect "open lane branch kept" test -n "$(git ls-remote origin refs/heads/lane/open)"
	expect "ready branch kept" test -n "$(git ls-remote origin refs/heads/lead/ready-T7-1)"
	expect "other branch kept" test -n "$(git ls-remote origin refs/heads/vendor/keep)"
	expect "untracked file kept" test -f untracked_file
	rm -f untracked_file
	ls .git/mq/pending/*.entry >/dev/null 2>&1
	touch .git/mq/pending/busy
	git push -q origin "$a:refs/heads/lane/merged2"
	tools/mq/cleanup.sh
	expect "not idle: nothing deleted" test -n "$(git ls-remote origin refs/heads/lane/merged2)"
	rm -f .git/mq/pending/busy
}

# Stands in for tools/mq/shots.sh: the same --start and --stop.
fake_shots() { # file marker
	cat > "$1" <<EOF
#!/bin/bash
# $2
SELF=\$(cd "\$(dirname "\$0")" && pwd -P)
G=\$(git rev-parse --path-format=absolute --git-common-dir); S="\$G/mq/shots"
case "\$1" in
--start)
	mkdir -p "\$S/bin"; cp "\$SELF/shots.sh" "\$SELF/shots_common.sh" "\$S/bin/"
	nohup bash "\$S/bin/shots.sh" --loop-here </dev/null >/dev/null 2>&1 &
	sleep 1 ;;
--stop)
	p=\$(cat "\$S/lock/pid" 2>/dev/null); [ -n "\$p" ] && kill "\$p"; sleep 1 ;;
--loop-here)
	mkdir -p "\$S/lock"; echo \$\$ > "\$S/lock/pid"
	trap 'rm -rf "\$S/lock"; exit 0' TERM
	while :; do sleep 1 & wait \$!; done ;;
esac
EOF
	: > "$(dirname "$1")/shots_common.sh"
}

sits_in() { # pid-file worktree
	[ "$(lsof -a -p "$(cat "$1")" -d cwd -Fn 2>/dev/null | sed -n 's/^n//p')" = "$(cd "$2" && pwd -P)" ]
}

status_says() { tools/mq/status.sh | sed -n '/-- standing/,/-- recent/p' | grep -q "$1"; }

# Each standing lane has its own folder, and a start moves one to new code.
case_standing() {
	newrepo standing
	local old stray
	sed -i '' '/^MQ_CLEANUP_OFF=/d' .git/mq/config
	start_lane; sleep 1
	expect "status: waiting for L05" status_says 'shots .*waiting for L05'
	expect "shots worktree ready" test -e .lanes/shots-lane/.git
	expect "build lane in .lanes/build" sits_in .git/mq/lock/pid .lanes/build
	expect "cleanup in .lanes/cleanup" sits_in .git/mq/cleanup.pid .lanes/cleanup
	expect "cleanup worktree locked" test -f .git/worktrees/cleanup/locked
	expect "shots worktree locked" test -f .git/worktrees/shots-lane/locked
	expect "status: build" status_says 'build .*running'
	expect "status: cleanup" status_says 'cleanup .*running.*\.lanes/cleanup'
	old=$(cat .git/mq/cleanup.pid)
	start_lane
	expect "a second start leaves cleanup alone" test "$(cat .git/mq/cleanup.pid)" = "$old"
	# A reload: new code in bin/, then the start the build lane makes.
	echo '# new' >> .git/mq/bin/cleanup.sh
	start_lane
	expect "cleanup took new code" test "$(cat .git/mq/cleanup.pid)" != "$old"
	expect "cleanup on bin's copy" sits_in .git/mq/cleanup.pid .lanes/cleanup
	# A loop left in the play folder is moved.
	old=$(cat .git/mq/cleanup.pid); kill "$old"; sleep 1
	nohup /bin/bash .git/mq/bin/cleanup.sh --loop </dev/null >/dev/null 2>&1 &
	stray=$!; sleep 1
	start_lane
	expect "stray cleanup gone" not kill -0 "$stray"
	expect "replaced in .lanes/cleanup" sits_in .git/mq/cleanup.pid .lanes/cleanup
	# shots.sh reaches main: the start a reload makes runs it; after that it moves
	# itself between renders, so a start must leave it running.
	fake_shots .git/mq/bin/shots.sh first-copy
	start_lane
	expect "bin's listener running" grep -q first-copy .git/mq/shots/bin/shots.sh
	expect "status: shots" status_says 'shots .*running'
	old=$(cat .git/mq/shots/lock/pid)
	fake_shots .git/mq/bin/shots.sh newer-copy
	start_lane
	expect "a running listener is not stopped" test "$(cat .git/mq/shots/lock/pid)" = "$old"
	expect "and still on its own copy" grep -q first-copy .git/mq/shots/bin/shots.sh
	echo MQ_PUSH=0 >> .git/mq/config
	start_lane
	expect "MQ_PUSH=0 keeps shots off" not test -f .git/mq/shots/lock/pid
	expect "status: shots stopped" status_says 'shots .*STOPPED'
	tools/mq/setup_lanes.sh --stop >/dev/null
	sleep 1
	expect "stop ends cleanup" not test -f .git/mq/cleanup.pid
}

wait_for() { # pattern: until it is in the events log
	local i=0
	while ! grep -q "$1" .git/mq/events.log && [ "$i" -lt 80 ]; do perl -e 'select(undef,undef,undef,0.25)'; i=$((i + 1)); done
	grep -q "$1" .git/mq/events.log
}

in_lane() { # file: a commit on main's tip in the lane, printed
	git -C .lanes/lane1 checkout -q --detach origin/main
	echo "$1 $RANDOM" >> ".lanes/lane1/$1"
	git -C .lanes/lane1 add -A; git -C .lanes/lane1 commit -q -m "$1"
	git -C .lanes/lane1 rev-parse HEAD
}

# The play folder sits on main: a land leaves it alone until `make pull`.
case_play_folder_on_main() {
	newrepo onmain
	local mk="$SRC/../../Makefile" before a b out
	git checkout -q main
	before=$(git rev-parse main)
	a=$(in_lane shared); queue "$a" T1
	start_lane; drain
	expect "landed" in_main "$a"
	expect "local main not moved" test "$(git rev-parse main)" = "$before"
	expect "folder not touched" not test -f shared
	expect "folder clean" test -z "$(git status --porcelain)"
	out=$(make --no-print-directory -f "$mk" pull 2>&1)
	expect "pull succeeds" test "$?" = 0
	expect "pull brings the files" test -f shared
	expect "main is at origin" test "$(git rev-parse main)" = "$(git rev-parse origin/main)"
	expect "lists what's new" sh -c "printf '%s' \"\$1\" | grep -q 'New since last update'" _ "$out"
	b=$(in_lane shared); queue "$b" T2; drain
	echo local-edit >> shared
	before=$(git rev-parse main)
	make --no-print-directory -f "$mk" pull >/dev/null 2>&1
	expect "refuses local edits" test "$?" != 0
	expect "edit kept" grep -q local-edit shared
	expect "main stayed" test "$(git rev-parse main)" = "$before"
	git checkout -q shared
	git commit -q --allow-empty -m diverged
	make --no-print-directory -f "$mk" pull >/dev/null 2>&1
	expect "refuses divergence" test "$?" != 0
	git reset -q --hard "$before"
	git checkout -q --detach
	out=$(make --no-print-directory -f "$mk" pull 2>&1)
	expect "skips off main" test "$?" = 0
	expect "says why" sh -c "printf '%s' \"\$1\" | grep -q 'skipping'" _ "$out"
}

# Someone else's push gets in while the gate runs.
case_lost_race() {
	newrepo race
	local other="$ROOT/race/other" a o
	git -C "$ROOT/race/origin.git" config receive.denyNonFastForwards true
	git clone -q "$ROOT/race/origin.git" "$other" 2>/dev/null
	git -C "$other" config user.name x; git -C "$other" config user.email x@example.invalid
	cat > "$ROOT/race.sh" <<EOF
#!/bin/bash
[ -f "$other.done" ] && exit 0
touch "$other.done"
cd "$other" && echo x > from_race && git add -A && git commit -q -m race && git push -q origin main
EOF
	chmod +x "$ROOT/race.sh"
	a=$(change a one race_me)
	queue "$a" T1
	start_lane
	expect "lost the race" wait_for 'RACE origin main moved'
	drain
	rm -f "$ROOT/race.sh"
	expect "landed on the new main" in_main "$a"
	o=$(git -C "$other" rev-parse HEAD)
	expect "their work kept" in_main "$o"
	expect "nobody rejected" not rejected T1
	expect "no stall" not grep -q STALLED .git/mq/events.log
	expect "no force on main" not grep -Eq 'git.* push .*(-f|--force)' "$SRC/buildlane.sh" "$SRC/pull_ready.sh"
	expect "no local main written" not grep -Eq 'update-ref .*main|branch -f main|merge .*--ff-only' "$SRC/buildlane.sh"
}

case_task_deps() {
	newrepo deps
	local d1 d2 d3 before
	d1=$(tools/mq/task.sh add "first"); d2=$(tools/mq/task.sh add "second"); d3=$(tools/mq/task.sh add "third")
	tools/mq/task.sh set "$d2" deps "$d1 T999"
	tools/mq/task.sh set "$d3" deps "$d1"
	before=$(git -C .lanes/lane1 rev-parse HEAD)
	expect "unmet dep refused" not tools/mq/lane.sh lane1 second "$d2"
	expect "refusal names the dep" sh -c "tools/mq/lane.sh lane1 second $d2 2>&1 | grep -q $d1"
	expect "task still open" grep -q '^status=open' ".git/mq/tasks/$d2/meta"
	expect "no branch made" not git -C .lanes/lane1 rev-parse -q --verify refs/heads/lane1/second
	expect "lane head unmoved" test "$(git -C .lanes/lane1 rev-parse HEAD)" = "$before"
	expect "ready lists only eligible" test "$(tools/mq/task.sh ready | tr '\n' ' ')" = "$d1 "
	tools/mq/task.sh set "$d1" status merged
	expect "d3 ready after merge" test "$(tools/mq/task.sh ready | tr '\n' ' ')" = "$d3 "
	expect "d3 starts" tools/mq/lane.sh lane1 third "$d3"
	tools/mq/task.sh set "$d2" deps "$d1"
	tools/mq/task.sh set "$d3" status dropped
	expect "dropped counts as met" test "$(tools/mq/task.sh unmet "$d2")" = ""
}

case_network_failure() {
	newrepo net
	local a good
	a=$(change a one)
	queue "$a" T1
	good=$(git remote get-url origin)
	git remote set-url origin "$ROOT/net/nowhere.git"
	start_lane
	expect "fetch failure stalls" wait_for 'STALLED cannot fetch'
	stop_lane
	git remote set-url origin "$good"
	git remote set-url --push origin "$ROOT/net/nowhere.git"
	start_lane
	expect "push failure stalls" wait_for 'STALLED could not push'
	stop_lane
	expect "not rejected" not rejected T1
	expect "back in the queue" test -n "$(ls .git/mq/pending/*.entry .git/mq/batches/*/*.entry 2>/dev/null)"
	git config --unset remote.origin.pushurl
	start_lane; drain
	expect "merged once it came back" in_main "$a"
}

case_push_off_holds() {
	newrepo pushoff
	local a
	a=$(change a one)
	queue "$a" T1
	echo MQ_PUSH=0 >> .git/mq/config
	start_lane
	expect "says it is holding" wait_for 'HOLDING MQ_PUSH=0'
	expect "status is loud" sh -c "tools/mq/status.sh | grep -q 'NOTHING CAN LAND'"
	expect "still queued" test -n "$(ls .git/mq/pending/*.entry 2>/dev/null)"
	expect "nothing landed" not in_main "$a"
	stop_lane
	sed -i '' '/^MQ_PUSH=0/d' .git/mq/config
	start_lane; drain
	expect "lands once it is back on" in_main "$a"
}

# A slow build as a gate line. `late` passes only on the build of this very
# commit; bake_secs is an input, so a slow build is a new one.
bake_repo() { # name [file-on-base]
	newrepo "$1" "${2:-}"
	cat > tools/bake.sh <<'EOF'
#!/bin/bash
[ -f fail_bake ] && exit 1
[ -f parse_hang ] && { echo 'SCRIPT ERROR: Parse Error: Identifier "ManorSitePlan" not declared in the current scope.'; sleep 60; }
mkdir -p built; echo partial > built/content; echo $$ > built/pid
[ -f .godot/global_script_class_cache.cfg ] && echo yes > built/had_class_cache
sleep "$(cat bake_secs)"
cat bake_input > built/content
EOF
	cat > tools/mq/gate.conf <<'EOF'
first: parse = "$MQ_BIN/parse.sh"
first: levels = MQ_LEVELS_SKIP=terrain "$MQ_BIN/levels.sh" ensure
terrain = "$MQ_BIN/levels.sh" ensure terrain
needs:terrain late = cmp built/content bake_input
early = "$MQ_BIN/godot.sh" check a
b = "$MQ_BIN/godot.sh" check b
EOF
	echo 'terrain | built | bash tools/bake.sh | tools/bake.sh bake_input bake_secs fail_bake' > tools/mq/generated.conf
	echo 4 > bake_secs; echo one > bake_input; echo built/ > .gitignore
	git add -A; git commit -q -m bake; git push -q origin HEAD:main
	git checkout -q --detach origin/main
	git -C "$REPO/.lanes/build" checkout -q --detach origin/main
}

in_build() { ( cd "$REPO/.lanes/build" && "$@" ); }
commit_build() { in_build sh -c "$1; git add -A; git -c user.name=s -c user.email=s@example.invalid commit -q -m step"; }
gate() { # out-name gate-args: the installed gate, in the build worktree
	GATE_OUT="$REPO/../gate-$1"; shift
	in_build /bin/bash "$REPO/.git/mq/bin/gate.sh" --out "$GATE_OUT" "$@"
}
said() { grep -q "^$1 $2 " "$GATE_OUT/results.txt"; }
ran() { grep -q " $1 " "$GATE_OUT/results.txt"; }
before() { # a b: a finished first
	[ "$(grep -n " $1 " "$GATE_OUT/results.txt" | cut -d: -f1)" -lt "$(grep -n " $2 " "$GATE_OUT/results.txt" | cut -d: -f1)" ]
}

case_build_line_order() {
	bake_repo order
	commit_build 'mkdir tests; echo "# gate: needs:terrain" > tests/test_w.gd; : > tests/test_u.gd; echo "@gut tests" >> tools/mq/gate.conf'
	gate cold; expect "gate passes" test "$?" = 0
	expect "unmarked line doesn't wait" before b terrain
	expect "unmarked gut test doesn't wait" before gut:tests/test_u.gd terrain
	expect "marked line waits" before terrain late
	expect "marked gut test waits" before terrain gut:tests/test_w.gd
	# The old bake is still in the worktree: late has to see the new one.
	commit_build 'echo two > bake_input'
	gate stale; expect "a stale bake never reaches a marked line" test "$?" = 0
	expect "unmarked still goes first" before b terrain
	commit_build 'echo three > bake_input'
	gate only --only late; expect "--only a marked line" test "$?" = 0
	expect "builds first" before terrain late
	expect "and runs nothing else" not ran b
	commit_build 'echo four > bake_input'
	gate bake --only terrain; expect "--only the build" test "$?" = 0
	expect "just the build" not ran late
	gate cached --only b; expect "--only an unmarked line" test "$?" = 0
	expect "skips the build" not ran terrain
}

case_build_fail_fast() {
	bake_repo fast
	gate good; expect "base passes" test "$?" = 0
	local good t0 secs
	good=$(in_build git rev-parse HEAD)
	commit_build 'echo two > bake_input; echo 30 > bake_secs; touch fail_a'
	t0=$(date +%s)
	gate bad; expect "a red test fails the gate" test "$?" = 1
	secs=$(( $(date +%s) - t0 ))
	expect "without waiting for the build (${secs}s)" test "$secs" -lt 15
	expect "the build was stopped" not kill -0 "$(cat "$REPO/.lanes/build/built/pid")"
	expect "named" grep -qx early "$GATE_OUT/failed"
	# The killed build left half its output: the old commit mustn't trust it.
	in_build git checkout -q --detach "$good"
	gate back; expect "a killed build isn't taken for a good one" test "$?" = 0
}

case_build_fail_narrowed() {
	bake_repo narrow
	local a b c
	a=$(change a file1); b=$(change b fail_bake); c=$(change c file3)
	queue "$a" T1; queue "$b" T2; queue "$c" T3
	start_lane; drain
	expect "good one before it lands" in_main "$a"
	expect "good one after it lands" in_main "$c"
	expect "bad build rejected, as the build" grep -q 'REJECTED T2 failed terrain' .git/mq/events.log
	expect "not landed" not in_main "$b"
}

case_build_known_red() {
	bake_repo redbuild fail_bake
	gate red --all; expect "red build fails" test "$?" = 1
	expect "what needs it can't run" said BLOCKED late
	expect "and isn't counted as red" not grep -qx late "$GATE_OUT/failed"
	expect "the rest run" said PASS b
	cp "$GATE_OUT/failed" "$ROOT/known"
	gate known --known "$ROOT/known"; expect "known red doesn't fail" test "$?" = 0
	expect "and still doesn't let it run" said BLOCKED late
}

case_needs_nothing() {
	bake_repo typo
	in_build sh -c 'echo "needs:terain x = true" >> tools/mq/gate.conf'
	gate typo; expect "a need naming no line can't test" test "$?" = 3
}

case_marker_check() {
	bake_repo marker
	mkdir tests
	echo 'preload("res://world/shared/world/world.tscn")' > tests/test_w.gd
	expect "a test loading the world needs the mark" not tools/mq/levels.sh check
	echo '# gate: needs:terrain' >> tests/test_w.gd
	expect "marked is fine" tools/mq/levels.sh check
}

case_script_uid() {
	newrepo uid
	local a b
	git checkout -q --no-track -b ch/nouid origin/main
	mkdir sub; echo 'extends Node' > sub/s.gd; git add -A; git commit -q -m nouid
	a=$(git rev-parse HEAD)
	echo 'uid://b1234567890ab' > sub/s.gd.uid; git add -A; git commit -q --amend -m withuid
	b=$(git rev-parse HEAD); git checkout -q --detach origin/main
	expect "a new script with no .uid is refused" not queue "$a" T1
	expect "a new script with its .uid is accepted" queue "$b" T2
}

case_miss_message() {
	bake_repo missmsg
	echo 0 > bake_secs
	tools/mq/levels.sh ensure >"$ROOT/miss.out" 2>"$ROOT/miss.err"
	expect "a cache miss says it is building" grep -q '^Building terrain ' "$ROOT/miss.err"
	expect "stdout stays empty on a miss" test ! -s "$ROOT/miss.out"
	tools/mq/levels.sh ensure >"$ROOT/hit.out" 2>"$ROOT/hit.err"
	expect "nothing printed when it is already built" test ! -s "$ROOT/hit.err"
	expect "stdout stays empty on a hit" test ! -s "$ROOT/hit.out"
}

case_stamp_without_output() {
	bake_repo restore
	echo 0 > bake_secs
	tools/mq/levels.sh ensure 2>/dev/null
	rm -rf built
	touch fail_bake
	tools/mq/levels.sh ensure >"$ROOT/restore.out" 2>"$ROOT/restore.err"
	expect "a stamped build with its output gone comes back from the cache" cmp built/content bake_input
	expect "and is not rebuilt" not grep -q '^Building ' "$ROOT/restore.err"
	rm -rf built "$REPO/.git/levelcache/terrain"
	rm -f fail_bake
	tools/mq/levels.sh ensure >"$ROOT/gone.out" 2>"$ROOT/gone.err"
	expect "gone from the cache too is a true miss, so it builds" grep -q '^Building terrain ' "$ROOT/gone.err"
	expect "and the output is back" cmp built/content bake_input
}

case_import_before_build() {
	bake_repo importfirst
	echo 0 > bake_secs
	mkdir -p lib; printf 'class_name ManorSitePlan\nextends RefCounted\n' > lib/plan.gd
	rm -rf .godot
	tools/mq/levels.sh ensure 2>"$ROOT/import.err"
	expect "a tree with no class cache imports before it builds" test -f built/had_class_cache
	expect "and says so" grep -q 'importing first' "$ROOT/import.err"
	expect "the class is in the cache" grep -q '&"ManorSitePlan"' .godot/global_script_class_cache.cfg
}

case_stale_class_cache() {
	bake_repo stalecache
	echo 0 > bake_secs
	mkdir -p lib; printf 'class_name ManorSitePlan\nextends RefCounted\n' > lib/plan.gd
	tools/mq/levels.sh ensure 2>/dev/null
	expect "fresh after the first import" tools/mq/class_cache.sh stale
	# A class added after the cache was written (F47: ArrowModel).
	printf 'class_name ArrowModel\nextends Node3D\n' > lib/arrow.gd
	expect "a class added later makes the cache stale" not tools/mq/class_cache.sh stale
	expect "and is named" sh -c 'tools/mq/class_cache.sh stale | grep -q "^ArrowModel (lib/arrow.gd)"'
	mkdir -p skip; touch skip/.gdignore; printf 'class_name NotImported\n' > skip/x.gd
	expect "a .gdignore folder's classes aren't expected" not sh -c 'tools/mq/class_cache.sh stale | grep -q NotImported'
	echo 1 > bake_input; rm -rf built
	tools/mq/levels.sh ensure 2>"$ROOT/stale.err"
	expect "the next build imports first" grep -q 'importing first' "$ROOT/stale.err"
	expect "and the new class is in the cache" grep -q '&"ArrowModel"' .godot/global_script_class_cache.cfg
}

case_parse_error_fails_fast() {
	bake_repo parsefail
	echo 0 > bake_secs
	touch parse_hang
	local t0=$SECONDS
	tools/mq/levels.sh ensure >/dev/null 2>"$ROOT/parse.err"; local rc=$?
	expect "a builder whose script won't parse fails the ensure" test "$rc" != 0
	expect "at once, not at the timeout" test $((SECONDS - t0)) -lt 20
	expect "and names the parse error" grep -q 'failed to parse' "$ROOT/parse.err"
	expect "and the class" grep -q 'ManorSitePlan' "$ROOT/parse.err"
	expect "nothing is stamped" test ! -f .git/mq-levels/terrain
	perl -e 'select(undef,undef,undef,2.5)'
	expect "and the hung builder isn't left running" not bake_running_in "$(pwd -P)"
}
bake_running_in() { # dir: a bake.sh whose cwd is under it (other scenarios bake too)
	local p
	for p in $(pgrep -f 'bash tools/bake.sh'); do
		lsof -a -p "$p" -d cwd -Fn 2>/dev/null | grep -q "^n$1" && return 0
	done
	return 1
}

case_test_when() {
	bake_repo testwhen
	commit_build 'mkdir tests zone; echo "# gate: when:zone/*,*.x" > tests/test_s.gd; : > tests/test_u.gd; echo "@gut tests" >> tools/mq/gate.conf'
	local base
	base=$(in_build git rev-parse HEAD)
	commit_build 'echo one > other.txt'
	gate off --base "$base"; expect "gate passes" test "$?" = 0
	expect "a scoped test the change doesn't touch is skipped" not ran gut:tests/test_s.gd
	expect "and the plan says why" grep -q '^SKIP gut:tests/test_s.gd' "$GATE_OUT/plan.txt"
	expect "an unscoped test still runs" ran gut:tests/test_u.gd
	commit_build 'echo two > zone/a'
	gate on --base "$base"; expect "gate passes again" test "$?" = 0
	expect "a change under its pattern runs it" ran gut:tests/test_s.gd
	in_build git checkout -q --detach "$base"
	commit_build 'echo three > b.x'
	gate ext --base "$base"; expect "a second pattern in the list runs it" ran gut:tests/test_s.gd
	in_build git checkout -q --detach "$base"
	commit_build 'mkdir -p zone/deep; echo six > zone/deep/a'
	gate deep --base "$base"; expect "a file deeper under the pattern runs it (the pattern isn't globbed)" ran gut:tests/test_s.gd
	in_build git checkout -q --detach "$base"
	commit_build 'echo four > tests/test_s.gd'
	gate own --base "$base"; expect "a change to the test file itself runs it" ran gut:tests/test_s.gd
	in_build git checkout -q --detach "$base"
	commit_build 'echo five > other.txt'
	gate full; expect "an idle gate (no --base) runs everything" ran gut:tests/test_s.gd
}

# Short tests share one engine; a red shard splits so blame stays per file.
case_gut_shards() {
	bake_repo shards
	commit_build 'mkdir tests; : > tests/test_p.gd; : > tests/test_q.gd; : > tests/test_r.gd; echo "# gate: alone" > tests/test_z.gd; echo "@gut tests" >> tools/mq/gate.conf'
	gate first; expect "first gate passes" test "$?" = 0
	expect "a test with no time yet runs alone" not grep -q '^SHARD' "$GATE_OUT/plan.txt"
	gate shard; expect "sharded gate passes" test "$?" = 0
	expect "short tests with a time share a shard" grep -q '^SHARD shard:1 .*gut:tests/test_p.gd.*' "$GATE_OUT/plan.txt"
	expect "the shard passes" said PASS shard:1
	expect "a test marked alone stays out of shards" not grep -q '^SHARD.*test_z' "$GATE_OUT/plan.txt"
	expect "and runs on its own" said PASS gut:tests/test_z.gd
	expect "and each test in it passes" said PASS gut:tests/test_q.gd
	expect "the build lines don't shard" ran late
	commit_build 'touch fail_test_q'
	gate red; expect "a red test in a shard fails the gate" test "$?" = 1
	expect "the shard splits" said SPLIT shard:1
	expect "the red test is named on its own" grep -qx gut:tests/test_q.gd "$GATE_OUT/failed"
	commit_build 'rm fail_test_q; touch clash'
	gate clash; expect "red only together passes" test "$?" = 0
	expect "the shard split" said SPLIT shard:1
	expect "and is called flaky" said FLAKY shard:1
	expect "every test passed alone" said PASS gut:tests/test_r.gd
	expect "the flake is an event" grep -q 'FLAKY shard:1 red together' .git/mq/events.log
}

for c in task_deps bad_first bad_middle bad_last two_bad pair known_red clean conflict restacked restack_conflict flaky flaky_last \
		stop_mid_batch stall_no_engine origin_ahead built_file ready_merged \
		ready_tag_and_moved not_home idle_gate idle_gate_red_and_killed cleanup standing play_folder_on_main lost_race \
		network_failure push_off_holds build_line_order build_fail_fast build_fail_narrowed \
		build_known_red needs_nothing marker_check script_uid union_log merge_retry builder_recipe miss_message stamp_without_output \
		import_before_build stale_class_cache parse_error_fails_fast test_when gut_shards; do
	[ -n "$ONLY" ] && [ "$ONLY" != "$c" ] && continue
	# bash 3.2 has no wait -n: poll for a free slot.
	while [ "$(jobs -pr | wc -l)" -ge "$JOBS" ]; do perl -e 'select(undef,undef,undef,0.2)'; done
	( scenario "$c" ) > "$ROOT/out.$c" 2>&1 &
	eval "pid_$c=$!"
	ran_cases="${ran_cases:-} $c"
done
for c in ${ran_cases:-}; do
	eval "wait \$pid_$c"; rc=$?
	cat "$ROOT/out.$c"
	if [ "$rc" = 0 ]; then PASSED=$((PASSED + 1)); else FAILED=$((FAILED + 1)); fi
done
# A finished run leaves nothing running from its temp root, by command or cwd.
leftovers() {
	ps -axo pid=,command= | grep -F "$ROOT" | grep -v "grep -F" | awk -v me="$$" '$1 != me'
	lsof -a -d cwd -Fpn 2>/dev/null | awk -v r="$ROOT" -v me="$$" '
		/^p/ { pid = substr($0, 2) }
		/^n/ { if (index(substr($0, 2), r) == 1 && pid != me) print pid " cwd " substr($0, 2) }'
}
if [ -z "$ONLY" ]; then
	cd "$ROOT" || exit 1
	left=""; i=0
	while [ "$i" -lt 20 ]; do
		left=$(leftovers | grep -v "^$$ ")
		[ -z "$left" ] && break
		perl -e 'select(undef,undef,undef,0.5)'; i=$((i + 1))
	done
	if [ -n "$left" ]; then
		echo "FAIL leftover processes under $ROOT:"; echo "$left"
		FAILED=$((FAILED + 1))
	fi
fi
echo "selftest: $PASSED passed, $FAILED failed"
[ "$FAILED" = 0 ]
