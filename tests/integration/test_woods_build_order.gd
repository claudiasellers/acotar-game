## A region's scatter must not depend on which regions were built before it in
## the same run (suriel_glade lost two forage types after border_woods).
## Each build order runs in its own Godot process, since what one build leaves
## behind (interned names, static caches) is per process.
extends GutTest

const TOOL := "res://tools/woods/write_woods_reports.gd"


func _report_after(order: Array, region: String) -> String:
	var out := []
	var args := ["--headless", "--path", ProjectSettings.globalize_path("res://"), "-s", TOOL, "--", "--dry-run"]
	args.append_array(order)
	OS.execute(OS.get_executable_path(), args, out, true)
	for line: String in "\n".join(out).split("\n"):
		if line.begins_with(region + " {"):
			return line
	return ""


func test_suriel_glade_is_the_same_built_alone_or_after_border_woods() -> void:
	var alone := _report_after(["suriel_glade"], "suriel_glade")
	var after := _report_after(["border_woods", "suriel_glade"], "suriel_glade")
	assert_ne(alone, "", "suriel_glade built")
	assert_eq(after, alone)


func test_ids_sort_by_name_not_by_when_they_were_interned() -> void:
	var d := {StringName("zz_order_" + str(1)): 0, StringName("aa_order_" + str(1)): 0, StringName("mm_order_" + str(1)): 0}
	assert_eq(WoodsScatter.sorted_ids(d), [&"aa_order_1", &"mm_order_1", &"zz_order_1"])
