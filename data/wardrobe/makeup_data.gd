## One makeup option for the dressing mirror. Applied as shader parameters on
## Feyre's skin material (channels below), so adding one needs no code.
class_name MakeupData
extends Resource

## Channels on the skin shader. Each has <channel>_color and <channel>_amount.
const CHANNELS: Array[StringName] = [
	&"lips", &"eyeshadow", &"liner", &"blush", &"brows", &"face_paint",
]

@export var id: StringName
@export var display_name: String
@export var channel: StringName = &"lips"
@export var color: Color = Color(0.7, 0.3, 0.35)
## 0 to 1: how strongly it covers the skin.
@export var amount: float = 0.6
## Shimmer (fae cosmetics, gold dust): adds to the channel's sheen.
@export var sheen: float = 0.0
@export var source: StringName = &"manor_dressing_room"
@export var phase: int = 2
@export var canon: String = "X"
