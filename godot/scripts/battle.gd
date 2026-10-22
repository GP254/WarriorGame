extends Node2D
signal finished(result: Dictionary)
const Catalog = preload("res://scripts/catalog.gd")
const CELL := 128.0
var territory_id := 1
var units: Array[Dictionary] = []
var grid: Dictionary = {}
var player: Dictionary
var camera: Camera2D
var input_axis := Vector2.ZERO
var held_strike := false
var held_guard := false
var elapsed := 0.0
var charge := 4.0
var stamina := 100.0
var blocked := false
var ended := false
var ending := 0.0
var kills := 0
var enemy_total := 180
var spawned := 0
var wave := 0
var wave_times := [0.0,35.0,70.0]
var particles: Array[Dictionary] = []
var arrows: Array[Dictionary] = []
var stains: Array[Dictionary] = []
var texts: Array[Dictionary] = []
var frames: Array = []
var draw_order: Array[Dictionary] = []
var frame_clock := 0.0
var horn_cooldown := 0.0
var formation := "line"
var rng := RandomNumberGenerator.new()
var initial_allies := 0
var trauma := 0.0

func build(id: int, deployment: Array, shape: String = "line", seed_value: int = 0) -> void:
	territory_id = id
	formation = shape
	if seed_value: rng.seed = seed_value
	else: rng.randomize()
	enemy_total = int(Catalog.territory(id).enemies)
	for kind in 4:
		var sheet_frames: Array = []
		for row in 8:
			for frame in 8: sheet_frames.append(Art.warrior(kind,row,frame))
		frames.append(sheet_frames)
	var ground := preload("res://scripts/ground.gd").new()
	add_child(ground)
	ground.setup(int(Catalog.territory(id).biome),false)
	if int(Catalog.territory(id).level) >= 2:
		for side in [-1,1]:
			var tower := Sprite2D.new()
			tower.texture = Art.cell("settlement-buildings",1,3,4,4)
			tower.scale = Vector2.ONE * 220.0/tower.texture.get_width()
			tower.position = Vector2(side*700,-800)
			tower.z_index = -1
			add_child(tower)
	var n := 0
	var total := 0
	for count in deployment: total += int(count)
	var columns := mini(32,maxi(12,int(sqrt(total * 3))))
	for kind in 4:
		for i in int(deployment[kind]):
			var at := Vector2((n % columns - (columns - 1) * 0.5) * 29,330 + (n / columns) * 27)
			if shape == "wedge":
				var row := int(sqrt(n))
				at = Vector2((n - row * row - row) * 27,330 + row * 24)
			elif shape == "shield": at = Vector2((i % 25 - 12) * 29,330 + (i / 25) * 28 + kind * 85)
			units.append(_unit(0,kind,at))
			n += 1
	player = _unit(0,int(Campaign.state.leader),Vector2(0,310),true)
	units.append(player)
	initial_allies = units.size()
	_spawn_wave()
	camera = Camera2D.new()
	camera.zoom = Vector2.ONE
	add_child(camera)
	_rebuild_grid()

func _unit(team: int, kind: int, at: Vector2, hero: bool = false) -> Dictionary:
	var difficulty := int(Catalog.territory(territory_id).level)
	var armor := Catalog.armor(mini(2,difficulty / 3) if team else int(Campaign.state.armor[kind]))
	var weapon := Catalog.weapon(str(Catalog.clan_class(kind).weapon) + "-" + str(mini(35,difficulty * 3)) if team else str(Campaign.state.equipped[kind]))
	var health := (float(Catalog.clan_class(kind).hp) + float(armor.hp)) * (6.0 if hero else 2.4 + difficulty * 0.08 if team else 2.6)
	return {"id":units.size(),"team":team,"kind":Catalog.family_index(str(weapon.family)),"class":kind,"pos":at,"hp":health,"max":health,"def":float(Catalog.clan_class(kind).def) + float(armor.def),"speed":float(Catalog.clan_class(kind).speed) * float(armor.speed),"damage":float(weapon.damage) * (2.8 if hero else 0.65 if team else 0.6),"range":float(weapon.range) * (1.2 if hero else 0.8),"rate":float(weapon.speed),"hero":hero,"cool":rng.randf_range(0,1),"attack":0.0,"duration":1.0,"heavy":false,"hit":false,"hurt":0.0,"dodge":0.0,"stun":0.0,"dead":0.0,"velocity":Vector2.ZERO,"phase":rng.randf_range(0,8),"facing":4 if team else 0,"moving":false,"block":false,"target":-1,"think":rng.randf_range(0,0.3)}

