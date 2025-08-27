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
var original_position = Vector2.ZERO

# Movement for mobile phase
var mobile_speed = 150.0
var movement_direction = Vector2.ZERO
var movement_change_timer = 0.0

# Path-based movement system
var path_points: Array[Vector2] = []
var current_path_index = 0
var path_progress = 0.0
var movement_pattern = "circle"  # circle, figure8, spiral, random

# Visual elements
var sprite: Sprite2D
var original_scale = Vector2.ONE

# Camera shake
var camera: Camera2D
var camera_shake_intensity = 0.0

# NEW: Sprite management - Load sprites directly
var normal_sprite: Texture2D
var mobile_sprite: Texture2D
var last_facing_direction = 1  # 1 for right, -1 for left

# Pattern timing
var pattern_cooldown = 0.0
var base_pattern_interval = 2.0

func _ready() -> void:
				print("FURNACE: _ready() called")
				add_to_group("furnace")
				
				# Store original position
				original_position = global_position
				
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
				
				# Get camera for shake effects
				camera = get_tree().get_first_node_in_group("camera") as Camera2D
				if not camera:
								camera = get_viewport().get_camera_2d()
				if camera:
								print("Furnace: Camera found for shake effects")
				else:
								print("Furnace: Camera not found - shake effects disabled")
				
				# Setup visual elements
				sprite = $Furnace if has_node("Furnace") else null
				original_scale = scale
				
				# Load sprites directly
				normal_sprite = load("res://art/furnace-64x64.png")
				mobile_sprite = load("res://art/furnace-walking-64x64.png")
				
				print("Furnace: Loaded normal sprite: ", normal_sprite != null)
				print("Furnace: Loaded mobile sprite: ", mobile_sprite != null)
				
				# Set initial sprite
				if sprite and normal_sprite:
								sprite.texture = normal_sprite
								print("Furnace: Normal sprite set successfully")
				else:
								print("Furnace: Failed to set normal sprite - sprite=", sprite, " normal_sprite=", normal_sprite)
				
				# Connect to game state signals
				gs.connect("risk_tier_changed", _on_heat_changed)
				gs.connect("pulse_started", _on_pulse_started)
				
				# Start normal phase
				_enter_normal_phase()
				print("Furnace: Ready complete")

func _process(delta: float) -> void:
				phase_timer += delta
				pattern_cooldown -= delta
				
				# Update camera shake
				if camera_shake_intensity > 0:
								camera_shake_intensity -= delta * 5.0
								_apply_camera_shake()
				
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
				# No more furnace shaking - only camera shake
				# After 2 seconds, enter mobile phase
				if phase_timer >= 2.0:
								_enter_mobile_phase()

func _process_mobile_phase(delta: float) -> void:
				# Setup movement pattern on first frame
				if phase_timer == 0:
								print("Furnace: Mobile phase started")
								_setup_movement_pattern()
				
				# Always process movement
				_update_pattern_movement(delta)
				
				# Debug: Print movement status
				if fmod(phase_timer, 2.0) < delta:  # Print every 2 seconds
								print("Furnace mobile phase active - pos: ", global_position, " velocity: ", velocity)
				
				# Update sprite facing direction based on movement
				_update_sprite_facing()
				
				# More aggressive shooting in mobile phase
				if pattern_cooldown <= 0 and active_patterns.size() < get_max_patterns() + 1:
								_start_random_pattern()
								pattern_cooldown = base_pattern_interval * 0.7

func _setup_movement_pattern() -> void:
				# Choose a random movement pattern
				var patterns = ["circle", "figure8", "spiral", "random"]
				movement_pattern = patterns[rng.randi() % patterns.size()]
				print("Furnace: Movement pattern set to: ", movement_pattern)
				
				# Get arena center
				var arena_center = global_position
				if arena_node:
								arena_center = arena_node.global_position
				
				# Setup path points based on pattern
				path_points.clear()
				current_path_index = 0
				path_progress = 0.0
				
				match movement_pattern:
								"circle":
												# Create circular path
												var radius = 150.0
												for i in range(8):
																var angle = (TAU * i) / 8.0
																path_points.append(arena_center + Vector2.RIGHT.rotated(angle) * radius)
								"figure8":
												# Create figure-8 path
												var radius_x = 120.0
												var radius_y = 80.0
												for i in range(12):
																var t = (float(i) / 12.0) * TAU
																var x = arena_center.x + radius_x * sin(t)
																var y = arena_center.y + radius_y * sin(t * 2.0)
																path_points.append(Vector2(x, y))
								"spiral":
												# Create spiral path
												for i in range(16):
																var angle = (TAU * i) / 16.0
																var radius = 50.0 + (i * 8.0)
																path_points.append(arena_center + Vector2.RIGHT.rotated(angle) * radius)
								"random":
												# Create random waypoints
												for i in range(6):
																var random_offset = Vector2(
																				rng.randf_range(-150.0, 150.0),
																				rng.randf_range(-150.0, 150.0)
																)
																path_points.append(arena_center + random_offset)

