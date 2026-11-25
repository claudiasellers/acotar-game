## What one manor station does when she presses E at it (UX review G6): a small
## real use for the things that used to take E and do nothing. One row per
## station_id in data/stations/uses/; StationUses runs them.
##
## Kinds (what `lines`, `alt_lines` and `day_lines` hold for each):
##   play     a few notes and sparkles; lines: a thought, one picked at random
##   letters  she practises her letters, once a day; lines: tiered by how often
##            she has practised (the last tier repeats); alt_lines: done today
##   arrows   fills her quiver with `item_id` up to `fill_to`, once a day;
##            lines: she took some; alt_lines: nothing to take
##   tend     binds her hurts with the supplies (heals her, draws out venom);
##            lines: tended; alt_lines: nothing needs mending
##   sleep    evening to morning, or a nap by day (`minutes`); calls
##            VitalsState.rest(): every night leaves her Well rested (the
##            user, 2026-11-24), a nap doesn't; lines: on waking from a night,
##            peaceful or a nightmare's echo, one at random; day_lines: the nap
##   soak     a hot bath for `minutes`: warms her through and eases her;
##            lines: a thought, one picked at random
class_name StationUse
extends Resource

@export var station_id: StringName
## The key prompt's verb: "E   play a few notes".
@export var verb: String
## sleep: the verb by day, when it is a nap ("rest a while"); "" = `verb`.
@export var day_verb: String
@export_enum("play", "letters", "arrows", "tend", "sleep", "soak") var kind: String = "play"
@export var lines: PackedStringArray = PackedStringArray()
@export var alt_lines: PackedStringArray = PackedStringArray()
@export var day_lines: PackedStringArray = PackedStringArray()
## PhaseManager phases it works in; empty = always.
@export var phases: PackedStringArray = PackedStringArray()
## Game minutes that pass (soak, letters, tend, the daytime nap).
@export var minutes: float = 0.0
## arrows: what she takes and how many she leaves with.
@export var item_id: StringName
@export var fill_to: int = 0
## Keeper tags: A (book), C (close to the book), X (invented).
@export var canon: String = "X"


func open_now() -> bool:
	return phases.is_empty() or phases.has(String(PhaseManager.current_phase))
