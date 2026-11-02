## The drums on the hills as heard from anywhere but the hill (ch20 [C]: "by
## ten o'clock" she follows the drums). Lives under the tree root from the
## order to stay inside until she reaches the fires, where the hill's own
## positional drums take over (CalanmaiNight). Quiet, low, everywhere.
class_name FarDrums
extends AudioStreamPlayer

const NAME := "CalanmaiFarDrums"
const UNTIL := ["calanmai_attended", "fact.calanmai_carried"]


## Starts the far drums once (safe to call again).
static func ensure(tree: SceneTree) -> FarDrums:
	if tree == null:
		return null
	var existing := tree.root.get_node_or_null(NAME) as FarDrums
	if existing:
		return existing
	for flag: String in UNTIL:
		if WorldState.has_flag(flag):
			return null
	var d := FarDrums.new()
	d.name = NAME
	d.stream = CalanmaiNight._looped(CalanmaiNight.DRUMS)
	d.volume_db = -30.0
	tree.root.add_child(d)
	return d


func _ready() -> void:
	play()
	var tw := create_tween()
	tw.tween_property(self, ^"volume_db", -13.0, 6.0)
	EventBus.flag_changed.connect(_on_flag)


func _on_flag(flag: String, _v: Variant) -> void:
	if UNTIL.has(flag):
		var tw := create_tween()
		tw.tween_property(self, ^"volume_db", -40.0, 4.0)
		tw.tween_callback(queue_free)