func _update_pattern_movement(delta: float) -> void:
				# Fallback: If no path points, use simple movement
				if path_points.size() == 0:
								# Simple fallback movement
								movement_change_timer -= delta
								if movement_change_timer <= 0:
												_change_movement_direction()
												movement_change_timer = rng.randf_range(2.0, 4.0)
								
								velocity = movement_direction * mobile_speed
								move_and_slide()
								return
				
				# Move along the path
				var target_point = path_points[current_path_index]
				var direction = (target_point - global_position).normalized()
				var distance = global_position.distance_to(target_point)
				
				# Move towards target
				if distance > 10.0:  # Increased threshold for smoother movement
								# Set velocity and move
								velocity = direction * mobile_speed
								var result = move_and_slide()
								
								# Debug movement
								if phase_timer < 1.0:  # Only print for first second of mobile phase
												print("Furnace moving: pos=", global_position, " target=", target_point, " dist=", distance)
				else:
								# Reached target, move to next point
								current_path_index = (current_path_index + 1) % path_points.size()
								print("Furnace reached waypoint, moving to next")
								if current_path_index == 0:
												# Completed a full cycle, maybe change pattern
												if rng.randf() < 0.3:  # 30% chance to change pattern
																print("Furnace changing movement pattern")
																_setup_movement_pattern()

func _update_sprite_facing() -> void:
				if not sprite:
								return
				
				# Update sprite facing based on movement direction
				if velocity.length() > 0.1:
								var movement_dir = velocity.normalized()
								if movement_dir.x > 0.1:
												# Moving right
												if last_facing_direction == -1:
																sprite.flip_h = false
																last_facing_direction = 1
								elif movement_dir.x < -0.1:
												# Moving left
												if last_facing_direction == 1:
																sprite.flip_h = true
																last_facing_direction = -1

func _enter_normal_phase() -> void:
				current_phase = Phase.NORMAL
				phase_timer = 0.0
				print("Furnace entered NORMAL phase")
				
				# Reset sprite to normal sprite
				if sprite and normal_sprite:
								if sprite.texture != normal_sprite:
												sprite.texture = normal_sprite
												print("Furnace: Changed to normal sprite")
								sprite.modulate = Color.WHITE
								scale = original_scale
								sprite.flip_h = false
								last_facing_direction = 1
								print("Furnace: Set to normal sprite")
				
				# Update UI status
				_update_ui_status("NORMAL")

func _change_movement_direction() -> void:
				var angle = rng.randf_range(0, TAU)
				movement_direction = Vector2.RIGHT.rotated(angle)
				print("Furnace: Changed movement direction to: ", movement_direction)

func _update_ui_status(phase: String) -> void:
				var ui = get_tree().get_first_node_in_group("ui")
				if ui and ui.has_method("update_furnace_status"):
								ui.update_furnace_status(phase)

func _enter_shaking_phase() -> void:
				current_phase = Phase.SHAKING
				phase_timer = 0.0
				shake_intensity = 10.0
				camera_shake_intensity = 15.0  # Start camera shake
				print("Furnace entered SHAKING phase")
				
				# Change visual appearance
				if sprite:
								sprite.modulate = Color.RED
				
				# Stop all current patterns and prevent shooting during shaking
				active_patterns.clear()
				pattern_cooldown = 3.0  # Prevent shooting for 3 seconds (2s shake + 1s buffer)
				
				# Update UI status
				_update_ui_status("SHAKING")

func _enter_mobile_phase() -> void:
				current_phase = Phase.MOBILE
				phase_timer = 0.0
				print("Furnace entered MOBILE phase")
				
				# Store the current position as the new original position for mobile phase
				original_position = global_position
				
				# Change visual appearance to mobile form
				if sprite and mobile_sprite:
								sprite.texture = mobile_sprite
								sprite.modulate = Color.ORANGE
								scale = original_scale * 1.2  # Make it slightly larger
								print("Furnace: Mobile sprite set to: ", mobile_sprite.resource_path if mobile_sprite else "null")
				else:
								# Fallback if no mobile sprite
								if sprite:
												sprite.modulate = Color.ORANGE
												scale = original_scale * 1.2
								print("Furnace: No mobile sprite available, using fallback")
				
				# Start moving
				_change_movement_direction()
				print("Furnace: Started moving with direction: ", movement_direction)
				
				# Update UI status
				_update_ui_status("MOBILE")

func _apply_camera_shake() -> void:
				if camera:
								var shake_offset = Vector2(
												rng.randf_range(-camera_shake_intensity, camera_shake_intensity),
												rng.randf_range(-camera_shake_intensity, camera_shake_intensity)
								)
								camera.offset = shake_offset

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
								# Remove the 90-degree rotation - fire directly in the intended direction
								pool.fire_fireball(pos, vel, life, damage)
				else:
								push_warning("Furnace: Bullet pool not connected!")

func _fire_laser(pos: Vector2, vel: Vector2, life: float, damage: int = 2) -> void:
				if pool:
								# Remove the 90-degree rotation - fire directly in the intended direction
								pool.fire_laser(pos, vel, life, damage)
				else:
								push_warning("Furnace: Bullet pool not connected!")

# --- Signal Handlers ---

func _on_heat_changed(_tier: int) -> void:
				# Adjust difficulty based on heat
				pass

func _on_pulse_started() -> void:
				await _flower_pulse()
				gs.pulse_end(true)
