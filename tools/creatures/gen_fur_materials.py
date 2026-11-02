"""Writes the fur coat materials (lane L43): a hide pass plus N shell passes
chained by next_pass, and the guard-hair card material. Deterministic.

Run: python3 tools/creatures/gen_fur_materials.py
Out: creatures/materials/<name>_coat.tres, great_wolf_guard_hair.tres
Wired in by the _subresources material remaps in creatures/models/*.gltf.import.

Draw calls: one per pass, so the great wolf's coat costs 1 + SHELLS.
"""

import os

ROOT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "..")
OUT = os.path.join(ROOT, "creatures", "materials")


def col(rgb):
    return "Color(%g, %g, %g, 1)" % rgb


COATS = {
    # Andras [C ch1, keeper]: charcoal and obsidian with ivory, reading silver
    # at a distance. Long, shaggy, starved: ribs show through.
    "great_wolf": dict(shells=6, params=dict(
        coat=col((0.24, 0.24, 0.27)), pale=col((0.62, 0.59, 0.52)), dark=col((0.06, 0.06, 0.07)),
        tip=col((0.74, 0.76, 0.8)), mouth=col((0.22, 0.04, 0.05)), tip_amount=0.65,
        fur_length=0.075, density=70.0, droop=0.4, comb=0.6, streak=0.55, rib_depth=0.55, rib_spacing=0.085,
        rim_amount=0.55, roughness_fur=0.8)),
    # The opening doe, winter coat [X]: grey-brown back, warmer flank, white
    # belly, throat, rump and tail flag, dark nose and ear rims.
    "deer": dict(shells=4, params=dict(
        coat=col((0.55, 0.41, 0.29)), pale=col((0.9, 0.87, 0.81)), dark=col((0.12, 0.08, 0.06)),
        tip=col((0.66, 0.58, 0.49)), mouth=col((0.3, 0.12, 0.12)), tip_amount=0.4,
        fur_length=0.022, density=130.0, droop=0.2, comb=0.7, streak=0.4, rib_depth=0.0, rib_spacing=0.09,
        rim_amount=0.35, roughness_fur=0.85)),
}

CARDS = {
    "great_wolf": dict(root_color=col((0.07, 0.07, 0.08)), tip_color=col((0.62, 0.64, 0.68)),
                       pale=col((0.6, 0.57, 0.5)), strands=6.0, rim_amount=0.55),
}


def params(d):
    return "".join("shader_parameter/%s = %s\n" % (k, v if isinstance(v, str) else repr(float(v))) for k, v in d.items())


def coat_tres(name, spec):
    n = spec["shells"]
    lines = ['[gd_resource type="ShaderMaterial" load_steps=%d format=3]\n\n' % (n + 2),
             '[ext_resource type="Shader" path="res://creatures/materials/fur.gdshader" id="1_fur"]\n\n']
    # Outermost shell first so each sub_resource can name the next.
    for i in range(n, 0, -1):
        lines.append('[sub_resource type="ShaderMaterial" id="Shell%d"]\n' % i)
        if i < n:
            lines.append('next_pass = SubResource("Shell%d")\n' % (i + 1))
        lines.append('shader = ExtResource("1_fur")\n')
        lines.append(params(spec["params"]))
        lines.append("shader_parameter/shell = %r\n\n" % (i / float(n)))
    lines.append("[resource]\n")
    lines.append('resource_name = "%s_coat"\n' % name)
    if n:
        lines.append('next_pass = SubResource("Shell1")\n')
    lines.append('shader = ExtResource("1_fur")\n')
    lines.append(params(spec["params"]))
    lines.append("shader_parameter/shell = 0.0\n")
    return "".join(lines)


def card_tres(name, spec):
    return ('[gd_resource type="ShaderMaterial" load_steps=2 format=3]\n\n'
            '[ext_resource type="Shader" path="res://creatures/materials/fur_card.gdshader" id="1_card"]\n\n'
            '[resource]\nresource_name = "%s_guard_hair"\nshader = ExtResource("1_card")\n' % name + params(spec))


def main():
    os.makedirs(OUT, exist_ok=True)
    for name, spec in COATS.items():
        with open(os.path.join(OUT, f"{name}_coat.tres"), "w") as f:
            f.write(coat_tres(name, spec))
    for name, spec in CARDS.items():
        with open(os.path.join(OUT, f"{name}_guard_hair.tres"), "w") as f:
            f.write(card_tres(name, spec))
    print("fur materials ->", os.path.relpath(OUT, ROOT))


if __name__ == "__main__":
    main()
