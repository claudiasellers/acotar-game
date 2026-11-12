# Contract: village shops, fells, blight and routine props (lane L73)

Owner: L73 (`art/wider_world/`, `tools/blender/wider_world_props.py`,
`tools/blender/upcoming_kit.py`, `tests/unit/upcoming/`). Models only, all [X]:
they dress places GAME_DESIGN_PLAN.md adds, not scenes from the book. Nothing
places them yet.

Rebuild: `/opt/bpyenv/bin/python tools/blender/wider_world_props.py` (deterministic;
`--only a,b`, `--sheet <dir>`). Sizes and triangle counts are in
`art/wider_world/wider_world_manifest.json`.

Same mesh contract as the other L73 families: node `<id>` and `<id>_lod1`,
vertex colour, finish index in UV.x, "opaque" and "clear" materials, true size,
base on the origin, front toward -Z, albedo at or under 0.85, at or under 3,000
triangles with a LOD1 at about half.

## Village of the Lesser Fae

Seamstress: `seam_dress_form`, `seam_loom`, `seam_fabric_bolts`,
`seam_ribbon_rack` (wall-hung), `seam_worktable`, `seam_crown_stand`.
Potion-maker: `potion_shelf`, `potion_alembic`, `potion_mortar`,
`potion_herb_rack` (hangs from a beam), `potion_counter`. Bottle colours match
the five steeped arrows in `art/arms/`.

## Western Fells and Sea Cliffs

Climbables: `climb_ivy_panel` (2 m wide, 3 m tall, tiles upward),
`climb_root_ladder`, `climb_ledge`, `climb_handholds`. Each carries the same
tell so a climbable reads at a glance: small butter-yellow star flowers (glowcaps
on the roots). They stand upright on the origin, growing up +Y, to be pushed against their wall.
`cliff_rope_anchor` is where a rope arrow bites.

Sentry dressing: `signal_brazier`, `sentry_weapon_rack`, `sentry_banner`,
`range_marker` (a distance post for the bow range).

## Blighted Reaches

Horror is not softened (R3). `blight_rose_bush`, `blight_thorn_arch`,
`blight_carcass`, `blight_dry_fountain`, `blight_withered_patch`,
`blight_dead_birds`.

## Cast routines

`laundry_basket`, `whetstone_kit`.
