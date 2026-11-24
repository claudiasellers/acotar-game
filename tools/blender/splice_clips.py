"""Puts freshly authored clips into a model without touching its looks.

    python3 tools/blender/splice_clips.py <donor.gltf> <target.gltf>

Re-exporting a creature from another Blender build changes how its mesh is
split (the same triangles, other vertex counts), so a clip change would drag
the whole model along. This takes only the animations from the donor (a
fresh tools/blender/creatures.py export of the same creature) and writes them
into the target; the target's meshes, materials, skin and nodes keep every
byte. Both must have the same nodes (the same skeleton), or it stops.

Plain Python, no Blender. Embedded-buffer .gltf only.
"""
import base64
import json
import sys

PREFIX = "data:application/octet-stream;base64,"


def load(path):
    with open(path) as f:
        g = json.load(f)
    if len(g["buffers"]) != 1 or not g["buffers"][0].get("uri", "").startswith(PREFIX):
        sys.exit(f"{path}: expected one embedded buffer")
    return g, base64.b64decode(g["buffers"][0]["uri"][len(PREFIX):])


def pose(node):
    return json.dumps({k: node.get(k) for k in ("name", "translation", "rotation", "scale", "children", "skin", "mesh")},
                      sort_keys=True)


def anim_accessors(g):
    used = set()
    for a in g.get("animations", []):
        for s in a["samplers"]:
            used.update((s["input"], s["output"]))
    return used


def splice(donor_path, target_path):
    donor, donor_bin = load(donor_path)
    target, target_bin = load(target_path)
    if [pose(n) for n in donor["nodes"]] != [pose(n) for n in target["nodes"]]:
        sys.exit(f"{donor_path} and {target_path} have different nodes; regenerate the model instead")

    # Everything in the target that is not animation data, repacked in order.
    drop = anim_accessors(target)
    others = set()
    for i, acc in enumerate(target["accessors"]):
        if i not in drop:
            others.add(acc["bufferView"])
    for img in target.get("images", []):
        if "bufferView" in img:
            others.add(img["bufferView"])
    drop_views = {target["accessors"][i]["bufferView"] for i in drop} - others
    out = bytearray()
    views, view_map = [], {}
    for i, view in enumerate(target["bufferViews"]):
        if i in drop_views:
            continue
        view_map[i] = len(views)
        views.append(_copy_view(view, target_bin, out))
    accessors, acc_map = [], {}
    for i, acc in enumerate(target["accessors"]):
        if i in drop:
            continue
        acc_map[i] = len(accessors)
        accessors.append(dict(acc, bufferView=view_map[acc["bufferView"]]))
    _remap(target, acc_map, view_map)

    # The donor's clips, appended.
    donor_map, donor_views = {}, {}
    for i in sorted(anim_accessors(donor)):
        acc = donor["accessors"][i]
        v = acc["bufferView"]
        if v not in donor_views:
            donor_views[v] = len(views)
            views.append(_copy_view(donor["bufferViews"][v], donor_bin, out))
        donor_map[i] = len(accessors)
        accessors.append(dict(acc, bufferView=donor_views[v]))
    animations = []
    for a in donor["animations"]:
        animations.append(dict(a, samplers=[dict(s, input=donor_map[s["input"]], output=donor_map[s["output"]])
                                            for s in a["samplers"]]))

    target["bufferViews"] = views
    target["accessors"] = accessors
    target["animations"] = animations
    target["buffers"] = [{"byteLength": len(out), "uri": PREFIX + base64.b64encode(bytes(out)).decode()}]
    with open(target_path, "w") as f:
        json.dump(target, f, separators=(",", ":"))
    print(f"{target_path}: {len(animations)} clips from {donor_path}, {len(out)} bytes")


def _copy_view(view, src, out):
    while len(out) % 4:
        out.append(0)
    start = view.get("byteOffset", 0)
    copy = dict(view, buffer=0, byteOffset=len(out))
    out.extend(src[start:start + view["byteLength"]])
    return copy


def _remap(g, acc_map, view_map):
    for mesh in g.get("meshes", []):
        for prim in mesh["primitives"]:
            prim["attributes"] = {k: acc_map[v] for k, v in prim["attributes"].items()}
            if "indices" in prim:
                prim["indices"] = acc_map[prim["indices"]]
            if "targets" in prim:
                prim["targets"] = [{k: acc_map[v] for k, v in t.items()} for t in prim["targets"]]
    for skin in g.get("skins", []):
        if "inverseBindMatrices" in skin:
            skin["inverseBindMatrices"] = acc_map[skin["inverseBindMatrices"]]
    for img in g.get("images", []):
        if "bufferView" in img:
            img["bufferView"] = view_map[img["bufferView"]]


if __name__ == "__main__":
    if len(sys.argv) != 3:
        sys.exit(__doc__)
    splice(sys.argv[1], sys.argv[2])