func _spawn_wave() -> void:
	var count := int(ceil(enemy_total * (0.45 if wave == 0 else 0.3)))
	if wave == 2: count = enemy_total - spawned
	for i in count:
		var kind := i % 3 if i < int(count * 0.78) else 3
		var unit := _unit(1,kind,Vector2((i % 28 - 13.5) * 30,-360 - (i / 28) * 30 - (100 if wave > 0 else 0)))
		units.append(unit)
	spawned += count
	wave += 1
	texts.append({"pos":player.pos + Vector2(0,-150),"text":"ENEMY REINFORCEMENTS" if wave > 1 else "RAISE YOUR BANNER","life":3.0})

func _rebuild_grid() -> void:
	grid.clear()
	for i in units.size():
		if units[i].hp <= 0: continue
		var cell := Vector2i(floori(units[i].pos.x / CELL),floori(units[i].pos.y / CELL))
		if not grid.has(cell): grid[cell] = []
		grid[cell].append(i)

func near(at: Vector2, radius: float) -> Array[int]:
	var output: Array[int] = []
	var low := Vector2i(floori((at.x-radius)/CELL),floori((at.y-radius)/CELL))
	var high := Vector2i(floori((at.x+radius)/CELL),floori((at.y+radius)/CELL))
	for x in range(low.x,high.x+1):
		for y in range(low.y,high.y+1):
			for index in grid.get(Vector2i(x,y),[]):
				if units[index].pos.distance_squared_to(at) <= radius * radius: output.append(index)
	return output

func action(kind: String) -> void:
	if blocked or ended or charge > 0 or player.hp <= 0: return
	if kind == "rally" and stamina >= 65 and horn_cooldown <= 0:
		stamina -= 65
		horn_cooldown = 14
		Sound.play("horn",-12)
		for i in near(player.pos,280):
			if units[i].team == 0: units[i].hp = minf(units[i].max,units[i].hp + 65)
		texts.append({"pos":player.pos,"text":"FOR THE CLAN","life":2.0})
		return
	if kind == "dodge" and stamina >= 24 and player.dodge <= 0:
		stamina -= 24
		player.dodge = 0.4
		player.velocity = (input_axis if input_axis.length() > 0.1 else Vector2.RIGHT).normalized() * 390
		return
	if kind in ["strike","heavy"] and player.cool <= 0 and player.attack <= 0 and player.stun <= 0:
		var cost := 27 if kind == "heavy" else 11
		if stamina < cost: return
		stamina -= cost
		_begin_attack(player,kind == "heavy")

func _begin_attack(unit: Dictionary, heavy: bool) -> void:
	if unit.hero: Sound.play("swing",-16)
	unit.duration = (1.05 if heavy else 0.72) / unit.rate
	unit.attack = unit.duration
	unit.cool = unit.duration + (0.12 if unit.hero else rng.randf_range(0.55,1.25))
	unit.hit = false
	unit.heavy = heavy

