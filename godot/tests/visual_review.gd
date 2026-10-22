extends SceneTree
var game: Node
func _initialize() -> void: call_deferred("run")
func shot(name: String) -> void:
	for i in 12: await process_frame
	await RenderingServer.frame_post_draw
	var image := root.get_texture().get_image()
	var path := "res://artifacts/"+name+".png"
	var error := image.save_png(path)
	if error != OK: push_error("Screenshot failed: "+name); quit(1)
	print("CAPTURE ",name," ",image.get_size())
func run() -> void:
	root.size = Vector2i(1280,720)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await shot("village-phone")
	game.world.set_physics_process(false)
	for npc in game.world.citizens: npc.set_physics_process(false)
	for step in 900:
		game.world.society.advance(0.1)
		for npc in game.world.citizens: npc._physics_process(0.1)
	game.world.player.position = Vector2(450,270)
	game.world.player.camera.reset_smoothing()
	await shot("village-working")
	game.world.player.position = Vector2(0,170)
	game.world.player.camera.reset_smoothing()
	game.show_dialogue(game.world.citizens[0])
	await shot("dialogue-phone")
	game.close_modal()
	game.show_settlement()
	await shot("settlement-phone")
	game.close_modal()
	game.show_clan()
	await shot("clan-phone")
	game.close_modal()
	game.show_armory()
	await shot("armory-phone")
	game.close_modal()
	game.show_map()
	await shot("map-phone")
	game.close_modal()
	game.show_war_council(1)
	await shot("war-council-phone")
	game.start_battle()
	game.world.set_physics_process(false)
	for i in 240: game.world.advance(1.0/30)
	game.world.blocked = true
	await shot("battle-phone")
	game.close_modal()
	game._enter_village(0)
	root.get_node("Campaign").state.levels["0"] = 3
	game._enter_village(0,Vector2(0,-180))
	await shot("village-upgraded")
	root.size = Vector2i(1366,1024)
	await shot("village-ipad")
	game.queue_free()
	await process_frame
	quit()
