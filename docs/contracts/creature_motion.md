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
| `walk`, `trot`, `gallop` | yes | gaits; paws planted by IK in the generator. Every gait starts its cycle on the left hind paw, and a paw lifts and lands already moving back at stance speed |
| `stalk` | yes | wolves only: belly-low creep |
| `graze` | yes | head to the ground (graze, feed, hold a kill) |
| `hit_l`, `hit_r` | no | an arrow strikes the left / right side |
| `death_l`, `death_r` | no | falls onto the left / right flank and dies; last frame holds |

Each model's native gait speeds and clip lengths are in
`data/animation/creatures/<model>_gaits.txt`, written by the generator:
`name native_speed_mps duration_s loop` (`-` = not a locomotion clip).
Regenerate with `/opt/bpyenv/bin/python tools/blender/creatures.py <out_dir> [names…]`.

To change clips without touching a model's looks, export to a scratch folder and
splice only the animations in:
`python3 tools/blender/splice_clips.py <out_dir>/great_wolf.gltf creatures/models/great_wolf.gltf`.
A re-export from another Blender build splits the mesh differently; the splice
keeps every mesh, material and skin byte.

### People: clips without a rebuild

The cast (`characters/<id>/model/<id>.glb`) and the court and village people
(`creatures/models/people/<id>.gltf`) are sculpted further after their build
(expression keys, the mouth), so their clips change by splice too. Check the
repo out a second time, change the clip code there, build there, then here:

- cast and Feyre: `/opt/bpyenv/bin/python tools/blender/cast/refresh_clips.py <fresh_tree> <id> …`
  (swaps the actions in `<id>.blend`, which the face pass re-exports from, and
  splices `<id>.glb`);
- people: `python3 tools/blender/splice_clips.py --rest <fresh_tree>/creatures/models/people/<id>.gltf creatures/models/people/<id>.gltf`
  (`--rest`: these figures rest in the first frame of their idle, so the rest
  pose goes with the clip).

Standing arms hang beside the thighs: shoulder to hand is 5 to 8 degrees off
straight down, set by `lower` in `feyre_anims.relaxed_arms` (cast, court,
village), `arms` under `idle` in `retarget_moves.POSTURE` (the player's own
move set) and `arm_out` in `person_rig.animate` (the older fae figures).
A body that wears something wide at the hip (a bell skirt, an apron, a sword
belt) hangs its arms further out by its own `ARM_CLEAR` (`cast_<id>.py`) or
`arm_clear` (a `DESIGNS` row), in degrees; the father's seated `sit_carve`
keeps the arm drop its lap pose was set on. Values in `docs/tuning.md`.

Probe: `tools/mq/godot.sh --fixed-fps 60 -s tools/creatures/arm_clip_probe.gd`
stands Feyre, the cast and every figure in their idle and prints how far each
one's hands and forearms sit behind skirt, hip, cloak or satchel. A new or
changed body gets the smallest clearance that keeps that under 5 mm, or no
worse than it was where a cloak already covers the arm. By eye:
`tools/creatures/stand_shot.tscn -- <out> [names]` (front and back lineup).

## Game side (`creatures/anim/creature_animator.gd`)

`Creature._ready` calls `CreatureAnimator.attach(self)`; it returns null for an
unrigged model, which keeps the old `_topple`. With an animator:

- The body's real ground speed (`get_real_velocity`, not what the brain asked
  for) picks one gait, walk, trot or gallop, with hysteresis at the midpoints
  of their native speeds, and cross-fades over a quarter second. Every gait
  clip runs at one cadence (strides per second) so they stay in step, and the
  cadence is the ground speed over the stride of what is playing: a planted
  paw stays where it landed at any speed up to `MAX_RATE`. From standing the
  stride grows with the speed. `animator.gait`, `gait_rate()`, `cadence`.
- Brains set only `move_direction`, `move_speed` and `gait_hint`, and move
  through `Creature._move`. Don't write `global_position`, `velocity` or the
  model's rotation on a moving creature in view: it reads as a slide.
- `Creature.gait_hint`: brains set `&"stalk"`, `&"graze"` or `&""` every think.
  A stalk at speed 0 freezes mid-step.
- `Creature.on_arrow_hit` → `animator.hit(arrow.global_position)` plays the
  flinch for the struck side. It never moves the creature toward the shooter.
