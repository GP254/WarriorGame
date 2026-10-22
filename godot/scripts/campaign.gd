extends Node
signal changed
signal save_failed(message: String)
const Catalog = preload("res://scripts/catalog.gd")
const SAVE_PATH := "user://campaign.json"
var state: Dictionary
var test_mode := false
var autosave := 0.0
var clock_fraction := 0.0
var clock_running := false
var save_path := SAVE_PATH

func fresh() -> Dictionary:
	return {"version": 1, "societies": {}, "gold": 1500, "wood": 420, "iron": 180, "owned": [0], "levels": {"0": 1}, "current": 0, "position": [0.0, 170.0], "squads": [60,50,50,40], "equipped": ["swords-0","axes-0","spears-0","bows-0"], "inventory": ["swords-0","axes-0","spears-0","bows-0"], "armor": [1,0,1,0], "armor_owned": [0,1], "leader": 0, "clock": 0, "collected": {}, "quests": [], "wins": 0, "settings": {"blood": true, "sound": true, "shake": true, "quality": 1}}

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS
	test_mode = "--test" in OS.get_cmdline_user_args() or "--review" in OS.get_cmdline_user_args()
	state = fresh()
	if not test_mode: load_game()

func _process(delta: float) -> void:
	if get_tree().paused or not clock_running: return
	clock_fraction += delta
	if clock_fraction >= 1.0:
		state.clock += int(clock_fraction)
		clock_fraction -= floor(clock_fraction)
	autosave += delta
	if autosave > 30.0:
		autosave = 0.0
		save_game()

func owns(id: int) -> bool: return id in state.owned
func level(id: int) -> int: return int(state.levels.get(str(id), 0))
func can_attack(id: int) -> bool:
	if id < 0 or id >= 16 or owns(id): return false
	for neighbor in Catalog.territory(id).links:
		if owns(int(neighbor)): return true
	return false

func conquer(id: int) -> bool:
	if not can_attack(id): return false
	var location := Catalog.territory(id)
	state.owned.append(id)
	state.levels[str(id)] = 0
	state.gold += int(location.gold)
	state.wood += int(location.wood)
	state.iron += int(location.iron)
	state.wins += 1
	state.collected[str(id)] = state.clock
	commit()
	return true

func can_pay(cost: Dictionary) -> bool:
	for resource in ["gold", "wood", "iron"]:
		if state[resource] < cost.get(resource, 0): return false
	return true

func pay(cost: Dictionary) -> bool:
	if not can_pay(cost): return false
	for resource in ["gold", "wood", "iron"]: state[resource] -= int(cost.get(resource, 0))
	return true

func upgrade(id: int) -> bool:
	if not owns(id) or level(id) >= 3: return false
	if not pay(Catalog.upgrade_cost(level(id))): return false
	state.levels[str(id)] = level(id) + 1
	commit()
	return true

func production_ready(id: int) -> bool:
	return owns(id) and state.clock - int(state.collected.get(str(id), 0)) >= 120

func collect(id: int) -> Dictionary:
	if not production_ready(id): return {}
	var tier := level(id) + 1
	var location := Catalog.territory(id)
	var reward := {"gold": 35 * tier, "wood": (8 + int(location.wood) / 12) * tier, "iron": (4 + int(location.iron) / 15) * tier}
	var society: Dictionary = state.get("societies",{}).get(str(id),{})
	if not society.is_empty():
		reward.gold += int(society.stock.coffers)
		society.stock.coffers = 0
	for key in reward: state[key] += int(reward[key])
	state.collected[str(id)] = state.clock
	commit()
	return reward

func buy_weapon(id: String, squad: int) -> bool:
	if squad < 0 or squad > 3: return false
	var item := Catalog.weapon(id)
	if item.id != id: return false
	if id not in state.inventory:
		if not pay({"gold": int(item.cost)}): return false
		state.inventory.append(id)
	state.equipped[squad] = id
	commit()
	return true

func buy_armor(id: int, squad: int) -> bool:
	if id < 0 or id > 3 or squad < 0 or squad > 3: return false
	var item := Catalog.armor(id)
	if id not in state.armor_owned:
		if not pay({"gold": int(item.cost), "wood": int(item.wood), "iron": int(item.iron)}): return false
		state.armor_owned.append(id)
	state.armor[squad] = id
	commit()
	return true

