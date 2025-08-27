extends Control
class_name ShopSystem

@onready var save: Node = get_node("/root/Save")
@onready var gs: GameStateData = get_node("/root/GameState") as GameStateData

signal shop_closed()

# Shop items data
var shop_items = [
		{
				"id": "health_upgrade",
				"name": "Health Upgrade",
				"description": "Increase max HP by 1",
				"cost": 100,
				"max_level": 5,
				"upgrade_key": "hp"
		},
		{
				"id": "speed_upgrade",
				"name": "Speed Boost",
				"description": "Increase movement speed by 10%",
				"cost": 80,
				"max_level": 3,
				"upgrade_key": "move"
		},
		{
				"id": "dash_upgrade",
				"name": "Dash Enhancement",
				"description": "Increase dash invulnerability frames",
				"cost": 120,
				"max_level": 3,
				"upgrade_key": "dash_iframes"
		},
		{
				"id": "coin_magnet",
				"name": "Coin Magnet",
				"description": "Increase coin collection range",
				"cost": 150,
				"max_level": 2,
				"upgrade_key": "coin_rate"
		},
		{
				"id": "fast_cashout",
				"name": "Fast Cashout",
				"description": "Reduce cashout channeling time",
				"cost": 90,
				"max_level": 3,
				"upgrade_key": "cashout"
		},
		{
				"id": "insurance",
				"name": "Death Insurance",
				"description": "Salvage 5% of coins on death",
				"cost": 200,
				"max_level": 1,
				"upgrade_key": "insurance"
		}
]

var current_category = "upgrades"
var shop_visible = false

func _ready() -> void:
		visible = false
		_setup_shop_ui()

func _setup_shop_ui() -> void:
		# Clear existing shop UI except the basic structure
		var shop_panel = get_node_or_null("ShopPanel")
		if shop_panel:
				# Clear existing children
				for child in shop_panel.get_children():
						if not child.is_in_group("keep_in_shop"):
								child.queue_free()
		else:
				shop_panel = Panel.new()
				shop_panel.name = "ShopPanel"
				shop_panel.set_anchors_and_offsets_preset(Control.PRESET_CENTER)
				shop_panel.size = Vector2(600, 400)
				shop_panel.add_to_group("keep_in_shop")
				add_child(shop_panel)
		
		# Shop title
		var title = Label.new()
		title.text = "FURNACE SHOP"
		title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		title.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		title.add_theme_font_size_override("font_size", 24)
		shop_panel.add_child(title)
		
		# Coins display
		var coins_label = Label.new()
		coins_label.name = "CoinsLabel"
		coins_label.text = "Coins: %d" % save.data.get("coins_banked", 0)
		coins_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		coins_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		shop_panel.add_child(coins_label)
		
		# Categories
		var categories = HBoxContainer.new()
		categories.name = "Categories"
		
		var upgrade_btn = Button.new()
		upgrade_btn.text = "Upgrades"
		upgrade_btn.pressed.connect(func(): _show_category("upgrades"))
		categories.add_child(upgrade_btn)
		
		var items_btn = Button.new()
		items_btn.text = "Items"
		items_btn.pressed.connect(func(): _show_category("items"))
		categories.add_child(items_btn)
		
		shop_panel.add_child(categories)
		
		# Items container
		var scroll_container = ScrollContainer.new()
		scroll_container.name = "ScrollContainer"
		scroll_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
		shop_panel.add_child(scroll_container)
		
		var items_container = VBoxContainer.new()
		items_container.name = "ItemsContainer"
		items_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		scroll_container.add_child(items_container)
		
		# Close button
		var close_btn = Button.new()
		close_btn.name = "CloseButton"
		close_btn.text = "Close (ESC)"
		close_btn.pressed.connect(_close_shop)
		close_btn.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
		close_btn.add_to_group("keep_in_shop")
		shop_panel.add_child(close_btn)
		
		# Show initial category
		_show_category("upgrades")

func _show_category(category: String) -> void:
		current_category = category
		var items_container = get_node("ShopPanel/ScrollContainer/ItemsContainer")
		
		# Clear existing items
		for child in items_container.get_children():
				child.queue_free()
		
		match category:
				"upgrades":
						_show_upgrades(items_container)
				"items":
						_show_items(items_container)

func _show_upgrades(container: VBoxContainer) -> void:
		for item_data in shop_items:
				var current_level = save.get_upgrade(item_data.upgrade_key)
				var can_afford = save.data.get("coins_banked", 0) >= item_data.cost
				var can_upgrade = current_level < item_data.max_level
				
				var item_panel = Panel.new()
				item_panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				container.add_child(item_panel)
				
				var item_content = VBoxContainer.new()
				item_content.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				item_panel.add_child(item_content)
				
				# Item name and level
				var name_label = Label.new()
				name_label.text = "%s (Level %d/%d)" % [item_data.name, current_level, item_data.max_level]
				name_label.add_theme_font_size_override("font_size", 16)
				item_content.add_child(name_label)
				
				# Description
				var desc_label = Label.new()
				desc_label.text = item_data.description
				desc_label.add_theme_color_override("font_color", Color.GRAY)
				item_content.add_child(desc_label)
				
				# Cost and buy button
				var cost_container = HBoxContainer.new()
				item_content.add_child(cost_container)
				
				var cost_label = Label.new()
				cost_label.text = "Cost: %d" % item_data.cost
				cost_label.size_flags_horizontal = Control.SIZE_EXPAND_FILL
				cost_container.add_child(cost_label)
				
				var buy_btn = Button.new()
				if can_upgrade and can_afford:
						buy_btn.text = "Buy"
						buy_btn.pressed.connect(func(): _buy_upgrade(item_data))
				elif not can_upgrade:
						buy_btn.text = "MAX"
						buy_btn.disabled = true
				else:
						buy_btn.text = "Can't Afford"
						buy_btn.disabled = true
				cost_container.add_child(buy_btn)

func _show_items(container: VBoxContainer) -> void:
		# Placeholder for consumable items
		var placeholder = Label.new()
		placeholder.text = "Consumable items coming soon!"
		placeholder.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		placeholder.add_theme_font_size_override("font_size", 18)
		container.add_child(placeholder)

func _buy_upgrade(item_data: Dictionary) -> void:
		var current_coins = save.data.get("coins_banked", 0)
		
		if current_coins >= item_data.cost:
				# Deduct cost
				save.data["coins_banked"] = current_coins - item_data.cost
				
				# Apply upgrade
				save.inc_upgrade(item_data.upgrade_key)
				
				# Update UI
				_update_coins_display()
				_show_category(current_category)  # Refresh the shop
				
				print("Purchased upgrade: %s" % item_data.name)

func _update_coins_display() -> void:
		var coins_label = get_node_or_null("ShopPanel/CoinsLabel")
		if coins_label:
				coins_label.text = "Coins: %d" % save.data.get("coins_banked", 0)

func open_shop() -> void:
		if not shop_visible:
				shop_visible = true
				visible = true
				_update_coins_display()
				# Pause the game
				get_tree().paused = true

func _close_shop() -> void:
		shop_visible = false
		visible = false
		# Resume the game
		get_tree().paused = false
		shop_closed.emit()

func _input(event: InputEvent) -> void:
				if event.is_action_pressed("ui_cancel") and shop_visible:
								_close_shop()
				elif event.is_action_pressed("Shop") and shop_visible:
								_close_shop()
