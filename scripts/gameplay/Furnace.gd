extends CharacterBody2D
class_name Furnace

@onready var rng: RNGService = get_node("/root/RNG") as RNGService
@onready var gs: GameStateData = get_node("/root/GameState") as GameStateData

# FIXED: Changed from @onready to @export so it appears in inspector
@export var bullet_pool_path: NodePath
@export var arena_path: NodePath  # Add this for flexible arena reference
var pool: BulletPool
var arena_node: Node2D  # Cache the arena node
var active_patterns: Array[String] = []

# Phase management
enum Phase { NORMAL, SHAKING, MOBILE }
var current_phase = Phase.NORMAL
var phase_timer = 0.0
var shake_intensity = 0.0

# Movement for mobile phase
var mobile_speed = 150.0
var movement_direction = Vector2.ZERO
var movement_change_timer = 0.0

# Visual elements
var sprite: Sprite2D
var original_scale = Vector2.ONE

# NEW: Sprite management - Add these exported variables
@export var normal_sprite: Texture2D
@export var mobile_sprite: Texture2D
var last_facing_direction = 1  # 1 for right, -1 for left

# Pattern timing
var pattern_cooldown = 0.0
var base_pattern_interval = 2.0

func _ready() -> void:
		print("FURNACE: _ready() called")
		add_to_group("furnace")
		
		# Get bullet pool
		if bullet_pool_path:
				pool = get_node(bullet_pool_path) as BulletPool
				print("Furnace: Bullet pool path found")
		
		# Get arena node - try multiple methods
		if arena_path:
				arena_node = get_node(arena_path) as Node2D
				print("Furnace: Arena found via path")
		elif get_parent() and get_parent().name == "Arena":
				arena_node = get_parent() as Node2D
				print("Furnace: Arena found as parent")
		else:
				# Try to find arena in the scene
				arena_node = get_tree().get_first_node_in_group("arena") as Node2D
				if arena_node:
						print("Furnace: Arena found via group")
				else:
						print("Furnace: Arena not found - shaking disabled")
		
		# Setup visual elements
		sprite = $Sprite2D if has_node("Sprite2D") else null
		original_scale = scale
		
		# Set initial sprite
		if sprite and normal_sprite:
				sprite.texture = normal_sprite
				print("Furnace: Normal sprite set")
		
		# Connect to game state signals
		gs.connect("risk_tier_changed", _on_heat_changed)
		gs.connect("pulse_started", _on_pulse_started)
		
		# Start normal phase
		_enter_normal_phase()
		print("Furnace: Ready complete")

func _process(delta: float) -> void:
		phase_timer += delta
		pattern_cooldown -= delta
		
		match current_phase:
				Phase.NORMAL:
						_process_normal_phase(delta)
				Phase.SHAKING:
						_process_shaking_phase(delta)
				Phase.MOBILE:
						_process_mobile_phase(delta)

func _process_normal_phase(delta: float) -> void:
		# Check if it's time to enter shaking phase (after 60 seconds)
		if phase_timer >= 60.0:
				_enter_shaking_phase()
				return
		
		# Normal shooting patterns
		if pattern_cooldown <= 0 and active_patterns.size() < get_max_patterns():
				_start_random_pattern()
				pattern_cooldown = base_pattern_interval

func _process_shaking_phase(delta: float) -> void:
		# Shake effect
		shake_intensity = max(0.0, shake_intensity - delta * 5.0)
		var shake_offset = Vector2(
				rng.randf_range(-shake_intensity, shake_intensity),
				rng.randf_range(-shake_intensity, shake_intensity)
		)
		
		# Use arena_node if available, otherwise use current position as fallback
		if arena_node:
				position = arena_node.global_position + shake_offset
		else:
				# Fallback: just shake in place
				position = global_position + shake_offset
		
		# After 2 seconds, enter mobile phase
		if phase_timer >= 2.0:
				_enter_mobile_phase()

func _process_mobile_phase(delta: float) -> void:
		# Movement
		movement_change_timer -= delta
		if movement_change_timer <= 0:
				_change_movement_direction()
				movement_change_timer = rng.randf_range(1.0, 3.0)
		
		# Move and stay within arena bounds - use arena_node if available
		var arena_center: Vector2
		var arena_radius: float
		
		if arena_node:
				arena_center = arena_node.global_position
				# Try to get shrink_level from arena script
				if arena_node.has_method("get_shrink_level"):
						arena_radius = 200.0 * (1.0 - arena_node.get_shrink_level())
				else:
						arena_radius = 200.0  # Fallback
		else:
				# Fallback: use current position as center
				arena_center = global_position
				arena_radius = 300.0  # Larger fallback radius
		
		var next_pos = global_position + movement_direction * mobile_speed * delta
		var distance_from_center = (next_pos - arena_center).length()
		
		if distance_from_center <= arena_radius:
				global_position = next_pos
		else:
				# Bounce off arena edge
				_change_movement_direction()
		
		# Update sprite facing direction
		_update_sprite_facing()
		
		# More aggressive shooting in mobile phase
		if pattern_cooldown <= 0 and active_patterns.size() < get_max_patterns() + 1:
				_start_random_pattern()
				pattern_cooldown = base_pattern_interval * 0.7

