# Contract: films and cutscenes (lane L33)

Scripted, letterboxed, skippable films: the new-game opening film "Once" and
the three cutscenes (A "Eyes Open", B "The Night Court", C "The Silent
Manor"). The script, with every line tagged canon or invented, is
`/mnt/project-files/plans/film/scripts.md` (v2.1, signed off by the Keeper
and the newcomer critic). Data rows are written by `tools/film/gen_film_data.py`.

## Pieces

| File | What |
|---|---|
| `story/film/film_script.gd` `FilmScript` | Data: `id`, `length`, `music_cue` (a SoundBank cue), `seen_flag`, `bars` (letterbox amount), `lines: Array[FilmLine]`, `beats: Array[FilmBeat]`. `line(id)`, `beat_time(name)`. |
| `story/film/film_line.gd` `FilmLine` | One caption: `id`, `at`, `hold`, `speaker` (empty = narration), `text`, `canon` (`C`, `C?`, `X`). |
| `story/film/film_beat.gd` `FilmBeat` | A named cue at time `at` for the film's director. |
| `story/film/film_player.gd` `FilmPlayer` | Plays one `FilmScript`. A root child named `FilmPlayer`, so it outlives a scene change. Clock, captions, score, skip, veil, letterbox. |
| `story/film/film_captions.gd` `FilmCaptions` | Narration in EB Garamond italic, speech upright and tinted by speaker, just above the bottom bar. |
| `story/film/film_skip.gd` `FilmSkip` | Hold any confirm/cancel action 0.8 s, or press twice within 0.6 s. Gold ring, "hold to skip". |
| `story/film/film_insert.gd` `FilmInsert` | A full-screen painted insert (own `World3D` in a SubViewport) laid over the game, brushed on and off with `cover_to(k, s)`. |
| `story/film/mural/mural_stage.gd` `MuralStage` | The living gold-and-ink mural: tableaux `land, court, slaves, war, treaty, mother, house, ships`, cut to with `play(id, s)`. `build_only` builds a subset. Figures keep their own colours (`mural_lit.gdshader`: the model's albedo, lit by the stage's warm key and cool rim, a thin gilt line, leaning into the tableau ink by `figure_ink` or a material's `ink_mix` meta); backdrops and props stay painted (`mural_paint`, `mural_sky`). Paint soaks on in a soft ragged front, never torn bands. Each tableau with a backdrop gets depth haze in its own colour and far focus (`focus`). |
| `story/film/opening/opening_film.gd` `OpeningFilm` | Part one (the mural and the turn at the Wall), in its own scene. |
| `story/film/opening/opening_film_world.gd` `OpeningFilmWorld` | Part two in the real game world: the cottage at night, memory flashes, dawn with Feyre, the wolf's eye, the title, the hand-over. |

## FilmPlayer

- `FilmPlayer.start(tree, film) -> FilmPlayer`: null when films can't play
  (headless without `FilmPlayer.headless_opt_in`) or another film is running.
  `FilmPlayer.current(tree)` is the running one.
- While it plays it holds `StoryControl` at `NONE` every frame (no walking,
  looking, pause menu or HUD) and emits
  `EventBus.scene_space_started("film_<id>")` / `scene_space_finished`.
- Time follows the wall clock, pulled toward the score's playback position.
  `beat(name)` and `line_shown(line)` fire in order. `seek(t)` fires
  everything up to `t`.
- `veil_to(alpha, s, color)`, `hide_ui_of(scene)` (restored at the end),
  `take_input_lead()` (moves it to the last root child so it hears input
  before the scene's own menus).
- `skip()` or reaching `length` ends it: `finished(skipped)`, the seen flag
  written (also when freed early), the UI and `StoryControl` handed back, the
  bars dropped. It frees itself shortly after.

## Facts and story flags

- Films never set story phase flags (R2). A film with a `seen_flag` writes it
  to `WorldState` as `fact.film_<id>_seen` when it ends, however it ends.
- The opening film has no seen flag: the game's first thought only plays
  when `WorldState` is empty, so the film calls it itself at its end.

## The opening film

- `OpeningFilm.route(load_slot)`: New Game (no slot) goes to
  `OpeningFilm.SCENE`; Continue goes straight to `act1_game.tscn`.
  `title_screen.gd` routes through it.
- Headless, or when the player can't start, `OpeningFilm` changes straight to
  the game scene, as New Game did before.
- Part one arms `OpeningFilmWorld`. In `Act1Game._spawn_at`,
  `OpeningFilmWorld.take(game, feyre, _first_thought)` returns true only
  right after the film. Part two then owns the camera (Cine), the Clock
  (night, then the game's dawn at 0.27) and Feyre's visibility until it hands
  over. Every other start is unchanged.
- Skipping in part one goes straight to the game. Skipping in part two hands
  over on the spot.

## Cutscenes A, B, C

They play when their story moment starts: `glamour_lift` (A, the glade in
Blossom Vale), `rhysand_visit` (B, the manor's dining hall), `alis_truth`
(C, the entry hall, the kitchen, the garden steps). The moment's data keeps
its anchor, gates and deed. Its steps are now: spawn the cast it owns,
`film <id>`, `until_flag` on the film's facts, then the deed (written by
`tools/story/gen_moments.py`). The story moves on whether the film plays,
is skipped, or can't play (headless: every fact is written at once).

| Film | Facts it writes | The moment then raises |
|---|---|---|
| `eyes_open` (76 s) | `fact.film_eyes_open_lift` (under the black, eyes closed), `fact.film_eyes_open_seen` | `glamour_lifted` on the lift fact |
| `night_court` (105 s) | `fact.false_name_clare_beddor` (her answer), `fact.film_night_court_seen` | `rhysand_faced` |
| `silent_manor` (150 s) | `fact.film_silent_manor_seen` | `alis_truth_heard` (journal entries first) |

- `Films.play(space, id)` (`story/film/films.gd`) starts the player and adds
  the film's director, `story/film/cutscenes/<id>.gd`, a `CutsceneDirector`.
- `CutsceneDirector` (`story/film/cutscene_director.gd`): one `_b_<beat>()`
  per beat. Points are in the moment's frame (`at`), or the manor house's
  layout frame after `use_house()` (lifted onto the ground floor:
  `ManorHouseBuilder.floor_y(0)`; `ground()` there finds the floor through
  furniture). Face shots (`close`, `over`, `shot_on`) frame the head where
  `FilmPose` draws it, swing round until no one else stands in front of the
  face (`clear_view`), and stay inside the room. Feyre's bow and quiver are
  hidden while a film plays (they hang off her controller, not her
  skeleton). It owns Cine, poses (`FilmPose`), a
  `FilmGrade` (veil, bloom, edge_gold, cold, crack) and its props; at the end,
  however it ends, the props go, poses let go, Feyre is put at `_end_mark()`
  and the camera eases back to hers. `add_set` dressing stays (A's willow and
  brook).
- `FilmPose` stages the cast (kneel, sit, crouch, reach, bow...) over the
  body animation; it also drives the townsfolk rig (`creatures/models/people`).
- B's Rhysand: the cast lane's `characters/rhysand/rhysand_model.tscn` when it
  exists; until then Tamlin's rig re-dressed (no mask or claws, blue-black
  hair, black and dark silver, violet eyes, his own dark). His dark is a
  negative light behind him (+Z, the rig faces -Z), never inside him: from his
  chest it blacks the undersides of brow, cheek and lip. B brings him
  itself; the moment no longer spawns him. B plays Tamlin and Lucien with its
  own models too (`bring_own`): the lunch's go when the lunch ends.
- `MuralDark` (`story/film/mural/mural_dark.gd`): the mural told true for C
  (queen, masks, terms; black, rust, thorns) and B's gold flash (well).
- Mac capture: `res://tools/film/cutscene_shot.tscn -- {out} <film_id>` starts
  the real game at the moment's anchor with its chain of deeds done and
  captures the film the story starts (`FilmCapture.wait_for_film`). The
  moment's own `fact.*` gate opens 4 s after she is placed, so the region
  (the house) is built before the film starts, and any other scene whose
  gate is open there is marked done as it is built (`_hush`, by flags only:
  some scenes, like Calanmai's order in the hall, bring their hour with them).

## Tests

`tests/unit/film/test_film_player.gd` covers:

- no play headless without opt-in;
- beats and lines in order;
- control held;
- skip and finish write the seen fact exactly once, including when the player is freed early;
- the HUD is hidden and restored;
- the skip inputs;
- `take()` is false unless the film is armed;
- New Game routing;
- `opening_film.tres` matches the script.

`tests/unit/film/test_cutscenes.gd` covers: each moment plays its film then
waits on its facts; films write only facts (R2); headless, every fact at once;
skipped on the first frame, the story moves on; every beat of every director
runs and its props go; the house frame stands on the ground floor; a posed
head is framed where the pose draws it.
