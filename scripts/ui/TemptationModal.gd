extends Control
class_name TemptationModal

signal chosen(id: String)

func show_options(options: Array) -> void:
	visible = true
	# Populate buttons (assumes 3 Button children)
	for i in range(min(options.size(), get_child_count())):
		var btn := get_child(i) as Button
		btn.text = options[i]["title"] + "
" + options[i]["desc"]
		btn.pressed.connect(func(): _choose(options[i]["id"]))

func _choose(id: String) -> void:
	visible = false
	emit_signal("chosen", id)
