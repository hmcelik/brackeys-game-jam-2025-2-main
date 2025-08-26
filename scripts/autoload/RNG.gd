extends Node
class_name RNGService

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
		_rng.randomize()

func seed_with(value: int) -> void:
		_rng.seed = value

func randi() -> int:
		return _rng.randi()

func randi_range(a: int, b: int) -> int:
		return _rng.randi_range(a, b)

func randf() -> float:
		return _rng.randf()

func randf_range(a: float, b: float) -> float:
		return _rng.randf_range(a, b)
