extends Area2D
class_name Pickup

@onready var gs: GameState = get_node("/root/GameState") as GameState

enum Kind { COIN, CRUMB, HEART, GOLDEN }
@export var kind := Kind.COIN
@export var value := 1
var attracted := false
var target: Node2D

func _physics_process(delta: float) -> void:
	if attracted and target:
		var dir := (target.global_position - global_position).normalized()
		global_position += dir * 300.0 * delta

func attract_to(p: Node2D) -> void:
	attracted = true
	target = p

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"): return
	match kind:
		Kind.COIN:
			gs.add_unbanked(int(round(value * gs.bm)))
		Kind.CRUMB:
			get_tree().call_group("specials", "add_crumb", 1)
		Kind.HEART:
			body.hp = min(body.hp + 1, body.max_hp)
		Kind.GOLDEN:
			gs.add_unbanked(value) # golden paid at extract; here we add raw
	queue_free()
