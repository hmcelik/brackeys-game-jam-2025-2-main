extends CharacterBody2D
class_name Player

@onready var save: Node = get_node("/root/Save")
@onready var gs: GameState = get_node("/root/GameState") as GameState

const BASE_SPEED := 220.0
@export var max_hp := 3
var hp := 3

var focus := false
var dash_cd := 0.0
var dash_iframes := 0.2
var dash_cooldown := 0.8
var is_dashing := false
var cashout_hold := 0.0
var cashout_time := 2.0

func _ready() -> void:
	add_to_group("player")
	gs.connect("request_player_hp_delta", _on_hp_delta)
	# upgrades
	max_hp = 3 + save.get_upgrade("hp")
	hp = max_hp
	dash_iframes += save.get_upgrade("dash_iframes") * 0.05
	cashout_time = max(0.6, cashout_time - save.get_upgrade("cashout") * 0.2)

func _physics_process(_delta: float) -> void:
	_update_movement()
	_update_dash(_delta)
	_update_cashout(_delta)

func _update_movement() -> void:
	var dir := Vector2.ZERO
	dir.y = int(Input.is_action_pressed("move_down")) - int(Input.is_action_pressed("move_up"))
	dir.x = int(Input.is_action_pressed("move_right")) - int(Input.is_action_pressed("move_left"))
	dir = dir.normalized()

	focus = Input.is_action_pressed("Focus")
	var spd: float = BASE_SPEED * (1.0 + save.get_upgrade("move") * 0.10)
	if focus:
		spd *= 0.5
	if is_dashing:
		spd *= 2.0
	velocity = dir * spd
	move_and_slide()

func _update_dash(delta: float) -> void:
	dash_cd -= delta
	if Input.is_action_just_pressed("Dash") and dash_cd <= 0.0:
		is_dashing = true
		dash_cd = dash_cooldown
		$CollisionShape2D.disabled = true
		await get_tree().create_timer(dash_iframes).timeout
		$CollisionShape2D.disabled = false
		is_dashing = false

func _update_cashout(delta: float) -> void:
	if Input.is_action_pressed("CashOut"):
		cashout_hold += delta
		# Slow while channeling
		velocity *= 0.7
		if cashout_hold >= cashout_time:
			gs.bank_unbanked_full_extract()
			cashout_hold = 0.0
	else:
		cashout_hold = 0.0

func take_damage(dmg: int = 1) -> void:
	if is_dashing:
		return
	hp -= dmg
	if hp <= 0:
		gs.end_run(false)

func _on_hp_delta(delta_frac: float) -> void:
	# delta_frac is percent of current HP (e.g., -0.25)
	var change := int(ceil(hp * -delta_frac))
	hp = clamp(hp - change, 1, max_hp)
