# Dialogue contract (free-roam lines and the cast in place, lane L34)

Two nodes, added by the game scene (`story/act1/act1_game.gd`):

- `DialogueDirector` (`systems/dialogue/dialogue_director.gd`, group `dialogue_director`) speaks
  what Feyre thinks when she walks into regions, manor rooms and places, what the people near her
  say, and what she (or whoever is near) says once a deed is done.
- `CastPresence` (`systems/dialogue/cast_presence.gd`) stands the cast where the book has them,
  so there is someone to talk to: the family in the cottage, villagers, Tamlin, Lucien, Alis,
  sentries, the masked household once the glamour lifts, the court fae, and revellers.

Both only read state. **A line never sets, gates or substitutes for a story flag (R2).** The only
thing written is `dlg.<line_id>` when a once-line has been heard, so a reload doesn't repeat it.
No choices, no objective text, no quest markers.

## Signals and calls other lanes use

| What | Where |
|---|---|
| `line_spoken(line_id: StringName, speaker: StringName, text: String, at: Vector3, inner: bool)` | `DialogueDirector`, every line it shows. The sound lane (L15) ducks the beds on it when `res://audio/voice/<line_id>.ogg` exists. `inner` = Feyre's thoughts (inner-voice treatment) |
| Voice files | `res://audio/voice/<line_id>.ogg`. When one exists the director plays it (positional at the speaker, flat for inner lines) on the `Sound` bus. The sheet for the voice tool is `data/dialogue/sheet/line_sheet.csv` (one row per line, delivery notes and target file) |
| `EventBus.line_spoken(actor, text, emotion, seconds)` | Also emitted for every line, once L01-11 adds that signal to EventBus (L36's faces listen). `actor` is the speaking node (Feyre's for her thoughts), and `emotion` comes from `DialogueLine.emotion`. **Two signals share the name:** the director's own `line_spoken(line_id, ...)` carries the id for voice files and ducking, and EventBus's carries the actor for faces |
| Talking hands | `CourtNpc.set_talking(true)` for the length of the line |
| Caption | The shared `Act2Caption` (`say(who, text)`). Inner lines show no name |

## When it stays quiet

Staged scenes always win. Nothing is said while `StoryControl.mode` isn't `FULL` (staged moments
narrow it, and the L33 films hold `NONE`), for 6 s after any `EventBus.scene_space_started` /
`scene_space_finished`, or while another caption is on screen. Some spaces run in FULL play for a
whole phase (Feyre's hall map in p3), so the mode is the test, not whether a space exists. Deed lines wait up to 120 s for the scene that raised the
deed to end. There are at least 5 s between ambient lines and 25 s before the same speaker speaks
again. A speaker greets her once per approach (within 4.5 m); she has to step 9 m away to re-arm.

Tamlin, Lucien and Alis leave their free-roam spots while a scene holds control or the story has spawned
its own `story_actor_<id>` for them, so they never double. Nesta, Elain and their father stay in
the cottage for the beast scene, because its `gather` cue moves them.

## Scene guides (a scene's own thoughts)

A staged scene that needs its own running thoughts gets a guide node: a child of the scene's
SceneSpace that only listens (beats, cues, hits, the bow) and calls
`DialogueDirector.say_beat(scene_id, beat)`. While a guide calls `hold(scene_id, true)`, the
director's own ambient, place and deed lines wait; `hold(..., false)` ends it with the usual hush.
A beat's lines are `SCENE` lines with `where = "<scene_id>.<beat>"`, spoken in book order one
after another; a newer beat cuts off what is left of the last. Scene beats speak whatever the
control mode (the guide decides when). The guide says each beat at most once per run.

`WolfHuntGuide` (`systems/dialogue/scene_guides/wolf_hunt_guide.gd`, under `WolfKill`, ch1, all
lines Keeper-checked): `doe` (the camera finds her), `eyes` (golden eyes, the snow holds), `size`,
`wait`, `nudge_draw` and `nudge_loose` (only while she has never drawn; the second only once he
has the doe), `wood`, `miss`, `ash`, `kill`. Her heart (`beast_heartbeat`, L15) beats under a
draw while he is alive. The staging (`WolfKillStaging`) frames the doe, then him, and tightens the
lens while she holds the bow drawn and aimed on him; the world's slow draw is the bow's own
(`BowController`), unchanged.

## Data (generated, never hand-edited)

`tools/dialogue/gen_dialogue.py` writes everything below. Edit the tables there and rerun it.

- `data/dialogue/lines/<area>.tres`: `DialogueBook` (`lines: Array[DialogueLine]`,
  `places: Array[DialoguePlace]`). `DialogueLine` fields: `id`, `speaker` (a cast id, a `CourtNpc`
  npc_id, or a group key: `villager`, `court_fae`, `servant`, `gardener`, `sentry`, `reveler`;
  see `DialogueRules.group_of`), `who`, `text`, `canon` (V/A/X), `trigger` (`ENTER_REGION`,
  `ENTER_ROOM`, `NEAR_PLACE`, `NEAR_SPEAKER`, `DEED`, `FOLLOW_UP`, `SCENE`), `where`, `deed`, `phases`,
  `require_flags`, `forbid_flags`, `hour_from`/`hour_to`, `once`/`cooldown`, `priority`, `inner`,
  `follow_up`, `delivery`, `emotion`.
- `where` is a `RegionDef` id, `manor_house`/`manor_grounds` (from `ManorSitePlan`), a manor room id
  (`data/regions/spring_court/manor_estate/house/*.tres`, found with `HallMap.room_at`), or a
  `DialoguePlace` id. Court places take their centres from `data/places/court_places.tres` (L32).
- `data/dialogue/presence.tres`: `PresenceRoster` of `PresenceSpot` (speaker, scene, region,
  `at`, plus a `room` (house space on that room's storey) or an `anchor` (relative to a story
  anchor), phases, flags, hours, wander). The Keeper checked the roster. The rules, which the
  contract test enforces: the family only in the human-realm phases; the household (`UNSEEN` in
  `test_court_people.gd`) only after `glamour_lifted`; house spots inside their room and more
  than 1.5 m from any door. The main cast uses its real models (`characters/<id>/<id>_model.tscn`,
  wrapped in `PresenceActor`), never `StandIns`. Nothing spawned has collision.

## Adding lines

Add rows to the generator under the right area and rerun it. Flags must be deed flags from
`lore/07-story/timeline-overview.md` (as in `data/phases/spring_court_phases.tres`) or a story
lane `fact.*`. Tag every line V, A or X. Ask the Keeper whenever you're unsure. A non-Feyre line
needs someone standing there to say it: add a spot, or the contract test fails.

Checks: `tests/unit/dialogue/test_dialogue_contract.gd`. Headless tour across the realms and
phases: `tools/mq/godot.sh --fixed-fps 30 res://tools/dialogue/dialogue_tour.tscn -- --out=/tmp/tour.json`.
