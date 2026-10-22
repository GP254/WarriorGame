extends Node2D
signal exit_requested(id: int)
const Citizen = preload("res://scripts/citizen.gd")
const Player = preload("res://scripts/player.gd")
var territory_id := 0
var tier := 0
var player: CharacterBody2D
var sorted: Node2D
var citizens: Array[Node2D] = []
var solids: Array[Rect2] = []
var exits: Array[Dictionary] = []
var sites: Array[Dictionary] = []
var blocked := false
var border_cooldown := 3.0
var building_count := 0
var rng := RandomNumberGenerator.new()
var focused_resident: Node2D
var daylight: CanvasModulate
var society = preload("res://scripts/society.gd").new()
var navigation := AStarGrid2D.new()
var homes: Array[Vector2] = []
var worksites: Array[Vector2] = [Vector2(-650,700),Vector2(480,650),Vector2(-440,145),Vector2(-980,400),Vector2(450,145),Vector2(-650,400),Vector2(0,200),Vector2(540,170)]
const BARRACKS_DOOR := Vector2(-580,-625)
var material_depot := Vector2(1000,670)

func build(id: int, arrival: Vector2 = Vector2(0,170)) -> void:
	territory_id = id
	tier = Campaign.level(id)
	rng.seed = id * 8341 + 51
	daylight = CanvasModulate.new()
	add_child(daylight)
	var biome := int(ClanCatalog.territory(id).biome)
	var ground := preload("res://scripts/ground.gd").new()
	add_child(ground)
	ground.setup(biome,true)
	sorted = Node2D.new()
	sorted.y_sort_enabled = true
	add_child(sorted)
	# Districts share a readable crossroad, with their own seeded edge dressing.
	_building(4 if tier < 2 else 5,Vector2(0,-340),340,"Clan hall")
	_building(6 if tier < 2 else 7,Vector2(450,60),230,"Smithy")
	_building(8 if tier == 0 else (9 if tier < 3 else 10),Vector2(-440,40),250,"Market")
	sites = [{"kind":"settlement","name":"Clan hall","at":Vector2(0,-240)},{"kind":"armory","name":"Smithy","at":Vector2(450,145)},{"kind":"collect","name":"Market supplies","at":Vector2(-440,145)}]
	_building(0,Vector2(-580,-730),350,"Barracks","barracks")
	sites.append({"kind":"barracks","name":"Recruiting officer","at":BARRACKS_DOOR})
	var officer := Sprite2D.new()
	officer.texture = Art.walk(0,4,0)
	officer.scale = Vector2.ONE*64/officer.texture.get_height()
	officer.position = BARRACKS_DOOR-Vector2(0,25)
	sorted.add_child(officer)
	_label("HIRE WARRIORS",BARRACKS_DOOR+Vector2(0,30),220)
	for i in 4:
		var drill := preload("res://scripts/training_warrior.gd").new()
		drill.position = Vector2(-820+i*58,-640)
		drill.kind = i
		drill.village = self
		sorted.add_child(drill)
	var home_positions := [Vector2(-450,-360),Vector2(440,-360),Vector2(-800,70),Vector2(800,70),Vector2(-450,480),Vector2(440,480),Vector2(-850,-440),Vector2(850,-440)]
	for i in range(4 + tier):
		var at: Vector2 = home_positions[(i+id)%home_positions.size()]
		_building(tier,at,220)
		homes.append(at+Vector2(0,60))
	_building(8,Vector2(-650,320),180,"Bakery")
	_building(11,Vector2(480,570),180,"Weaver")
	_prop(6,material_depot-Vector2(0,50),90)
	_label("MATERIAL DEPOT",material_depot-Vector2(0,80),220)
	_label("HERB GARDEN",worksites[3]+Vector2(0,50),190)
	_label("GRAIN FIELDS",worksites[0]+Vector2(0,60),190)
	for row in 4:
		for column in 7:
			var grain := Sprite2D.new()
			grain.texture = Art.icon("grain")
			grain.position = worksites[0]+Vector2(column*35-100,row*32+100)
			grain.scale = Vector2.ONE*0.12
			sorted.add_child(grain)
	if tier >= 1: _building(14,Vector2(830,530),220,"Granary")
	if tier >= 2:
		_building(11,Vector2(-830,530),225)
		_prop(5,Vector2(0,60),100)
	else: _prop(4,Vector2(0,60),90)
	if tier >= 3:
		_building(13,Vector2(-220,-800),165)
		_building(13,Vector2(220,-800),165)
		_building(15,Vector2(850,830),180)
	_prop(12,Vector2(-145,-230),115)
	_prop(12,Vector2(145,-230),115)
	for i in range(10 + tier * 4):
		var at := Vector2(rng.randf_range(-1150,1150),rng.randf_range(-850,850))
		if absf(at.x) < 200 or absf(at.y) < 200 or not walkable(at,80): continue
		if Rect2(-930,-790,600,300).has_point(at): continue
		_prop([2,3,6,7,8,9,15][i % 7],at,65 + (i % 3) * 15)
	for i in 80:
		var at := Vector2(rng.randf_range(-1450,1450),rng.randf_range(-1030,1030))
		if absf(at.x) < 1080 and absf(at.y) < 780: continue
		if absf(at.x) < 160 or absf(at.y) < 150 or not walkable(at,75): continue
		_prop(1 if biome == 1 else i % 2,at,rng.randf_range(120,190),true)
	_build_exits()
	_build_navigation()
	society.setup(self)
	player = Player.new()
	player.position = arrival if walkable(arrival,15) else Vector2(0,170)
	sorted.add_child(player)
	for i in range(20 + tier * 12):
		var npc := Citizen.new()
		npc.position = road_point(rng)
		sorted.add_child(npc)
		npc.setup(id * 64 + i,self)
		citizens.append(npc)
	# A helpful resident begins close to the arrival point.
	citizens[0].position = Vector2(90,170)
	citizens[0].destination = citizens[0].position
	citizens[0].wait_time = 10

