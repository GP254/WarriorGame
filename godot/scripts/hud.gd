extends CanvasLayer
signal requested(action: String)
signal combat_pressed(action: String, down: bool)
signal direction_changed(value: Vector2)
const TouchAction = preload("res://scripts/touch_action.gd")
const Stick = preload("res://scripts/touch_stick.gd")
var root: Control
var safe: Control
var top: HBoxContainer
var resources: Label
var location: Label
var subtitle: Label
var stick: Control
var context: Button
var combat_row: Control
var context_hint: Label
var health: ProgressBar
var stamina: ProgressBar
var battle_info: Label
var controls: Array[Control] = []
var village_mode := true
var suspended := false

func _ready() -> void:
	layer = 20
	root = Control.new()
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)
	root.theme = make_theme()
	safe = Control.new()
	safe.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(safe)
	top = HBoxContainer.new()
	top.alignment = BoxContainer.ALIGNMENT_END
	top.add_theme_constant_override("separation",10)
	safe.add_child(top)
	for spec in [["MAP","map"],["CLAN","clan"],["VILLAGE","settlement"],["PAUSE","pause"]]:
		var button := circle_button(spec[0],spec[1],func(): requested.emit(spec[1]),82)
		top.add_child(button)
		controls.append(button)
	resources = label("",17,Color("d5c69d"))
	resources.position = Vector2(20,77)
	safe.add_child(resources)
	location = label("",30,Color("ead9b0"))
	location.position = Vector2(20,12)
	safe.add_child(location)
	subtitle = label("",17,Color("b6c2ac"))
	subtitle.position = Vector2(22,51)
	safe.add_child(subtitle)
	stick = Stick.new()
	stick.size = Vector2(216,216)
	safe.add_child(stick)
	stick.moved.connect(func(value): direction_changed.emit(value))
	context = circle_button("TALK","talk",func(): requested.emit("interact"),116)
	safe.add_child(context)
	context_hint = label("Follow the village roads",17)
	context_hint.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	context_hint.size = Vector2(340,55)
	context_hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	safe.add_child(context_hint)
	combat_row = Control.new()
	combat_row.mouse_filter = Control.MOUSE_FILTER_IGNORE
	combat_row.size = Vector2(400,290)
	safe.add_child(combat_row)
	var centers := [Vector2(330,216),Vector2(302,92),Vector2(210,226),Vector2(96,196),Vector2(185,110)]
	for i in 5:
		var key: String = ["strike","heavy","guard","dodge","rally"][i]
		var button := circle_button(key.to_upper(),key,func(): pass,116 if i == 0 else 96)
		button.position = centers[i]-button.custom_minimum_size/2
		button.button_down.connect(func(): combat_pressed.emit(key,true))
		button.button_up.connect(func(): combat_pressed.emit(key,false))
		combat_row.add_child(button)
	health = ProgressBar.new()
	health.show_percentage = false
	health.custom_minimum_size = Vector2(250,14)
	health.value = 100
	safe.add_child(health)
	stamina = ProgressBar.new()
	stamina.show_percentage = false
	stamina.value = 100
	stamina.custom_minimum_size = Vector2(250,8)
	var gold := StyleBoxFlat.new()
	gold.bg_color = Color("b8a76c")
	stamina.add_theme_stylebox_override("fill",gold)
	safe.add_child(stamina)
	battle_info = label("",19)
	battle_info.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	battle_info.custom_minimum_size = Vector2(430,60)
	safe.add_child(battle_info)
	get_viewport().size_changed.connect(fit)
	fit()
	set_mode(true)

func fit() -> void:
	var view := get_viewport().get_visible_rect().size
	var inset := Vector4(18,12,18,16)
	if OS.get_name() == "iOS" or OS.get_name() == "Android":
		var window := Vector2(DisplayServer.window_get_size())
		var area := Rect2(DisplayServer.get_display_safe_area())
		if window.x > 0 and window.y > 0:
			var ratio := view/window
			inset = Vector4(maxf(18,area.position.x*ratio.x),maxf(12,area.position.y*ratio.y),maxf(18,(window.x-area.end.x)*ratio.x),maxf(16,(window.y-area.end.y)*ratio.y))
	safe.position = Vector2(inset.x,inset.y)
	safe.size = view-Vector2(inset.x+inset.z,inset.y+inset.w)
	top.position = Vector2(safe.size.x-358,0)
	top.size = Vector2(358,82)
	stick.position = Vector2(4,safe.size.y-226)
	context.size = Vector2(116,116)
	context.position = Vector2(safe.size.x-142,safe.size.y-146)
	context_hint.position = Vector2(safe.size.x-360,safe.size.y-207)
	combat_row.position = Vector2(safe.size.x-408,safe.size.y-298)
	health.position = Vector2(20,safe.size.y-254)
	health.size = Vector2(210,14)
	stamina.position = Vector2(20,safe.size.y-232)
	stamina.size = Vector2(210,8)
	battle_info.position = Vector2(safe.size.x-450,100)

