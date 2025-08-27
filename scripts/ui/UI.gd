extends CanvasLayer

var gs: GameStateData
var health_bar: ProgressBar
var health_hearts: HBoxContainer
var risk_bar: ProgressBar
var banked_label: Label
var unbanked_label: Label
var multiplier_label: Label
var shop_system: ShopSystem
var status_text: Label
var damage_overlay: ColorRect
var damage_indicator: Label

# Damage system variables
var damage_flash_timer := 0.0
var current_damage_indicators := []

func _ready() -> void:
				gs = get_node("/root/GameState") as GameStateData
				add_to_group("ui")
				
				# Get UI nodes
				health_bar = get_node_or_null("MainContainer/TopBar/HealthSection/HealthBar")
				health_hearts = get_node_or_null("MainContainer/TopBar/HealthSection/HealthHearts")
				risk_bar = get_node_or_null("MainContainer/TopBar/RiskSection/RiskBar")
				banked_label = get_node_or_null("MainContainer/TopBar/CoinSection/BankedCoins")
				unbanked_label = get_node_or_null("MainContainer/TopBar/CoinSection/UnbankedCoins")
				multiplier_label = get_node_or_null("MainContainer/TopBar/CoinSection/Multiplier")
				shop_system = get_node_or_null("ShopSystem") as ShopSystem
				status_text = get_node_or_null("MainContainer/BottomBar/StatusSection/StatusText")
				damage_overlay = get_node_or_null("DamageOverlay")
				damage_indicator = get_node_or_null("DamageIndicator")
				
				# Connect shop button
				var shop_button = get_node_or_null("MainContainer/BottomBar/ControlsSection/ShopButton")
				if shop_button:
								shop_button.pressed.connect(_open_shop)
				
				# Connect game state signals
				if gs:
								gs.connect("coins_changed", func(v): if unbanked_label: unbanked_label.text = "At-Risk: %d" % v)
								gs.connect("banked_changed", func(v): if banked_label: banked_label.text = "Banked: %d" % v)
								gs.connect("bm_changed", func(v): if multiplier_label: multiplier_label.text = "BM ×%.1f" % v)
								gs.connect("risk_tier_changed", _on_heat)
				
				# Set up damage system
				set_process(true)

func _process(delta: float) -> void:
				# Update damage flash
				if damage_flash_timer > 0:
								damage_flash_timer -= delta
								if damage_overlay:
												damage_overlay.visible = true
												damage_overlay.color.a = damage_flash_timer * 0.5
				else:
								if damage_overlay:
									damage_overlay.visible = false
				
				# Update damage indicators
				for i in range(current_damage_indicators.size() - 1, -1, -1):
								var indicator = current_damage_indicators[i]
								if indicator.has_method("update"):
												indicator.update(delta)
												if indicator.is_finished():
														indicator.queue_free()
														current_damage_indicators.remove_at(i)

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
				# Update health bar
				if health_bar:
								health_bar.value = float(current_hp) / float(max_hp) * 100.0
				
				# Update health hearts display
				if health_hearts:
								# Clear existing hearts
								for child in health_hearts.get_children():
												child.queue_free()
								
								# Add hearts
								for i in range(max_hp):
												var heart_container = TextureRect.new()
												heart_container.expand_mode = TextureRect.EXPAND_FIT_WIDTH_PROPORTIONAL
												heart_container.custom_minimum_size = Vector2(32, 32)
												
												if i < current_hp:
																# Full heart - use red color
																heart_container.modulate = Color.RED
												else:
																# Empty heart - use dark red
																heart_container.modulate = Color.DARK_RED
												
												# Create a simple heart shape using a colored rectangle
												var heart_texture = PlaceholderTexture2D.new()
												heart_texture.size = Vector2(32, 32)
												heart_container.texture = heart_texture
												
												health_hearts.add_child(heart_container)
				
				# Update status based on health
				if status_text:
								if current_hp <= 0:
												status_text.text = "DEFEATED"
												status_text.modulate = Color.RED
								elif current_hp <= max_hp * 0.3:
												status_text.text = "CRITICAL"
												status_text.modulate = Color.ORANGE
								elif current_hp <= max_hp * 0.6:
												status_text.text = "DAMAGED"
												status_text.modulate = Color.YELLOW
								else:
												status_text.text = "Normal"
												status_text.modulate = Color.WHITE

func show_damage_effect(damage_amount: int, position: Vector2 = Vector2.ZERO) -> void:
				# Flash the screen
				damage_flash_timer = 0.3
				
				# Show damage indicator at position
				if position != Vector2.ZERO:
								_create_floating_damage(damage_amount, position)
				else:
								# Show centered damage indicator
								if damage_indicator:
												damage_indicator.text = "-%d" % damage_amount
												damage_indicator.visible = true
												damage_indicator.modulate = Color.RED
												
												# Hide after a short time
												await get_tree().create_timer(0.5).timeout
												damage_indicator.visible = false

func _create_floating_damage(damage_amount: int, position: Vector2) -> void:
				# Create a floating damage number
				var damage_label = Label.new()
				damage_label.text = "-%d" % damage_amount
				damage_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
				damage_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
				damage_label.modulate = Color.RED
				damage_label.add_theme_font_size_override("font_size", 20)
				damage_label.add_theme_color_override("font_outline_color", Color.BLACK)
				damage_label.add_theme_constant_override("outline_size", 2)
				
				# Position the label
				damage_label.global_position = position
				damage_label.z_index = 100
				
				# Add to scene
				add_child(damage_label)
				
				# Create floating animation
				var tween = create_tween()
				tween.set_parallel(true)
				tween.tween_property(damage_label, "position:y", position.y - 50, 1.0)
				tween.tween_property(damage_label, "modulate:a", 0.0, 1.0)
				
				# Remove after animation
				await tween.finished
				if damage_label and is_instance_valid(damage_label):
								damage_label.queue_free()

func update_furnace_status(phase: String) -> void:
				if status_text:
								match phase:
												"NORMAL":
																status_text.text = "Normal"
																status_text.modulate = Color.WHITE
												"SHAKING":
																status_text.text = "TRANSFORMING..."
																status_text.modulate = Color.ORANGE
												"MOBILE":
																status_text.text = "MOBILE PHASE"
																status_text.modulate = Color.RED

func show_game_over(victory: bool) -> void:
				if status_text:
								if victory:
												status_text.text = "VICTORY!"
												status_text.modulate = Color.GREEN
								else:
												status_text.text = "GAME OVER"
												status_text.modulate = Color.RED