func _update_sprite_facing() -> void:
		if not sprite:
				return
		
		# Check if we're moving left or right
		if movement_direction.x > 0.1:
				# Moving right
				if last_facing_direction == -1:
						sprite.flip_h = false
						last_facing_direction = 1
		elif movement_direction.x < -0.1:
				# Moving left
				if last_facing_direction == 1:
						sprite.flip_h = true
						last_facing_direction = -1

func _enter_normal_phase() -> void:
		current_phase = Phase.NORMAL
		phase_timer = 0.0
		print("Furnace entered NORMAL phase")
		
		# Reset sprite
		if sprite and normal_sprite:
				sprite.texture = normal_sprite
				sprite.modulate = Color.WHITE
				scale = original_scale
				sprite.flip_h = false
				last_facing_direction = 1

func _enter_shaking_phase() -> void:
		current_phase = Phase.SHAKING
		phase_timer = 0.0
		shake_intensity = 10.0
		print("Furnace entered SHAKING phase")
		
		# Change visual appearance
		if sprite:
				sprite.modulate = Color.RED
		
		# Stop all current patterns
		active_patterns.clear()

func _enter_mobile_phase() -> void:
		current_phase = Phase.MOBILE
		phase_timer = 0.0
		print("Furnace entered MOBILE phase")
		
		# Change visual appearance to mobile form
		if sprite and mobile_sprite:
				sprite.texture = mobile_sprite
				sprite.modulate = Color.ORANGE
				scale = original_scale * 1.2  # Make it slightly larger
		else:
				# Fallback if no mobile sprite
				if sprite:
						sprite.modulate = Color.ORANGE
						scale = original_scale * 1.2
		
		# Start moving
		_change_movement_direction()

func _change_movement_direction() -> void:
		var angle = rng.randf_range(0, TAU)
		movement_direction = Vector2.RIGHT.rotated(angle)

func get_max_patterns() -> int:
		return 1 + int(gs.heat / 2)

func _start_random_pattern() -> void:
		var patterns = ["radial", "spiral", "aimed", "wall", "orbit", "flower"]
		
		# Add more dangerous patterns in mobile phase
		if current_phase == Phase.MOBILE:
				patterns.append_array(["cross_fire", "spiral_burst", "chaos_orb"])
		
		# Make sure patterns array is not empty
		if patterns.size() == 0:
				return
		
		var random_index = rng.randi() % patterns.size()
		var pattern = patterns[random_index]
		_start_pattern(pattern)

func _start_pattern(pattern_name: String) -> void:
		if active_patterns.has(pattern_name):
				return
		
		active_patterns.append(pattern_name)
		
		match pattern_name:
				"radial": await _radial_burst()
				"spiral": await _spiral_stream()
				"aimed": await _aimed_volley()
				"wall": await _wall_sweep()
				"orbit": await _orbit_mines()
				"flower": await _flower_pulse()
				"cross_fire": await _cross_fire()
				"spiral_burst": await _spiral_burst()
				"chaos_orb": await _chaos_orb()
		
		active_patterns.erase(pattern_name)

# --- Enhanced Pattern Implementations ---

func _radial_burst() -> void:
		var n = 12 + gs.heat * 6
		var speed = 120.0 + gs.heat * 30.0
		
		for i in range(n):
				var ang = TAU * (float(i)/n)
				_fire_fireball(global_position, Vector2.RIGHT.rotated(ang) * speed, 4.0)
		
		await get_tree().create_timer(1.0).timeout

func _spiral_stream() -> void:
		var rpm = 60.0 + gs.heat * 20.0
		var speed = 100.0 + gs.heat * 25.0
		var t = 0.0
		var dur = 2.0
		
		while t < dur:
				var ang = deg_to_rad((t * rpm) * 6.0)
				_fire_fireball(global_position, Vector2.RIGHT.rotated(ang) * speed, 4.0)
				t += 0.08
				await get_tree().create_timer(0.08).timeout

func _aimed_volley() -> void:
		var player = get_tree().get_first_node_in_group("player") as Node2D
		if not player: return
		
		var spread = deg_to_rad(10.0 + gs.heat * 5.0)
		var dir = (player.global_position - global_position).angle()
		
		for angle in [dir-spread, dir, dir+spread]:
				_fire_fireball(global_position, Vector2.RIGHT.rotated(angle) * 180.0, 4.0)
		
		await get_tree().create_timer(0.6).timeout

