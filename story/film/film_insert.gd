## A film insert (lane L33): a small stage in its own world (a SubViewport
## with own_world_3d), laid over the frame by a TextureRect with the painter's
## shader (film_insert.gdshader). The opening film's mural and its memory
## flashes over the real cottage are inserts, as is the wolf's eye.
## `cover_to` brushes it on and off; `paint` is how much it looks painted.
class_name FilmInsert
extends CanvasLayer

const SHADER := preload("res://story/film/film_insert.gdshader")

var viewport: SubViewport
var rect: TextureRect
var stage: Node3D
var cover: float = 0.0

var _mat: ShaderMaterial
var _tween: Tween


func _init() -> void:
	layer = FilmPlayer.LAYER_INSERT
	name = "FilmInsert"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	viewport = SubViewport.new()
	viewport.own_world_3d = true
	viewport.transparent_bg = false
	viewport.msaa_3d = Viewport.MSAA_4X
	viewport.render_target_update_mode = SubViewport.UPDATE_DISABLED
	add_child(viewport)
	rect = TextureRect.new()
	rect.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	rect.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	rect.stretch_mode = TextureRect.STRETCH_SCALE
	_mat = ShaderMaterial.new()
	_mat.shader = SHADER
	rect.material = _mat
	add_child(rect)
	rect.texture = viewport.get_texture()
	_mat.set_shader_parameter(&"view", viewport.get_texture())
	get_viewport().size_changed.connect(_fit)
	_fit()
	_apply(0.0)


func _fit() -> void:
	var s := get_viewport().get_visible_rect().size
	viewport.size = Vector2i(maxi(int(s.x), 64), maxi(int(s.y), 36))


## Puts `node` (a Node3D stage with its own camera) in the insert's world.
func set_stage(node: Node3D) -> void:
	if stage and is_instance_valid(stage):
		stage.queue_free()
	stage = node
	viewport.add_child(node)


func set_param(param: StringName, value: Variant) -> void:
	_mat.set_shader_parameter(param, value)


## Brushes the insert on (1) or off (0) over `seconds`.
func cover_to(k: float, seconds: float) -> void:
	if _tween:
		_tween.kill()
	if k > 0.0:
		viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	if seconds <= 0.0:
		_apply(k)
		return
	_tween = create_tween()
	_tween.tween_method(_apply, cover, k, seconds).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_IN_OUT)


func _apply(k: float) -> void:
	cover = k
	_mat.set_shader_parameter(&"cover", k)
	rect.visible = k > 0.0
	# An insert that is off costs nothing.
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS if k > 0.0 else SubViewport.UPDATE_DISABLED
