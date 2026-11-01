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

## Staging (`story/staging/`, lane L22)

`Cine` (`story/staging/cine.gd`) is the film camera for anchored moments.
There is one per scene tree, made on demand with `Cine.of(get_tree())`. Its
timing is in real seconds.

- `follow(fov, blend)`: rides Feyre's own camera with another lens. She keeps
  full control (aim, look) and the frame only tightens.
- `shot(xform, fov, blend, track, push, push_time)`: an authored angle.
  `blend` 0 is a cut. `track` is a Callable giving a world point to keep
  framed, followed with a little lag. `push` is metres of slow dolly. There is
  a faint handheld breath unless `GameSettings.reduced_effects` is on.
- `release(blend)`: eases back into Feyre's camera and makes it current.
- `bars_to(k, seconds)`: letterbox, with 1 = 2.39:1 and 0 = none.
- `Cine.clear_view(world, subject, dirs, dist, height)`: a camera spot that
  sees the subject past trees and terrain.

Cine never changes `StoryControl`. Scenes hold and release control
themselves.

`CreatureAnimator.slow(scale, hold, ramp)` slows one creature's body (hit-stop,
slow motion) without touching `Engine.time_scale`, which the bow's slow draw
owns.

`WolfKillStaging` is a child of the WolfKill space, added by one line in
`wolf_kill.gd`. It only listens (focus, `creature_hit`, `creature_killed`):

- His eyes: `follow(36°)` with half bars.
- The ash: a hit-stop, a jolt (`StoryControl.shake`), then `follow(54°)` for his look.
- The kill:
  1. Slow motion, with `StoryControl.Mode.NONE` held, even across the scene's own finish.
  2. Cut to a low 34° angle on the side he falls toward.
  3. Cut over Feyre's shoulder for the last breaths.
  4. Release, about 10 s in all. Interact skips once 1.5 s have passed.

If another space starts during the kill shots, it cuts back to her camera
and leaves `StoryControl` alone.

Probe: `tools/creatures/wolf_kill_film_shot.tscn -- <out> [numbers]`.

`BeastDoorStaging` is a child of the BeastDoor space, added by one line in
`beast_door.gd`. It is camera only and never calls `set_mode` or touches
`allowed_actions`:

- On the door bursting: over her shoulder at the doorway, with full bars.
- On "it fills the room" (focus on him): low at her side, looking up, with a push.
- While the throw window is open (LOOK with `fire` allowed): her own view through a 55° lens with half bars.
- On the father's plea: a two-shot of the beast and her father, both checked in sight.
- On the arrow snapping: close on his head.
- On the scene ending: release.

Each shot tries spots that see past walls and beams, and falls back to her
own view through a tighter lens. The scene's `StoryControl.shake` carries into
every Cine shot.

Probe: `tools/creatures/beast_door_film_shot.tscn -- <out> [numbers]`.
Test: `tests/unit/story/test_staging.gd`.

Ownership: a staging calls `cine.claim(self)` before each move and ends with
`cine.drop(self, blend)`. That releases only if it still holds the camera.
A staging that is freed mid-shot is dropped automatically, with no calls into
it after that.

`Cine.rig(subject, offset, look, fov, blend, lag, carried)` carries the
camera with a moving subject, given in the subject's frame. A jump of more
than 25 m is a cut. Trees with collision pull the camera in, and it never goes
below the terrain. With `lag` alone the lens trails a fast subject by about
speed/lag metres. With `carried` it moves with the subject like a camera car,
so the lag only smooths turns. Use `carried` for shots from behind, where
trailing would let foliage with no collision come between.

`RideNorthStaging` is a child of the RideNorth space, added by one line in
the `_ready` of `ride_north.gd`. It is camera only:

- On the `lead` cue: a tracking shot ahead of the horse, then her own view
  (`follow(58°)`, half bars).
- On `enchanted_sleep`: a slow rise behind and above.
- On the spring grade swap: ahead on the path looking back as they pass the
  wall, then her view.
- When the veil is dark: her own camera, which goes with her to the gate.
- On the fade in: behind and above up the drive.
- On the `leave` cue (the dismount) or the space finishing: drop. It never
  holds past the dismount.

Probe: `tools/creatures/ride_north_film_shot.tscn -- <out> [numbers]`.
Test: `tests/unit/story/test_ride_staging.gd`.
