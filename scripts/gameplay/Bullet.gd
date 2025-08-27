extends Area2D
class_name Bullet

@export var speed := 140.0
var velocity := Vector2.ZERO
var lifetime := 4.0
var alive := false

# Bullet type and properties
enum BulletType { FIREBALL, LASER }
var bullet_type = BulletType.FIREBALL
var is_laser := false
var damage := 1

# Visual effects - NOW EXPORTED FOR INSPECTOR!
@export var fireball_sprite: Texture2D
@export var laser_sprite: Texture2D
@export var fireball_particle_texture: Texture2D
@export var laser_particle_texture: Texture2D

# Visual settings
@export var fireball_scale: Vector2 = Vector2(1, 1)
@export var laser_scale: Vector2 = Vector2(0.3, 2.0)
@export var fireball_color: Color = Color.ORANGE
@export var laser_color: Color = Color.RED
@export var fireball_tilt_degrees: float = 0.0  # Removed the bottom-left tilt

var original_scale := Vector2.ONE
var trail_particles: GPUParticles2D

func _ready() -> void:
				original_scale = scale
				
				# Set up default sprites if none assigned
				if not fireball_sprite:
								fireball_sprite = create_default_texture(fireball_color, Vector2(16, 16))
				if not laser_sprite:
								laser_sprite = create_default_texture(laser_color, Vector2(8, 32))
				if not fireball_particle_texture:
								fireball_particle_texture = fireball_sprite
				if not laser_particle_texture:
								laser_particle_texture = laser_sprite
				
				# Create visual elements based on bullet type
				if bullet_type == BulletType.FIREBALL:
								_setup_fireball_trail()
				elif bullet_type == BulletType.LASER:
								_setup_laser_visual()

func create_default_texture(color: Color, size: Vector2) -> Texture2D:
				# Create a simple colored rectangle as fallback texture
				var image = Image.create(size.x, size.y, false, Image.FORMAT_RGBA8)
				image.fill(color)
				return ImageTexture.create_from_image(image)

func _setup_fireball_trail() -> void:
				trail_particles = GPUParticles2D.new()
				trail_particles.amount = 6  # Reduced from 10 to 6
				trail_particles.lifetime = 0.3  # Reduced from 0.5 to 0.3
				trail_particles.process_material = create_fireball_material()
				trail_particles.texture = fireball_particle_texture
				trail_particles.emitting = false
				add_child(trail_particles)

func _setup_laser_visual() -> void:
				# Set laser visual properties
				if has_node("Sprite2D"):
								var sprite = $Sprite2D
								sprite.scale = laser_scale
								sprite.modulate = laser_color

func create_fireball_material() -> ParticleProcessMaterial:
				var material = ParticleProcessMaterial.new()
				material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_POINT
				material.direction = Vector3(0, 0, -1)
				material.spread = 120.0  # Reduced from 180.0 to 120.0 for more focused trail
				material.gravity = Vector3.ZERO
				material.initial_velocity_min = 20.0  # Increased from 10.0
				material.initial_velocity_max = 40.0  # Increased from 30.0
				material.scale_min = 0.2  # Reduced from 0.5 for smaller particles
				material.scale_max = 0.4  # Reduced from 1.0 for smaller particles
				material.color = fireball_color
				material.emission_sphere_radius = 3.0  # Reduced from 5.0
				return material

func fire(pos: Vector2, vel: Vector2, life: float) -> void:
				global_position = pos
				velocity = vel
				lifetime = life
				alive = true
				visible = true
				monitoring = true
				
				# Set appropriate sprite based on bullet type
				if has_node("Sprite2D"):
								var sprite = $Sprite2D
								match bullet_type:
												BulletType.FIREBALL:
																sprite.texture = fireball_sprite
																sprite.scale = fireball_scale
																sprite.modulate = fireball_color
												BulletType.LASER:
																sprite.texture = laser_sprite
																sprite.scale = laser_scale
																sprite.modulate = laser_color
				
				# Start particle effects
				if trail_particles:
								trail_particles.emitting = true
				
				# Set rotation based on velocity direction
				if vel != Vector2.ZERO:
								rotation = vel.angle()
								# Apply fireball tilt (if any)
								if bullet_type == BulletType.FIREBALL:
												rotation += deg_to_rad(fireball_tilt_degrees)

func _physics_process(delta: float) -> void:
				if not alive:
								return
				
				lifetime -= delta
				if lifetime <= 0.0:
								_despawn()
								return
				
				global_position += velocity * delta
				
				# Update particle position for fireballs
				if trail_particles and bullet_type == BulletType.FIREBALL:
								trail_particles.global_position = global_position - velocity.normalized() * 10

func _on_body_entered(body: Node) -> void:
				print("Bullet hit: ", body.name)
				if body.is_in_group("player"):
								print("Bullet hit player!")
								# Apply damage to player
								var player = body as Player
								if player:
												print("Player reference obtained, calling take_damage...")
												player.take_damage(damage)
												# Create impact effect
												_create_impact_effect(global_position)
								else:
												print("Failed to cast to Player")
								_despawn()
				else:
								print("Bullet hit non-player object: ", body.name)

func _create_impact_effect(pos: Vector2) -> void:
				# Create impact particles
				var impact_particles = GPUParticles2D.new()
				impact_particles.amount = 12  # Reduced from 20
				impact_particles.lifetime = 0.2  # Reduced from 0.3
				impact_particles.one_shot = true
				impact_particles.process_material = create_impact_material()
				
				# Set appropriate impact texture
				match bullet_type:
								BulletType.FIREBALL:
												impact_particles.texture = fireball_particle_texture
								BulletType.LASER:
												impact_particles.texture = laser_particle_texture
				
				impact_particles.global_position = pos
				get_tree().root.add_child(impact_particles)
				
				# Remove particles after they finish
				await get_tree().create_timer(0.3).timeout  # Reduced from 0.5
				if impact_particles and is_instance_valid(impact_particles):
								impact_particles.queue_free()

func create_impact_material() -> ParticleProcessMaterial:
				var material = ParticleProcessMaterial.new()
				material.emission_shape = ParticleProcessMaterial.EMISSION_SHAPE_SPHERE
				material.direction = Vector3(0, 0, 1)
				material.spread = 180.0
				material.gravity = Vector3.ZERO
				material.initial_velocity_min = 60.0  # Increased from 50.0
				material.initial_velocity_max = 120.0  # Increased from 100.0
				material.scale_min = 0.1  # Reduced from 0.2
				material.scale_max = 0.3  # Reduced from 0.8
				
				# Use appropriate color based on bullet type
				match bullet_type:
								BulletType.FIREBALL:
												material.color = fireball_color
								BulletType.LASER:
												material.color = laser_color
				
				return material

func _despawn() -> void:
				alive = false
				visible = false
				monitoring = false
				
				# Stop particle effects
				if trail_particles:
								trail_particles.emitting = false
