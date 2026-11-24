"""Carries re-authored clips into a built cast member without rebuilding its looks.

    /opt/bpyenv/bin/python tools/blender/cast/refresh_clips.py <fresh_tree> <id> [<id> ...]

A cast member's face and body are sculpted further in its .blend after the
build (the expression keys, the mouth), so a change to a clip can't go through
a rebuild. Instead: check the repo out a second time (<fresh_tree>), run
build_cast.py <id> (build_feyre.py for feyre) there with the changed clip
code, then run this here. It swaps the actions in
characters/<id>/model/<id>.blend for the fresh tree's, and splices the fresh
clips into <id>.glb (tools/blender/splice_clips.py). Meshes, keys and
materials are untouched in both.
"""

import os
import sys

import bpy

HERE = os.path.dirname(os.path.abspath(__file__))
REPO = os.path.abspath(os.path.join(HERE, "..", "..", ".."))
sys.path.insert(0, os.path.join(HERE, ".."))

import splice_clips  # noqa: E402


def refresh(fresh, char):
    rel = os.path.join("characters", char, "model", char)
    bpy.ops.wm.open_mainfile(filepath=os.path.join(REPO, rel + ".blend"))
    with bpy.data.libraries.load(os.path.join(fresh, rel + ".blend")) as (src, dst):
        names = list(src.actions)
        for name in names:
            if name in bpy.data.actions:
                bpy.data.actions.remove(bpy.data.actions[name])
        dst.actions = names
    for action in dst.actions:
        action.use_fake_user = True
    bpy.context.preferences.filepaths.save_version = 0
    bpy.ops.wm.save_as_mainfile(filepath=os.path.join(REPO, rel + ".blend"), compress=True)
    splice_clips.splice(os.path.join(fresh, rel + ".glb"), os.path.join(REPO, rel + ".glb"))


if __name__ == "__main__":
    args = [a for a in sys.argv[1:] if not a.startswith("-")]
    if len(args) < 2:
        sys.exit(__doc__)
    for who in args[1:]:
        refresh(os.path.abspath(args[0]), who)
