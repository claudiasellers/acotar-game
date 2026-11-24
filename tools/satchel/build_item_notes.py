#!/usr/bin/env python3
"""Writes data/satchel/notes/<id>.tres from tools/satchel/item_notes.tsv, one
ItemNotes per item. Edit the table, then run from the repo root:
python3 tools/satchel/build_item_notes.py"""
import os

TABLE = "tools/satchel/item_notes.tsv"
OUT = "data/satchel/notes"
BODY = """[gd_resource type="Resource" script_class="ItemNotes" format=3]

[ext_resource type="Script" path="res://data/satchel/item_notes.gd" id="1"]

[resource]
script = ExtResource("1")
id = &"{id}"
labels = PackedStringArray("{a}", "{b}")
canon = "{canon}"
"""

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    wanted = set()
    for row in open(TABLE, encoding="utf-8"):
        row = row.rstrip("\n")
        if not row or row.startswith("#"):
            continue
        item, a, b, canon = row.split("\t")
        name = item.replace(":", "_") + ".tres"
        wanted.add(name)
        with open(os.path.join(OUT, name), "w", encoding="utf-8") as f:
            f.write(BODY.format(id=item, a=a, b=b, canon=canon))
    for name in os.listdir(OUT):
        if name.endswith(".tres") and name not in wanted:
            os.remove(os.path.join(OUT, name))
