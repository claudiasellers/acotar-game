#!/usr/bin/env python3
"""One-off (render program T2): swap built-in stock material sub-resources in
.tscn files for the CandyMaterial .tres files convert_scene_materials.gd wrote.
Reads its "MAP res://a.tscn::Type_id -> res://b.tres (OK)" lines on stdin."""
import re
import sys

maps = {}
for line in sys.stdin:
    m = re.match(r"MAP res://(\S+)::(\S+) -> (res://\S+)", line)
    if m:
        maps.setdefault(m.group(1), []).append((m.group(2), m.group(3)))

for scene, items in maps.items():
    text = open(scene).read()
    blocks = re.split(r"(?m)^(?=\[)", text)
    ids = {sub for sub, _ in items}
    blocks = [b for b in blocks if not any(b.startswith('[sub_resource type="%s" id="%s"]' % (s.split("_")[0], s)) for s in ids)]
    ext = "".join('[ext_resource type="Material" path="%s" id="candy_%s"]\n' % (tres, sub.split("_", 1)[1]) for sub, tres in items)
    last_ext = max(i for i, b in enumerate(blocks) if b.startswith("[ext_resource"))
    blocks[last_ext] = blocks[last_ext].rstrip("\n") + "\n" + ext + ("\n" if blocks[last_ext].endswith("\n\n") else "")
    text = "".join(blocks)
    for sub, _ in items:
        text = text.replace('SubResource("%s")' % sub, 'ExtResource("candy_%s")' % sub.split("_", 1)[1])
    # drop sub-resources nothing references any more (the gradients those materials used)
    while True:
        blocks = re.split(r"(?m)^(?=\[)", text)
        dead = []
        for b in blocks:
            m = re.match(r'\[sub_resource type="\w+" id="([^"]+)"\]', b)
            if m and text.count('SubResource("%s")' % m.group(1)) == 0:
                dead.append(b)
        if not dead:
            break
        text = "".join(b for b in blocks if b not in dead)
    open(scene, "w").write(text)
    print("patched", scene, len(items))
