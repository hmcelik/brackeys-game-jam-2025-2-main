extends Node
# NOTE: Do NOT give this script a `class_name` if your autoload is also named "Save".
# That avoids the class-vs-singleton name collision.

const SAVE_PATH := "user://save.json"

# Explicitly type the dictionary to avoid "inferred from Variant" warnings.
var data: Dictionary = {
	"coins_banked": 0,
	"upgrades": {
		"hp": 1, "dash_iframes": 0, "move": 0,
		"coin_rate": 0, "cashout": 0, "free_hit": 0
	},
	"streak": 0,
	"best": {"survival": 0.0, "peak_bm": 1.0, "biscuits": 0},
	"options": {"screenshake": true, "reduced_flash": false, "insurance": false}
}

func _ready() -> void:
	load_game()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		save_game()
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f:
		var txt: String = f.get_as_text()
		var parsed: Variant = JSON.parse_string(txt)
		if typeof(parsed) == TYPE_DICTIONARY:
			data = (parsed as Dictionary)

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))

func add_bank(amount: int) -> void:
	var safe_amount: int = max(amount, 0)
	var current: int = int(data.get("coins_banked", 0))
	data["coins_banked"] = current + safe_amount
	save_game()

func set_option(key: String, value: Variant) -> void:
	var opts: Dictionary = (data.get("options", {}) as Dictionary)
	opts[key] = value
	data["options"] = opts
	save_game()

func get_upgrade(key: String) -> int:
	var ups: Dictionary = (data.get("upgrades", {}) as Dictionary)
	return int(ups.get(key, 0))

func inc_upgrade(key: String) -> void:
	var ups: Dictionary = (data.get("upgrades", {}) as Dictionary)
	ups[key] = int(ups.get(key, 0)) + 1
	data["upgrades"] = ups
	save_game()
