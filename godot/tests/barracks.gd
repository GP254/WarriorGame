extends SceneTree
var checks := 0
var failures: Array[String] = []
var game: Node
var campaign: Node
func _initialize() -> void: call_deferred("run")
func check(value: bool, title: String) -> void:
	checks += 1
	if not value: failures.append(title); push_error(title)
func shot(title: String) -> void:
	if DisplayServer.get_name() == "headless": return
	for i in 8: await process_frame
	await RenderingServer.frame_post_draw
	root.get_texture().get_image().save_png("res://artifacts/"+title+".png")
func run() -> void:
	campaign = root.get_node("Campaign")
	campaign.set_process(false)
	campaign.state = campaign.fresh()
	for squad in 4:
		for batch in [1,5,10,25]:
			campaign.state.squads[squad] = 50
			campaign.state.gold = 1000
			check(campaign.recruit(squad,batch),"Hire batch %d into squad %d" % [batch,squad])
			check(campaign.state.squads[squad] == 50+batch and campaign.state.gold == 1000-batch*9,"Exact count and price")
	campaign.state.squads[0] = 123
	campaign.state.gold = 18
	var quote: Dictionary = campaign.recruitment_quote(0,25)
	check(quote.count == 2 and quote.gold == 18 and quote.can_hire,"Only charge for remaining capacity")
	check(campaign.recruit(0,25) and campaign.state.squads[0] == 125 and campaign.state.gold == 0,"Fill last two places")
	check(not campaign.recruit(0,1),"Full squad cannot be overfilled")
	campaign.state.squads[1] = 50
	campaign.state.gold = 89
	check(not campaign.recruit(1,10) and campaign.state.squads[1] == 50 and campaign.state.gold == 89,"Unaffordable recruitment is atomic")
	for args in [[-1,10],[4,10],[0,0],[1,-5],[1,26]]: check(not campaign.recruit(args[0],args[1]),"Reject invalid recruitment")
	campaign.state = campaign.fresh()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	for id in 16:
		game._enter_village(id)
		var site: Dictionary = {}
		for candidate in game.world.sites:
			if candidate.kind == "barracks": site = candidate
		check(not site.is_empty(),"Barracks exists in region %d" % id)
		check(game.world.walkable(site.at,15) and not game.world.route(Vector2(0,170),site.at).is_empty(),"Recruiter accessible in region %d" % id)
		await process_frame
	campaign.state = campaign.fresh()
	game._enter_village(0,Vector2(-580,-580))
	game.world.player.camera.reset_smoothing()
	check(game.world.nearest_interaction().get("kind") == "barracks","Walk-up officer offers recruitment")
	await shot("barracks-yard-phone")
	game.interact()
	check(game.modal_kind == "barracks" and game.world.blocked,"Officer opens recruitment and pauses village")
	await shot("barracks-phone")
	var button := game.modal.find_child("HireSquad0",true,false) as Button
	check(button != null and not button.disabled,"Recruitment card usable")
	button.pressed.emit()
	check(campaign.state.squads[0] == 70 and campaign.state.gold == 1410,"Recruitment UI adds ten warriors for ninety gold")
	check(game.world.citizens.size() == 32,"Hiring preserves village jobs")
	campaign.save_path = "user://barracks-regression.json"
	campaign.test_mode = false
	check(campaign.save_game(),"Recruitment saves")
	campaign.state = campaign.fresh()
	check(campaign.load_game() and campaign.state.squads[0] == 70 and campaign.state.gold == 1410,"Recruitment survives reload")
	campaign.test_mode = true
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(campaign.save_path+suffix): DirAccess.remove_absolute(campaign.save_path+suffix)
	game.show_war_council(1)
	check(game.deployment[0] == 70,"New recruits available for deployment")
	game.show_barracks()
	root.size = Vector2i(1366,1024)
	await shot("barracks-ipad")
	game.queue_free()
	await process_frame
	print("BARRACKS ",checks," checks; ",failures.size()," failures")
	quit(0 if failures.is_empty() else 1)
