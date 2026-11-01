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

## People (`tools/blender/fae_people.py` + `tools/blender/person_rig.py`)

Every villager and court figure built by `fae_people.py` (not the main cast,
which is on Feyre's rig) is exported with a biped skeleton:

`root`, `body` (carriers), `pelvis`, `spine`, `chest`, `neck`, `head`,
`clav_l|r`, `arm_l|r`, `forearm_l|r`, `hand_l|r`, and per leg (`leg_l`,
`leg_r`) `upper_<leg>`, `lower_<leg>`, `paw_<leg>` (the foot).

| clip | loops | what |
|---|---|---|
| `idle` | yes | breath, weight shift, glances |
| `walk` | yes | heel strike and toe roll, pelvis sway, arm swing; feet planted by IK |
| `talk` | yes | idle with the hands and head at work |
| `flinch` | no | startle back from a fright |
| `bow` | no | a bow from the waist |

Speeds and lengths: `data/animation/people/<model>_gaits.txt` (same format).
Regenerate with `ONLY=a,b /opt/bpyenv/bin/python tools/blender/fae_people.py`.

## Game side for people

- `CourtNpc` attaches `PersonAnimator.attach(model, npc, model_name)` to each
  model (both glamour layers; only the visible one runs). Ground speed drives
  idle↔walk, with playback matched to the speed. A rigged model is never
  y-scaled to breathe.
- `CourtNpc.set_talking(on)` blends in `talk`; `CourtNpc.gesture(&"flinch"|&"bow")`.
- `NoticePlayer` (`creatures/anim/notice_player.gd`): a `LookAtModifier3D` on
  the head turns it to the "player" group's eyes when she is within 7 m and
  not behind them, easing in and out. Villagers get one from their animator.
  The main cast get one in `characters/cast/cast_model.gd` (`model.notice`).
  A scene that stages a look elsewhere sets `notice.enabled = false`.

Proof probe: `tools/creatures/people_motion_shot.tscn -- <out> [numbers]`.
Test: `tests/unit/creatures/test_person_animator.gd`.