func recruitment_quote(squad: int, requested: int = 10) -> Dictionary:
	if squad < 0 or squad > 3 or requested < 1 or requested > 25:
		return {"count":0,"gold":0,"can_hire":false,"reason":"Invalid recruitment choice"}
	var count := mini(requested,125-int(state.squads[squad]))
	var cost := count*9
	var reason := "Squad full" if count == 0 else "Need %d more gold" % maxi(0,cost-int(state.gold)) if state.gold < cost else "Ready to join your clan"
	return {"count":count,"gold":cost,"can_hire":count > 0 and state.gold >= cost,"reason":reason}

func recruit(squad: int, requested: int = 10) -> bool:
	var quote := recruitment_quote(squad,requested)
	if not quote.can_hire or not pay({"gold":quote.gold}): return false
	state.squads[squad] += int(quote.count)
	commit()
	return true

func claim_welcome() -> bool:
	if "welcome" in state.quests: return false
	state.quests.append("welcome")
	state.gold += 100
	state.wood += 40
	commit()
	return true

func commit() -> void:
	changed.emit()
	save_game()

func validate(value: Variant) -> bool:
	if not value is Dictionary or value.get("version") != 1: return false
	for key in ["gold", "wood", "iron", "clock", "wins", "current", "leader"]:
		if not value.get(key) is float and not value.get(key) is int: return false
		if not is_finite(float(value[key])) or value[key] < 0 or value[key] != floor(value[key]): return false
	if value.current >= 16 or value.leader > 3: return false
	for key in ["owned", "squads", "equipped", "inventory", "armor", "armor_owned", "quests", "position"]:
		if not value.get(key) is Array: return false
	if value.squads.size() != 4 or value.equipped.size() != 4 or value.armor.size() != 4: return false
	if 0 not in value.owned or value.current not in value.owned: return false
	for id in value.owned:
		if not (id is float or id is int) or id < 0 or id >= 16 or id != floor(id): return false
	for n in value.squads:
		if not (n is float or n is int) or n < 0 or n > 125 or n != floor(n): return false
	for id in value.inventory:
		if not id is String or Catalog.weapon(id).id != id: return false
	for id in value.equipped:
		if id not in value.inventory: return false
	for id in value.armor:
		if not (id is float or id is int) or id < 0 or id > 3 or id not in value.armor_owned: return false
	for key in ["levels", "collected", "settings"]:
		if not value.get(key) is Dictionary: return false
	for key in value.levels:
		var tier = value.levels[key]
		if not str(key).is_valid_int() or int(key) < 0 or int(key) > 15: return false
		if not (tier is float or tier is int) or tier < 0 or tier > 3 or tier != floor(tier): return false
	for id in value.armor_owned:
		if not (id is float or id is int) or id < 0 or id > 3 or id != floor(id): return false
	for key in value.collected:
		var tick = value.collected[key]
		if not str(key).is_valid_int() or int(key) not in value.owned: return false
		if not (tick is float or tick is int) or not is_finite(float(tick)) or tick < 0 or tick > value.clock or tick != floor(tick): return false
	for key in ["blood", "sound", "shake"]:
		if not value.settings.get(key) is bool: return false
	for quest in value.quests:
		if quest != "welcome": return false
	for id in value.owned:
		if value.owned.count(id) != 1 or not value.levels.has(str(int(id))): return false
	if value.position.size() != 2: return false
	for coord in value.position:
		if not (coord is float or coord is int) or not is_finite(float(coord)) or absf(float(coord)) > 1500: return false
	if not preload("res://scripts/society.gd").validate(value.get("societies",{})): return false
	return true

func load_game() -> bool:
	for path in [save_path, save_path + ".bak"]:
		if not FileAccess.file_exists(path): continue
		var parsed = _read_save(path)
		if validate(parsed):
			state = parsed
			return true
	return false

func save_game() -> bool:
	if test_mode: return true
	var file := FileAccess.open(save_path + ".tmp", FileAccess.WRITE)
	if file == null:
		save_failed.emit("Unable to save. Keep the game open and free some device storage.")
		return false
	file.store_string(JSON.stringify(state))
	file.flush()
	var error := file.get_error()
	file.close()
	if error != OK:
		save_failed.emit("Save could not be written. Your previous save is intact.")
		return false
	if FileAccess.file_exists(save_path) and validate(_read_save(save_path)):
		DirAccess.copy_absolute(save_path, save_path + ".bak")
	error = DirAccess.rename_absolute(save_path + ".tmp", save_path)
	if error != OK: save_failed.emit("Save could not be completed. Your previous save is intact.")
	return error == OK

func _read_save(path: String) -> Variant:
	var parser := JSON.new()
	if parser.parse(FileAccess.get_file_as_string(path)) != OK: return null
	return Catalog.normalize(parser.data)
