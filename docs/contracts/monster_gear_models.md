# Contract: monster weapon and camp gear models (lane L88)

Owner: L88 (`art/monster_gear/`, `tools/blender/monster_gear*.py`,
`tools/monster_gear/`, `tests/unit/monster_gear/`). Models only. The names,
stats, durability, imbues, loot and placement are L75's
(`plans/hostile-fae/monster-gear.md`); the ids here are that spec's, so the
game loads `art/monster_gear/<id>.glb` by item id.

Rebuild: `/opt/bpyenv/bin/python tools/blender/monster_gear.py` (deterministic;
`--family <name>` or `--only id,id` for a part, `--sheet <dir>` for look
sheets). Sizes, triangle counts and every point below are in
`art/monster_gear/monster_gear_manifest.json`, in the game's axes.

In-engine line-up beside Feyre:
`godot --path . res://tools/monster_gear/gear_shot.tscn -- <out_dir> <weapons|camp|hands> [family]`.

All meshes follow the prop_kit contract: vertex colour in COLOR_0, the finish
index in UV.x, two materials ("opaque", "clear"), so `PropFinishes` shades
them. No textures, no emission. Albedo is capped at 0.85 per channel. Every
model is at or under 3,000 triangles with a LOD1 at half.

## Weapons

| Node | What |
|---|---|
| `<id>` | the weapon. The grip's centre is the origin, it runs up +Y, and its edge or striking face looks down -Z: the bows' axes, so one hand socket fits both |
| `<id>_worn` | the same weapon near breaking, in the same place: chipped and cracked, a bite out of its leading edge, the haft splinted or the binding trailing, a step darker. Its outline from the side differs from the clean one's by at least 4% (the manifest's `worn_delta`; the build fails under that). Hidden by default in the game's hands: show it instead of `<id>` below 30% durability |
| `<id>_lod1` | one merged mesh at half the triangles |
| `<id>_tip` | empty at the far end. Its distance from the grip is the manifest's `reach_m` |
| `<id>_imbue` | empty where a steep's glow hangs |

The same file is the world drop. The manifest's `rest_deg` (rotation, degrees)
and `rest_lift_m` (lift above the ground) lay it flat. `hands` is 1 or 2.
The flail's `_cord` is modelled running straight on past the stick, its origin
at the stick's tip: rotate it about X to hang or swing it.

| Id | Family | Reach (m) | Hands | Look |
|---|---|---|---|---|
| `wpn_gloamer_hookknife` | gloamer | 0.341 | 1 | a mortal reaping hook ground down to a knife, cord grip, one stolen trinket |
| `wpn_gloamer_knuckleclub` | gloamer | 0.585 | 1 | a root club studded with knuckle bones |
| `wpn_gloamer_trinket_flail` | gloamer | 1.36 | 1 | a stick and a 1 m cord of stolen silver and brass; child `_cord` hangs from the stick's tip |
| `wpn_gloamer_scythe_glaive` | gloamer | 1.172 | 2 | a scythe blade lashed straight on a pole, two hands |
| `wpn_woodcutter_hatchet` | gloamer | 0.269 | 1 | a mortal hatchet, black-brown iron worn bright at the edge |
| `wpn_pruning_hook` | gloamer | 0.648 | 1 | a gardener's long hook |
| `wpn_naga_talon_knife` | naga | 0.259 | 1 | one black wet talon, the root wrapped in shed skin |
| `wpn_naga_talon_hook` | naga | 0.307 | 1 | a talon lashed across a reed stem |
| `wpn_fishers_gaff` | naga | 1.039 | 2 | a mortal fisher's gaff on an alder pole |
| `wpn_briar_thorn_whip` | briarling | 1.398 | 1 | a living cane on its root ball; the worn one has lost its leaves |
| `wpn_briar_rose_shiv` | briarling | 0.23 | 1 | one great thorn in a bound hip |
| `wpn_smiths_hammer` | hob | 0.265 | 1 | a cross-peen hammer on a gnawed oak root |
| `wpn_shepherds_crook` | hob | 0.868 | 2 | an iron crook with wool caught in it, two hands |
| `wpn_hob_tooth_cleaver` | hob | 0.44 | 1 | one of the Hob's teeth split and bound to a stone-weighted handle (unique) |
| `wpn_blackvein_veinhook` | blackvein | 0.352 | 1 | a long hooked finger, pearl with a black vein, silk-wrapped knuckle |
| `wpn_blackvein_jaw_shears` | blackvein | 0.245 | 1 | half a sideways jaw, hooked teeth on the inner edge |
| `wpn_martax_tooth_club` | martax | 0.565 | 2 | a thigh bone with three staggered rows of teeth under rawhide, two hands |
| `wpn_martax_fang_knife` | martax | 0.237 | 1 | a yellowed serrated fang gripped in matted mane |
| `wpn_crow_beak_awl` | crow | 0.137 | 1 | a hooked beak on a twig, an eye-spot feather at the butt |

