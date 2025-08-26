extends Node
class_name Specials

var crumbs := 0
var shield_time := 0.0

func _ready() -> void:
	add_to_group("specials")

func add_crumb(n: int) -> void:
	crumbs += n

func use_shield() -> bool:
	if crumbs < 1: return false
	crumbs -= 1
	shield_time = 10.0
	return true

func use_bomb() -> bool:
	if crumbs < 1: return false
	crumbs -= 1
	get_tree().call_group("pattern_controller", "_radial_burst")
	return true

func use_slow() -> bool:
	if crumbs < 2: return false
	crumbs -= 2
	Engine.time_scale = 0.4
	await get_tree().create_timer(3.0, true, false, true).timeout
	Engine.time_scale = 1.0
	return true