func _building(index: int, at: Vector2, width: float, title: String = "", texture_key: String = "") -> void:
	var anchor := Node2D.new()
	anchor.position = at
	sorted.add_child(anchor)
	var sprite := Sprite2D.new()
	sprite.texture = Art.texture(texture_key) if not texture_key.is_empty() else Art.cell("settlement-buildings",index % 4,index / 4,4,4)
	sprite.scale = Vector2.ONE * width / sprite.texture.get_width()
	sprite.position.y = -width * 0.34
	anchor.add_child(sprite)
	var rect := Rect2(at + Vector2(-width * 0.38,-width * 0.65),Vector2(width * 0.76,width * 0.65))
	_add_solid(rect)
	if not title.is_empty(): _label(title.to_upper(),at + Vector2(0,24),230)
	building_count += 1

func _prop(index: int, at: Vector2, width: float, solid: bool = false) -> void:
	var anchor := Node2D.new()
	anchor.position = at
	sorted.add_child(anchor)
	var sprite := Sprite2D.new()
	sprite.texture = Art.cell("settlement-props",index % 4,index / 4,4,4)
	sprite.scale = Vector2.ONE * width / sprite.texture.get_width()
	sprite.position.y = -width * 0.32
	anchor.add_child(sprite)
	if solid: _add_solid(Rect2(at - Vector2(10,10),Vector2(20,20)))

func _add_solid(rect: Rect2) -> void:
	solids.append(rect)
	var body := StaticBody2D.new()
	body.collision_layer = 1
	body.collision_mask = 0
	var collision := CollisionShape2D.new()
	var box := RectangleShape2D.new()
	box.size = rect.size
	collision.shape = box
	collision.position = rect.get_center()
	body.add_child(collision)
	add_child(body)