func hit(source: Dictionary, target: Dictionary, multiplier: float = 1.0) -> void:
	if target.hp <= 0 or target.dodge > 0 or (target.hero and target.hurt > 0): return
	var guard: bool = target.block if target.hero else (target["class"] == 0 and target.attack <= 0 and rng.randf() < 0.2)
	var damage := maxf(2.0,(source.damage * multiplier - target.def * 0.25) * (0.18 if guard else 1.0))
	target.hp = maxf(0,target.hp-damage)
	if target.pos.distance_to(player.pos) < 400: Sound.play("guard" if guard else "hit",-20 if not source.hero and not target.hero else -12)
	if source.hero or target.hero: trauma = minf(1.0,trauma + (0.25 if guard else 0.55))
	target.hurt = 0.4 if target.hero else 0.1
	target.stun = 0.06 if guard else 0.12
	target.velocity = (target.pos-source.pos).normalized() * (110 if multiplier > 1.3 else 35)
	if guard and target.hero: stamina = maxf(0,stamina-7)
	if bool(Campaign.state.settings.blood) and not guard:
		for i in 4: particles.append({"pos":target.pos,"velocity":Vector2(rng.randf_range(-70,70),rng.randf_range(-60,60)),"height":20.0,"up":rng.randf_range(30,75),"life":rng.randf_range(0.4,0.8)})
	if source.hero: texts.append({"pos":target.pos,"text":"GUARD" if guard else str(int(damage)),"life":0.65})
	if target.hp <= 0:
		target.dead = 0.001
		target.attack = 0.0
		if source.hero: kills += 1
		if bool(Campaign.state.settings.blood): stains.append({"pos":target.pos,"radius":rng.randf_range(7,15)})

func _fire(source: Dictionary, target: Dictionary) -> void:
	var duration := maxf(0.15,source.pos.distance_to(target.pos) / 520.0)
	arrows.append({"pos":source.pos,"velocity":(target.pos-source.pos)/duration,"target":target,"source":source,"time":0.0,"duration":duration,"height":20.0})

func _physics_process(delta: float) -> void:
	if blocked: return
	advance(delta)

