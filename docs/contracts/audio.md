# Audio contract (sound lane, L15)

The game's sound is one node, `SoundDirector` (`systems/audio/sound_director.gd`),
added by the game scene (`story/act1/act1_game.gd`). It only listens, so a lane
gets sound by emitting what it already emits. Files are self-made and CC0
(`audio/CREDITS.md`); `tools/audio/gen_act1_audio.py` rebuilds every file and
`data/audio/act1_sound_bank.tres` from fixed seeds.

## What already makes a sound

| Event (owner) | Sound |
|---|---|
| Feyre crosses a space (`WorldStreamer.region_at`, cottage interior anchor) | ambience bed crossfade 2.5 s, music crossfade 4 s |
| `EventBus.mood_requested(&"dread", i, s)` | bed x (1-i), music x (1-i)^2, sub-bass dread bed x i. Outside a story scene, a dread rising past 0.5 plays the one wrong sound (`horror_wrong`) |
| `WallSenseVolume.proximity_changed(a)` | bed and music drop to 10% at the line |
| Feyre moves on the floor | footstep per stride (0.6–2.1 m by speed), surface by space: snow, wood (cottage interior), grass (Prythian) |
| `Feyre.jump_motor.jumped / landed` | cloth whoosh; heavy snow landing above 7 m/s impact |
| `Feyre.is_drawing` rises / falls | bow creak starts / stops |
| `Feyre.arrow_fired(arrow)` | string release; whoosh rides the arrow; `arrow.hit` → flesh (any `Creature` or group `creature`), wood (`StaticBody3D`, CSG), else snow; `arrow.broke` → snap |
| `story_actor_cue(&"great_wolf", &"seize_doe")` | the wolf bursts from cover and takes the doe |
| `creature_hit(_, &"great_wolf", ...)` | bark of pain; first hit adds his low growl and lifts dread to 0.45 (canon: the snow falls again) |
| `creature_killed(_, &"great_wolf", ...)` | whine, whimper, slowing breaths |
| `WolfPack.target_acquired / lunged` | pack growl |
| `story_actor_cue(&"tamlin_beast", &"enter")` or `BeastActor` stage `BREAK` (once per 5 s) | door gives, roar, then a snarl loop at the beast and her heartbeat loop |
| `tamlin_beast` `accuse` / `speak` / `snap_ash_arrow` | MURDERERS bellow + claws in the table / WHO KILLED HIM bellow + plates rattling / the arrow snaps |
| `tamlin_beast` `lead`, `leave`; stages `LEAD`, `WITHDRAW`, `GONE`; dread below 0.3 | snarl and heartbeat fade out |
| `BeastActor` `APPROACH` / `PRESENCE` / `LOOM` | huff and footfalls |
| `EventBus.celebration_requested` | harp sweep, bell chord, glitter (once per 1.5 s) |
| Any `BaseButton` (hover, focus, press) | glass tick, soft bell. Set meta `silent` = true to opt out |
| `get_tree().paused` turns on / off | harp rise / fall; the bed ducks 6 dB while paused |
| `SatchelSounds.play(&"pickup")` | `res://audio/ui/satchel_pickup.ogg` (its own loader) |

Pickup, craft, unlock and outfit chimes stay with `Juice` (feedback lane).

## Calling it directly

`SoundDirector.cue(&"<cue_id>", position)` plays a cue (flat when the position
is left out). It does nothing when no director is running, so tools and tests
need no guard. Cue ids are listed in `data/audio/act1_sound_bank.tres`.

## Adding sound

- New space: add its region id to `SPACE_BEDS`, `SPACE_MUSIC` (leave it out for
  silence) and `SPACE_SURFACES` in the generator, and rerun it.
- New file: a function and a `SOUNDS` row in the generator, a `CUES` row, and
  rerun. Keep each file under 2 MB (the contract test checks this).
- Buses: music players join `GameSettings.MUSIC_GROUP`, everything else lands on
  `Sound`, so the pause menu's two sliders cover all of it.

## Canon (Storykeeper, 30 Oct)

The wolf arrives in silence ("The forest went silent. The wind died."), barks
when hit, growls, and dies whining. The beast cuts a quiet room with a roar,
snow bursting in, bellows "MURDERERS!" and "WHO KILLED HIM?", shakes the
plates, sinks its claws into the table; Feyre's heartbeat pounds. The Spring
Court arrival is hushed: breeze and small birds, no music.
