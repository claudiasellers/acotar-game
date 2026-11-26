# Contract: monster gear (L75): looted weapons, imbue slots, loot

The catalogue (names, stats, looks, canon) is `plans/hostile-fae/monster-gear.md`
in the project files. The models are L88's (`docs/contracts/monster_gear_models.md`):
one `art/monster_gear/<id>.glb` per item id. The game loads a model when its
file exists and never builds a stand-in. `GearModel` (`systems/weapons/gear_model.gd`)
is the one setup: `_lod1` hidden, `<id>_worn` shown instead of `<id>` when worn,
PropFinishes on the "opaque" and "clear" surfaces, and a drop laid by the
manifest's `rest_deg` and `rest_lift_m` (required: every weapon and camp
container has its model and row, and a missing one is a `push_error`, with no
drop spawned). Drops and containers carry no light; they read as takeable
through the Interactor's prompt, like every pickup. The manifest's `reach_m` is the
model's grip-to-tip length; `WeaponData.reach_m` is the game's reach from her
centre, and the two are separate on purpose.

## Data
- `WeaponData` (`systems/weapons/weapon_data.gd`), rows in `data/combat/weapons/<id>.tres`.
  Fields: `id` (also the model id), `display_name`, `family`, `kind`, `power`
  (a multiple of the target's `arrow_damage`; the boot knife is 1), `swing_s`,
  `reach_m`, `stagger_s`, `durability` (hits), `imbue_slots`, `two_handed`,
  `trait_id` (bleed, hamstring, sweep, stun, weakspot, glint), `trait_count`
  (sweep), `unique`, `canon`, `description`. Looked up with `WeaponTable`.
- `LootTable` (`systems/weapons/loot_table.gd`), one per family in
  `data/combat/loot/<family>.tres`, keyed by `CreatureData.kind` (a site by
  `HostileSiteData.family`): `carried` (by member index, cycling), `leader_at`
  and `leader_weapon`, `carried_wear`, `trophies` with `trophy_chances`,
  `camp_weapon`, `camp_coins`, `camp_container` (the prop's model id).
- Both are written by `tools/combat/gen_weapons.py`. Edit its tables, rerun it,
  and commit the outputs.

## Imbue slots (`ImbueSlots`, `systems/imbue/`): the one imbue system
This is the first slice of progression plan §8b. The Codex, Kits and the station
swap (L76/L77) write these slots; they don't build a second system.
- One slot holds `{element, tier, until_day}`. Tier I and II come from brews and
  last until the end of `until_day`. Tier III (Folk) is `FOREVER` (-1).
- `WEAPON_SHARES` holds the shares per slot at Tier I, II and III: Ember, Rime
  and Glimmer are 10/20/30%, and Hush is —/15/25%. `WEAR_SHARES` holds the
  wearables' elements. Caps: 50% for a weapon element, 60% for a resistance,
  40% for Bark.
- `share(element, day)` and `shares(day)` add up a piece's slots, capped.
  `HOSTILE_ELEMENT` maps a weapon element to its hostile element row: ember to
  fire, rime to frost, glimmer to light, hush to sleep.

## The rack (`WeaponRack`, a child of the player; `WeaponRack.of(player)`)
- It carries up to `CAPACITY` (5) instances: `{id, left, imbue: ImbueSlots}`.
  `held` is an index, or -1 for the boot knife.
- `add(id, wear, imbue)` takes a weapon, and she holds it at once if
  empty-handed. `drop(i)`, `hold(i)`, `put_away()`, `imbue(i, element, tier, until_day)`.
- `wear_held(resisted)` is 1 per landed hit, or `RESISTED_WEAR` (2) on a
  resisted element. On the last hit the weapon breaks (`broke`): her hand goes
  to the next one she carries, or to the boot knife. `last_hit()` is true when
  the next hit breaks it, and that hit lands `BREAK_MULT` (×2). `is_worn(i)`
  is true below 30%, which is when L88's `<id>_worn` node shows. Wear shows before
  the break: crossing 30% emits `worn` and notes "The x is cracking." in the
  pickup log, the hit that leaves one blow notes "won't take another blow", and
  the break notes "The x broke."
- A unique weapon drops once per save (`fact.weapon_unique.<id>`). When it
  breaks it leaves `fact.weapon_broken_keepsake.<id>` for the keepsake.
- Save provider `weapon_rack`.

## Strike (`StrikeController`)
- With a held weapon, the knife blows (plain, sneak, finisher) use its `power`
  (× the sneak or finisher mult), `reach_m` (`reach()`, which also picks the
  target), `swing_s` and `stagger_s` (×1.5 for `stun`, and for `glint` on a
  family that wants glints). The hit goes through `Creature.apply_hit` with
  cause `knife` and the weapon's id as weapon_id, so `knife_scale` (the boot
  knife's) doesn't apply.
- Traits: `bleed` sets `bleeding` to 60. `hamstring` slows for 4 s. `sweep`
  also hits up to `trait_count - 1` more in reach in the half in front of her
  (only the first hit wears the weapon). `weakspot` counts the hit weak when the
  target has a weak spot and faces her.
- Imbues: each weapon element with a share calls `HostileElements.react` (the
  family's row: burst, sound and line). Resisted wears it double; otherwise
  `imbue_effect(c, element, share × mult)`. Fire burns and frost slows for
  `IMBUE_SECONDS` × strength. Sleep adds to the creature's `hush_build` meta
  and drops it like a sleep arrow at 1.
- Cutting free and the bow bash never use the held weapon.
- Not yet: two-handed weapons don't lower the bow, and there's no rack card for
  choosing a weapon (UI follow-up). Both are noted in the catalogue.

## Loot
- `HostileRoamer.carried_weapon`: its family table's `carried_by(member_index,
  pack size)`. The model rides `animator.socket(&"hand_r")` when the file exists.
- `HostileRoamer.die` drops its weapon (`WeaponDrop`) at `carried_wear` of its
  durability, plus each trophy at its chance. The rolls are seeded by the
  creature id and the day (`LootTable.roll`).
- `WeaponDrop` (`systems/weapons/weapon_drop.gd`) has the Interactor's station
  shape: `station_id` `weapon_drop`, `use_verb` ("take hook-knife"; with the rack
  full, "swap my knuckle-club for hook-knife", naming the held weapon she
  gives up, or "no room for hook-knife" with only the knife in hand),
  `open_now()` and `use(user)`. With the rack full, it swaps in the held
  weapon, which is left lying there. What she carries, holds and leaves is
  the Weapons page's (`ui/weapons/weapons_tab.gd`, `docs/contracts/ui-frame.md` step 8s). The first
  trophy from a speaking family (`SPEAKING_FAMILIES`: naga) plays
  `loot_first_trophy` once.
- `CampContainer` (`creatures/hostile/camp_container.gd`): `HostileSite`
  places one near its core (`camp_loot`), whether or not the camp is settled,
  when its family's table has a camp weapon or coins. Its station id is
  `camp_loot` and its verb is "search". It gives coins (`Gameplay.inventory.coin`)
  and lays the camp weapon at its opening, once. Before `glamour_lifted` it
  then stays empty; after that it refills `settle_days` after it was emptied
  (`fact.camp_loot_taken.<site>`).
