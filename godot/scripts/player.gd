extends CharacterBody2D
var move_input := Vector2.ZERO
var blocked := false
var phase := 0.0
var facing := 0
var kind := 0
var sprite: Sprite2D
var camera: Camera2D

func _ready() -> void:
	collision_layer = 2
	collision_mask = 1
	var shape := CollisionShape2D.new()
	var circle := CircleShape2D.new()
	circle.radius = 13
	shape.shape = circle
	add_child(shape)
	sprite = Sprite2D.new()
	sprite.position.y = -26
	sprite.scale = Vector2.ONE * 0.31
	add_child(sprite)
	kind = ClanCatalog.family_index(str(ClanCatalog.weapon(Campaign.state.equipped[int(Campaign.state.leader)]).family))
	camera = Camera2D.new()
	camera.position_smoothing_enabled = true
	camera.position_smoothing_speed = 7
	camera.zoom = Vector2(1.2,1.2)
	camera.limit_left = -1500
	camera.limit_right = 1500
	camera.limit_top = -1100
	camera.limit_bottom = 1100
	add_child(camera)

func _physics_process(delta: float) -> void:
	var axis := move_input
	if not blocked:
		axis += Vector2(float(Input.is_physical_key_pressed(KEY_D) or Input.is_physical_key_pressed(KEY_RIGHT)) - float(Input.is_physical_key_pressed(KEY_A) or Input.is_physical_key_pressed(KEY_LEFT)),float(Input.is_physical_key_pressed(KEY_S) or Input.is_physical_key_pressed(KEY_DOWN)) - float(Input.is_physical_key_pressed(KEY_W) or Input.is_physical_key_pressed(KEY_UP)))
	else: axis = Vector2.ZERO
	velocity = axis.limit_length() * 205.0
	move_and_slide()
	position = position.clamp(Vector2(-1460,-1060),Vector2(1460,1060))
	if axis.length() > 0.1:
		phase += delta * 8 * axis.length()
		Sound.play("step",-23)
		facing = Art.direction(axis)
	else: phase = 0
	sprite.texture = Art.walk(kind,facing,int(phase) % 4)
	sprite.scale = Vector2.ONE*69/sprite.texture.get_height()
	queue_redraw()

func _draw() -> void:
	draw_arc(Vector2.ZERO,17,0,TAU,24,Color("c6ac6a"),1.5)
