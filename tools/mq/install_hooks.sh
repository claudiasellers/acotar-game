#!/bin/bash
# Installs the pre-push hook (make setup). Safe to re-run. Lives in the shared
# git dir, so every worktree of this clone gets it. The hook runs the
# tools/mq/pre_push.sh of the worktree you push from; an older hook of yours
# is kept as pre-push.local and still runs first.
set -eu
hooks=$(git rev-parse --path-format=absolute --git-common-dir)/hooks
mkdir -p "$hooks"
hook="$hooks/pre-push"
if [ -e "$hook" ] && ! grep -q 'acotar-uid-hook' "$hook"; then
	mv "$hook" "$hooks/pre-push.local"
	echo "Kept your existing pre-push hook as pre-push.local (it still runs)."
fi
cat > "$hook" <<'HOOK'
#!/bin/bash
# acotar-uid-hook (installed by make setup)
input=$(cat)
d=$(dirname "$0")
if [ -x "$d/pre-push.local" ]; then printf '%s\n' "$input" | "$d/pre-push.local" "$@" || exit $?; fi
top=$(git rev-parse --show-toplevel 2>/dev/null) || exit 0
[ -x "$top/tools/mq/pre_push.sh" ] || exit 0
printf '%s\n' "$input" | "$top/tools/mq/pre_push.sh" "$@"
HOOK
chmod +x "$hook"
echo "Installed pre-push hook: lead/ready-* pushes are checked for missing .uid files."