func _wall_sweep() -> void:
		# Enhanced wall sweep with laser-like behavior
		var rect = get_viewport_rect()
		var size = rect.size
		var heat = gs.heat
		var cols = 8 + heat * 2
		var speed = 160.0 + heat * 30.0
		
		var col_spacing = size.x / float(cols + 1)
		var mode = rng.randi_range(0, 3)
		
		match mode:
				0: # Horizontal laser sweep
						var life = (size.x + 120.0) / speed
						for i in range(cols):
								var x_pos = rect.position.x + (i + 1) * col_spacing
								var pos = Vector2(x_pos, rect.position.y - 40.0)
								_fire_laser(pos, Vector2(0, speed), life)
								await get_tree().create_timer(0.1).timeout
				1: # Vertical laser sweep
						var life = (size.y + 120.0) / speed
						for i in range(cols):
								var y_pos = rect.position.y + (i + 1) * col_spacing
								var pos = Vector2(rect.position.x - 40.0, y_pos)
								_fire_laser(pos, Vector2(speed, 0), life)
								await get_tree().create_timer(0.1).timeout
				2: # Cross pattern
						var life = max(size.x, size.y) / speed
						# Horizontal line
						for i in range(cols):
								var x_pos = rect.position.x + (i + 1) * col_spacing
								var pos = Vector2(x_pos, global_position.y)
								_fire_laser(pos, Vector2.RIGHT * speed, life)
						# Vertical line
						for i in range(cols):
								var y_pos = rect.position.y + (i + 1) * col_spacing
								var pos = Vector2(global_position.x, y_pos)
								_fire_laser(pos, Vector2.DOWN * speed, life)
						await get_tree().create_timer(0.8).timeout

func _orbit_mines() -> void:
		var count = 2 + gs.heat
		for i in range(count):
				var ang = TAU * (float(i)/count)
				var pos = global_position + Vector2.RIGHT.rotated(ang) * 60.0
				_fire_fireball(pos, Vector2.ZERO, 2.0)
				await get_tree().create_timer(0.5).timeout
		
		# Detach phase
		for i in range(count):
				var ang = TAU * (float(i)/count)
				_fire_fireball(global_position, Vector2.RIGHT.rotated(ang) * 140.0, 3.0)
		
		await get_tree().create_timer(0.8).timeout

func _flower_pulse() -> void:
		var petals = 10 + gs.heat * 2
		var speed = 120.0 + gs.heat * 20.0
		var waves = 6 + gs.heat
		
		for w in range(waves):
				var phase = w * 0.35
				for i in range(petals):
						var ang = TAU * i/float(petals) + phase
						_fire_fireball(global_position, Vector2.RIGHT.rotated(ang) * speed, 5.0)
				await get_tree().create_timer(0.25).timeout

# --- New Mobile Phase Patterns ---

func _cross_fire() -> void:
		var speed = 150.0 + gs.heat * 25.0
		var life = 4.0
		
		# Fire in 8 directions
		for i in range(8):
				var ang = TAU * i / 8.0
				_fire_fireball(global_position, Vector2.RIGHT.rotated(ang) * speed, life)
		
		await get_tree().create_timer(0.5).timeout

func _spiral_burst() -> void:
		var spirals = 3 + gs.heat
		var speed = 120.0 + gs.heat * 20.0
		
		for s in range(spirals):
				var offset_angle = TAU * s / spirals
				for i in range(12):
						var ang = offset_angle + (TAU * i / 12.0)
						_fire_fireball(global_position, Vector2.RIGHT.rotated(ang) * speed, 4.0)
				await get_tree().create_timer(0.2).timeout

func _chaos_orb() -> void:
		var orbs = 4 + gs.heat
		var speed = 100.0
		
		for i in range(orbs):
				var ang = rng.randf_range(0, TAU)
				var pos = global_position + Vector2.RIGHT.rotated(ang) * 80.0
				var vel = Vector2.RIGHT.rotated(ang + rng.randf_range(-0.5, 0.5)) * speed
				_fire_fireball(pos, vel, 3.0)
		
		await get_tree().create_timer(0.8).timeout

# --- Bullet Firing Methods ---

func _fire_fireball(pos: Vector2, vel: Vector2, life: float, damage: int = 1) -> void:
		if pool:
				# Rotate velocity 90 degrees counter-clockwise
				var rotated_vel = vel.rotated(deg_to_rad(-90))
				pool.fire_fireball(pos, rotated_vel, life, damage)
		else:
				push_warning("Furnace: Bullet pool not connected!")

func _fire_laser(pos: Vector2, vel: Vector2, life: float, damage: int = 2) -> void:
		if pool:
				# Rotate velocity 90 degrees counter-clockwise
				var rotated_vel = vel.rotated(deg_to_rad(-90))
				pool.fire_laser(pos, rotated_vel, life, damage)
		else:
				push_warning("Furnace: Bullet pool not connected!")

# --- Signal Handlers ---

func _on_heat_changed(_tier: int) -> void:
		# Adjust difficulty based on heat
		pass

func _on_pulse_started() -> void:
		await _flower_pulse()
		gs.pulse_end(true)
