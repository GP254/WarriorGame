extends Control
signal moved(value: Vector2)
var enabled := true
var finger := -1
var output := Vector2.ZERO
var radius := 68.0
var thumb := Vector2.ZERO
var mouse_drag := false
const DEADZONE := 0.12

func _ready() -> void: mouse_filter = Control.MOUSE_FILTER_IGNORE

func reset() -> void:
	finger = -1
	mouse_drag = false
	output = Vector2.ZERO
	thumb = Vector2.ZERO
	moved.emit(output)
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not enabled or not is_visible_in_tree(): return
	var inverse := get_global_transform_with_canvas().affine_inverse()
	if event is InputEventScreenTouch:
		var local: Vector2 = inverse * event.position
		if event.pressed and finger == -1 and local.distance_to(size*0.5) < size.x*0.5:
			finger = event.index
			_update(local)
			get_viewport().set_input_as_handled()
		elif not event.pressed and event.index == finger:
			reset()
			get_viewport().set_input_as_handled()
	elif event is InputEventScreenDrag and event.index == finger:
		_update(inverse * event.position)
		get_viewport().set_input_as_handled()
	elif event is InputEventMouseButton and event.device != InputEvent.DEVICE_ID_EMULATION and event.button_index == MOUSE_BUTTON_LEFT and finger == -1:
		var local: Vector2 = inverse * event.position
		if event.pressed and local.distance_to(size*0.5) < size.x*0.5:
			mouse_drag = true
			_update(local)
			get_viewport().set_input_as_handled()
		elif not event.pressed and mouse_drag: reset()
	elif event is InputEventMouseMotion and mouse_drag:
		_update(inverse * event.position)
		get_viewport().set_input_as_handled()

func _update(at: Vector2) -> void:
	thumb = ((at-size*0.5)/radius).limit_length()
	output = thumb.normalized() * maxf(0,(thumb.length()-DEADZONE)/(1-DEADZONE))
	moved.emit(output)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT: reset()

func _draw() -> void:
	var center := size*0.5
	var base := size.x*0.5-5
	draw_circle(center+Vector2(0,4),base,Color(0,0,0,0.3))
	draw_circle(center,base,Color(0.05,0.09,0.10,0.75))
	draw_arc(center,base,0,TAU,64,Color("847b60"),2,true)
	draw_arc(center,base-6,0,TAU,64,Color(0.5,0.57,0.53,0.25),1,true)
	draw_arc(center,radius-3,0,TAU,48,Color(0.6,0.7,0.65,0.14),1,true)
	for i in 4:
		var axis := Vector2.from_angle(i*PI/2)
		draw_line(center+axis*(base-19),center+axis*(base-11),Color("938565"),2,true)
	var knob := center+thumb*radius
	draw_circle(knob+Vector2(0,4),33,Color(0,0,0,0.5))
	draw_circle(knob,33,Color("31494a"))
	draw_arc(knob,33,0,TAU,48,Color("b8a77c"),2,true)
	draw_arc(knob,27,0,TAU,48,Color("64746a"),1,true)
	draw_circle(knob,5,Color("a5b3a0"))
