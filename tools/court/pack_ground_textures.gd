## Packs CC0 photo ground textures (Poly Haven 1k: <id>_diff/_disp/_nor_gl/_rough)
## into the terrain's slot format, in the court's own palette:
##   <slot>_albedo.png  rgb colour, a height     (512 px, tileable)
##   <slot>_normal.png  rgb OpenGL normal, a roughness
## The photo gives the structure (blades, pebbles, leaf litter, its height and
## normal); the colour is the slot's palette from gen_terrain_textures.gd LOOKS,
## with a little of the photo's own hue kept, softened and capped at the glare
## rule (albedo <= 0.85). Run from the project:
##   tools/mq/godot.sh -s tools/court/pack_ground_textures.gd -- <source dir> [--look L] [--out DIR] [slot...]
## Looks (LOOKS_ALT): "photo" (structure kept), "soft" (quiet detail, flatter
## normals), "pastel" (soft, in the foliage's mint-and-blossom family),
## "storybook" (pastel, light and dark in soft painted bands).

extends SceneTree

func _initialize() -> void:
	var args := OS.get_cmdline_user_args()
	if args.is_empty():
		push_error("pack_ground_textures: give the folder with the Poly Haven maps")
		quit(1)
		return
	var src: String = args[0]
	var rest := Array(args.slice(1))
	var look := "photo"
	var out := GroundTexturePacker.OUT
	var li := rest.find("--look")
	if li >= 0:
		look = rest[li + 1]
		rest.remove_at(li + 1)
		rest.remove_at(li)
	var oi := rest.find("--out")
	if oi >= 0:
		out = rest[oi + 1]
		rest.remove_at(oi + 1)
		rest.remove_at(oi)
		DirAccess.make_dir_recursive_absolute(out)
	var packer := GroundTexturePacker.new(look, out)
	var slots: Array = rest if not rest.is_empty() else GroundTexturePacker.SOURCES.keys()
	var done := 0
	for slot: String in slots:
		if packer.pack(src, slot):
			done += 1
	print("pack_ground_textures: %d slots written" % done)
	quit(0 if done == slots.size() else 1)
