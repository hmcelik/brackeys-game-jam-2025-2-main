extends CanvasLayer

var gs: GameStateData
var hp_label: Label
var banked_label: Label
var unbanked_label: Label
var bm_label: Label
var risk_bar: ProgressBar
var health_bar: ProgressBar
var health_container: HBoxContainer
var shop_system: ShopSystem

func _ready() -> void:
		gs = get_node("/root/GameState") as GameStateData
		add_to_group("ui")
		
		# Try to find HUD nodes; warn if missing rather than crash
		# Match your scene: Ui/Hud/HP, Banked, Unbanked, BM, Risk
		hp_label = get_node_or_null("Hud/HP")
		banked_label = get_node_or_null("Hud/Banked")
		unbanked_label = get_node_or_null("Hud/Unbanked")
		bm_label = get_node_or_null("Hud/BM")
		risk_bar = get_node_or_null("Hud/Risk")
		health_bar = get_node_or_null("Hud/HealthBar")
		health_container = get_node_or_null("Hud/HealthContainer")
		shop_system = get_node_or_null("ShopSystem") as ShopSystem
		
		# Connect shop button
		var shop_button = get_node_or_null("Hud/ShopButton")
		if shop_button:
				shop_button.pressed.connect(_open_shop)
		
		if gs:
				gs.connect("coins_changed", func(v): if unbanked_label: unbanked_label.text = "At‑Risk: %d" % v)
				gs.connect("banked_changed", func(v): if banked_label: banked_label.text = "Banked: %d" % v)
				gs.connect("bm_changed", func(v): if bm_label: bm_label.text = "BM ×%.1f" % v)
				gs.connect("risk_tier_changed", _on_heat)

func _input(event: InputEvent) -> void:
		if event.is_action_pressed("Shop"):
				_open_shop()

func _open_shop() -> void:
		if shop_system:
				shop_system.open_shop()

func _on_heat(tier: int) -> void:
		if risk_bar:
				risk_bar.value = tier

func update_health(current_hp: int, max_hp: int) -> void:
		# Update health bar if it exists
		if health_bar:
				health_bar.value = float(current_hp) / float(max_hp) * 100.0
		
		# Update health container (hearts) if it exists
		if health_container:
				# Clear existing hearts
				for child in health_container.get_children():
						child.queue_free()
				
				# Add hearts
				for i in range(max_hp):
						var heart = TextureRect.new()
						heart.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
						heart.custom_minimum_size = Vector2(30, 30)
						
						if i < current_hp:
								# Full heart
								heart.modulate = Color.RED
						else:
								# Empty heart
								heart.modulate = Color.DARK_RED
						
						# Use a simple colored rectangle as heart placeholder
						# You can replace this with actual heart textures
						var heart_texture = PlaceholderTexture2D.new()
						heart_texture.size = Vector2(30, 30)
						heart.texture = heart_texture
						
						health_container.add_child(heart)
		
		# Update HP label if it exists
		if hp_label:
				hp_label.text = "HP: %d/%d" % [current_hp, max_hp]
