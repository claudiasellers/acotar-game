## The in-play screen: one layer of zones, and every HUD piece sits in one.
## A piece is a Control handed to place(); the zone owns where it sits and
## whether it shows, so a piece never makes a CanvasLayer, never sets its own
## place on screen and never asks what mode the game is in. A piece may still
## hide itself for a reason of its own (nothing to say, a setting).
## Lives under ScreenStack; reach it with HudLayout.of(tree).
## Contract: docs/contracts/ui-frame.md.
class_name HudLayout
extends CanvasLayer

enum Zone {
	EDGE,  ## Screen-edge effects, under everything (its own layer).
	WORLD,  ## Full screen: the aim reticle, the grab ring.
	WAY,  ## Full screen: the player's own pin, floating over its spot.
	THOUGHT,  ## Top left: Feyre's thought and its tab.
	NOTICE,  ## Top centre: first finds, rewards, chapter cards.
	MINIMAP,  ## Top right.
	VITALS,  ## Bottom left: statuses over the health bar and the bow.
	PROMPT,  ## Bottom centre, over the strap: what a key does here.
	STRAP,  ## Bottom centre: the quick strap.
	BOW,  ## Right, low: the quiver card.
	CONTROLS,  ## Bottom right corner, under BOW: the controls hint.
}

const NODE := ^"ScreenStack/HudLayout"
const MARGIN := 28.0
## Spoken lines run along the bottom between VITALS and BOW, from here
## rightwards. Nothing in VITALS reaches past it.
const LANE_LEFT := 384.0
## A dread mood with no renewal and no "calm" lapses after this long, so a
## scene that never sends calm can't hush the cards for good.
const DREAD_LAPSE_MS := 30000

const _PLAY := 1 << UiMode.Mode.PLAY
const _STAGED := 1 << UiMode.Mode.STAGED
const _HELD := 1 << UiMode.Mode.HELD
const _FILM := 1 << UiMode.Mode.FILM
const _SCREEN := 1 << UiMode.Mode.SCREEN
## Zone -> the modes it shows in.
const SHOWS := {
	Zone.EDGE: _PLAY | _STAGED | _HELD | _FILM | _SCREEN,
	Zone.WORLD: _PLAY | _STAGED | _HELD,
	Zone.WAY: _PLAY,
	Zone.THOUGHT: _PLAY,
	Zone.NOTICE: _PLAY | _STAGED | _HELD,
	Zone.MINIMAP: _PLAY,
	Zone.VITALS: _PLAY,
	Zone.PROMPT: _PLAY | _STAGED,
	Zone.STRAP: _PLAY,
	Zone.BOW: _PLAY | _STAGED | _HELD,
	Zone.CONTROLS: _PLAY | _STAGED | _HELD,
}
## Corner zones: [anchor preset, offset from that anchor]. The rest fill the
## screen.
const CORNERS := {
	Zone.THOUGHT: [Control.PRESET_TOP_LEFT, Vector2(MARGIN, MARGIN)],
	Zone.NOTICE: [Control.PRESET_CENTER_TOP, Vector2(0, 36)],
	Zone.MINIMAP: [Control.PRESET_TOP_RIGHT, Vector2(-MARGIN, MARGIN)],
	Zone.VITALS: [Control.PRESET_BOTTOM_LEFT, Vector2(56, -70)],
	Zone.PROMPT: [Control.PRESET_CENTER_BOTTOM, Vector2(0, -214)],
	Zone.STRAP: [Control.PRESET_CENTER_BOTTOM, Vector2(0, -84)],
	Zone.BOW: [Control.PRESET_BOTTOM_RIGHT, Vector2(-40, -230)],
	Zone.CONTROLS: [Control.PRESET_BOTTOM_RIGHT, Vector2(-MARGIN, -MARGIN)],
}

var _zones: Dictionary[Zone, Control] = {}
var _dread_until: int = 0


static func of(tree: SceneTree) -> HudLayout:
	return tree.root.get_node(NODE) as HudLayout


