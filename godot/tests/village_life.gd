extends SceneTree
var checks := 0
var failures: Array[String] = []
var campaign: Node
var art: Node
var game: Node
func _initialize() -> void: call_deferred("run")
func check(value: bool, title: String) -> void:
	checks += 1
	if not value: failures.append(title); push_error(title)
func run() -> void:
	campaign = root.get_node("Campaign")
	art = root.get_node("Art")
	campaign.set_process(false)
	game = load("res://scenes/main.tscn").instantiate()
	root.add_child(game)
	await process_frame
	game.set_process(false)
	var village = game.world
	village.set_physics_process(false)
	village.player.set_physics_process(false)
	for npc in village.citizens: npc.set_physics_process(false)
	var society = village.society
	for i in 8:
		var axis := Vector2.from_angle(-PI/2+i*PI/4)
		check(art.direction(axis) == i,"Direction %d selects actual pose" % i)
		for kind in 4:
			var frame: AtlasTexture = art.walk(kind,i,3)
			check(Rect2(Vector2.ZERO,frame.atlas.get_size()).encloses(frame.region),"Warrior frame bounds")
		for body in 8:
			var frame: AtlasTexture = art.citizen_walk(body,i,3)
			check(Rect2(Vector2.ZERO,frame.atlas.get_size()).encloses(frame.region),"Civilian frame bounds")
	var needs := {"hunger":80.0,"energy":10.0,"social":10.0,"completed":0}
	check(society.priority(needs) == "eat","Hunger interrupts work and rest")
	society.state.stock.bread = 0
	check(society.priority(needs) == "forage","Empty bakery has food fallback")
	society.state.stock.bread = 36
	needs.hunger = 10
	check(society.priority(needs) == "rest","Exhausted villagers rest")
	needs.energy = 90
	check(society.priority(needs) == "social","Lonely villagers seek company")
	needs.social = 90
	check(society.priority(needs) == "work","Fed rested villagers work")
	society.state.time = 660
	check(society.priority(needs) == "rest","Night sends villagers home")
	society.state.time = 240
	var stock: Dictionary = society.state.stock
	stock.ore = 2; stock.wood = 1; stock.tools = 0
	society.produce(4,needs)
	check(stock.ore == 0 and stock.wood == 0 and stock.tools == 2,"Smith consumes ore and timber to make tools")
	check(society.produce(4,needs).begins_with("Waiting") and stock.tools == 2,"Smith stops without materials")
	stock.grain = 2; stock.bread = 0
	society.produce(5,needs)
	check(stock.grain == 0 and stock.bread == 6,"Baker consumes grain for food")
	stock.tools = 5; stock.coffers = 0
	society.produce(2,needs)
	check(stock.tools == 4 and stock.coffers == 8,"Trader sells surplus while reserving village tools")
	var before_gold: int = campaign.state.gold
	check(society.fund_meal() and stock.bread == 38 and campaign.state.gold == before_gold-60,"Player food support charges real gold")
	check(society.deliver_supplies() and stock.ore == 20,"Player forge support transfers materials")
	var targets: Array = village.worksites.duplicate()
	targets.append_array(village.homes)
	targets.append(village.material_depot)
	for target in targets:
		var route: PackedVector2Array = village.route(Vector2(0,170),target)
		check(not route.is_empty(),"Reachable village destination "+str(target))
		var safe := true
		for point in route:
			if not village.walkable(point,10): safe = false
		check(safe,"Routes avoid building footprints")
	# Exercise actual resident movement, arrival, production, and needs for three minutes.
	for step in 1800:
		society.advance(0.1)
		for npc in village.citizens: npc._physics_process(0.1)
	var produced := {}
	var stuck: Array = []
	for npc in village.citizens:
		if npc.needs.completed > 0: produced[int(npc.identity.body)] = true
		else: stuck.append({"job":npc.identity.job,"pos":str(npc.position),"dest":str(npc.destination),"activity":npc.activity,"path":npc.path.size()})
	for body in 8: check(produced.has(body),"Occupation reaches work and completes task: "+str(body))
	print("RESIDENTS ",JSON.stringify(stuck))
	check(campaign.validate(campaign.state),"Evolved society remains valid save data")
	var broken: Dictionary = campaign.state.duplicate(true)
	broken.societies["0"].stock.bread = -1
	check(not campaign.validate(broken),"Reject corrupt negative food stock")
	broken = campaign.state.duplicate(true)
	broken.societies["0"].residents.values()[0].energy = "bad"
	check(not campaign.validate(broken),"Reject malformed resident needs")
	var legacy: Dictionary = campaign.fresh()
	legacy.erase("societies")
	check(campaign.validate(legacy),"Existing campaigns migrate without losing progress")
	campaign.save_path = "user://society-regression.json"
	campaign.test_mode = false
	var expected: String = JSON.stringify(campaign.state.societies)
	check(campaign.save_game(),"Save society")
	campaign.state = campaign.fresh()
	check(campaign.load_game() and JSON.stringify(campaign.state.societies) == expected,"Reload exact stocks and resident needs")
	campaign.test_mode = true
	for suffix in ["",".bak",".tmp"]:
		if FileAccess.file_exists(campaign.save_path+suffix): DirAccess.remove_absolute(campaign.save_path+suffix)
	# Circular hit regions reject the corners of their bounding squares.
	var button = game.hud.context
	check(button.contains(button.global_position+button.size/2),"Circular button accepts center")
	check(not button.contains(button.global_position+Vector2(3,3)),"Circular button rejects square corners")
	var stick = game.hud.stick
	stick._update(stick.size/2+Vector2(stick.radius*0.56,0))
	check(absf(stick.output.length()-0.5)<0.01,"Analog magnitude continuously remaps dead zone")
	stick.reset()
	check(stick.output == Vector2.ZERO,"Analog returns to center")
	game.show_map()
	await process_frame
	var map = game.modal.find_child("RealmMap",true,false)
	check(map != null and map.size.x > 500 and map.size.y > 300,"Map keeps a large canvas on phone")
	map.change_zoom(2)
	check(map.zoom == 2,"Map zoom")
	var down := InputEventScreenTouch.new()
	down.index = 0; down.position = Vector2(200,200); down.pressed = true
	map._gui_input(down)
	down = down.duplicate(); down.index = 1; down.position = Vector2(300,200)
	map._gui_input(down)
	var drag := InputEventScreenDrag.new()
	drag.index = 1; drag.position = Vector2(340,200)
	map._gui_input(drag)
	check(map.zoom > 2 and map.dragged,"Two-finger pinch zooms without selecting")
	for i in 2:
		down = InputEventScreenTouch.new(); down.index = i; down.pressed = false; down.position = Vector2(200+i*140,200)
		map._gui_input(down)
	check(map.touches.is_empty(),"Map releases all pointers")
	print("VILLAGE LIFE ",checks," checks; ",failures.size()," failures")
	var report := FileAccess.open("res://artifacts/village-life.json",FileAccess.WRITE)
	report.store_string(JSON.stringify({"checks":checks,"failures":failures,"jobs_working":produced.keys(),"stocks":stock},"\t"))
	report.close()
	game.queue_free()
	await process_frame
	quit(0 if failures.is_empty() else 1)