- Hit reactions (health-interactions §3.5 item 7), in `Creature.react_to_hit`
  for every hit that leaves it alive: a flinch (`FLINCH_SECONDS` 0.25) and,
  off the weak spot, a flat push of `FLINCH_PUSH_M` (0.3 m) away from where the
  blow landed, never held in its velocity. The brain keeps thinking, so a
  flinch never cancels a wind-up. A weak-spot hit is a stagger instead
  (`STAGGER_WEAK_SECONDS` 0.8, no push), which cancels the wind-up through the
  brain's `stagger()`. `creature_hit` and `creature_killed` are unchanged (one
  emit per hit; HitStop listens).
- `Creature.die` → `animator.die()` falls away from the last blow (struck on the
  right, it lies on its left flank). `animator.death_length()` is the clip time.
- The model's basis is owned by the animator (slope pitch/roll, lean into
  turns, corpse along the slope). Don't tween `model.rotation` on a rigged creature.
- Arrows that stick in the body (`stuck_arrows` group, reparented to the
  creature) are moved onto a `BoneAttachment3D` on the nearest bone.

Proof probe: `tools/creatures/creature_motion_shot.tscn -- <out> [numbers]`.
Test: `tests/unit/creatures/test_creature_animator.gd`.

Do the feet plant? `tools/mq/godot.sh --fixed-fps 60 res://tools/creatures/gait_plant_probe.tscn -- [names]`
walks creatures and cast models over flat ground at set speeds, headless, and
prints how far a planted foot drifts per metre travelled (0 = nailed down,
1 = no steps at all). Run it after any change to clips, speeds or animators.

## Monsters (`tools/blender/monsters/`, lane L83)

The hostile fae of the bestiary (`plans/hostile-fae/bestiary.md`) are built by
one generator each on a shared kit and drive the same `CreatureAnimator`:

- `kit.py`: clay forms blended into one skin, carved and displaced, cut down
  to a game mesh (15k triangles at most), with the fine surface baked to
  `<name>_albedo|normal|orm|emit|mask.webp` beside the model.
- `rig.py`, `biped.py`: bones, skinning, key-pose clips, planted feet. A gait's
  native speed is the distance its planted foot travels, so nothing slides.
- `<monster>.py`, `<monster>_body.py`, `<monster>_rig.py`, `<monster>_clips.py`:
  the creature itself. `naga.py` is the first.

Regenerate: `/opt/bpyenv/bin/python tools/blender/monsters/naga.py` (about
25 minutes; `--fast --nobake --noexport --preview <dir> <view or clip>...` for a look).

Biped monster bones: `root`, `body` (carriers), `pelvis`, `spine`, `spine2`,
`chest`, `neck`, `neck2`, `head`, `jaw`, `tongue0..2`, `clav_l|r`, `arm_l|r`,
`forearm_l|r`, `hand_l|r`, `finger_<i>_l|r`, `finger_<i>b_l|r`, and per leg
(`leg_l`, `leg_r`) `upper_<leg>`, `lower_<leg>`, `foot_<leg>`, `paw_<leg>`.
Sockets are bones with no skin: `throat`, `mouth`, `grab_point`, `talon_l`,
`talon_r`; `animator.socket(name)` gives a `BoneAttachment3D` on one.

Clip names are the bestiary's (1.4, 1.5): `idle`, `walk`, `run`, `stalk`,
`alert`, `startle`, `call`, `telegraph_<attack id>`, `attack_<attack id>`,
`recover`, `hit_l|r`, `stagger`, `sleep_fall`, `sleep`, `wake`, `burn`,
`death_l|r`, `death_<weak spot>`, plus each family's own. The gaits file has
two more columns for them: `name speed duration loop contact_s travel_m`.
`contact_s` is when an attack's blow lands; `travel_m` is how far the clip
expects the code to carry the body (a lunge, a stagger back). `-` = none.

What the animator adds for them (all no-ops on a model without the clip):

- The gait ladder (`animator.loco`) comes from the gaits file: every clip with
  a native speed except `idle`, `stalk` and `swim`, slowest first (`walk`,
  `lope`, `run` for the naga). Gait choice, cadence and planted feet work as above.
- `play_attack(id) -> float`: `telegraph_<id>` then `attack_<id>` with no
  dip between; returns seconds until the blow lands, or -1.
  `cancel_attack()` eases out of it. `is_acting()` is true meanwhile.
