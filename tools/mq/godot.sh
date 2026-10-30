#!/bin/bash
# Runs the game from the current worktree with a scratch data folder, silent
# and with no window. Never run the bare engine from a lane or the gate: the
# owner's saves live under the real HOME.
#   tools/mq/godot.sh <engine args>
# MQ_SCRATCH overrides the data folder (the gate gives each test its own).
# On a Mac everything here runs clamped to utility QoS, so it gives way to the
# owner's apps for about 8% more time. Not `taskpolicy -b`: that took 3x as long.
# make play doesn't come through here, so the game keeps full priority.
. "$(dirname "$0")/common.sh"
engine=$(mq_engine) || { echo "mq: no Godot $MQ_GODOT_VERSION found" >&2; exit 125; }
wt=$(git rev-parse --show-toplevel)
if [ -z "$MQ_SCRATCH" ]; then
	MQ_SCRATCH="/tmp/$MQ_PROJECT-$(basename "$wt")/data"
fi
mkdir -p "$MQ_SCRATCH"
export HOME="$MQ_SCRATCH" XDG_DATA_HOME="$MQ_SCRATCH" XDG_CONFIG_HOME="$MQ_SCRATCH" XDG_CACHE_HOME="$MQ_SCRATCH"
clamp=""
[ -x /usr/sbin/taskpolicy ] && clamp="/usr/sbin/taskpolicy -c utility"
exec $clamp "$engine" --headless --audio-driver Dummy --path "$wt" "$@"
