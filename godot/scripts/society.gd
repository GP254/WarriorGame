extends RefCounted
# Only the loaded village advances. No offline rewards or background population scans.
const GOODS := ["grain","bread","ore","wood","tools","cloth","herbs","coffers"]
const TASKS := ["Tending fields","Weaving cloth","Trading surplus","Gathering herbs","Forging tools","Baking bread","Sharing stories","Delivering materials"]
var state: Dictionary
var village: Node2D

func setup(owner_village: Node2D) -> void:
	village = owner_village
	if not Campaign.state.has("societies"): Campaign.state.societies = {}
	var key := str(village.territory_id)
	if not Campaign.state.societies.has(key):
		Campaign.state.societies[key] = {"time":240.0,"stock":{"grain":24,"bread":36,"ore":12,"wood":16,"tools":4,"cloth":0,"herbs":4,"coffers":0},"residents":{}}
	state = Campaign.state.societies[key]

func resident(id: int) -> Dictionary:
	var key := str(id)
	if not state.residents.has(key):
		state.residents[key] = {"hunger":float(12+posmod(id*17,38)),"energy":float(65+posmod(id*11,30)),"social":float(40+posmod(id*7,50)),"completed":0}
	return state.residents[key]

func hour() -> float: return fmod(float(state.time)/30.0,24.0)
func time_label() -> String:
	var h := hour()
	return "%02d:%02d" % [int(h),int(fmod(h,1.0)*60)]
func advance(delta: float) -> void: state.time = fmod(float(state.time)+delta,720.0)

func priority(needs: Dictionary) -> String:
	if needs.hunger >= 65: return "eat" if state.stock.bread > 0 else "forage"
	if needs.energy < 22 or hour() >= 21 or hour() < 6: return "rest"
	if needs.social < 22 or (hour() >= 18 and hour() < 21): return "social"
	return "work"

func decay(needs: Dictionary, delta: float) -> void:
	needs.hunger = minf(100,needs.hunger+delta*0.13)
	needs.energy = maxf(0,needs.energy-delta*0.065)
	needs.social = maxf(0,needs.social-delta*0.06)

func produce(body: int, needs: Dictionary) -> String:
	var stock: Dictionary = state.stock
	var yield_bonus := 1 if stock.tools > 0 and village.tier >= 2 else 0
	match body:
		0: stock.grain = mini(999,stock.grain+4+yield_bonus)
		1: stock.cloth = mini(999,stock.cloth+2+yield_bonus)
		2:
			if stock.tools > 4:
				stock.tools -= 1
				stock.coffers = mini(9999,stock.coffers+8)
			elif stock.cloth > 2:
				stock.cloth -= 2
				stock.coffers = mini(9999,stock.coffers+6)
			else: return "Waiting for surplus tools or cloth"
		3: stock.herbs = mini(999,stock.herbs+2)
		4:
			if stock.ore < 2 or stock.wood < 1: return "Waiting for ore and timber"
			stock.ore -= 2
			stock.wood -= 1
			stock.tools = mini(999,stock.tools+2)
		5:
			if stock.grain < 2: return "Waiting for grain from the fields"
			stock.grain -= 2
			stock.bread = mini(999,stock.bread+6)
		6:
			for npc in village.citizens:
				if npc.position.distance_to(village.worksites[6]) < 130: npc.needs.social = minf(100,npc.needs.social+12)
		7:
			stock.ore = mini(999,stock.ore+3)
			stock.wood = mini(999,stock.wood+3)
	needs.completed = mini(1000000,int(needs.completed)+1)
	return TASKS[body]

func deliver_supplies() -> bool:
	if not Campaign.pay({"wood":20,"iron":20}): return false
	state.stock.wood = mini(999,state.stock.wood+20)
	state.stock.ore = mini(999,state.stock.ore+20)
	Campaign.commit()
	return true

func fund_meal() -> bool:
	if not Campaign.pay({"gold":60}): return false
	state.stock.bread = mini(999,state.stock.bread+32)
	Campaign.commit()
	return true

func overview() -> String:
	var hungry := 0
	var tired := 0
	for npc in village.citizens:
		if npc.needs.hunger >= 65: hungry += 1
		if npc.needs.energy < 22: tired += 1
	return "%s · %d hungry · %d tired\n%d bread · %d grain · %d tools\n%d ore · %d timber · %d cloth · %d herbs\nTrade earnings ready: %d gold" % [time_label(),hungry,tired,state.stock.bread,state.stock.grain,state.stock.tools,state.stock.ore,state.stock.wood,state.stock.cloth,state.stock.herbs,state.stock.coffers]

static func validate(societies: Variant) -> bool:
	if not societies is Dictionary or societies.size() > 16: return false
	for key in societies:
		if not str(key).is_valid_int() or int(key) < 0 or int(key) > 15: return false
		var entry = societies[key]
		if not entry is Dictionary or not entry.get("stock") is Dictionary or not entry.get("residents") is Dictionary: return false
		if not number_between(entry.get("time"),0,720): return false
		for good in GOODS:
			if not number_between(entry.stock.get(good),0,9999): return false
			if entry.stock[good] != floor(entry.stock[good]): return false
		if entry.residents.size() > 64: return false
		for id in entry.residents:
			if not str(id).is_valid_int() or int(id) < int(key)*64 or int(id) >= (int(key)+1)*64: return false
			var needs = entry.residents[id]
			if not needs is Dictionary: return false
			for need in ["hunger","energy","social"]:
				if not number_between(needs.get(need),0,100): return false
			if not number_between(needs.get("completed"),0,1000000): return false
	return true

static func number_between(value: Variant, low: float, high: float) -> bool:
	return (value is int or value is float) and is_finite(float(value)) and value >= low and value <= high
