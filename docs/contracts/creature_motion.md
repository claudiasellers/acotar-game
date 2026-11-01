# Contract: creature motion (lane L22)

How a creature's body moves: skeleton, clips, and the game-side driver.
Owner: L22 ("Make creature and character motion natural"). Changing a name or
format here needs the director's OK (R13).

## Models (`tools/blender/creatures.py` + `tools/blender/creature_rig.py`)

Every quadruped built on `quadruped()` (wolf, great_wolf, deer, hare) is
exported with a skeleton and its clips. Bones sit on the skin graph's joints:

`root`, `body` (carriers, no skin), `hips`, `spine`, `ribs` (breath), `chest`,
`neck`, `head`, `muzzle`, `jaw` (wolves), `ear_l|r`, `tail0..tailN`, and per leg
(`fl_l`, `fl_r`, `hl_l`, `hl_r`) `upper_<leg>`, `lower_<leg>`, `paw_<leg>`.

Clips (glTF animations, in place; the game moves the body):

| clip | loops | what |
|---|---|---|
| `idle` | yes | breath, head scan, ear flicks, tail |
| `walk`, `trot`, `gallop` | yes | gaits; paws planted by IK in the generator |
| `stalk` | yes | wolves only: belly-low creep |
| `graze` | yes | head to the ground (graze, feed, hold a kill) |
| `hit_l`, `hit_r` | no | an arrow strikes the left / right side |
| `death_l`, `death_r` | no | falls onto the left / right flank and dies; last frame holds |

Each model's native gait speeds and clip lengths are in
`data/animation/creatures/<model>_gaits.txt`, written by the generator:
`name native_speed_mps duration_s loop` (`-` = not a locomotion clip).
Regenerate with `/opt/bpyenv/bin/python tools/blender/creatures.py creatures/models [names…]`.

## Game side (`creatures/anim/creature_animator.gd`)

`Creature._ready` calls `CreatureAnimator.attach(self)`; it returns null for an
unrigged model, which keeps the old `_topple`. With an animator:

- Ground speed drives the gait blend; playback is 1x between gait points and
  scaled past the gallop up to `MAX_RATE`.
- `Creature.gait_hint`: brains set `&"stalk"`, `&"graze"` or `&""` every think.
  A stalk at speed 0 freezes mid-step.
- `Creature.on_arrow_hit` → `animator.hit(arrow.global_position)` plays the
  flinch for the struck side. It never moves the creature toward the shooter.
- `Creature.die` → `animator.die()` falls away from the last blow (struck on the
  right, it lies on its left flank). `animator.death_length()` is the clip time.
- The model's basis is owned by the animator (slope pitch/roll, lean into
  turns, corpse along the slope). Don't tween `model.rotation` on a rigged creature.
- Arrows that stick in the body (`stuck_arrows` group, reparented to the
  creature) are moved onto a `BoneAttachment3D` on the nearest bone.

Proof probe: `tools/creatures/creature_motion_shot.tscn -- <out> [numbers]`.
Test: `tests/unit/creatures/test_creature_animator.gd`.
