#!/bin/bash
# The quick check: refresh Godot's class cache (a new class_name needs this),
# then parse. With file arguments, only those scripts.
#   tools/mq/parse.sh [a.gd b.gd]
dir=$(cd "$(dirname "$0")" && pwd)
. "$dir/common.sh"
"$dir/godot.sh" --import >/dev/null 2>&1
[ "$?" = "125" ] && exit 125
if [ "$#" -gt 0 ]; then
	exec "$dir/godot.sh" -s "$dir/parse_check.gd" -- "$@"
fi
exec "$dir/godot.sh" -s "$dir/parse_check.gd"
