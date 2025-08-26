extends Node2D
class_name Arena

@onready var gs: GameStateData = get_node("/root/GameState") as GameStateData

var shrink_level := 0.0

func _ready() -> void:
		add_to_group("arena")
		gs.start_run()

func shrink_arena(amount: float) -> void:
		shrink_level = clamp(shrink_level + amount, 0.0, 0.3)
		scale = Vector2(1.0 - shrink_level, 1.0 - shrink_level)

# Add this method for furnace to access shrink level
func get_shrink_level() -> float:
		return shrink_level