- `play_windup(id, seconds)`: `telegraph_<id>` alone, stretched to `seconds`
  (the row's `windup_s`) and held on its last pose until `play_strike`,
  `play_attack` or `cancel_attack`. One name scheme: every attack row has a
  `telegraph_<row id>` clip. A family that calls it has no other tell (no
  procedural pose beside it): a model without the clip is a `push_error`, and
  each family's test checks every attack row it uses has its clip.
- `play_strike(id) -> float`: `attack_<id>` alone; returns its `contact_s`.
- `play_oneshot(clip) -> float`: one clip once; returns its length.
- `hold(clip) -> float`: one clip looping on the action layer until a `play_*`,
  a wind-up or `cancel_attack` replaces it (a day-long bush pose, a sleeper).
- `set_alert(on)`: the looping `alert` layer, while standing.
- `die(variant)`: `die(&"throat")` plays `death_throat` when the model has it.
- `clip_contact`, `clip_travel`: the two new columns, by clip name.

The hide (`creatures/materials/monster_hide.gdshader`, one `.tres` per
monster) has per-instance parameters, set with
`GeometryInstance3D.set_instance_shader_parameter`: `glint` (0..1, the tell on
the talons before an attack), `seam_tint` (the individual's undertone), `scar`
(0 or 1), `dull` (0..1, an ash wound) and `eye_glow` (0 by default: nothing
glows by day unless the code says so).

Cloth (`rig.Rig` spec `cloth`, `kit.ribbon`): loose strips (a veil's ends, a
torn hem) are chains of bones that hang by themselves in every pose and lie
along the ground where they reach it; a clip only blows on them
(`Pose.blow`). The motion is in the clips, never the game's wind.

The Suriel (`suriel.py`, bestiary 3) is a story actor, not a `Creature`: its
model has no animator, and `creatures/fae/suriel.gd` plays the clips on the
model's own `AnimationPlayer`. `CreatureAnimator.apply_loops(player,
"res://data/animation/creatures/suriel_gaits.txt")` marks the looping ones.
Clips: `idle`, `stalk` (0.6 m/s), `snared`, `scream`, `sit_down`, `sit_idle`,
`notice`, `warn`, `burst`, `hit_l|r`, and three additive ones that move only
what they name from the rest pose, to lay over `sit_idle` with an `Add2`:
`head_cock` (ends cocked; fade it out), `speak` (the jaw, and a finger click
every 0.5 s, hands alternating), `laugh`. Sockets: `ankle_l` (the snare),
`mouth`, `eyes`. Cloth bones: `veil_fl|fr_<n>`, `veil_b<i>_<n>`,
`sleeve_l|r_<n>`, `hem_<i>_<n>`. Shape keys: `threat`, `speak_open`,
`eyes_wide`. Its eyes glow by canon: `suriel_hide.tres` sets `emit_base`.

Test: `tests/unit/creatures/test_monster_animator.gd`.

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

### The main cast walk by how they are moved (`characters/feyre/model/feyre_model.gd`)

A cast model (anything on Feyre's rig that is not driven by her mocap tree)
measures how far it was moved each frame and plays its own `walk`, `run` or
`sprint` at the rate that keeps planted feet still; moved backwards, the gait
runs in reverse; stopped, it idles. Whoever moves it (a tween, a story beat, a
routine) only moves it: don't call `play_locomotion` or play `walk` from a
scene. How fast each clip walks is measured from the clip (`GaitMeter`,
`creatures/anim/gait_meter.gd`), so a model with its own walk (the father's
`walk_limp`) needs no number. It keeps its hands off the player while a scene
has another clip on it (a bow, a roar), doesn't walk when lifted off the
ground (a saddle), and treats a move of more than 1.5 m in a frame as a
placement, not a step.

### Cast cues (`creatures/anim/cast_cues.gd`)

Every main-cast model (`cast_model.gd`) carries a `CastCues` node, `cues`.
It acts out a story cue on its own when the model is the story actor, that
is, when it is in the group `story_actor_<id>`, as `StandIns.figure` makes
it. `HunchModifier` is the forward bend on top of any clip; its `amount`
runs from 0 to 1.

- `leaves_sick` (Lucien, ch17): he backs off about 1.4 m from the sight,
  retches twice bent double, takes a breath, turns, and walks out at 1.6 m/s.
  He goes to the `exit_to` meta if the scene sets one. Otherwise he leaves by
  the manor's front doors when he is within 16 m of them, or walks 9 m on,
  away from the sight. Then he is hidden but not freed. It takes about 9 s.

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
