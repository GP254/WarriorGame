extends SceneTree
var checks := 0
var failures: Array[String] = []
var game: Node
var campaign: Node
func _initialize() -> void: call_deferred("run")
func check(condition: bool, message: String) -> void:
	checks += 1
	if not condition:
		failures.append(message)
		push_error(message)
func touch(index: int, at: Vector2, down: bool) -> void:
	var event := InputEventScreenTouch.new()
	event.index = index
	event.position = at
	event.pressed = down
	root.push_input(event,true)
func run() -> void:
	campaign = root.get_node("Campaign")
	campaign.set_process(false)
	check(campaign.validate(campaign.fresh()),"Fresh state must validate")
	for key in ["gold","clock","owned","equipped","collected","settings"]:
		var bad: Dictionary = campaign.fresh()
		bad[key] = "corrupt"
		check(not campaign.validate(bad),"Reject malformed "+key)
	var bad: Dictionary = campaign.fresh()
	bad.collected["0"] = "invalid"
	check(not campaign.validate(bad),"Reject corrupt collection timer")
	bad = campaign.fresh()
	bad.settings.blood = "yes"
	check(not campaign.validate(bad),"Reject corrupt settings")
	var identities := {}
	for i in 256: identities[ClanCatalog.npc_identity(i).variant] = true
	check(identities.size() == 256,"256 deterministic villager appearances")
	check(ClanCatalog.data().weapons.size() == 200,"200 weapons")
	var art := root.get_node("Art")
	for weapon in ClanCatalog.data().weapons:
		var icon: AtlasTexture = art.weapon_icon(weapon)
		check(icon.region.size.x > 30 and icon.region.size.y > 30 and Rect2(Vector2.ZERO,icon.atlas.get_size()).encloses(icon.region),"Complete atlas bounds "+str(weapon.id))
	for i in 16:
		var t := ClanCatalog.territory(i)
		check(t.links.size() <= 4,"Every road has a unique cardinal exit")
		for id in t.links: check(i in ClanCatalog.territory(int(id)).links,"Reciprocal roads %d to %d" % [i,id])
	check(not campaign.conquer(15),"Cannot conquer disconnected territory")
	var gold: int = campaign.state.gold
	check(campaign.conquer(1),"Adjacent conquest")
	check(not campaign.conquer(1),"Cannot claim rewards twice")
	check(campaign.state.gold == gold+int(ClanCatalog.territory(1).gold),"Exact conquest reward")
	check(campaign.upgrade(1) and campaign.level(1) == 1,"Upgrade newly captured village")
	check(campaign.claim_welcome() and not campaign.claim_welcome(),"NPC quest reward once")
	campaign.state.clock = 240
	check(not campaign.collect(0).is_empty() and campaign.collect(0).is_empty(),"Production cooldown")
	check(not campaign.buy_weapon("unknown",0),"Reject invalid purchase")
	campaign.state.gold = 100000
	check(campaign.buy_weapon("axes-49",0) and campaign.state.equipped[0] == "axes-49","Equip cross-class weapon")
	var after: int = campaign.state.gold
	check(campaign.buy_weapon("axes-49",1) and campaign.state.gold == after,"Owned gear is free to reassign")
	# Isolated save path: never read or alter a player's actual campaign.
	campaign.save_path = "user://regression-campaign.json"
	campaign.test_mode = false
	check(campaign.save_game(),"Atomic initial save")
	campaign.state.gold = 4567
	check(campaign.save_game(),"Atomic replacement save")
	var file := FileAccess.open(campaign.save_path,FileAccess.WRITE)
	file.store_string("{broken")
	file.close()
	check(campaign.load_game() and campaign.state.gold == after,"Recover previous complete save from backup")
	check(campaign.save_game(),"Repair corrupt primary without replacing valid backup")
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(campaign.save_path+suffix): DirAccess.remove_absolute(campaign.save_path+suffix)
	campaign.test_mode = true
	campaign.save_path = campaign.SAVE_PATH
	campaign.state = campaign.fresh()
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	for i in 4: await process_frame
	check(game.world.citizens.size() == 32,"Starting village population")
	var count: int = game.world.building_count
	campaign.state.levels["0"] = 3
	game._enter_village(0)
	check(game.world.building_count > count and game.world.citizens.size() == 56,"Upgrade changes buildings and population")
	for i in 16:
		game._enter_village(i)
		check(game.world.walkable(game.world.player.position,13),"Safe spawn in village %d" % i)
		for portal in game.world.exits:
			check(game.world.walkable(portal.at,20),"Clear exit %d to %d" % [i,portal.id])
		await process_frame
	campaign.state = campaign.fresh()
	game._enter_village(0)
	game.show_pause()
	check(game.world.blocked and not campaign.clock_running,"Pause blocks world and economy timer")
	game.close_modal()
	check(not game.world.blocked and campaign.clock_running,"Resume world and economy")
	game.show_dialogue(game.world.citizens[0])
	check(game.modal_kind == "dialogue","Dialogue opens")
	game.close_modal()
	campaign.conquer(1)
	game._on_exit(1)
	check(game.transiting and not campaign.clock_running,"Boundary starts named loading transition")
	await create_timer(1.2).timeout
	check(game.current == 1 and not game.transiting and not game.world.blocked,"Boundary finishes into destination village")
	check(game.world.player.position.distance_to(game._arrival(1,0)) < 2,"Arrival uses connected road")
	campaign.state = campaign.fresh()
	game._enter_village(0)
	game.show_war_council(1)
	game.start_battle()
	game.world.set_physics_process(false)
	for i in 6: await process_frame
	game.world.charge = 0
	var stick: Control = game.hud.stick
	var strike: Control = game.hud.combat_row.get_child(0)
	var guard: Control = game.hud.combat_row.get_child(2)
	touch(3,stick.global_position+stick.size*0.5+Vector2(45,0),true)
	touch(4,strike.get_global_rect().get_center(),true)
	touch(5,guard.get_global_rect().get_center(),true)
	check(game.world.input_axis.x > 0.5 and game.world.held_strike and game.world.held_guard,"Three simultaneous combat touches")
	touch(4,strike.get_global_rect().get_center(),false)
	check(not game.world.held_strike and game.world.held_guard and game.world.input_axis.x > 0.5,"Release one finger preserves others")
	game.show_pause()
	check(game.world.input_axis == Vector2.ZERO and not game.world.held_guard and stick.finger == -1,"Pause clears held input")
	game.close_modal()
	var b: Node2D = game.world
	var enemy: Dictionary = b.units[b.initial_allies]
	b.player.hurt = 0
	b.player.block = false
	var hp: float = b.player.hp
	b.hit(enemy,b.player)
	var normal: float = hp-b.player.hp
	b.player.hp = hp
	b.player.hurt = 0
	b.player.block = true
	b.hit(enemy,b.player)
	check(hp-b.player.hp < normal*0.25,"Guard reduces damage")
	b.player.dodge = 0.4
	b.player.hurt = 0
	hp = b.player.hp
	b.hit(enemy,b.player)
	check(b.player.hp == hp,"Dodge grants invulnerability")
	b.player.dodge = 0
	b.player.hurt = 0
	b.player.stun = 0
	b.player.cool = 0
	b.player.attack = 0
	b.stamina = 100
	b.player.pos = enemy.pos+Vector2(0,25)
	hp = enemy.hp
	b.action("heavy")
	check(enemy.hp == hp and b.player.attack > 0,"Attack has a windup before impact")
	enemy["class"] = 1
	b.player.damage = enemy.max*2
	b.hit(b.player,enemy)
	check(enemy.hp == 0 and enemy.dead > 0 and b.kills == 1,"Lethal hit starts collapse and kill reward")
	# Winning callback and its close button must lead into the new village.
	game._battle_finished({"win":true,"kills":1,"seconds":90,"survivors":100})
	check(campaign.owns(1) and game.modal_kind == "result","Battle victory owns the territory")
	game._close_requested()
	await create_timer(1.2).timeout
	check(game.current == 1 and not game.in_battle,"Closing results enters conquered village")
	game.queue_free()
	await process_frame
	print("REGRESSION ",checks," checks; ",failures.size()," failures")
	root.get_node("Sound").stop_all()
	for i in 3: await process_frame
	quit(0 if failures.is_empty() else 1)
