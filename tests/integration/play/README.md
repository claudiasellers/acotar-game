# Play tests

Scripted play in the real game scene (`story/act1/act1_game.tscn`), driven by
real input events, checking what a player would see happen. Unit tests prove a
system's parts; these prove "it passes" means "it plays".

| File | Region | What it plays |
|---|---|---|
| `test_play_woods.gd` | the cottage and the woods, from New Game | wake on the ground at the door, walk in and talk to her family, N minimap, walk/run/sprint and stop, the cottage wall, the whistle refused south of the Wall, pause + save + Continue |
| `test_play_court.gd` | the manor and stable yard, through Continue | wake in her bedroom, a wall, talk to Alis, a person blocks then lets her squeeze past (T092), N minimap, walk/run/sprint and stop, whistle + mount + ride + gallop + get down, pause + save + Continue |
| `test_play_sit.gd` | the dining hall, through Continue | the first dinner: walk in, sit, the shove, E to eat, stand and walk away |
| `test_play_shoot.gd` | the woods and the court | the Zelda-style bow: hold aim, nock, one click one full arrow, release lowers with no shot, fresh aim after a shot, Q cycles types |

Each file boots the game once in `before_all` and runs its tests in order in
that one game; setup moves her with `place_on_ground` (never the verb tested).

## The harness (`play_harness.gd`)

`var h := PlayHarness.new(self)` (preload it; no class_name, so a test never
waits on the class cache). `h.dispose()` in `after_all`.

- Boot: `boot_new_game()`, `boot_from_save(slot, dict)`, `boot_slot(slot)`;
  each returns true once she has control (`has_control()`). `shutdown()`.
- Input (all through `Input.parse_input_event`, the real road):
  `press(action, frames)`, `hold(action)`, `release(action)`,
  `hold_for(action, physics_frames)`, `release_all()`; left stick `stick(v)`,
  `stick_toward(point, amount)` (under 0.5 walks); right stick `look_stick(v)`,
  `look_toward(point)`; `mouse_move(rel)`. `event_for(action)` builds the
  player's first binding: key, else mouse button, else pad button.
- Waiting: `wait_until(cond, max_frames)`, `walk_to(point, radius, max_frames, sprint, amount)`,
  `wait_still()`. A frame budget is game ticks (physics frames, 1/60 s of
  game time), never wall-clock and never drawn frames. After a wait,
  `h.last_wait` says how many ticks, drawn frames and milliseconds it took and
  what could have held the game (fps cap, time scale, pause); put it in the
  message of an assert that fails on a wait.
- Looking: `flat_speed()`, `flat_distance(a, b)`, `child_of(Type)`,
  `nearest_in_group(group)`, `ground_y(x, z, from_y)`, `on_solid_ground()`,
  `place_on_ground(x, z, drop, max_frames, from_y)`.

## Things that bite

- Drawn frames are not game time. The harness holds `Engine.max_fps` at 60,
  but the build machine has drawn 89 frames in 7 ticks with the cap set
  (rejected/L77-10), so a budget counted in `wait_process_frames` can be a
  tenth of a second there and most of a second in the cloud. Budget in ticks;
  use `wait_process_frames` only to let a drawn frame happen.
- `wait_physics_frames(1)` can return after two physics ticks on a busy
  machine. Count `Engine.get_physics_frames()` when ticks matter.
- Headless the mouse is never captured: mouse look does nothing and the first
  click only captures. Turn the camera with `look_toward`.
- `ground_y` from high up finds roofs. Indoors, pass `from_y` just above the floor.
- The pause menu's Save buttons go to the title (a scene change ends GUT), so
  the tests call `SaveSystem.save_game` where the button would and load through
  the real Continue road.
- A test that finds a real game bug marks itself `pending` with the reason,
  so the gate stays green, and the bug becomes a task.
- Setup that never gives her control is not a game bug: `before_each` calls
  `h.require_control(booted)`, which fails the test. Pending would exit 0 and
  pass the gate with no asserts (T123). `ACOTAR_PLAY_NO_CONTROL=1` forces it.
- Each file loads World: keep `# gate: needs:terrain` and the `when:` line.

Run one: `tools/mq/godot.sh -s addons/gut/gut_cmdln.gd -gconfig= -gexit -gtest=res://tests/integration/play/test_play_court.gd`
