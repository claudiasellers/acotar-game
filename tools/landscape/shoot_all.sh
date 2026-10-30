#!/usr/bin/env bash
# Renders every landscape shot into $1 (cloud: needs xvfb + mesa-vulkan-drivers).
# Terrain3D crashes llvmpipe, so it is switched off for the run and restored after.
set -u
out=${1:?out dir}; shift
mkdir -p "$out"
ext=addons/terrain_3d/terrain.gdextension
[ -f "$ext" ] && mv "$ext" "$ext.off"
trap '[ -f "$ext.off" ] && mv "$ext.off" "$ext"' EXIT
for id in ${@:-bw_walk bw_raised bw_plan bv_walk bv_raised bv_plan}; do
	timeout 900 xvfb-run -a -s "-screen 0 1920x1080x24" "${GODOT:-godot}" --rendering-driver vulkan --path . \
		res://tools/landscape/landscape_shot.tscn -- "$id" "$out/$id.png" 2>&1 | grep -E "^SHOT|SCRIPT ERROR|crash" | head -5
done
