"""Writes creatures/people/scenes/<id>.tscn for every secondary-cast model.

Run: python3 tools/creatures/gen_people_scenes.py  (after tools/blender/fae_people.py)
Edit PEOPLE below; canon tags follow the keeper (C canon, C? implied, X invented).
"""

import os

ROOT = os.path.join(os.path.dirname(__file__), "..", "..")
MODELS = os.path.join(ROOT, "creatures", "models", "people")
OUT = os.path.join(ROOT, "creatures", "people", "scenes")

# id: (display name, canon, wander radius)
PEOPLE = {
    "alis": ("Alis", "C", 0.0),
    "servant_maid": ("Maid", "C?", 3.0),
    "servant_footman": ("Footman", "C?", 0.0),
    "servant_cook": ("Cook", "C?", 2.0),
    "seamstress": ("Seamstress", "C?", 1.5),
    "potion_maker": ("Potion-maker", "C?", 1.5),
    "sentry_1": ("Sentry", "X", 0.0),
    "sentry_2": ("Sentry", "X", 0.0),
    "fae_dryad": ("Dryad", "X", 4.0),
    "fae_mushroom": ("Toadstool faerie", "X", 3.0),
    "fae_moth": ("Moth faerie", "X", 4.0),
    "fae_fox": ("Fox faerie", "X", 5.0),
    "fae_stag": ("Stag faerie", "X", 4.0),
    "fae_nymph": ("Water nymph", "X", 3.0),
    "fae_birch": ("Birch faerie", "X", 2.0),
    "fae_hedgehog": ("Hedgehog faerie", "X", 3.0),
    "fae_pixie": ("Pixie", "X", 5.0),
    "fae_satyr": ("Satyr", "X", 4.0),
    "fae_rose": ("Rose faerie", "X", 3.0),
    "fae_owl": ("Owl faerie", "X", 2.0),
    "human_woman": ("Villager", "C?", 4.0),
    "human_man": ("Villager", "C?", 4.0),
    "human_elder": ("Old villager", "C?", 2.0),
    "human_youth": ("Villager", "C?", 5.0),
    "peddler": ("Peddler", "C?", 0.0),
}


def scene(pid, name, canon, wander):
    true = os.path.exists(os.path.join(MODELS, f"{pid}_true.gltf"))
    steps = 4 if true else 3
    lines = [f"[gd_scene load_steps={steps} format=3]", "",
             '[ext_resource type="Script" path="res://creatures/people/court_npc.gd" id="1"]',
             f'[ext_resource type="PackedScene" path="res://creatures/models/people/{pid}.gltf" id="2"]']
    if true:
        lines.append(f'[ext_resource type="PackedScene" path="res://creatures/models/people/{pid}_true.gltf" id="3"]')
    node = "".join(w.capitalize() for w in pid.split("_"))
    lines += ["", f'[node name="{node}" type="Node3D"]', 'script = ExtResource("1")', f'npc_id = &"{pid}"',
              f'display_name = "{name}"', f'canon = "{canon}"', 'model_scene = ExtResource("2")']
    if true:
        lines.append('true_model_scene = ExtResource("3")')
    lines.append(f"wander_radius = {wander}")
    with open(os.path.join(OUT, f"{pid}.tscn"), "w") as f:
        f.write("\n".join(lines) + "\n")


if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    for pid, (name, canon, wander) in PEOPLE.items():
        scene(pid, name, canon, wander)
    print(len(PEOPLE), "people")
