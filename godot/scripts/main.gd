extends Node
const HUD = preload("res://scripts/hud.gd")
const Village = preload("res://scripts/village.gd")
const Battle = preload("res://scripts/battle.gd")
const MapView = preload("res://scripts/campaign_map.gd")
var world: Node2D
var hud: CanvasLayer
var modal: Control
var modal_kind := ""
var transition: Control
var title: Control
var transiting := false
var in_battle := false
var current := 0
var selected := 1
var squad := 0
var recruit_batch := 10
var family := 0
var page := 0
var deployment: Array = []
var formation := "line"
var refresh_timer := 0.0
var ui_clicks := 0
var last_result: Dictionary = {}

func _ready() -> void:
	hud = HUD.new()
	add_child(hud)
	hud.requested.connect(_request)
	hud.combat_pressed.connect(_combat)
	hud.direction_changed.connect(_move)
	Campaign.save_failed.connect(_toast)
	get_viewport().size_changed.connect(func(): _fit_modal.call_deferred())
	Campaign.changed.connect(func(): refresh_timer = 1)
	if "--review" in OS.get_cmdline_user_args() or "--test" in OS.get_cmdline_user_args():
		_enter_village(0,Vector2(0,170))
	else: _title_screen()
	if OS.is_debug_build() and "--device-review" in OS.get_cmdline_user_args():
		add_child(load("res://tools/device_review.gd").new())

func _process(delta: float) -> void:
	if world == null: return
	refresh_timer += delta
	if refresh_timer < 0.16: return
	refresh_timer = 0
	if in_battle: hud.refresh_battle(world)
	else:
		var interaction: Dictionary = world.nearest_interaction()
		world.focused_resident = interaction.get("npc")
		hud.refresh_world(current,interaction)
		hud.subtitle.text += " · " + world.society.time_label()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT and is_instance_valid(hud) and world != null:
		Campaign.save_game()
		if not transiting and modal == null and not Campaign.test_mode: show_pause()
	if what == NOTIFICATION_WM_CLOSE_REQUEST:
		Campaign.save_game()

func _unhandled_key_input(event: InputEvent) -> void:
	if not event is InputEventKey or not event.pressed or event.echo: return
	if event.physical_keycode == KEY_ESCAPE:
		if modal != null: _close_requested()
		elif world != null: show_pause()
	elif modal == null and not transiting:
		if event.physical_keycode == KEY_E:
			if in_battle: world.action("rally")
			else: interact()
		if in_battle:
			if event.physical_keycode == KEY_K: world.action("heavy")
			if event.physical_keycode == KEY_SPACE: world.action("dodge")

func _input(event: InputEvent) -> void:
	if not in_battle or world == null or modal != null: return
	if event is InputEventKey and event.physical_keycode in [KEY_L,KEY_SHIFT]: world.held_guard = event.pressed

func _move(value: Vector2) -> void:
	if world == null: return
	if in_battle: world.input_axis = value
	elif is_instance_valid(world.player): world.player.move_input = value

func _combat(action: String, down: bool) -> void:
	if not in_battle or world == null: return
	if action == "strike": world.held_strike = down
	if action == "guard": world.held_guard = down
	if down: world.action(action)

func _request(action: String) -> void:
	if transiting: return
	match action:
		"map": show_map()
		"clan": show_clan()
		"settlement": show_settlement()
		"pause": show_pause()
		"interact": interact()

func _set_blocked(value: bool) -> void:
	Campaign.clock_running = not value and world != null
	hud.suspend(value)
	if world != null:
		world.blocked = value
		if in_battle:
			world.held_strike = false
			world.held_guard = false
			world.input_axis = Vector2.ZERO
		else:
			world.player.blocked = value
			world.player.move_input = Vector2.ZERO

func _close_requested() -> void:
	if modal_kind == "result": travel_to(selected if last_result.get("win",false) else current)
	else: close_modal()

func _fit_modal() -> void:
	if not is_instance_valid(modal): return
	var box := modal.get_node_or_null("DialogPanel") as Control
	if box == null: return
	box.offset_left = maxf(30,hud.safe.position.x+20)
	box.offset_right = -maxf(30,hud.root.size.x-hud.safe.position.x-hud.safe.size.x+20)
	box.offset_top = maxf(24,hud.safe.position.y+12)
	box.offset_bottom = -maxf(24,hud.root.size.y-hud.safe.position.y-hud.safe.size.y+12)