func _init() -> void:
	name = "HudLayout"
	layer = UiLayers.HUD
	process_mode = Node.PROCESS_MODE_ALWAYS
	var edge_layer := CanvasLayer.new()
	edge_layer.name = "EdgeLayer"
	edge_layer.layer = UiLayers.EDGE
	add_child(edge_layer)
	for zone: Zone in Zone.values():
		var node := _make(zone)
		node.name = (Zone.keys()[zone] as String).capitalize()
		node.mouse_filter = Control.MOUSE_FILTER_IGNORE
		# Pieces stop with the game; the edges ease on through a pause.
		node.process_mode = Node.PROCESS_MODE_ALWAYS if zone == Zone.EDGE else Node.PROCESS_MODE_PAUSABLE
		(edge_layer if zone == Zone.EDGE else self).add_child(node)
		_zones[zone] = node


func _ready() -> void:
	EventBus.mood_requested.connect(_on_mood)
	_show_for(UiMode.current(get_tree()))


func _process(_delta: float) -> void:
	_show_for(UiMode.current(get_tree()))


## Puts `piece` in `zone`. With `keeper`, the piece is freed when the keeper
## leaves the tree, so a scene's HUD goes with the scene.
func place(piece: Control, zone: Zone, keeper: Node = null) -> void:
	var into := _zones[zone]
	if CORNERS.has(zone):
		var side: int = CORNERS[zone][0]
		piece.size_flags_horizontal = Control.SIZE_SHRINK_BEGIN
		if side == Control.PRESET_CENTER_TOP or side == Control.PRESET_CENTER_BOTTOM:
			piece.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		elif side == Control.PRESET_TOP_RIGHT or side == Control.PRESET_BOTTOM_RIGHT:
			piece.size_flags_horizontal = Control.SIZE_SHRINK_END
	else:
		piece.set_anchors_preset(Control.PRESET_FULL_RECT)
	into.add_child(piece)
	if keeper:
		keeper.tree_exited.connect(func() -> void:
			if is_instance_valid(piece):
				piece.queue_free())


func zone(which: Zone) -> Control:
	return _zones[which]


## Whether `which` shows in `mode`.
static func shows(which: Zone, mode: UiMode.Mode) -> bool:
	return int(SHOWS[which]) & (1 << mode) != 0


## Dread is in the air: a dread mood was asked for and hasn't been calmed or
## lapsed.
func dread() -> bool:
	return Time.get_ticks_msec() < _dread_until


func _on_mood(mood: StringName, intensity: float, _seconds: float) -> void:
	_dread_until = Time.get_ticks_msec() + DREAD_LAPSE_MS if mood == &"dread" and intensity > 0.0 else 0


func _show_for(mode: UiMode.Mode) -> void:
	for which: Zone in _zones:
		_zones[which].visible = shows(which, mode)


func _make(which: Zone) -> Control:
	if not CORNERS.has(which):
		var full := Control.new()
		full.set_anchors_preset(Control.PRESET_FULL_RECT)
		return full
	var spec: Array = CORNERS[which]
	var side: int = spec[0]
	var at: Vector2 = spec[1]
	var box := VBoxContainer.new()
	box.add_theme_constant_override(&"separation", 10)
	box.set_anchors_preset(side)
	box.offset_left = at.x
	box.offset_right = at.x
	box.offset_top = at.y
	box.offset_bottom = at.y
	var bottom := side == Control.PRESET_BOTTOM_LEFT or side == Control.PRESET_CENTER_BOTTOM \
			or side == Control.PRESET_BOTTOM_RIGHT
	var right := side == Control.PRESET_TOP_RIGHT or side == Control.PRESET_BOTTOM_RIGHT
	var centre := side == Control.PRESET_CENTER_TOP or side == Control.PRESET_CENTER_BOTTOM
	box.grow_vertical = Control.GROW_DIRECTION_BEGIN if bottom else Control.GROW_DIRECTION_END
	box.grow_horizontal = Control.GROW_DIRECTION_BOTH if centre \
			else (Control.GROW_DIRECTION_BEGIN if right else Control.GROW_DIRECTION_END)
	box.alignment = BoxContainer.ALIGNMENT_END if bottom else BoxContainer.ALIGNMENT_BEGIN
	return box
