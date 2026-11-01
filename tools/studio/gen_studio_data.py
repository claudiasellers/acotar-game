#!/usr/bin/env python3
"""Writes data/studio/*.tres for Feyre's studio (L30). Run from the repo root:
    python3 tools/studio/gen_studio_data.py
Canon (Keeper, ch16/19): the painting room is stocked with "so, so many paints,
beyond the four basic ones". Exact colours are [X]; the colour book is [X].
"""
import os

def col(h):
    h = h.lstrip("#")
    return tuple(int(h[i:i + 2], 16) / 255.0 for i in (0, 2, 4))

def paint_set(path, sid, entries, notes):
    names = ", ".join('"%s"' % n for n, _ in entries)
    cols = ", ".join("%.3f, %.3f, %.3f, 1" % col(h) for _, h in entries)
    with open(path, "w") as f:
        f.write('[gd_resource type="Resource" script_class="StudioPaintSet" format=3]\n\n')
        f.write('[ext_resource type="Script" path="res://data/studio/studio_paint_set.gd" id="1"]\n\n')
        f.write('[resource]\nscript = ExtResource("1")\n')
        f.write('id = &"%s"\nnames = PackedStringArray(%s)\ncolors = PackedColorArray(%s)\n' % (sid, names, cols))
        f.write('canon = "X"\nnotes = "%s"\n' % notes)

# The manor stock: the four basics first, then the rest (unlimited, after gallery_opened).
MANOR = [
    ("Vermilion", "#d8402e"), ("Chrome yellow", "#f2c230"), ("Ultramarine", "#2f4fb0"), ("Lead white", "#f6f2ea"),
    ("Lamp black", "#24202a"), ("Rose madder", "#e0607e"), ("Sap green", "#4f8a3c"), ("Yellow ochre", "#c99a45"),
    ("Burnt umber", "#6b4630"), ("Cerulean", "#5aa6d6"), ("Viridian", "#2f8f7a"), ("Violet", "#7d55b5"),
    ("Blush", "#f7c6d0"), ("Lilac", "#cdb4f0"), ("Periwinkle", "#9fb2f2"), ("Mint", "#b7ecd2"),
    ("Butter", "#fbe7a1"), ("Pearl", "#f3ecf4"), ("Gold leaf", "#e6c06a"), ("Starlight silver", "#d7dbe8"),
]
# The colour book: shades to discover by mixing on the palette.
BOOK = [
    ("Rose", "#e98aa5"), ("Blush", "#f7c6d0"), ("Lilac", "#cdb4f0"), ("Periwinkle", "#9fb2f2"),
    ("Mint", "#b7ecd2"), ("Butter", "#fbe7a1"), ("Pearl", "#f3ecf4"), ("Spring green", "#7cc36a"),
    ("Moss", "#5e7a3a"), ("Forest", "#2f5a3a"), ("Sky", "#8cc4ec"), ("Twilight", "#5a4f8f"),
    ("Plum", "#7a3d6a"), ("Coral", "#f08a70"), ("Apricot", "#f6b67a"), ("Honey", "#e3a83a"),
    ("Fawn", "#b8926a"), ("Bark", "#5e4433"), ("Slate", "#5d6a7a"), ("Dove grey", "#b9b4bd"),
    ("Snow shadow", "#c7d3e6"), ("Ember", "#c4472c"), ("Wine", "#7e2238"), ("Starlit teal", "#3f8f98"),
    ("Lavender", "#b39ad8"), ("Seafoam", "#9fd8c4"),
]
BRUSHES = [
    # id, name, shape, opacity, pickup, spacing, size_scale, oriented
    ("round", "Round sable", "ROUND", 0.8, 0.22, 0.22, 1.0, False),
    ("flat", "Flat", "FLAT", 0.9, 0.18, 0.18, 1.1, True),
    ("bristle", "Bristle", "BRISTLE", 0.85, 0.35, 0.15, 1.2, True),
    ("wash", "Wash", "WASH", 0.22, 0.08, 0.2, 1.8, False),
    ("sparkle", "Sparkle", "SPARKLE", 0.9, 0.0, 0.9, 1.4, False),
]
SHAPES = {"ROUND": 0, "FLAT": 1, "BRISTLE": 2, "WASH": 3, "SPARKLE": 4}

def main():
    os.makedirs("data/studio/brushes", exist_ok=True)
    paint_set("data/studio/manor_paints.tres", "manor_paints", MANOR,
              "The painting room's stock (ch19, [C] that it is stocked; the colours are [X]).")
    paint_set("data/studio/colour_book.tres", "colour_book", BOOK,
              "Shades Feyre can discover by mixing [X].")
    for bid, name, shape, op, pick, sp, sc, orient in BRUSHES:
        with open("data/studio/brushes/%s.tres" % bid, "w") as f:
            f.write('[gd_resource type="Resource" script_class="StudioBrushData" format=3]\n\n')
            f.write('[ext_resource type="Script" path="res://data/studio/studio_brush_data.gd" id="1"]\n\n')
            f.write('[resource]\nscript = ExtResource("1")\n')
            f.write('id = &"%s"\ndisplay_name = "%s"\nshape = %d\nopacity = %s\npickup = %s\nspacing = %s\nsize_scale = %s\noriented = %s\ncanon = "X"\n'
                    % (bid, name, SHAPES[shape], op, pick, sp, sc, "true" if orient else "false"))

if __name__ == "__main__":
    main()