func close_modal() -> void:
	if modal != null:
		modal.get_parent().remove_child(modal)
		modal.queue_free()
		modal = null
	modal_kind = ""
	if world != null and not in_battle:
		for npc in world.citizens: npc.held = false
	_set_blocked(transiting)

func _panel(heading: String, subheading: String = "") -> VBoxContainer:
	close_modal()
	_set_blocked(true)
	modal = ColorRect.new()
	modal.color = Color(0.015,0.025,0.02,0.88)
	modal.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.root.add_child(modal)
	var box := PanelContainer.new()
	box.name = "DialogPanel"
	box.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	box.offset_left = 60
	box.offset_right = -60
	box.offset_top = 30
	box.offset_bottom = -30
	modal.add_child(box)
	_fit_modal()
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",12)
	box.add_child(column)
	var header := HBoxContainer.new()
	column.add_child(header)
	var titles := VBoxContainer.new()
	titles.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(titles)
	titles.add_child(HUD.label(heading,30,Color("e5d2a3")))
	if not subheading.is_empty(): titles.add_child(HUD.label(subheading,17,Color("9cad92")))
	header.add_child(HUD.circle_button("×","",_close_requested,88))
	var scroll := ScrollContainer.new()
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	column.add_child(scroll)
	var body := VBoxContainer.new()
	body.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	body.add_theme_constant_override("separation",14)
	scroll.add_child(body)
	return body

func _text(parent: Node, text: String, font_size: int = 20) -> Label:
	var label := HUD.label(text,font_size)
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	parent.add_child(label)
	return label

func _picture(texture: Texture2D, size: Vector2) -> TextureRect:
	var picture := TextureRect.new()
	picture.texture = texture
	picture.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	picture.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	picture.custom_minimum_size = size
	picture.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	return picture

func _title_screen() -> void:
	hud.safe.hide()
	title = Control.new()
	title.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.root.add_child(title)
	var art := TextureRect.new()
	art.texture = Art.texture("realm-map-v2")
	art.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	art.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_COVERED
	art.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	art.modulate = Color(0.35,0.4,0.34)
	title.add_child(art)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	title.add_child(center)
	var column := VBoxContainer.new()
	column.add_theme_constant_override("separation",24)
	center.add_child(column)
	var name_label := HUD.label("ASHEN BANNER",64,Color("ead3a2"))
	name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	column.add_child(name_label)
	_text(column,"Lead your clan. Build a home. Claim the frontier.",23).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var button := HUD.make_button("ENTER " + str(ClanCatalog.territory(int(Campaign.state.current)).name).to_upper(),func():
		title.queue_free()
		title = null
		hud.safe.show()
		var at := Vector2(float(Campaign.state.position[0]),float(Campaign.state.position[1]))
		travel_to(int(Campaign.state.current),at)
	)
	button.custom_minimum_size.y = 88
	column.add_child(button)
	_text(column,"LANDSCAPE · SINGLE PLAYER · OFFLINE",16).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER

func _clear_world() -> void:
	if world != null:
		remove_child(world)
		world.queue_free()
		world = null

func _enter_village(id: int, arrival: Vector2 = Vector2(0,170)) -> void:
	_clear_world()
	in_battle = false
	current = id
	Campaign.state.current = id
	Campaign.state.position = [arrival.x,arrival.y]
	world = Village.new()
	add_child(world)
	world.build(id,arrival)
	world.exit_requested.connect(_on_exit)
	hud.safe.show()
	hud.set_mode(true)
	refresh_timer = 1
	_set_blocked(transiting)

func _arrival(id: int, from: int) -> Vector2:
	var links: Array = ClanCatalog.territory(id).links
	var index := links.find(from)
	if index < 0: return Vector2(0,170)
	return [Vector2(1150,0),Vector2(-1150,0),Vector2(0,-760),Vector2(0,760)][index % 4]

