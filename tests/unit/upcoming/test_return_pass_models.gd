extends "res://tests/unit/upcoming/model_family_contract.gd"
## Contract test for the return-home and wrecked-manor props (lane L73,
## docs/contracts/return_pass_models.md).
# gate: when:art/return_pass/*,tools/blender/return_pass_props.py,tools/blender/upcoming_kit.py,tests/unit/upcoming/*


func before_all() -> void:
	dir = "res://art/return_pass/"
	manifest = "return_pass_manifest.json"
	required = [
		"trunk_gold", "trunk_gowns", "raw_ruby", "gold_scale", "tulip_bed", "dug_plot",
		"bulb_crate", "watering_can", "garden_trug", "iron_bracelet", "ball_flower_stand",
		"estate_gate", "supply_satchel", "garden_tangle", "cottage_window_cracked", "beddor_ruin",
		"door_shattered", "table_wrecked", "curtain_shredded", "glass_shards", "claw_gouges",
		"blood_puddle", "blood_smear_wall", "alis_satchel", "dagger", "cave_mouth_pass",
		"shrine_stone_worn",
	]
	super.before_all()
