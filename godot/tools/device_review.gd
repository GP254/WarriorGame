extends Node
var results: Dictionary = {"checks":[],"captures":[]}
func check(value: bool, title: String) -> void:
	results.checks.append({"name":title,"passed":value})
	if not value: push_error("DEVICE REVIEW: "+title)
func shot(title: String) -> void:
	for i in 10: await get_tree().process_frame
	await RenderingServer.frame_post_draw
	var error := get_viewport().get_texture().get_image().save_png("user://review-"+title+".png")
	check(error == OK,"Capture "+title)
	results.captures.append(title)
func _ready() -> void:
	if not OS.is_debug_build() or not Campaign.test_mode:
		queue_free()
		return
	await get_tree().create_timer(2).timeout
	var game := get_parent()
	results.platform = OS.get_name()
	results.viewport = str(get_viewport().get_visible_rect().size)
	results.window = str(DisplayServer.window_get_size())
	results.safe_area = str(DisplayServer.get_display_safe_area())
	check(get_viewport().get_visible_rect().size.x>get_viewport().get_visible_rect().size.y,"Landscape viewport")
	check(game.hud.safe.get_global_rect().encloses(game.hud.context.get_global_rect()),"Village action inside safe area")
	await shot("village")
	game.show_armory()
	await shot("armory")
	game.show_map()
	await shot("map")
	game.show_war_council(1)
	await shot("deployment")
	game.start_battle()
	game.world.set_physics_process(false)
	for i in 300: game.world.advance(1.0/30)
	game.world.blocked = true
	check(game.hud.safe.get_global_rect().encloses(game.hud.combat_row.get_global_rect()),"Combat controls inside safe area")
	await shot("battle")
	game._enter_village(0)
	Campaign.state.levels["0"] = 3
	game._enter_village(0,Vector2(0,-180))
	await shot("upgraded")
	results.static_memory_mb = Performance.get_monitor(Performance.MEMORY_STATIC)/1048576.0
	var report := FileAccess.open("user://device-review.json",FileAccess.WRITE)
	report.store_string(JSON.stringify(results,"\t"))
	report.close()
	print("DEVICE REVIEW COMPLETE ",JSON.stringify(results))
