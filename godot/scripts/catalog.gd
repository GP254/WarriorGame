class_name ClanCatalog
extends RefCounted

static var _data: Dictionary = {}
static func data() -> Dictionary:
	if _data.is_empty():
		_data = normalize(JSON.parse_string(FileAccess.get_file_as_string("res://data/catalog.json")))
	return _data

static func territory(id: int) -> Dictionary:
	return data().territories[clampi(id, 0, 15)]

static func weapon(id: String) -> Dictionary:
	for item: Dictionary in data().weapons:
		if item.id == id: return item
	return data().weapons[0]

static func clan_class(id: int) -> Dictionary:
	return data().classes[clampi(id, 0, 3)]

static func armor(id: int) -> Dictionary:
	return data().armors[clampi(id, 0, 3)]

static func family_index(family: String) -> int:
	return maxi(0, ["swords", "axes", "spears", "bows"].find(family))

static func npc_identity(seed_id: int) -> Dictionary:
	const FIRST = ["Mara", "Orin", "Sella", "Bram", "Iven", "Tessa", "Edda", "Rowan", "Nessa", "Hale", "Fenn", "Lysa", "Oren", "Vera", "Alda", "Corin"]
	const LAST = ["Ashbrook", "Reed", "Stonewell", "Pine", "Thorn", "Vale", "Moss", "Briar", "Hollow", "Rook", "Flint", "Wren", "Alder", "Marsh", "Wood", "Fern"]
	const JOBS = ["Farmer", "Weaver", "Trader", "Herbalist", "Blacksmith", "Baker", "Elder", "Courier"]
	var variant := posmod(seed_id * 73 + 17, 256)
	return {"id": seed_id, "name": FIRST[posmod(seed_id * 7, 16)] + " " + LAST[posmod(seed_id / 16 + seed_id, 16)], "job": JOBS[variant % 8], "body": variant % 8, "palette": variant / 8, "variant": variant}

static func upgrade_cost(level: int) -> Dictionary:
	return [{"gold": 250, "wood": 70, "iron": 20}, {"gold": 500, "wood": 140, "iron": 55}, {"gold": 900, "wood": 240, "iron": 100}][clampi(level, 0, 2)]

# JSON stores every number as a float; IDs must keep a single type for Array.has/find.
static func normalize(value: Variant) -> Variant:
	if value is float and is_finite(value) and value == floor(value): return int(value)
	if value is Array:
		var result: Array = []
		for item in value: result.append(normalize(item))
		return result
	if value is Dictionary:
		var result: Dictionary = {}
		for key in value: result[key] = normalize(value[key])
		return result
	return value
