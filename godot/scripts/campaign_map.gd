extends Control
signal selected(id: int)
var selected_id := 0
var marker_rects: Array[Rect2] = []
var zoom := 1.0
var pan := Vector2.ZERO
var touches: Dictionary = {}
var press_at := Vector2.ZERO
var dragged := false
var mouse_drag := false
var map_scale := 1.0
var origin := Vector2.ZERO
# Positions follow the new coastline; gameplay adjacency remains in the catalog.
const POINTS := [Vector2(.47,.43),Vector2(.60,.50),Vector2(.36,.51),Vector2(.37,.30),Vector2(.72,.63),Vector2(.48,.66),Vector2(.17,.48),Vector2(.25,.66),Vector2(.57,.17),Vector2(.60,.32),Vector2(.86,.51),Vector2(.78,.76),Vector2(.40,.80),Vector2(.22,.20),Vector2(.83,.22),Vector2(.88,.37)]
const MAP_SIZE := Vector2(1536,1024)

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_STOP
	clip_contents = true
	resized.connect(func(): _clamp_pan(); queue_redraw())

func _clamp_pan() -> void:
	var scale := maxf(size.x/MAP_SIZE.x,size.y/MAP_SIZE.y)*zoom
	var margin := (MAP_SIZE*scale-size)*0.5
	pan = pan.clamp(-margin.max(Vector2.ZERO),margin.max(Vector2.ZERO))

func change_zoom(factor: float, pivot: Vector2 = Vector2(-1,-1)) -> void:
	if pivot.x < 0: pivot = size*0.5
	var old := zoom
	zoom = clampf(zoom*factor,1.0,2.8)
	pan = pivot-size*0.5-(pivot-size*0.5-pan)*(zoom/old)
	_clamp_pan()
	queue_redraw()

func focus_home() -> void:
	zoom = 1.6
	var scale := maxf(size.x/MAP_SIZE.x,size.y/MAP_SIZE.y)*zoom
	pan = (MAP_SIZE*0.5-POINTS[int(Campaign.state.current)]*MAP_SIZE)*scale
	_clamp_pan()
	queue_redraw()

func _draw() -> void:
	map_scale = maxf(size.x/MAP_SIZE.x,size.y/MAP_SIZE.y)*zoom
	origin = (size-MAP_SIZE*map_scale)*0.5+pan
	draw_rect(Rect2(Vector2.ZERO,size),Color("102526"))
	draw_texture_rect(Art.texture("realm-map-v2"),Rect2(origin,MAP_SIZE*map_scale),false,Color(.78,.85,.82))
	marker_rects.clear()
	for point in POINTS:
		var at: Vector2 = origin+point*MAP_SIZE*map_scale
		marker_rects.append(Rect2(at-Vector2(44,44),Vector2(88,88)))
	for territory: Dictionary in ClanCatalog.data().territories:
		for neighbour in territory.links:
			if int(neighbour) <= int(territory.id): continue
			var a := marker_rects[int(territory.id)].get_center()
			var b := marker_rects[int(neighbour)].get_center()
			var available: bool = Campaign.owns(int(territory.id)) or Campaign.owns(int(neighbour))
			draw_line(a,b,Color(0.03,0.08,0.08,0.8),4,true)
			draw_dashed_line(a,b,Color("c5b17a") if available else Color(0.6,0.67,0.63,0.35),1.5,7,true,true)
	for i in POINTS.size():
		var center := marker_rects[i].get_center()
		var color := Color("78c6b2") if Campaign.owns(i) else Color("e5bc6a") if Campaign.can_attack(i) else Color("758987")
		var chosen := i == selected_id
		if chosen:
			draw_circle(center,47,Color(color,0.13))
			draw_arc(center,43,0,TAU,48,color,2,true)
		var radius := 25.0 if Campaign.owns(i) or Campaign.can_attack(i) or chosen else 19.0
		draw_circle(center+Vector2(0,3),radius+2,Color(0,0,0,.65))
		draw_circle(center,radius,Color("102626"))
		draw_arc(center,radius,0,TAU,48,color,2,true)
		var index := 5 if i == 0 else 13 if int(ClanCatalog.territory(i).level) >= 4 else 1
		draw_texture_rect(Art.cell("settlement-buildings",index%4,index/4,4,4),Rect2(center-Vector2(radius,radius+4),Vector2.ONE*radius*2),false,Color.WHITE if radius > 20 else Color(.7,.78,.75))
		if i == int(Campaign.state.current):
			draw_circle(center+Vector2(0,-32),5,Color("b9efe0"))
		if chosen or Campaign.owns(i) or Campaign.can_attack(i) or zoom > 1.45:
			_name(str(ClanCatalog.territory(i).name),center+Vector2(0,39),color,15 if chosen else 13)
		if chosen:
			var territory := ClanCatalog.territory(i)
			var resource := "wood" if int(territory.wood) >= int(territory.iron) else "iron"
			var amount := int(territory[resource])
			if i == 0: resource = "settlement"
			var label := "YOUR HOME" if i == 0 else "+%d %s" % [amount,resource.to_upper()]
			var at := center-Vector2(60,78)
			draw_style_box(_pill(),Rect2(at,Vector2(120,30)))
			draw_texture_rect(Art.icon(resource),Rect2(at+Vector2(5,3),Vector2(24,24)),false)
			draw_string(ThemeDB.fallback_font,at+Vector2(32,20),label,HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color("eee1be"))
	draw_rect(Rect2(Vector2.ZERO,size),Color("667369"),false,1)