func advance(delta: float) -> void:
	if ended:
		ending += delta
		for unit in units:
			if unit.hp <= 0: unit.dead += delta
		if ending >= 1.4 and ending < 10:
			ending = 100
			finished.emit({"win":player.hp > 0,"kills":kills,"seconds":int(elapsed),"survivors":counts().allies})
		queue_redraw()
		return
	elapsed += delta
	stamina = minf(100,stamina + delta * (4 if held_guard else 15))
	horn_cooldown = maxf(0,horn_cooldown-delta)
	if charge > 0:
		charge -= delta
		for unit in units:
			unit.pos.y += (65 if unit.team else -65) * delta
			unit.moving = true
			unit.phase += delta * 10
		_finish_frame(delta)
		return
	if wave < 3 and elapsed >= wave_times[wave]: _spawn_wave()
	_rebuild_grid()
	var alive_allies: Array[int] = []
	var alive_enemies: Array[int] = []
	for i in units.size():
		if units[i].hp > 0:
			if units[i].team: alive_enemies.append(i)
			else: alive_allies.append(i)
	if player.hp <= 0 or (spawned == enemy_total and alive_enemies.is_empty()):
		ended = true
		return
	for i in units.size():
		var u := units[i]
		u.cool -= delta
		u.hurt = maxf(0,u.hurt-delta)
		u.stun = maxf(0,u.stun-delta)
		u.dodge = maxf(0,u.dodge-delta)
		u.pos += u.velocity * delta
		u.velocity *= exp(-delta*8)
		u.moving = false
		if u.hp <= 0:
			u.dead += delta
			continue
		if u.hero:
			u.block = held_guard and stamina > 0 and u.attack <= 0
			var axis := input_axis + Vector2(float(Input.is_physical_key_pressed(KEY_D))-float(Input.is_physical_key_pressed(KEY_A)),float(Input.is_physical_key_pressed(KEY_S))-float(Input.is_physical_key_pressed(KEY_W)))
			if u.stun <= 0:
				u.pos += axis.limit_length() * 190 * delta * (0.4 if u.block else 0.55 if u.attack > 0 else 1.0)
				u.moving = axis.length() > 0.1
				if u.moving: u.facing = Art.direction(axis)
			if held_strike or Input.is_physical_key_pressed(KEY_J): action("strike")
		else:
			u.think -= delta
			if u.think <= 0 or u.target < 0 or units[u.target].hp <= 0:
				var candidates := near(u.pos,520 if u.kind == 3 else 190)
				var best := INF
				u.target = -1
				for candidate in candidates:
					if units[candidate].team == u.team or units[candidate].hp <= 0: continue
					var distance: float = u.pos.distance_squared_to(units[candidate].pos)
					if distance < best:
						best = distance
						u.target = candidate
				if u.target < 0:
					var opponents: Array[int] = alive_allies if u.team else alive_enemies
					var samples := mini(40,opponents.size())
					for sample in samples:
						var candidate: int = opponents[(sample*opponents.size()/samples+int(u.id)*7)%opponents.size()]
						var distance: float = u.pos.distance_squared_to(units[candidate].pos)
						if distance < best:
							best = distance
							u.target = candidate
				u.think = rng.randf_range(0.25,0.5)
			if u.target >= 0 and u.stun <= 0 and u.attack <= 0:
				var target := units[u.target]
				var offset: Vector2 = target.pos-u.pos
				u.facing = Art.direction(offset)
				var reach: float = 290.0 if u.kind == 3 else u.range * 0.7
				if offset.length() > reach:
					u.pos += offset.normalized() * u.speed * delta * 0.85
					u.moving = true
				elif u.cool <= 0: _begin_attack(u,rng.randf() < 0.18)
		if u.attack > 0:
			u.attack -= delta
			if 1.0-u.attack/u.duration >= 0.53 and not u.hit:
				u.hit = true
				var targets: Array[int] = []
				for candidate in near(u.pos,u.range * (1.15 if u.heavy else 1.0)):
					if units[candidate].team != u.team and units[candidate].hp > 0: targets.append(candidate)
				targets.sort_custom(func(a,b): return units[a].pos.distance_squared_to(u.pos) < units[b].pos.distance_squared_to(u.pos))
				if u.kind == 3:
					if not targets.is_empty(): _fire(u,units[targets[0]])
				else:
					for target_id in targets.slice(0,(6 if u.heavy else 3) if u.hero else (2 if u.heavy else 1)): hit(u,units[target_id],1.8 if u.heavy else 1.0)
		u.phase += delta * (10 if u.moving else 1)
		u.pos = u.pos.clamp(Vector2(-1400,-1000),Vector2(1400,1000))
	_rebuild_grid()
	_separate()
	for arrow in arrows:
		arrow.time += delta
		arrow.pos += arrow.velocity * delta
		arrow.height = 20 + sin(arrow.time/arrow.duration * PI) * 70
		if arrow.time >= arrow.duration and arrow.target.hp > 0 and arrow.pos.distance_to(arrow.target.pos) < 32: hit(arrow.source,arrow.target,0.8)
	arrows = arrows.filter(func(a): return a.time < a.duration)
	if int(Catalog.territory(territory_id).level) >= 2 and floori(elapsed/12) != floori((elapsed-delta)/12) and not alive_enemies.is_empty():
		for i in mini(10,alive_allies.size()):
			var archer: Dictionary = units[alive_enemies[0]].duplicate()
			archer.pos = Vector2(-700 if i%2 else 700,-800)
			archer.damage = 14
			_fire(archer,units[alive_allies[rng.randi_range(0,alive_allies.size()-1)]])
	_update_effects(delta)
	_finish_frame(delta)

func _update_effects(delta: float) -> void:
	for particle in particles:
		particle.life -= delta
		particle.pos += particle.velocity * delta
		particle.height += particle.up * delta
		particle.up -= 220 * delta
		if particle.height < 0: particle.height = 0
	particles = particles.filter(func(p): return p.life > 0)
	if particles.size() > 500: particles = particles.slice(particles.size()-500)
	for item in texts: item.life -= delta
	texts = texts.filter(func(t): return t.life > 0)

