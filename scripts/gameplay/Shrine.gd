extends Area2D
class_name Shrine

@onready var gs: GameState = get_node("/root/GameState") as GameState

@export var active_time := 6.0

func _ready() -> void:
	gs.connect("spawn_shrine", _on_spawn)

func _on_spawn() -> void:
	visible = true
	monitoring = true
	$CollisionShape2D.disabled = false
	await get_tree().create_timer(active_time).timeout
	_despawn()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		gs.bank_at_shrine()
		_despawn()

func _despawn() -> void:
	visible = false
	monitoring = false
	$CollisionShape2D.disabled = true
