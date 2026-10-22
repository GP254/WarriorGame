extends Button
# Each circular control owns one pointer independently of the movement stick.
var finger := -1
var mouse_held := false
var caption := ""
var icon_key := "strike"
var cooldown := 0.0
var accent := Color("bca979")

func _ready() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	focus_mode = Control.FOCUS_NONE
	for state in ["normal","hover","pressed","disabled","focus"]:
		add_theme_stylebox_override(state,StyleBoxEmpty.new())
	resized.connect(queue_redraw)

func _process(_delta: float) -> void: queue_redraw()

func contains(at: Vector2) -> bool:
	var local := get_global_transform_with_canvas().affine_inverse() * at
	return local.distance_to(size * 0.5) <= minf(size.x,size.y) * 0.5 - 3

func reset() -> void:
	var was_down := finger >= 0 or mouse_held
	finger = -1
	mouse_held = false
	set_pressed_no_signal(false)
	if was_down: button_up.emit()
	queue_redraw()

func _input(event: InputEvent) -> void:
	if disabled or not is_visible_in_tree():
		reset()
		return
	if event is InputEventScreenTouch:
		var inside := contains(event.position)
		if event.pressed and finger == -1 and not mouse_held and inside:
			finger = event.index
			set_pressed_no_signal(true)
			button_down.emit()
			get_viewport().set_input_as_handled()
		elif not event.pressed and finger == event.index:
			reset()
			if inside: pressed.emit()
			get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT and finger == -1:
		var inside := contains(event.position)
		if event.pressed and inside:
			mouse_held = true
			set_pressed_no_signal(true)
			button_down.emit()
			get_viewport().set_input_as_handled()
		elif not event.pressed and mouse_held:
			reset()
			if inside: pressed.emit()
			get_viewport().set_input_as_handled()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: reset()

func _draw() -> void:
	var center := size * 0.5
	var radius := minf(size.x,size.y) * 0.5 - 4
	var rim := accent.darkened(0.5) if disabled else accent
	draw_circle(center + Vector2(0,4),radius+2,Color(0,0,0,0.4))
	draw_circle(center,radius,Color("111d20"))
	draw_circle(center,radius-5,Color("365451") if button_pressed else Color("1b3031"))
	draw_arc(center,radius,0,TAU,64,rim,2,true)
	draw_arc(center,radius-5,0,TAU,64,rim.darkened(0.5),1,true)
	draw_arc(center,radius-2,PI*1.1,PI*1.85,32,rim.lightened(0.15),1,true)
	var extent := radius * 1.25
	var offset := Vector2(0,3) if button_pressed else Vector2.ZERO
	if not icon_key.is_empty(): draw_texture_rect(Art.icon(icon_key),Rect2(center - Vector2(extent/2,extent/2+5) + offset,Vector2.ONE*extent),false,Color(1,1,1,0.3) if disabled else Color.WHITE)
	if not caption.is_empty():
		var font := ThemeDB.fallback_font
		var font_size := 30 if icon_key.is_empty() else 12 if radius < 45 else 13
		var width := font.get_string_size(caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size).x
		draw_string(font,center+Vector2(-width/2,10 if icon_key.is_empty() else radius-13),caption,HORIZONTAL_ALIGNMENT_LEFT,-1,font_size,rim.lightened(0.25))
	if cooldown > 0: draw_arc(center,radius+1,-PI/2,-PI/2+TAU*clampf(cooldown,0,1),64,Color("80cec4"),4,true)
