# Contract: Act II coded scenes (story lane, L24; used by L25)

Act II's book scenes (phase `p2_grounds` onward) can be real mechanics instead
of the generic data steps. The data moment in `data/story/moments/*.tres`
(written by `tools/story/gen_moments.py`) stays the source of truth for
**where** a scene is (anchor), **what opens it** (`require_flags`, `night_only`,
`trigger`) and **which deed it raises**. Code in `story/act2/` decides **how it
plays**. The moment tests (`tests/unit/story/test_story_moments.gd`) still play
every moment's data steps, so the chain p2 → p8 keeps passing.

## Pieces

| File | What |
|---|---|
| `story/act2/act2_spaces.gd` `Act2Spaces` | The registry. `CODED`: moment id → `{script, stage}`. `EXTRA`: anchor id → list of `{name, script, stage}` for scenes with no moment (the arrival, Alis's welcome). |
| `story/act2/act2_space.gd` `Act2Space` | Base class (extends `SceneSpace`). Copies the moment's gates in `_ready`, adds `stage.extra_require`. Helpers: `mark(name)`, `cast(actor, at_mark, face_mark)`, `actor(id)`, `dismiss(id)`, `say(line_id)` (a beat), `reach(mark, r)` (a beat), `delight(kind, mark)`, `presses()` / `press_interact()`, `nudges()` / `nudge()` (move presses while running). |
| `story/act2/act2_stage.gd` `Act2Stage` | Staging data (`data/story/act2/*.tres`): `marks` (anchor-local offsets), `lines` (`{who, text}`), `extra_require`, `invented` (line ids tagged canon:"X"), `canon` note. |
| `story/act2/act2_cast.gd` `Act2Cast` | Actor fallbacks: Tamlin and Lucien are L02's cast models (via `StandIns.figure`), Alis is a coloured placeholder at 1.6 m (R4) until she is modelled. |
| `story/act2/act2_caption.gd` `Act2Caption` | Spoken lines on screen (speaker + text). No choices, ever (R2). |

`StoryDirector._space_for(moment)` asks `Act2Spaces.space_for(moment)` first
and falls back to `MomentSpace`; `StoryDirector.attach_anchor()` also calls
`Act2Spaces.attach(anchor)`. Node names stay `Moment_<id>`, so attaching twice
adds nothing.

## Rules

- Deeds only through `raise(flag)` (an `ActionTrigger`), flag names verbatim
  from `lore/07-story/timeline-overview.md` (R2). Scene-internal facts use the
  `fact.` prefix (`fact.manor_arrived`, `fact.alis_bathed`, ...).
- Code-only gates go in the stage's `extra_require`, never into the moment
  `.tres` (that would break the data chain test).
- Actors: ask with `cast()`. Creature lanes can still answer
  `story_spawn_requested` (group `story_actor_<id>`); otherwise the fallback
  is built under the scene and freed by `dismiss()`.
- Don't edit `creatures/creature.gd` or animation clips (L22). Drive creatures
  with their public calls (`BeastActor.lead(to)`) or cues.
- One contract test per scene in `tests/unit/story/test_act2_<scene>.gd`,
  driving `tick()` with `auto_tick = false`.

## Act II scenes (L24)

| Scene | Hangs on | Gate → deed |
|---|---|---|
| `ManorArrival` (ch6) | `manor_dining_table` (extra) | `wall_crossed` → `fact.manor_arrived` |
| `AlisWelcome` (ch6) | `feyre_bedroom_window` (extra) | `fact.manor_arrived` → `fact.alis_bathed` |
| `FirstDinner` (ch7) | moment `first_dinner` | `wall_crossed` + `fact.alis_bathed` → `first_dinner_eaten` |
| `CurtainTrap` (ch7–8) | moment `curtain_trap` | `first_dinner_eaten`, night → `curtain_trap_set`, then `fact.alis_tripped` at dawn |

## Act II scenes (L25: the grounds' dangers)

| Scene | Hangs on | Gate → deed |
|---|---|---|
| `BoggeHunt` (ch9–10) | moment `bogge` (`bogge_hunt_path`) | `first_dinner_eaten` → `bogge_survived`; a failed attempt raises `fact.bogge_looked` and can be retried |
| `PucaLure` (ch10–11) | moment `puca` (`garden_gate`, opens across the garden under her window) | `bogge_survived`, night → `puca_resisted` |

Both extend `Act2DreadSpace` (`story/act2/act2_dread_space.gd`): view and
gaze helpers (`view()`, `looking_at()`, `gaze_override` for tests),
`summon()` (the real creature through `request_actor`, its own scene as the
fallback), `place_player()`, `veil()`, looping `sound()`s from
`Act2DreadAudio`, and `abort()` (ends without the deed). The Bogge's pleas go
through `Act2Whisper` (a voice in her head, not the caption card).

Creature calls they use (creature files owned by L25's behaviour work, never
`creature.gd` or clips):
- `Bogge.pass_behind_frame(centre, ahead, seconds)`, `follow_behind(node, ahead)`,
  `set_reveal(0..1)`, `manifest(at)`, `withdraw()`; signals `begged`, `passed`.
- `Puca.lure_to(point)`, `arrived()`, `dart(away)`; cues `looks_like_father`,
  `shift_image`, `dart`; signals `image_changed`, `darted`.

Rules: the Bogge is real only while looked at. Each second in a 40° cone
makes it more real (fades at 0.3/s when she looks away); 0.8 s fails. The fog
a look raises stays for the attempt. The puca changes shape only while she
holds it in a 25° cone (1.4 s each, four times: bow, supplies, sisters,
father). Walking more than 45 m from it ends the lure with no deed.
