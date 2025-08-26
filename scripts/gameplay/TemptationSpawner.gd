extends Control
class_name TemptationSpawner

@onready var gs: GameStateData = get_node("/root/GameState") as GameStateData

@export var modal_path: NodePath
var modal: TemptationModal

func _ready() -> void:
	modal = get_node_or_null(modal_path) as TemptationModal
	if not modal:
		push_error("TemptationSpawner: modal_path not set or node not found.")
		return
	gs.connect("spawn_temptation", _on_spawn)
	if not modal.chosen.is_connected(on_choice):
		modal.chosen.connect(on_choice)

func _on_spawn() -> void:
	modal.show_options([
		{"id":"blood_for_batter", "title":"Blood for Batter", "desc":"Lose 25% HP → +0.6 BM"},
		{"id":"bring_the_heat", "title":"Bring the Heat", "desc":"Elite burst now → +1 drop"},
		{"id":"squeeze_the_circle", "title":"Squeeze the Circle", "desc":"Arena −10% → +20% coin"},
	])

func on_choice(id: String) -> void:
	gs.apply_temptation(id)