func _finish_frame(delta: float) -> void:
	trauma = maxf(0,trauma-delta*2.4)
	if is_instance_valid(camera):
		camera.position = camera.position.lerp(player.pos-Vector2(0,130),minf(1,delta*3))
		camera.offset = Vector2(sin(elapsed*71),cos(elapsed*63))*trauma*4 if Campaign.state.settings.shake else Vector2.ZERO
	frame_clock += delta
	if frame_clock > 0.08:
		draw_order = units.duplicate()
		draw_order.sort_custom(func(a,b): return (a.hp <= 0 and b.hp > 0) or ((a.hp > 0) == (b.hp > 0) and a.pos.y < b.pos.y))
		frame_clock = 0
	queue_redraw()

func counts() -> Dictionary:
	var allies := 0
	var enemies := 0
	for unit in units:
		if unit.hp > 0:
			if unit.team: enemies += 1
			else: allies += 1
	return {"allies":allies,"enemies":enemies,"reserve":enemy_total-spawned}

func _draw() -> void:
	if frames.is_empty(): return
	for stain in stains: draw_circle(stain.pos,stain.radius,Color(0.28,0.055,0.065,0.6))
	for u in draw_order:
		var row := 0
		var frame := int(u.phase) % 8 if u.moving else 0
		if u.hp <= 0:
			row = 3
			frame = mini(7,int(u.dead/1.1*8))
		elif u.attack > 0:
			row = 2 if u.heavy else 1
			frame = clampi(int((1-u.attack/u.duration)*8),0,7)
		var width := 65.0 if u.hero else 48.0
		var tint := Color(1,1,1,0.55) if u.dodge > 0 else Color.WHITE
		var sprite: Texture2D = frames[u.kind][(row + int(u.team)*4)*8 + frame]
		if row == 0:
			sprite = Art.walk(int(u.kind),int(u.facing),int(u.phase) % 4 if u.moving else 0)
			if u.team: tint *= Color(1.0,0.64,0.58)
		draw_texture_rect(sprite,Rect2(u.pos-Vector2(width*0.5,width*0.8),Vector2.ONE*width),false,tint)
		if u.hero and u.hp > 0:
			draw_arc(u.pos,21,0,TAU,24,Color("e0c581"),2)
			draw_string(ThemeDB.fallback_font,u.pos+Vector2(-16,-65),"YOU",HORIZONTAL_ALIGNMENT_LEFT,-1,13,Color("f6d797"))
		if u.block: draw_arc(u.pos-Vector2(0,20),23,PI,TAU,14,Color("aacbc2"),2)
	for arrow in arrows:
		var at: Vector2 = arrow.pos-Vector2(0,arrow.height)
		draw_line(at-arrow.velocity.normalized()*13,at,Color("d7c99d"),1.5)
	for particle in particles: draw_rect(Rect2(particle.pos-Vector2(0,particle.height),Vector2(3,3)),Color("a43b31"))
	for item in texts: draw_string(ThemeDB.fallback_font,item.pos-Vector2(12,65+(1-item.life)*12),item.text,HORIZONTAL_ALIGNMENT_LEFT,-1,14,Color("ecd8a2"))

func _separate() -> void:
	# Small collision buckets avoid scanning the much wider combat-target grid per soldier.
	var cells := {}
	for i in units.size():
		if units[i].hp <= 0: continue
		var at: Vector2 = units[i].pos
		var cell := Vector2i(floori(at.x/32),floori(at.y/32))
		if not cells.has(cell): cells[cell] = []
		cells[cell].append(i)
	const OFFSETS = [Vector2i(0,0),Vector2i(1,0),Vector2i(0,1),Vector2i(1,1),Vector2i(-1,1)]
	for cell in cells:
		for offset: Vector2i in OFFSETS:
			var other: Vector2i = cell+offset
			if not cells.has(other): continue
			for i in cells[cell]:
				for j in cells[other]:
					if offset == Vector2i.ZERO and j <= i: continue
					var a: Dictionary = units[i]
					var b: Dictionary = units[j]
					var gap: Vector2 = b.pos-a.pos
					var squared := gap.length_squared()
					if squared > 0.0001 and squared < 441:
						var distance := sqrt(squared)
						var push := gap/distance*(21-distance)*0.47
						a.pos -= push
						b.pos += push