func _label(text: String, at: Vector2, width: float) -> void:
	var label := Label.new()
	label.text = text
	label.position = at - Vector2(width / 2,0)
	label.size.x = width
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.add_theme_font_size_override("font_size",15)
	label.add_theme_color_override("font_color",Color("dfd5b4"))
	label.add_theme_color_override("font_shadow_color",Color("111813"))
	label.add_theme_constant_override("shadow_offset_x",2)
	label.add_theme_constant_override("shadow_offset_y",2)
	sorted.add_child(label)

func _build_exits() -> void:
	const POSITIONS = [Vector2(1360,0),Vector2(-1360,0),Vector2(0,-970),Vector2(0,970)]
	var links: Array = ClanCatalog.territory(territory_id).links
	for i in links.size():
		var destination := int(links[i])
		var at: Vector2 = POSITIONS[i % 4]
		exits.append({"id":destination,"at":at})
		_prop(11,at + Vector2(75,0),100)
		_label("TO " + str(ClanCatalog.territory(destination).name).to_upper(),at + Vector2(0,-100),300)
		_label("SAFE ROAD" if Campaign.owns(destination) else "RIVAL TERRITORY",at + Vector2(0,-75),250)

func road_point(random: RandomNumberGenerator) -> Vector2:
	for attempt in 25:
		var at := Vector2(random.randf_range(-900,900),random.randf_range(-650,650))
		if random.randf() < 0.5: at.x = random.randf_range(-145,145)
		else: at.y = random.randf_range(90,230)
		if walkable(at,16): return at
	return Vector2(130,220)

func walkable(at: Vector2, radius: float = 10) -> bool:
	for rect in solids:
		if rect.grow(radius).has_point(at): return false
	return absf(at.x) < 1480 and absf(at.y) < 1080

func nearest_interaction() -> Dictionary:
	if player == null: return {}
	var best := 105.0
	var result: Dictionary = {}
	for site in sites:
		var distance: float = player.position.distance_to(site.at)
		if distance < best:
			best = distance
			result = site
	for npc in citizens:
		var distance: float = player.position.distance_to(npc.position)
		if distance < best:
			best = distance
			result = {"kind":"talk","name":str(npc.identity.name),"npc":npc}
	return result

func _physics_process(delta: float) -> void:
	if player == null: return
	player.blocked = blocked
	if blocked: return
	society.advance(delta)
	var sunlight := smoothstep(5,8,society.hour())*(1.0-smoothstep(18,22,society.hour()))
	daylight.color = Color("667c96").lerp(Color.WHITE,sunlight)
	border_cooldown -= delta
	Campaign.state.position = [player.position.x,player.position.y]
	if border_cooldown > 0: return
	for portal in exits:
		if player.position.distance_to(portal.at) < 95:
			border_cooldown = 5
			exit_requested.emit(int(portal.id))
			return

func _build_navigation() -> void:
	navigation.region = Rect2i(-36,-26,73,53)
	navigation.cell_size = Vector2(40,40)
	navigation.diagonal_mode = AStarGrid2D.DIAGONAL_MODE_ONLY_IF_NO_OBSTACLES
	navigation.default_compute_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	navigation.default_estimate_heuristic = AStarGrid2D.HEURISTIC_OCTILE
	navigation.update()
	for x in range(-36,37):
		for y in range(-26,27): navigation.set_point_solid(Vector2i(x,y),not walkable(Vector2(x,y)*40,27))

func nearest_open(at: Vector2) -> Vector2:
	var cell := Vector2i((at/40).round())
	for radius in range(0,12):
		for x in range(-radius,radius+1):
			for y in range(-radius,radius+1):
				var candidate := cell+Vector2i(x,y)
				if navigation.is_in_boundsv(candidate) and not navigation.is_point_solid(candidate): return Vector2(candidate)*40
	return Vector2(0,200)

func route(from: Vector2, to: Vector2) -> PackedVector2Array:
	var first := Vector2i((nearest_open(from)/40).round())
	var last := Vector2i((nearest_open(to)/40).round())
	return navigation.get_point_path(first,last)
