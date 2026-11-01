## One thing the Suriel tells Feyre (ch 14), in book order. Each answer is a
## journal entry (EventBus.journal_entry_added) and, when it names a place,
## sketches that place onto her map.
class_name SurielAnswer
extends Resource

@export var id: StringName
## Book order, 1-5. The naga cut her off after SnarePlan.answers_for().
@export var order: int = 1
## What Feyre asks (her own thought, shown small above the answer).
@export var asked: String
## What the Suriel says. Paraphrased, never book text.
@export_multiline var said: String
## Said instead when the naga cut the answer short (the blight, ch 14).
@export_multiline var said_cut: String
## data/map/map_places.tres id sketched in when she hears it, or empty.
@export var map_place: StringName
@export var canon: String = "C"
