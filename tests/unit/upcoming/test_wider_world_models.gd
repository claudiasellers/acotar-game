extends "res://tests/unit/upcoming/model_family_contract.gd"
## Contract test for the fae village shops, the fells climbables and sentry
## dressing, the Blighted Reaches and the routine props (lane L73,
## docs/contracts/wider_world_models.md).
# gate: when:art/wider_world/*,tools/blender/wider_world_props.py,tools/blender/upcoming_kit.py,tests/unit/upcoming/*


func before_all() -> void:
	dir = "res://art/wider_world/"
	manifest = "wider_world_manifest.json"
	required = [
		"seam_dress_form", "seam_loom", "seam_fabric_bolts", "seam_ribbon_rack", "seam_worktable",
		"seam_crown_stand", "potion_shelf", "potion_alembic", "potion_mortar", "potion_herb_rack",
		"potion_counter", "climb_ivy_panel", "climb_root_ladder", "climb_ledge", "climb_handholds",
		"cliff_rope_anchor", "signal_brazier", "sentry_weapon_rack", "sentry_banner", "range_marker",
		"blight_rose_bush", "blight_thorn_arch", "blight_carcass", "blight_dry_fountain",
		"blight_withered_patch", "blight_dead_birds", "laundry_basket", "whetstone_kit",
	]
	super.before_all()
