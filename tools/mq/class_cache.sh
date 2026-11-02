#!/bin/bash
# Godot finds a class_name only through .godot/global_script_class_cache.cfg,
# which only an import writes. A cache from before a class was added (F47:
# ArrowModel, so the bow wouldn't fire) or no cache at all (F42: a fresh
# checkout's builders) breaks every script that names it.
#   class_cache.sh stale    lists project class_names the cache lacks; exit 1 if any
# make import, make generate and levels.sh ensure use it to import when needed.
# Run from the project folder. Folders with a .gdignore are not imported, so
# their classes are not expected.
set -u
CACHE=.godot/global_script_class_cache.cfg

missing() {
	local ignored
	ignored=$(find . -name .gdignore -not -path './.git/*' -not -path './.godot/*' 2>/dev/null | sed 's|^\./||; s|/\.gdignore$|/|' | tr '\n' ' ')
	{
		[ -f "$CACHE" ] && grep -o '"class": &"[A-Za-z0-9_]*"' "$CACHE" | sed 's/.*&"\(.*\)"/have \1/'
		grep -rH -m1 -E '^class_name[[:space:]]+[A-Za-z_]' --include='*.gd' \
			--exclude-dir=.git --exclude-dir=.godot --exclude-dir=.tools --exclude-dir=.lanes . 2>/dev/null |
			sed 's|^\./||; s|:class_name[[:space:]]*\([A-Za-z0-9_]*\).*| \1|; s/^/want /'
	} | awk -v ignored="$ignored" '
		BEGIN { n = split(ignored, ig, " ") }
		$1 == "have" { have[$2] = 1; next }
		$1 == "want" {
			for (i = 1; i <= n; i++) if (index($2, ig[i]) == 1) next
			if (!($3 in have)) print $3 " (" $2 ")"
		}'
}

case "${1:-}" in
	stale)
		out=$(missing)
		[ -z "$out" ] && exit 0
		echo "$out"; exit 1 ;;
	*) echo "usage: class_cache.sh stale" >&2; exit 2 ;;
esac
