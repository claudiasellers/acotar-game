# Wardrobe contract (outfits, hair, makeup)

Owner: gameplay lane (`data/wardrobe/`, `systems/wardrobe/`). Feyre's model and the dressing-room UI build against this.

## Data (all `.tres`, `canon` "C", "C?" or "X")
- `WardrobePiece` (`data/wardrobe/pieces/*.tres`): `id`, `display_name`, `slots` (any of `top bottom outer feet hands head neck mask ears wrist legs_wear`; a gown is `[top, bottom]`), `hides_body_regions` (`torso arms legs feet hands`), `mesh_path` (glTF skinned to Feyre's skeleton), `color`, `warmth`, `stealth`, `swift`, `reaction_tag`, `source`, `phase`.
- `HairstyleData` (`data/wardrobe/hair/*.tres`): `id`, `display_name`, `mesh_path`, `occupies_head`.
- `MakeupData` (`data/wardrobe/makeup/*.tres`): `id`, `display_name`, `channel` (one of `lips eyeshadow liner blush brows face_paint`), `color`, `amount` 0..1, `sheen`, `source`, `phase`.

## Runtime
- `Wardrobe` (`systems/wardrobe/wardrobe.gd`, RefCounted, held by `Gameplay.wardrobe`):
  - `equip(piece_id) -> bool`, `unequip_slot(slot)`, `equipped() -> Dictionary[slot -> id]`
  - `set_hair(id)`, `apply_makeup(makeup_id)`, `clear_makeup(channel)`, `makeup() -> Dictionary[channel -> {color, amount, sheen}]`
  - `owned_pieces()`, `grant(piece_id)` (pieces Feyre has found/been given)
  - `warmth()`, `stealth()`, `swift()` totals; signal `changed`
  - Saved through SaveSystem provider `"wardrobe"`.
- `WardrobeApplier` (`systems/wardrobe/wardrobe_applier.gd`, child of Feyre): listens to `changed`, loads piece meshes onto Feyre's `Skeleton3D`, hides covered body regions, and sets skin shader params.

## Feyre's model must provide
- A `Skeleton3D` with Godot humanoid bone names (`Hips Spine Chest UpperChest Neck Head LeftUpperArm ...`).
- Body mesh with separate surfaces per region named `torso arms legs feet hands head` so covered regions can be hidden.
- Skin material using `characters/feyre/feyre_skin.gdshader` with, for each makeup channel `c`: `uniform vec4 c_color`, `uniform float c_amount`, `uniform float c_sheen`, masked by a channel mask texture (`makeup_mask_a`: R lips, G eyeshadow, B liner, A blush; `makeup_mask_b`: R brows, G face_paint).

## Dressing room UI
Opened when Feyre uses a station with `station_id` `wardrobe` (outfits and hair) or `dressing_mirror` (makeup and hair). The gameplay lane owns that UI (`ui/dressing_room/`); the manor lane owns the room and the station nodes (group `station`, `station_id`, `use(user)`).
