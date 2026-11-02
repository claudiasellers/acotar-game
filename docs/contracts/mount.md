# Contract: the white mare (L47)

Feyre's travel mount. Owner: the mount lane (L47). Paths: `systems/mount/`,
`data/mount/`, `tools/mount/`, `tools/blender/white_mare.py`,
`tools/playtest/mount_ride_clip.*`, `tests/unit/mount/`, this file. Changing a
name or rule here needs the director's OK (R13).

## One horse

The mare is the beast's white horse of the ch5 ride north: one model,
`creatures/models/fae/white_horse.gltf`, built by `tools/blender/white_mare.py`
(cloud Blender, 14k tris, the shared quadruped rig of
`docs/contracts/creature_motion.md`: idle, walk, trot, gallop, graze, hit_l/r,
death_l/r; gait speeds in `data/animation/creatures/white_horse_gaits.txt`).
`white_horse()` in `fae_creatures.py` is retired. `WhiteHorse`
(`creatures/fae/white_horse.gd`) keeps its actor id, cues and `mount_point`
for the ride north, and now plays its gait clips from how fast it moves
(`MareAnimator`), however it is moved. Set `speed_override` to give the speed
outright.

Canon: ch 9, Feyre rides a white mare from the painted stables with Lucien
(C); ch 5, the beast's white horse (C). Gold tack, pastel mane and the garland
of blooms are the R3 look (X).

## Story (R2: by deed, no markers)

- Before `first_dinner_eaten` there is no mare and no whistle.
- After it, the mare waits saddled in the stable yard (`MountData.home`)
  whenever Feyre is within 220 m of it.
- Mounting her the first time fires an `ActionTrigger` with the fact
  `fact.mare_ridden` (never a phase flag). From then on the whistle works.
- After the first dismount a one-time card teaches the whistle key (kept in
  `WorldDeltas` region `mount`, not a story flag).

## Where she can't go

`MountDirector.block_reason(at)` is `&""` or one of:

| reason | when |
|---|---|
| `not_yet` | before `first_dinner_eaten` |
| `scene` | any SceneSpace is running (one starting mid-ride takes Feyre down at once) |
| `story` | `StoryControl.mode` isn't FULL |
| `realm` | south of the Wall, or within 12 m of it |
| `indoors` | a roof over the spot (the manor, the stables' rooms) |
| `dread` | `DreadField.withdrawal_at` > 0.15 (the Bogge) or a region in `MountData.no_ride_regions` (`suriel_glade`, which holds the naga reeds) |

The whistle and mounting check it; riding into dread, she balks (snort, head
toss, stops) and only turns back. `scene`, `story` and `realm` mid-ride
dismount her.

## Deed triggers are never skipped

While she rides, every 0.1 s `MountDirector.sweep_triggers()` fires each
`ActionTrigger` (fire_on_body_enter, its `required_group` matched against
Feyre) that a 2.6 m capsule over the mare passes through and Feyre's own body
didn't touch. Feyre stays a `CharacterBody3D` in group `player` at the saddle,
so position-based checks (wayside, exit conditions, the streamer) see her.

## Controls

| input | on foot | in the saddle |
|---|---|---|
| H / pad share (`call_mount`, added at runtime) | whistle | |
| E (`interact`) | on the mare: mount | tap: pick what's in reach from the saddle (forage, arrows, a carcass); a station (bench, nook, snare) or nothing in reach: get down (and use the station). Hold 0.35 s: get down |
| move | | steer, camera-relative; light stick walks (2.2 m/s), full canters (10) |
| sprint | | gallop, 15 m/s (capped for streaming: ~20 s look-ahead); the lens widens 12° and the wind rises |
| jump | | a leap (from 3 m/s) |

The bow is off in the saddle. In the saddle the chase camera is lifted 0.8 m
and drawn back 1.6 m (`Feyre.camera_lift` / `camera_arm_extra`, eased over
0.6 s each way) so it looks down past Feyre to the mare's neck and ears; after
0.8 s without look input it swings in behind her and settles to -18° pitch. The white horse's meshes are in `CameraFade.NEVER_GROUP`,
so the chase camera's sight-line fade never turns her see-through.

## Nodes

- `MountDirector` (`systems/mount/mount_director.gd`): one in the game scene
  (`act1_game.gd`: `add_child(MountDirector.new())`). Signals `mounted`,
  `dismounted`, `whistled(answered)`. `autopilot: Callable` -> `[dir, gallop]`
  steers for probes.
- `MareMount` (`mare_mount.gd`): the body, layer 6 (`1 << 5`, nothing else
  uses it; arrows and the camera's spring arm ignore it), mask world. Group
  `station` with `station_id` `white_mare` while nobody rides. States
  STANDING, COMING, RIDDEN, GOING_HOME.
- `Saddle` (`saddle.gd`): the one way to sit Feyre on the white horse, used by
  both the mount and the ch5 ride north (`story/act1/ride_north.gd`).
  `Saddle.seat(rider)` adds the `RidePose`, `Saddle.place(rider, horse)` puts
  her hips on `WhiteHorse.seat_point()` (a bone attachment on the horse's
  spine plus `WhiteHorse.SEAT_OFFSET`, so she rides with the gait),
  `Saddle.unseat(rider)` takes it off.
- `RidePose` (`ride_pose.gd`): a `SkeletonModifier3D` on Feyre's skeleton
  (the shared cast rig): hips in the saddle, thighs on the barrel, feet in
  the stirrups (hung at 0.84 of the withers height in `white_mare.py`),
  hands on the reins.
- `MountData` (`mount_data.gd`, `data/mount/white_mare.tres`): every number.
- Sounds: `systems/mount/sounds/*.wav` from `tools/mount/mare_sounds.py` (numpy, fixed seed).

Proof probe: `tools/playtest/mount_ride_clip.tscn` (mount, gallop the Wall
road with streaming numbers, dismount, whistle). Test: `tests/unit/mount/test_mount.gd`.