func set_mode(village: bool) -> void:
	village_mode = village
	context.visible = village
	context_hint.visible = village
	combat_row.visible = not village
	health.visible = not village
	stamina.visible = not village
	battle_info.visible = not village
	for i in controls.size():
		if i < 3: controls[i].visible = village

func suspend(value: bool) -> void:
	suspended = value
	stick.enabled = not value
	if value: stick.reset()
	context.disabled = value
	if value: context.reset()
	for control in controls:
		control.disabled = value
		if value: control.reset()
	for child in combat_row.get_children():
		child.disabled = value
		if value: child.reset()

func refresh_world(id: int, interaction: Dictionary) -> void:
	resources.text = "%d GOLD   %d WOOD   %d IRON" % [Campaign.state.gold,Campaign.state.wood,Campaign.state.iron]
	location.text = str(ClanCatalog.territory(id).name)
	subtitle.text = ["A settlement to rebuild","A home worth defending","A growing township","A flourishing stronghold"][Campaign.level(id)] + "  ·  %d / 16 lands" % Campaign.state.owned.size()
	context.caption = "TALK" if interaction.get("kind") == "talk" else "HIRE" if interaction.get("kind") == "barracks" else "VISIT"
	context.icon_key = "talk" if interaction.get("kind") == "talk" else "clan" if interaction.get("kind") == "barracks" else "settlement"
	context_hint.text = str(interaction.name) if not interaction.is_empty() else "Explore · follow the roads"
	context.disabled = interaction.is_empty() or suspended

func refresh_battle(battle: Node2D) -> void:
	resources.text = "%d GOLD   %d WOOD   %d IRON" % [Campaign.state.gold,Campaign.state.wood,Campaign.state.iron]
	location.text = str(ClanCatalog.territory(battle.territory_id).name)
	var count: Dictionary = battle.counts()
	battle_info.text = "YOUR CLAN %d   ·   ENEMY %d\n%d in reserve   ·   %d:%02d" % [count.allies,count.enemies,count.reserve,int(battle.elapsed)/60,int(battle.elapsed)%60]
	subtitle.text = "CHARGE · %d" % int(ceil(battle.charge)) if battle.charge > 0 else "Wave %d / 3 · Fight beside your clan" % battle.wave
	if count.enemies == 0 and battle.wave < 3: subtitle.text = "Hold the field · reinforcements in %ds" % maxi(0,int(battle.wave_times[battle.wave]-battle.elapsed))
	health.value = battle.player.hp/battle.player.max*100
	stamina.value = battle.stamina
	combat_row.get_child(4).cooldown = battle.horn_cooldown / 14.0

static func label(text: String, font_size: int = 20, color: Color = Color("dddcc9")) -> Label:
	var result := Label.new()
	result.text = text
	result.add_theme_font_size_override("font_size",font_size)
	result.add_theme_color_override("font_color",color)
	return result

static func make_button(text: String, callback: Callable) -> Button:
	var result := Button.new()
	result.text = text
	result.custom_minimum_size = Vector2(120,88)
	result.focus_mode = Control.FOCUS_NONE
	result.pressed.connect(callback)
	result.pressed.connect(func(): Sound.play("ui",-14))
	return result

static func make_theme() -> Theme:
	var theme := Theme.new()
	theme.default_font_size = 21
	var panel := StyleBoxFlat.new()
	panel.bg_color = Color(0.055,0.085,0.067,0.96)
	panel.border_color = Color("766e49")
	panel.set_border_width_all(1)
	panel.content_margin_left = 18
	panel.content_margin_right = 18
	panel.content_margin_top = 12
	panel.content_margin_bottom = 12
	theme.set_stylebox("panel","PanelContainer",panel)
	for state in ["normal","hover","pressed","disabled","focus"]:
		var style := panel.duplicate() as StyleBoxFlat
		style.bg_color = Color("203529") if state == "normal" else Color("3d4a33") if state in ["hover","pressed"] else Color("17221a")
		style.border_color = Color("b5a16c") if state == "pressed" else Color("665f41")
		theme.set_stylebox(state,"Button",style)
	theme.set_color("font_color","Button",Color("e0d7b7"))
	theme.set_color("font_disabled_color","Button",Color("626d5b"))
	theme.set_color("font_color","Label",Color("dedcc7"))
	var fill := StyleBoxFlat.new()
	fill.bg_color = Color("9ab18a")
	theme.set_stylebox("fill","ProgressBar",fill)
	var background := StyleBoxFlat.new()
	background.bg_color = Color("283326")
	theme.set_stylebox("background","ProgressBar",background)
	return theme

static func circle_button(caption: String, icon: String, callback: Callable, diameter: float = 88) -> Button:
	var result := TouchAction.new()
	result.caption = caption
	result.icon_key = icon
	result.custom_minimum_size = Vector2.ONE*diameter
	result.size = result.custom_minimum_size
	result.pressed.connect(callback)
	return result
