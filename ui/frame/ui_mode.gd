## What the game is doing right now, as far as the in-play screen cares. Not a
## state anyone sets: one function reads what the game already knows. HudLayout
## shows and hides its zones from it, and anything that waits for a quiet
## moment (a celebration card, one of Feyre's thoughts) asks quiet().
## Contract: docs/contracts/ui-frame.md.
class_name UiMode
extends RefCounted

enum Mode {
	PLAY,  ## Feyre is the player's.
	STAGED,  ## A moment has narrowed her controls (StoryControl WALK or LOOK).
	HELD,  ## A moment holds her entirely (StoryControl NONE).
	FILM,  ## A film is playing.
	SCREEN,  ## A screen is open (the book, the pause panel, a station).
}


static func current(tree: SceneTree) -> Mode:
	if not ScreenStack.is_empty():
		return Mode.SCREEN
	var film := FilmPlayer.current(tree)
	if film and film.playing:
		return Mode.FILM
	match StoryControl.mode:
		StoryControl.Mode.FULL:
			return Mode.PLAY
		StoryControl.Mode.NONE:
			return Mode.HELD
	return Mode.STAGED


## True while a pastel card or a stray thought would land badly: any mode but
## PLAY, or dread in the air (R3: horror is never toned down). Callers queue
## and ask again.
static func quiet(tree: SceneTree) -> bool:
	return current(tree) != Mode.PLAY or HudLayout.of(tree).dread()
