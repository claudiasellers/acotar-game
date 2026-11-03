extends SceneTree
## Writes the committed candy_lit variants (render program T2) under
## world/shared/shaders/candy/: every combination a glb import can produce, plus
## the keys saved scenes use. Other keys are built in memory at runtime
## (CandyMaterial.shader_for), so this list only has to cover saved resources.
##   godot --headless -s tools/render/candy_variants.gd

const SCENE_KEYS := [
	"unshaded-alpha-bb_particles-keep_scale-noshadow-proxfade",
	"unshaded",
	"unshaded-alpha-double",
	"unshaded-double-bb_particles",
]


func _init() -> void:
	var keys: Array[String] = []
	for shade in ["", "unshaded"]:
		for alpha in ["", "alpha", "scissor"]:
			for cull in ["", "double"]:
				for normal in ([""] if shade == "unshaded" else ["", "normal"]):
					var t := PackedStringArray()
					for tok in [shade, alpha, cull, normal]:
						if tok != "":
							t.append(tok)
					keys.append("-".join(t))
	for k in SCENE_KEYS:
		if not keys.has(k):
			keys.append(k)
	DirAccess.make_dir_recursive_absolute(CandyMaterial.VARIANT_DIR)
	var n := 0
	for k in keys:
		if k.is_empty():
			continue  # candy_lit.gdshader itself
		var f := FileAccess.open(CandyMaterial.variant_path(k), FileAccess.WRITE)
		f.store_string(CandyMaterial.variant_code(k))
		n += 1
	print("candy_variants: wrote %d variants" % n)
	quit()
