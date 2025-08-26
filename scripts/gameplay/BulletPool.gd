extends Node
class_name BulletPool

const MAX_BULLETS := 400
@export var bullet_scene: PackedScene
@export var default_fireball_sprite: Texture2D
@export var default_laser_sprite: Texture2D
@export var default_fireball_particle_texture: Texture2D
@export var default_laser_particle_texture: Texture2D
var pool: Array[Bullet] = []

func _ready() -> void:
		pool.resize(MAX_BULLETS)
		for i in range(MAX_BULLETS):
				var b := bullet_scene.instantiate() as Bullet
				b.visible = false
				b.monitoring = false
				
				# Apply default sprites if not already set
				if not b.fireball_sprite and default_fireball_sprite:
						b.fireball_sprite = default_fireball_sprite
				if not b.laser_sprite and default_laser_sprite:
						b.laser_sprite = default_laser_sprite
				if not b.fireball_particle_texture and default_fireball_particle_texture:
						b.fireball_particle_texture = default_fireball_particle_texture
				if not b.laser_particle_texture and default_laser_particle_texture:
						b.laser_particle_texture = default_laser_particle_texture
				
				add_child(b)
				pool[i] = b

func get_bullet() -> Bullet:
		for b in pool:
				if not b.alive:
						return b
		return null

func fire_fireball(pos: Vector2, vel: Vector2, life: float, damage: int = 1) -> void:
		var b := get_bullet()
		if b:
				b.bullet_type = Bullet.BulletType.FIREBALL
				b.is_laser = false
				b.damage = damage
				b.fire(pos, vel, life)

func fire_laser(pos: Vector2, vel: Vector2, life: float, damage: int = 1) -> void:
		var b := get_bullet()
		if b:
				b.bullet_type = Bullet.BulletType.LASER
				b.is_laser = true
				b.damage = damage
				b.fire(pos, vel, life)

# Legacy method for backward compatibility
func fire(pos: Vector2, vel: Vector2, life: float) -> void:
		fire_fireball(pos, vel, life, 1)