func travel_to(id: int, arrival: Vector2 = Vector2(0,170)) -> void:
	if transiting or not Campaign.owns(id): return
	transiting = true
	close_modal()
	_set_blocked(true)
	transition = ColorRect.new()
	transition.color = Color("0b130e")
	transition.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	hud.root.add_child(transition)
	var center := CenterContainer.new()
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	transition.add_child(center)
	var column := VBoxContainer.new()
	column.custom_minimum_size.x = 600
	column.add_theme_constant_override("separation",24)
	center.add_child(column)
	_text(column,"THE ROAD AHEAD",18).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text(column,str(ClanCatalog.territory(id).name),50).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text(column,str(ClanCatalog.territory(id).desc),20).horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var progress := ProgressBar.new()
	progress.show_percentage = false
	progress.custom_minimum_size.y = 5
	column.add_child(progress)
	create_tween().tween_property(progress,"value",65.0,0.3)
	await get_tree().create_timer(0.35).timeout
	_enter_village(id,arrival)
	world.blocked = true
	progress.value = 100
	await get_tree().create_timer(0.45).timeout
	transition.queue_free()
	transition = null
	transiting = false
	_set_blocked(false)
	Campaign.commit()

func _on_exit(id: int) -> void:
	selected = id
	if Campaign.owns(id): travel_to(id,_arrival(id,current))
	else: show_war_council(id)

func interact() -> void:
	if world == null or in_battle: return
	var target: Dictionary = world.nearest_interaction()
	if target.is_empty(): return
	match str(target.kind):
		"talk": show_dialogue(target.npc)
		"armory": show_armory()
		"barracks": show_barracks()
		"settlement": show_settlement()
		"collect":
			var reward := Campaign.collect(current)
			if reward.is_empty(): _toast("Supplies are still being gathered. Return to the market in a little while.")
			else: _toast("Collected %d gold, %d timber and %d iron." % [reward.gold,reward.wood,reward.iron])

func show_dialogue(npc: Node2D) -> void:
	var body := _panel(str(npc.identity.name),str(npc.identity.job) + " · " + str(ClanCatalog.territory(current).name))
	modal_kind = "dialogue"
	npc.held = true
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",30)
	body.add_child(row)
	var portrait := _picture(Art.cell("villagers-a-v2" if int(npc.identity.body) < 4 else "villagers-b",0,(int(npc.identity.body)%4)*2+1),Vector2(160,200))
	portrait.material = Art.palette(int(npc.identity.palette))
	row.add_child(portrait)
	_text(row,npc.dialogue(Campaign.level(current)),24)
	if "welcome" not in Campaign.state.quests:
		_text(body,"Your people have gathered a small contribution for the clan.")
		body.add_child(HUD.make_button("ACCEPT SUPPLIES · 100 GOLD + 40 TIMBER",func():
			Campaign.claim_welcome()
			show_dialogue(npc)
		))
	body.add_child(HUD.make_button("HOW CAN I HELP THIS VILLAGE?",show_settlement))
	body.add_child(HUD.make_button("FAREWELL",close_modal))

func show_settlement() -> void:
	if in_battle: return
	var tier := Campaign.level(current)
	var body := _panel(str(ClanCatalog.territory(current).name),"SETTLEMENT · " + ["Scarred outpost","Restored village","Growing township","Flourishing stronghold"][tier])
	modal_kind = "settlement"
	var row := HBoxContainer.new()
	body.add_child(row)
	row.add_child(_picture(Art.cell("settlement-buildings",tier,0,4,4),Vector2(260,220)))
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(detail)
	_text(detail,"%d residents · %d buildings" % [world.citizens.size(),world.building_count],25)
	_text(detail,["Repair the damaged homes and reopen the market.","Expand workshops, improve homes, and welcome more families.","Build stone towers and turn the settlement into a thriving stronghold.","Your people have built a place they are proud to call home."][tier])
	if tier < 3:
		var cost := ClanCatalog.upgrade_cost(tier)
		_text(detail,"COST · %d gold · %d timber · %d iron" % [cost.gold,cost.wood,cost.iron])
		var upgrade := HUD.make_button("BUILD THE NEXT STAGE",func():
			if Campaign.upgrade(current):
				var at: Vector2 = world.player.position
				close_modal()
				_enter_village(current,at)
				_toast("The settlement has grown. New homes and residents are ready to explore.")
		)
		upgrade.disabled = not Campaign.can_pay(cost)
		detail.add_child(upgrade)
	var supplies := HUD.make_button("COLLECT VILLAGE SUPPLIES",func():
		var reward := Campaign.collect(current)
		if not reward.is_empty(): show_settlement()
	)
	supplies.disabled = not Campaign.production_ready(current)
	body.add_child(supplies)
	body.add_child(HUD.make_button("BARRACKS · HIRE WARRIORS",show_barracks))
	_text(body,"Barracks: northwest of the clan hall. Speak to the recruiting officer beside the training yard.",18)
	_text(body,"VILLAGE LIFE",25)
	_text(body,world.society.overview(),21)
	var support := HBoxContainer.new()
	body.add_child(support)
	var materials := HUD.make_button("SUPPLY FORGE · 20 WOOD + 20 IRON",func():
		if world.society.deliver_supplies(): show_settlement()
	)
	materials.disabled = not Campaign.can_pay({"wood":20,"iron":20})
	support.add_child(materials)
	var meal := HUD.make_button("STOCK FOOD · 60 GOLD",func():
		if world.society.fund_meal(): show_settlement()
	)
	meal.disabled = not Campaign.can_pay({"gold":60})
	support.add_child(meal)
	_text(body,"Farmers grow grain → bakers make bread. Couriers bring ore and timber → smiths forge tools. Traders sell surplus tools and cloth. Hungry people eat, tired people go home, and neighbours meet in the square. Only this village advances while you explore.",18)
	for npc in world.citizens:
		_text(body,str(npc.identity.job)+" · "+str(npc.identity.name)+" — "+npc.status,17)


