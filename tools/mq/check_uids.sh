#!/bin/bash
# Lists scripts and shaders committed without their .uid sidecar.
#   tools/mq/check_uids.sh [--added-since <base>] [<commit>]
# Default: every tracked file in <commit> (default HEAD). With --added-since,
# only files the commit adds relative to <base> (the queue uses this: a lane is
# not blamed for what main already holds).
# Prints one line per offender, "missing .uid: <path>", on stdout and exits 1;
# exits 0 and prints nothing when clean; 2 on a usage or git error.
#
# Covers .gd, .gdshader and .gdshaderinc, the types Godot 4.7 writes a tracked
# <file>.uid next to. NOT .tscn/.tres: Godot keeps a scene's uid inside the
# file (uid="uid://..." in the header) and writes no sidecar, so main's 191
# scenes have none. Checked against the commit's tree, not the disk.
# Skipped: tools/mq/ and addons/ (same exclusions as submit.sh).
set -u
base=""
if [ "${1:-}" = "--added-since" ]; then
	[ "$#" -ge 2 ] || { echo "usage: check_uids.sh [--added-since <base>] [<commit>]" >&2; exit 2; }
	base="$2"; shift 2
fi
[ "$#" -le 1 ] || { echo "usage: check_uids.sh [--added-since <base>] [<commit>]" >&2; exit 2; }
sha=$(git rev-parse --verify "${1:-HEAD}^{commit}" 2>/dev/null) || { echo "check_uids: unknown commit ${1:-HEAD}" >&2; exit 2; }

if [ -n "$base" ]; then
	git rev-parse --verify "$base^{commit}" >/dev/null 2>&1 || { echo "check_uids: unknown base $base" >&2; exit 2; }
	files=$(git diff --no-renames --name-only --diff-filter=A "$base" "$sha")
else
	files=$(git ls-tree -r --name-only "$sha")
fi

bad=0
while IFS= read -r f; do
	case "$f" in tools/mq/*|addons/*) continue ;; esac
	case "$f" in *.gd|*.gdshader|*.gdshaderinc) ;; *) continue ;; esac
	if ! git cat-file -e "$sha:$f.uid" 2>/dev/null; then
		echo "missing .uid: $f"; bad=1
	fi
done <<EOF2
$files
EOF2
if [ "$bad" = 1 ]; then
	echo "Run tools/mq/godot.sh --import (or open the project in Godot) so it writes <file>.uid next to each file above, then commit the .uid files with them. Never write a uid by hand." >&2
	exit 1
fi
exit 0
