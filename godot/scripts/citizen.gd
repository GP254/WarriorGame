extends Node2D
var identity: Dictionary
var sprite: Sprite2D
var destination := Vector2.ZERO
var walk_time := 0.0
var wait_time := 0.0
var village: Node2D
var rng := RandomNumberGenerator.new()
var held := false
var needs: Dictionary
var resident_id := 0
var activity := ""
var status := "Finding my workplace"
var path := PackedVector2Array()
var facing := 4
var task_time := 0.0
var carrying := false
var last_priority := ""
var activity_label: Label

func setup(id: int, owner_village: Node2D) -> void:
	resident_id = id
	identity = ClanCatalog.npc_identity(id)
	village = owner_village
	needs = village.society.resident(id)
	rng.seed = id+91
	sprite = Sprite2D.new()
	sprite.texture = Art.citizen_walk(int(identity.body),facing,0)
	sprite.material = Art.palette(int(identity.palette))
	sprite.scale = Vector2.ONE*0.25
	sprite.position.y = -22
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	add_child(sprite)
	activity_label = Label.new()
	activity_label.position = Vector2(-95,-75)
	activity_label.size = Vector2(190,24)
	activity_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	activity_label.add_theme_font_size_override("font_size",12)
	activity_label.add_theme_color_override("font_color",Color("dfcf9f"))
	activity_label.add_theme_color_override("font_shadow_color",Color.BLACK)
	activity_label.add_theme_constant_override("shadow_offset_y",2)
	add_child(activity_label)
	wait_time = rng.randf_range(0.3,3)
	destination = position

func _physics_process(delta: float) -> void:
	if held or village.blocked: return
	village.society.decay(needs,delta)
	wait_time -= delta
	if wait_time > 0: return
	var priority: String = village.society.priority(needs)
	if activity.is_empty() or (priority != last_priority and priority != "work"):
		choose_task(priority)
	activity_label.visible = village.focused_resident == self
	activity_label.text = status
	if not path.is_empty():
		var offset := path[0]-position
		if offset.length() < 4:
			path.remove_at(0)
		else:
			var move := offset.normalized()*minf(offset.length(),delta*48)
			if village.walkable(position+move,9): position += move
			else:
				path = village.route(position,destination)
				if path.is_empty(): activity = ""
			facing = Art.direction(move)
			walk_time += delta*5
			sprite.texture = Art.citizen_walk(int(identity.body),facing,int(walk_time)%4)
			_fit_sprite(55)
		return
	if position.distance_to(destination) > 55:
		activity = ""
		return
	task_time += delta
	match activity:
		"eat":
			status = "Eating at the market"
			if task_time >= 4:
				if village.society.state.stock.bread > 0:
					village.society.state.stock.bread -= 1
					needs.hunger = maxf(0,needs.hunger-65)
				activity = ""
		"forage":
			status = "Foraging · the bakery is empty"
			if task_time >= 14:
				needs.hunger = maxf(0,needs.hunger-45)
				activity = ""
		"rest":
			status = "Resting at home"
			needs.energy = minf(100,needs.energy+delta*(1.5+village.tier*0.3))
			if needs.energy >= 85 and village.society.hour() >= 6 and village.society.hour() < 21: activity = ""
		"social":
			status = "Talking in the square"
			var companion := false
			for npc in village.citizens:
				if npc != self and npc.position.distance_squared_to(position) < 150*150: companion = true; break
			if companion: needs.social = minf(100,needs.social+delta*2)
			if task_time >= 16: activity = ""
		"pickup":
			status = "Collecting ore and timber"
			if task_time >= 6:
				carrying = true
				choose_task("work")
		"work":
			if task_time >= 16+rng.randf_range(0,4):
				status = village.society.produce(int(identity.body),needs)
				task_time = 0
				if int(identity.body) == 7:
					carrying = false
					activity = ""
	if activity in ["work","pickup","forage","social"]:
		sprite.texture = Art.work(6 if activity == "social" else int(identity.body),int(task_time*4)%4)
		_fit_sprite(55)
	else:
		sprite.texture = Art.citizen_walk(int(identity.body),facing,0)
		_fit_sprite(55)

func _fit_sprite(height: float) -> void:
	sprite.scale = Vector2.ONE*height/sprite.texture.get_height()

func choose_task(priority: String) -> void:
	last_priority = priority
	activity = priority
	task_time = 0
	var target: Vector2
	match activity:
		"eat": target = village.worksites[2]; status = "Going to eat"
		"forage": target = village.worksites[3]; status = "Looking for food"
		"rest": target = village.homes[resident_id % village.homes.size()]; status = "Going home to rest"
		"social": target = village.worksites[6]; status = "Meeting neighbours"
		_:
			target = village.worksites[int(identity.body)]
			status = village.society.TASKS[int(identity.body)]
			if int(identity.body) == 7 and not carrying:
				activity = "pickup"
				target = village.material_depot
				status = "Fetching ore and timber"
	var slot := (resident_id % 64) / 8
	var lane := Vector2((slot%4-1.5)*72,(slot/4)*85)
	destination = village.nearest_open(target+lane)
	path = village.route(position,destination)

func dialogue(_level: int) -> String:
	var text := status + "."
	if needs.hunger >= 65: text += " I'm hungry. We need bread at the market."
	elif needs.energy < 22: text += " I need some sleep before I can work again."
	elif needs.social < 22: text += " It has been a long day alone. I'll find someone in the square."
	else: text += " My household is managing well today."
	var messages := ["I grow grain for our baker. Better tools help the harvest.","The trader buys our spare cloth and puts the gold in the village coffer.","I sell spare tools and cloth. The village keeps four tools for its workers.","I gather herbs for the village stores.","Each pair of tools needs two ore and one timber. The couriers bring both.","Two sacks of grain make six loaves. Everyone eats from the same store.","People come to the square for company. A village needs more than work.","I collect supplies at the depot and carry them to the smithy."]
	return text+"\n\n"+messages[int(identity.body)]+"\n\nHunger %d%% · Energy %d%% · Company %d%%" % [needs.hunger,needs.energy,needs.social]
