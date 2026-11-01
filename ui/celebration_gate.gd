## Holds celebratory UI (find cards, "A new truth", rewards) back while the
## game is frightening or staged, so a pastel card never lands in the middle
## of the Suriel, the naga or the beast (R3: horror is never toned down).
## Hushed while a dread mood is active (EventBus.mood_requested, as DreadField
## and the scripted scenes send it) or while a moment holds Feyre
## (StoryControl not FULL). Callers queue and ask again later.
class_name CelebrationGate
extends RefCounted

## A dread request with no renewal or "calm" after this long has lapsed, so a
## scene that never sends calm can't silence the cards for good.
const DREAD_LAPSE_MS := 30000
## How often a held queue asks again.
const RECHECK := 0.5

static var _watching: bool = false
static var _dread_until: int = 0


## Starts listening for moods. Call early (GuideJournal does on _ready); safe
## to call again.
static func watch() -> void:
	if _watching:
		return
	_watching = true
	EventBus.mood_requested.connect(func(mood: StringName, intensity: float, _seconds: float) -> void:
		if mood == &"dread" and intensity > 0.0:
			_dread_until = Time.get_ticks_msec() + DREAD_LAPSE_MS
		else:
			_dread_until = 0)


static func dread() -> bool:
	return Time.get_ticks_msec() < _dread_until


static func hushed() -> bool:
	return dread() or StoryControl.mode != StoryControl.Mode.FULL


## Tests: forget any dread.
static func reset() -> void:
	_dread_until = 0
