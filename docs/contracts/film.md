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
| `story/film/mural/mural_stage.gd` `MuralStage` | The living gold-and-ink mural: tableaux `land, court, slaves, war, treaty, mother, house, ships`, cut to with `play(id, s)`. |
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

## Cutscenes A, B, C (next hand-in)

They play when their story moment starts (`glamour_lift`, `rhysand_visit`,
`alis_truth`). The moment's data keeps its anchor, gates and the deed it
raises, fired the same way. Its other steps are thinned to
`until_flag fact.film_<id>_seen` with a safety fallback, so the story moves
on whether the film plays, is skipped, or can't play (headless).

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
