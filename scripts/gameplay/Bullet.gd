extends Area2D
class_name Bullet

@export var speed := 140.0
var velocity := Vector2.ZERO
var lifetime := 4.0
var alive := false

func fire(pos: Vector2, vel: Vector2, life: float) -> void:
	global_position = pos
	velocity = vel
	lifetime = life
	alive = true
	visible = true
	monitoring = true

func _physics_process(delta: float) -> void:
	if not alive:
		return
	lifetime -= delta
	if lifetime <= 0.0:
		_despawn()
		return
	global_position += velocity * delta

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_despawn()

func _despawn() -> void:
	alive = false
	visible = false
	monitoring = false
