extends Node2D
# Training is scenery; recruits are counted once, by Campaign.recruit.
var village: Node2D
var kind := 0
var phase := 0.0
var sprite: Sprite2D
func _ready() -> void:
	phase = kind*0.7
	sprite = Sprite2D.new()
	sprite.position.y = -25
	add_child(sprite)
	_update_pose()
func _physics_process(delta: float) -> void:
	if village.blocked: return
	phase += delta
	_update_pose()
func _update_pose() -> void:
	var cycle := fmod(phase,3.2)
	sprite.texture = Art.warrior(kind,1,clampi(int(cycle/1.2*8),0,7)) if cycle < 1.2 else Art.walk(kind,0,0)
	sprite.scale = Vector2.ONE*62/sprite.texture.get_height()
