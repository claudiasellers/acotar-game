#!/bin/bash
# Contract test for check_uids.sh, the pre-push hook and the install script.
#   tools/mq/uid_selftest.sh
# Throwaway repos only; touches nothing in this clone.
set -u
SRC=$(cd "$(dirname "$0")" && pwd)
ROOT=$(mktemp -d "${TMPDIR:-/tmp}/uid-selftest.XXXXXX")
trap 'rm -rf "$ROOT"' EXIT
P=0; F=0
ok() { P=$((P+1)); echo "ok   $1"; }
no() { F=$((F+1)); echo "FAIL $1"; }
expect() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then ok "$d"; else no "$d"; fi; }
refute() { local d="$1"; shift; if "$@" >/dev/null 2>&1; then no "$d"; else ok "$d"; fi; }

g() { git -c user.email=t@t -c user.name=t "$@"; }
cd "$ROOT" && git init -q --bare remote.git && git init -q -b main work && cd work || exit 1
mkdir -p tools/mq
cp "$SRC/check_uids.sh" "$SRC/pre_push.sh" "$SRC/install_hooks.sh" tools/mq/
echo 'extends Node' > old.gd; echo 'uid://b0000000000001' > old.gd.uid
g add -A; g commit -q -m base; g remote add origin ../remote.git; g push -q origin main; g fetch -q origin
chk=tools/mq/check_uids.sh

expect "clean tree passes" $chk
# New files: .gd, .gdshader, .gdshaderinc without uid; .tscn legitimately has none.
echo 'extends Node' > a.gd; echo 'shader_type spatial;' > b.gdshader; echo 'x' > c.gdshaderinc
echo '[gd_scene]' > d.tscn; mkdir -p addons/x; echo 'extends Node' > addons/x/e.gd
g add -A; g commit -q -m nouid
refute "missing uids fail" $chk
out=$($chk 2>/dev/null)
[ "$out" = "$(printf 'missing .uid: a.gd\nmissing .uid: b.gdshader\nmissing .uid: c.gdshaderinc')" ] && ok "names exactly the three offenders, not .tscn or addons/" || { no "exact paths"; echo "$out"; }
[ "$($chk --added-since origin/main 2>/dev/null | wc -l | tr -d ' ')" = 3 ] && ok "--added-since agrees" || no "--added-since"

# Hook: installed in the shared git dir, fires only for lead/ready-*.
tools/mq/install_hooks.sh >/dev/null && ok "install_hooks runs" || no "install_hooks"
tools/mq/install_hooks.sh >/dev/null && [ ! -e .git/hooks/pre-push.local ] && ok "re-install does not chain itself" || no "re-install"
refute "push to lead/ready-L99-1 is refused" git push -q origin HEAD:refs/heads/lead/ready-L99-1
git push origin HEAD:refs/heads/lead/ready-L99-1 2>&1 | grep -q 'missing .uid: a.gd' && ok "refusal prints the exact path" || no "refusal text"
expect "push to another branch is not checked" git push -q origin HEAD:refs/heads/lane/wip
for f in a.gd b.gdshader c.gdshaderinc; do echo 'uid://b0000000000002' > "$f.uid"; done
g add -A; g commit -q -m uids
expect "complete uids pass" $chk
expect "push to lead/ready-L99-1 now succeeds" git push -q origin HEAD:refs/heads/lead/ready-L99-1
expect "deleting a ready branch is not blocked" git push -q origin :refs/heads/lead/ready-L99-1

# Existing foreign hook is preserved and still runs.
rm .git/hooks/pre-push; printf '#!/bin/bash\ntouch ../foreign.ran\n' > .git/hooks/pre-push; chmod +x .git/hooks/pre-push
tools/mq/install_hooks.sh >/dev/null; git push -q origin HEAD:refs/heads/lane/wip2
expect "a pre-existing hook is kept and still runs" test -e "$ROOT/foreign.ran"

echo "$P passed, $F failed"; [ "$F" = 0 ]
