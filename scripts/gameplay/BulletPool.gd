extends Node
class_name BulletPool

const MAX_BULLETS := 400
@export var bullet_scene: PackedScene
var pool: Array[Bullet] = []

func _ready() -> void:
	pool.resize(MAX_BULLETS)
	for i in range(MAX_BULLETS):
		var b := bullet_scene.instantiate() as Bullet
		b.visible = false
		b.monitoring = false
		add_child(b)
		pool[i] = b

func get_bullet() -> Bullet:
	for b in pool:
		if not b.alive:
			return b
	return null

func fire(pos: Vector2, vel: Vector2, life: float) -> void:
	var b := get_bullet()
	if b:
		b.fire(pos, vel, life)