func show_clan() -> void:
	var body := _panel("Your clan","Equip a squad, recruit warriors, and choose the class you lead.")
	modal_kind = "clan"
	var tabs := HBoxContainer.new()
	body.add_child(tabs)
	for i in 4:
		var button := HUD.make_button(str(ClanCatalog.clan_class(i).name),func(): squad = i; show_clan())
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(button)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",28)
	body.add_child(row)
	row.add_child(_picture(Art.warrior(squad,4,0),Vector2(210,240)))
	var detail := VBoxContainer.new()
	detail.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(detail)
	var c := ClanCatalog.clan_class(squad)
	var weapon := ClanCatalog.weapon(str(Campaign.state.equipped[squad]))
	var armor := ClanCatalog.armor(int(Campaign.state.armor[squad]))
	_text(detail,str(c.name) + " · " + str(c.role),28)
	_text(detail,str(c.desc))
	_text(detail,"%d warriors / 125 · %s\n%s · +%d armor" % [Campaign.state.squads[squad],weapon.name,armor.name,armor.def])
	var lead := HUD.make_button("YOU LEAD THIS CLASS" if Campaign.state.leader == squad else "LEAD AS THIS CLASS",func():
		Campaign.state.leader = squad
		Campaign.commit()
		world.player.kind = ClanCatalog.family_index(str(weapon.family))
		show_clan()
	)
	lead.disabled = Campaign.state.leader == squad
	detail.add_child(lead)
	var actions := HBoxContainer.new()
	body.add_child(actions)
	for spec in [["EQUIP WEAPON",show_armory],["EQUIP ARMOR",show_armor],["BARRACKS · HIRE WARRIORS",show_barracks]]:
		var button := HUD.make_button(spec[0],spec[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)
	_text(body,"Outfitting applies to the whole squad. Fallen warriors regroup after a battle. Your complete warband can grow to 500 troops.",18)

func show_barracks() -> void:
	if in_battle: return
	var total := 0
	for count in Campaign.state.squads: total += int(count)
	var body := _panel("The barracks","%d GOLD  ·  %d / 500 WARRIORS  ·  9 gold per recruit" % [Campaign.state.gold,total])
	modal_kind = "barracks"
	var order := HBoxContainer.new()
	order.add_theme_constant_override("separation",12)
	body.add_child(order)
	var label := HUD.label("RECRUITS PER SQUAD",18)
	label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	order.add_child(label)
	for amount in [1,5,10,25]:
		var button := HUD.make_button(str(amount)+("  ✓" if amount == recruit_batch else ""),func(): recruit_batch = amount; show_barracks())
		button.custom_minimum_size = Vector2(92,68)
		order.add_child(button)
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation",14)
	body.add_child(row)
	for i in 4:
		var c := ClanCatalog.clan_class(i)
		var panel := PanelContainer.new()
		panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		row.add_child(panel)
		var card := VBoxContainer.new()
		card.add_theme_constant_override("separation",10)
		panel.add_child(card)
		card.add_child(_picture(Art.walk(i,4,0),Vector2(120,115)))
		_text(card,str(c.name),24)
		_text(card,str(c.role),17)
		_text(card,"%d HP · %d DEF · %d SPD" % [c.hp,c.def,c.speed],16)
		_text(card,"%d / 125 in your clan" % Campaign.state.squads[i],18)
		var quote := Campaign.recruitment_quote(i,recruit_batch)
		var hire := HUD.make_button("HIRE %d · %d GOLD" % [quote.count,quote.gold] if quote.count > 0 else "SQUAD FULL",func():
			var fresh_quote := Campaign.recruitment_quote(i,recruit_batch)
			if Campaign.recruit(i,recruit_batch):
				show_barracks()
				_toast("%d %s warriors joined your clan." % [fresh_quote.count,c.name])
			else:
				show_barracks()
				_toast(str(fresh_quote.reason))
		)
		hire.name = "HireSquad%d" % i
		hire.disabled = not quote.can_hire
		hire.add_theme_font_size_override("font_size",17)
		card.add_child(hire)
		_text(card,str(quote.reason),15)
	_text(body,"Recruits join immediately and use their squad’s equipped weapons and armor. Your villagers keep their jobs. Choose deployment numbers at the war council.",18)
	var actions := HBoxContainer.new()
	body.add_child(actions)
	for spec in [["MANAGE EQUIPMENT",show_clan],["RETURN TO VILLAGE",close_modal]]:
		var button := HUD.make_button(spec[0],spec[1])
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		actions.add_child(button)

func show_armory() -> void:
	var body := _panel("The armory","50 weapons per family · Equipment for " + str(ClanCatalog.clan_class(squad).name))
	modal_kind = "armory"
	var tabs := HBoxContainer.new()
	body.add_child(tabs)
	for i in 4:
		var button := HUD.make_button(["SWORDS","AXES","SPEARS","BOWS"][i],func(): family = i; page = 0; show_armory())
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		tabs.add_child(button)
	var grid := GridContainer.new()
	grid.columns = 5
	grid.add_theme_constant_override("h_separation",10)
	grid.add_theme_constant_override("v_separation",10)
	body.add_child(grid)
	for i in range(page*10,mini(50,page*10+10)):
		var item: Dictionary = ClanCatalog.data().weapons[family*50+i]
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		card.add_child(_picture(Art.weapon_icon(item),Vector2(140,100)))
		_text(card,str(item.name),17)
		_text(card,"%d damage · %.2f speed" % [item.damage,item.speed],15)
		var owned: bool = item.id in Campaign.state.inventory
		var button := HUD.make_button("EQUIP" if owned else "%d GOLD" % int(item.cost),func():
			if Campaign.buy_weapon(str(item.id),squad):
				if Campaign.state.leader == squad: world.player.kind = ClanCatalog.family_index(str(item.family))
				show_armory()
		)
		button.disabled = (not owned and Campaign.state.gold < item.cost) or Campaign.state.equipped[squad] == item.id
		if Campaign.state.equipped[squad] == item.id: button.text = "EQUIPPED"
		card.add_child(button)
	var pages := HBoxContainer.new()
	body.add_child(pages)
	for i in 5:
		pages.add_child(HUD.make_button(str(i+1),func(): page = i; show_armory()))

func show_armor() -> void:
	var body := _panel("Armor for " + str(ClanCatalog.clan_class(squad).name),"Protection trades movement speed for health and defense.")
	modal_kind = "armor"
	var grid := GridContainer.new()
	grid.columns = 4
	body.add_child(grid)
	for i in 4:
		var item := ClanCatalog.armor(i)
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		grid.add_child(card)
		card.add_child(_picture(Art.warrior(i,4,0),Vector2(190,160)))
		_text(card,str(item.name),23)
		_text(card,"+%d health · +%d defense\n%d%% mobility" % [item.hp,item.def,int(float(item.speed)*100)],18)
		var owned: bool = i in Campaign.state.armor_owned
		_text(card,"OWNED" if owned else "%d gold · %d iron · %d wood" % [item.cost,item.iron,item.wood],16)
		var button := HUD.make_button("EQUIP" if owned else "BUY & EQUIP",func(): Campaign.buy_armor(i,squad); show_armor())
		button.disabled = Campaign.state.armor[squad] == i or (not owned and not Campaign.can_pay({"gold":item.cost,"wood":item.wood,"iron":item.iron}))
		if Campaign.state.armor[squad] == i: button.text = "EQUIPPED"
		card.add_child(button)

func show_map() -> void:
	var body := _panel("The Shattered Frontier","YOUR CLAN  ·  teal      CONQUERABLE  ·  gold      DISTANT  ·  grey")
	modal_kind = "map"
	var scroll := body.get_parent()
	var column := scroll.get_parent()
	scroll.remove_child(body)
	column.remove_child(scroll)
	scroll.queue_free()
	body.queue_free()
	var row := HBoxContainer.new()
	row.size_flags_vertical = Control.SIZE_EXPAND_FILL
	row.add_theme_constant_override("separation",22)
	column.add_child(row)
	var map_area := VBoxContainer.new()
	map_area.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(map_area)
	var map_view := MapView.new()
	map_view.name = "RealmMap"
	map_view.selected_id = selected
	map_view.size_flags_vertical = Control.SIZE_EXPAND_FILL
	map_area.add_child(map_view)
	var tools := HBoxContainer.new()
	map_area.add_child(tools)
	for spec in [["−",0],["+",1],["HOME",2]]:
		var button := HUD.circle_button(spec[0],"" if spec[1] != 2 else "settlement",func():
			if spec[1] == 2: map_view.focus_home()
			else: map_view.change_zoom(1.25 if spec[1] == 1 else 0.8)
		,64)
		tools.add_child(button)
	var hint := HUD.label("Drag to explore · pinch to zoom",15,Color("9aafa5"))
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	tools.add_child(hint)
	var detail := VBoxContainer.new()
	detail.custom_minimum_size.x = 300
	detail.add_theme_constant_override("separation",14)
	row.add_child(detail)
	map_view.selected.connect(func(id): selected = id; _map_detail(detail,id))
	_map_detail(detail,selected)

func _map_detail(detail: VBoxContainer, id: int) -> void:
	for child in detail.get_children(): detail.remove_child(child); child.queue_free()
	var location := ClanCatalog.territory(id)
	_text(detail,"YOUR LAND" if Campaign.owns(id) else "WITHIN REACH" if Campaign.can_attack(id) else "BEYOND YOUR BORDERS",16)
	_text(detail,str(location.name),30)
	_text(detail,str(location.type).to_upper(),15)
	_text(detail,str(location.desc),19)
	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	detail.add_child(spacer)
	_text(detail,"VILLAGE STORES" if Campaign.owns(id) else "CONQUEST REWARDS",15)
	var rewards := HBoxContainer.new()
	detail.add_child(rewards)
	for resource in ["gold","wood","iron"]:
		var item := VBoxContainer.new()
		item.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		rewards.add_child(item)
		item.add_child(_picture(Art.icon(resource),Vector2(52,45)))
		var quantity := str(location[resource])
		if Campaign.owns(id):
			var village_state: Dictionary = Campaign.state.get("societies",{}).get(str(id),{})
			var stock_key: String = {"gold":"coffers","wood":"wood","iron":"ore"}[resource]
			quantity = str(village_state.stock[stock_key]) if not village_state.is_empty() else "—"
		var amount := _text(item,quantity,18)
		amount.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_text(detail,"Safe to explore" if Campaign.owns(id) else "%d defenders · 3 waves" % location.enemies,18)
	var button := HUD.make_button("TRAVEL HERE" if Campaign.owns(id) else "PREPARE CONQUEST",func():
		if Campaign.owns(id): travel_to(id)
		else: show_war_council(id)
	)
	button.disabled = not Campaign.owns(id) and not Campaign.can_attack(id)
	if button.disabled: button.text = "REACH A NEIGHBOUR FIRST"
	detail.add_child(button)

func show_war_council(id: int, reset: bool = true) -> void:
	if not Campaign.can_attack(id): return
	selected = id
	if reset: deployment = Campaign.state.squads.duplicate()
	var total := 1
	for n in deployment: total += int(n)
	var location := ClanCatalog.territory(id)
	var body := _panel("The battle for " + str(location.name),"%d YOUR WARRIORS · %d ENEMIES · THREE REINFORCEMENT WAVES" % [total,location.enemies])
	modal_kind = "war"
	var roster := HBoxContainer.new()
	body.add_child(roster)
	for i in 4:
		var card := VBoxContainer.new()
		card.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		roster.add_child(card)
		card.add_child(_picture(Art.warrior(i,0,0),Vector2(150,110)))
		_text(card,str(ClanCatalog.clan_class(i).name),22)
		_text(card,"%d / %d ready" % [deployment[i],Campaign.state.squads[i]],20)
		var count := HBoxContainer.new()
		card.add_child(count)
		for step in [-10,10]:
			count.add_child(HUD.make_button("− 10" if step < 0 else "+ 10",func(): deployment[i] = clampi(int(deployment[i])+step,0,int(Campaign.state.squads[i])); show_war_council(id,false)))
	var shapes := HBoxContainer.new()
	body.add_child(shapes)
	for shape in ["line","wedge","shield"]:
		var button := HUD.make_button(("✓ " if formation == shape else "")+str(shape).to_upper(),func(): formation = shape; show_war_council(id,false))
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shapes.add_child(button)
	_text(body,"Expect a sustained fight. Reinforcements arrive after 35 and 70 seconds. Guard, dodge, and rally to keep your leader alive. Victory brings the village under your banner.",20)
	body.add_child(HUD.make_button("RAISE YOUR BANNER",start_battle))

func start_battle() -> void:
	if not Campaign.can_attack(selected): return
	close_modal()
	_clear_world()
	in_battle = true
	world = Battle.new()
	add_child(world)
	world.build(selected,deployment,formation)
	world.finished.connect(_battle_finished)
	hud.set_mode(false)
	refresh_timer = 1

func _battle_finished(result: Dictionary) -> void:
	last_result = result
	if result.win: Campaign.conquer(selected)
	var body := _panel("Your banner rises." if result.win else "The clan will rise again.","BATTLE COMPLETE · %d:%02d" % [int(result.seconds)/60,int(result.seconds)%60])
	modal_kind = "result"
	_text(body,(str(ClanCatalog.territory(selected).name) + " now belongs to your clan.") if result.win else "Your warriors regroup. Your lands and equipment remain safe.",30)
	_text(body,"%d personal kills · %d survivors" % [result.kills,result.survivors],24)
	if result.win:
		var t := ClanCatalog.territory(selected)
		_text(body,"SPOILS · +%d gold · +%d timber · +%d iron" % [t.gold,t.wood,t.iron])
	body.add_child(HUD.make_button("ENTER YOUR NEW SETTLEMENT" if result.win else "RETURN HOME",func(): travel_to(selected if result.win else current)))

func show_pause() -> void:
	var body := _panel("Around the campfire","The world waits for you.")
	modal_kind = "pause"
	body.add_child(HUD.make_button("RESUME",close_modal))
	for setting in ["blood","shake","sound"]:
		body.add_child(HUD.make_button(({"blood":"BLOOD & BATTLE REMAINS","shake":"CAMERA MOTION","sound":"SOUND"}[setting]) + (" · ON" if Campaign.state.settings[setting] else " · OFF"),func(): Campaign.state.settings[setting] = not Campaign.state.settings[setting]; Campaign.commit(); show_pause()))
	if in_battle: body.add_child(HUD.make_button("RETREAT TO YOUR VILLAGE",func(): travel_to(current)))
	else: body.add_child(HUD.make_button("SAVE CAMPAIGN",func(): if Campaign.save_game(): _toast("Campaign saved on this device.")))
	_text(body,"Move: left joystick / WASD · Interact: action button / E\nBattle: J strike · K heavy · L guard · Space dodge · E rally\nProgress is saved automatically. Landscape orientation supports either side.",19)

func _toast(message: String) -> void:
	var panel := PanelContainer.new()
	panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	panel.offset_left = -400
	panel.offset_right = 400
	panel.offset_top = 180
	hud.root.add_child(panel)
	var text := HUD.label(message,20)
	text.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	text.custom_minimum_size.x = 760
	panel.add_child(text)
	await get_tree().create_timer(3.5).timeout
	if is_instance_valid(panel): panel.queue_free()