## Camp gear

| Node | What |
|---|---|
| `<id>` | base centre at the origin, up +Y, front toward -Z |
| `<id>_lod1` | one merged mesh |
| `<id>_loot` | empty at a container's mouth, where the loot prompt and the spill go |
| `<id>_lid` | a mesh whose origin is its hinge: rotate it to open |
| `<id>_fire`, `_rest`, `_cut` | empties: where a flame or glow goes, where the monster lies, where she cuts |

A piece whose manifest row has `hangs: true` has its origin at the point it
hangs from and runs down from there (the drape hangs from two points, 2 m
either side of its origin along X).

Keeper rules these models keep: naga carry nothing made (talons and a mortal
gaff only), no ash wood on any handle, no Spring Court, sentry or High Fae
gear, and every skull and bone is a beast's.

| Id | Family | Size x × y × z (m) | Notes |
|---|---|---|---|
| `camp_gloamer_hoard_log` | gloamer | 2.795 × 1.123 × 0.89 | hollow log; child `_lid` is the bark flap |
| `camp_gloamer_shiny_line` | gloamer | 1.003 × 0.586 × 1.032 | stolen things in a row on a stump |
| `camp_gloamer_trinket_cords` | gloamer | 3.815 × 2.447 × 0.265 | cords of trinkets between two stakes |
| `camp_gloamer_squabble_pile` | gloamer | 1.333 × 0.726 × 1.054 | kettle, boot, lantern, basket |
| `camp_gloamer_rag_nest` | gloamer | 1.68 × 0.416 × 1.677 | a nest of stolen cloth |
| `camp_naga_reed_cache` | naga | 1.231 × 0.873 × 1.273 | woven reed pot; child `_lid` |
| `camp_naga_basking_stone` | naga | 2.203 × 0.533 × 2.161 | a flat river stone |
| `camp_naga_midden` | naga | 1.495 × 0.416 × 1.193 | fish bones in mud |
| `camp_naga_reed_nest` | naga | 3.128 × 0.938 × 3.372 | a trampled reed ring |
| `camp_briar_seedpods` | briarling | 0.92 × 0.741 × 0.77 | black thorned pods |
| `camp_briar_thorn_cage` | briarling | 0.572 × 1.46 × 0.538 | a cage of canes on a stem; child `_bird`, empty `_cut` where she cuts it open |
| `camp_briar_uprooted_ring` | briarling | 7.373 × 0.562 × 6.67 | eight rose bushes pulled up in a 7 m ring |
| `camp_hob_loot_pile` | hob | 2.895 × 1.836 × 3.065 | cart wheel, scarecrow's coat, cradle, plough share |
| `camp_hob_sleep_stone` | hob | 4.24 × 0.896 × 3.584 | a 4 m mossy slab with a worn hollow; empty `_rest` |
| `camp_hob_sheep_bones` | hob | 1.432 × 0.273 × 1.126 | skulls, a rib cage, fleece |
| `camp_blackvein_cocoon` | blackvein | 0.478 × 1.227 × 0.497 | hangs; a silk bundle with a shape inside; empty `_cut` |
| `camp_blackvein_silk_drape` | blackvein | 4.321 × 1.935 × 0.87 | hangs from two points 4 m apart |
| `camp_blackvein_bone_rain` | blackvein | 1.758 × 0.057 × 1.808 | small bird bones over 2 m |
| `camp_martax_den_hoard` | martax | 3.709 × 1.439 × 2.193 | a cart on its side, sacks spilled |
| `camp_martax_bone_heap` | martax | 2.095 × 0.664 × 2.033 | cracked cattle bones |
| `camp_martax_drag_furrow` | martax | 6.066 × 0.327 × 1.342 | 5 m of furrows along X to a half-eaten deer at +X |
| `camp_lampwing_roost_lantern` | lampwing | 0.209 × 0.634 × 0.237 | hangs; a dusty mortal lantern; empty `_fire` where the game lights it |
| `camp_fire_spit` | any | 1.586 × 0.885 × 1.185 | extra: a cook fire and spit; empty `_fire` |
| `camp_bone_totem` | any | 0.947 × 2.761 × 0.445 | extra: beast skulls on a pole |
| `camp_skull_stake` | any | 0.296 × 1.194 × 0.226 | extra: one beast skull on a stake |
| `camp_hide_lean_to` | any | 2.3 × 1.443 × 1.656 | extra: a hide shelter |

The four `camp_*` pieces marked "extra" are not in the spec: generic camp
dressing for any family, free to use or leave.