func _pill() -> StyleBoxFlat:
	var box := StyleBoxFlat.new()
	box.bg_color = Color(.03,.08,.08,.94)
	box.set_corner_radius_all(5)
	box.border_color = Color("817653")
	box.set_border_width_all(1)
	return box

func _name(text: String, at: Vector2, color: Color, font_size: int) -> void:
	var width := ThemeDB.fallback_font.get_string_size(text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
	draw_style_box(_pill(),Rect2(at-Vector2(width/2+7,16),Vector2(width+14,23)))
	draw_string(ThemeDB.fallback_font,at-Vector2(width/2,0),text,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,color)

func _select(at: Vector2) -> void:
	var choice := -1
	var best := 44.0*44.0
	for i in marker_rects.size():
		var distance := marker_rects[i].get_center().distance_squared_to(at)
		if distance < best:
			best = distance
			choice = i
	if choice >= 0:
		selected_id = choice
		selected.emit(choice)
		queue_redraw()

func _gui_input(event: InputEvent) -> void:
	if event is InputEventScreenTouch:
		if event.pressed:
			touches[event.index] = event.position
			press_at = event.position
			dragged = touches.size() > 1
		else:
			if touches.has(event.index) and not dragged and touches.size() == 1: _select(event.position)
			touches.erase(event.index)
		accept_event()
	elif event is InputEventScreenDrag and touches.has(event.index):
		var old: Vector2 = touches[event.index]
		if touches.size() == 2:
			var other: Vector2 = touches[touches.keys()[1] if touches.keys()[0] == event.index else touches.keys()[0]]
			var before := old.distance_to(other)
			if before > 10: change_zoom(event.position.distance_to(other)/before,(old+other)/2)
			dragged = true
		else:
			pan += event.position-old
			if event.position.distance_to(press_at) > 8: dragged = true
		touches[event.index] = event.position
		_clamp_pan()
		queue_redraw()
		accept_event()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION:
		if event.pressed and event.button_index in [MOUSE_BUTTON_WHEEL_UP,MOUSE_BUTTON_WHEEL_DOWN]:
			change_zoom(1.15 if event.button_index == MOUSE_BUTTON_WHEEL_UP else 1/1.15,event.position)
		elif event.button_index == MOUSE_BUTTON_LEFT:
			mouse_drag = event.pressed
			if event.pressed: press_at = event.position; dragged = false
			elif not dragged: _select(event.position)
		accept_event()
	elif event is InputEventMouseMotion and mouse_drag:
		pan += event.relative
		if event.position.distance_to(press_at) > 8: dragged = true
		_clamp_pan()
		queue_redraw()
		accept_event()
	elif event is InputEventMagnifyGesture:
		change_zoom(event.factor,event.position)
		accept_event()
