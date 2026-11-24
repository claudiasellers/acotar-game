"""Puts freshly authored clips into a model without touching its looks.

    python3 tools/blender/splice_clips.py [--rest] <donor> <target>

Re-exporting a creature from another Blender build changes how its mesh is
split (the same triangles, other vertex counts), so a clip change would drag
the whole model along. This takes only the animations from the donor (a
fresh tools/blender/creatures.py export of the same creature) and writes them
into the target; the target's meshes, materials, skin and nodes keep every
byte. Bones are matched by name and must rest alike in both, or it stops
(--rest takes the donor's rest pose too, for a model whose rest is a frame
of a clip); the target may carry nodes the donor lacks (a mesh added after
the build).

Plain Python, no Blender. Takes .glb and .gltf (buffer embedded or in a
.bin beside it); the target keeps its form. The donor may be either.
"""
import base64
import json
import os
import struct
import sys

PREFIX = "data:application/octet-stream;base64,"
GLB_MAGIC, CHUNK_JSON, CHUNK_BIN = 0x46546C67, 0x4E4F534A, 0x004E4942


def load(path):
    """The model's JSON and its one buffer: a .glb, or a .gltf with the buffer
    embedded or in a .bin beside it."""
    if path.endswith(".glb"):
        with open(path, "rb") as f:
            data = f.read()
        magic, _version, _length = struct.unpack_from("<III", data, 0)
        if magic != GLB_MAGIC:
            sys.exit(f"{path}: not a glb")
        size, kind = struct.unpack_from("<II", data, 12)
        if kind != CHUNK_JSON:
            sys.exit(f"{path}: expected the JSON chunk first")
        g = json.loads(data[20:20 + size])
        at = 20 + size
        size, kind = struct.unpack_from("<II", data, at)
        if kind != CHUNK_BIN or len(g["buffers"]) != 1:
            sys.exit(f"{path}: expected one binary chunk")
        return g, data[at + 8:at + 8 + g["buffers"][0]["byteLength"]]
    with open(path) as f:
        g = json.load(f)
    if len(g["buffers"]) != 1:
        sys.exit(f"{path}: expected one buffer")
    uri = g["buffers"][0].get("uri", "")
    if uri.startswith(PREFIX):
        return g, base64.b64decode(uri[len(PREFIX):])
    with open(os.path.join(os.path.dirname(path), uri), "rb") as f:
        return g, f.read()


def save(path, g, out):
    """Writes the model back in the form it came in."""
    if path.endswith(".glb"):
        g["buffers"] = [{"byteLength": len(out)}]
        text = json.dumps(g, separators=(",", ":")).encode()
        text += b" " * (-len(text) % 4)
        body = bytes(out) + b"\0" * (-len(out) % 4)
        with open(path, "wb") as f:
            f.write(struct.pack("<III", GLB_MAGIC, 2, 28 + len(text) + len(body)))
            f.write(struct.pack("<II", len(text), CHUNK_JSON) + text)
            f.write(struct.pack("<II", len(body), CHUNK_BIN) + body)
        return
    uri = g["buffers"][0].get("uri", "")
    if uri.startswith(PREFIX):
        g["buffers"] = [{"byteLength": len(out), "uri": PREFIX + base64.b64encode(bytes(out)).decode()}]
    else:
        g["buffers"] = [{"byteLength": len(out), "uri": uri}]
        with open(os.path.join(os.path.dirname(path), uri), "wb") as f:
            f.write(bytes(out))
    with open(path, "w") as f:
        json.dump(g, f, separators=(",", ":"))


def rest(node):
    return json.dumps({k: node.get(k) for k in ("translation", "rotation", "scale")}, sort_keys=True)


def bone_map(donor, target, donor_path, target_path, take_rest):
    """Donor node -> target node for every node the donor's clips move, matched
    by name. The two rests must be equal, since a body nothing plays stands in
    its rest; with take_rest the target takes the donor's (the court and
    village figures rest in the first frame of their idle)."""
    by_name = {}
    for i, n in enumerate(target["nodes"]):
        by_name.setdefault(n.get("name"), []).append(i)
    out = {}
    for a in donor.get("animations", []):
        for ch in a["channels"]:
            i = ch["target"]["node"]
            if i in out:
                continue
            node = donor["nodes"][i]
            found = by_name.get(node.get("name"), [])
            if len(found) != 1:
                sys.exit(f"{target_path} has no single bone {node.get('name')}; regenerate the model instead")
            if rest(target["nodes"][found[0]]) != rest(node):
                if not take_rest:
                    sys.exit(f"{donor_path} and {target_path} rest differently at bone {node.get('name')}; "
                             "pass --rest to take the donor's rest, or regenerate the model")
                for k in ("translation", "rotation", "scale"):
                    target["nodes"][found[0]].pop(k, None)
                    if k in node:
                        target["nodes"][found[0]][k] = node[k]
            out[i] = found[0]
    return out


def anim_accessors(g):
    used = set()
    for a in g.get("animations", []):
        for s in a["samplers"]:
            used.update((s["input"], s["output"]))
    return used


def splice(donor_path, target_path, take_rest=False):
    donor, donor_bin = load(donor_path)
    target, target_bin = load(target_path)
    bones = bone_map(donor, target, donor_path, target_path, take_rest)

    # Everything in the target that is not animation data, repacked in order.
    drop = anim_accessors(target)
    others = set()
    for i, acc in enumerate(target["accessors"]):
        if i not in drop:
            others.update(_views_of(acc))
    for img in target.get("images", []):
        if "bufferView" in img:
            others.add(img["bufferView"])
    drop_views = {v for i in drop for v in _views_of(target["accessors"][i])} - others
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
        accessors.append(_with_views(acc, view_map))
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
                                            for s in a["samplers"]],
                               channels=[dict(c, target=dict(c["target"], node=bones[c["target"]["node"]]))
                                         for c in a["channels"]]))

    target["bufferViews"] = views
    target["accessors"] = accessors
    target["animations"] = animations
    save(target_path, target, out)
    print(f"{target_path}: {len(animations)} clips from {donor_path}, {len(out)} bytes")


def _views_of(acc):
    """Buffer views an accessor reads, its sparse (blend shape) parts included."""
    found = [acc["bufferView"]] if "bufferView" in acc else []
    for part in ("indices", "values"):
        if "sparse" in acc:
            found.append(acc["sparse"][part]["bufferView"])
    return found


def _with_views(acc, view_map):
    copy = dict(acc)
    if "bufferView" in acc:
        copy["bufferView"] = view_map[acc["bufferView"]]
    if "sparse" in acc:
        copy["sparse"] = dict(acc["sparse"])
        for part in ("indices", "values"):
            copy["sparse"][part] = dict(acc["sparse"][part], bufferView=view_map[acc["sparse"][part]["bufferView"]])
    return copy


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
    args = [a for a in sys.argv[1:] if a != "--rest"]
    if len(args) != 2:
        sys.exit(__doc__)
    splice(args[0], args[1], take_rest="--rest" in sys.argv)
