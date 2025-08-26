extends CanvasLayer

var gs: GameStateData
var hp_label: Label
var banked_label: Label
var unbanked_label: Label
var bm_label: Label
var risk_bar: ProgressBar

func _ready() -> void:
	gs = get_node("/root/GameState") as GameStateData
	# Try to find HUD nodes; warn if missing rather than crash
	# Match your scene: Ui/Hud/HP, Banked, Unbanked, BM, Risk
	hp_label = get_node_or_null("Hud/HP")
	banked_label = get_node_or_null("Hud/Banked")
	unbanked_label = get_node_or_null("Hud/Unbanked")
	bm_label = get_node_or_null("Hud/BM")
	risk_bar = get_node_or_null("Hud/Risk")

	if gs:
		gs.connect("coins_changed", func(v): if unbanked_label: unbanked_label.text = "At‑Risk: %d" % v)
		gs.connect("banked_changed", func(v): if banked_label: banked_label.text = "Banked: %d" % v)
		gs.connect("bm_changed", func(v): if bm_label: bm_label.text = "BM ×%.1f" % v)
		gs.connect("risk_tier_changed", _on_heat)

func _on_heat(tier: int) -> void:
	if risk_bar:
		risk_bar.value = tier
