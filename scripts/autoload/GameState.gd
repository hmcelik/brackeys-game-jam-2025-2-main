extends Node
class_name GameStateData

signal risk_tier_changed(tier: int)
signal bm_changed(bm: float)
signal coins_changed(unbanked: int)
signal banked_changed(banked: int)
signal spawn_shrine()
signal spawn_temptation()
signal pulse_started()
signal pulse_finished(success: bool)
signal request_player_hp_delta(delta: float)
signal run_over(extracted: bool)

# Run state
var running := false
var survival_time := 0.0
var heat := 0                       # Heat 0..3
var bm := 1.0                       # Biscuit Multiplier
var unbanked := 0
var banked := 0
var streak := 0

# Timers (seconds)
var t_since_temptation := 0.0
var t_since_shrine := 0.0
var t_since_pulse := 0.0
var t_since_bm_tick := 0.0

# Config (can be tweaked at runtime)
var temptation_interval := 25.0
var shrine_interval := 45.0
var pulse_interval := 90.0
var pulse_duration := 14.0
var shrine_tax := 0.15
var base_coin_rate := 1.0            # per second

# Risk progression
var t_since_heat := 0.0
var risk_tier_period := 30.0

# Meta modifiers
var coin_rate_bonus := 0.0
var cashout_bonus := 0.0  # -seconds to channel (applied in Player)

# Reference the Save autoload explicitly
@onready var Save: Node = get_node("/root/Save")

func start_run() -> void:
	running = true
	survival_time = 0.0
	heat = 0
	var _streak_i: int = int(Save.data.get("streak", 0))
	bm = 1.0 + min(0.5, float(_streak_i) * 0.1)
	unbanked = 0
	t_since_temptation = 0.0
	t_since_shrine = 0.0
	t_since_pulse = 0.0
	t_since_bm_tick = 0.0
	t_since_heat = 0.0
	coin_rate_bonus = Save.get_upgrade("coin_rate") * 0.2
	cashout_bonus = Save.get_upgrade("cashout") * 0.2
	emit_signal("bm_changed", bm)
	emit_signal("coins_changed", unbanked)

func end_run(extracted: bool) -> void:
	running = false
	if extracted:
		Save.data["streak"] = int(Save.data.get("streak", 0)) + 1
	else:
		Save.data["streak"] = 0
		if Save.data["options"].get("insurance", false) and unbanked > 0:
			var salvage := int(round(unbanked * 0.05))
			banked += salvage
			Save.add_bank(salvage)
			emit_signal("banked_changed", banked)
	Save.save_game()
	emit_signal("run_over", extracted)

func _process(delta: float) -> void:
	if not running:
		return
	survival_time += delta
	t_since_temptation += delta
	t_since_shrine += delta
	t_since_pulse += delta
	t_since_bm_tick += delta
	t_since_heat += delta

	# Passive coins
	var rate := base_coin_rate + coin_rate_bonus
	add_unbankedf(rate * delta * bm)

	# BM tick (+0.3 every 20s)
	if t_since_bm_tick >= 20.0:
		t_since_bm_tick -= 20.0
		add_bm(0.3)

	# Heat tiering (every 30s)
	if heat < 3 and t_since_heat >= risk_tier_period:
		t_since_heat -= risk_tier_period
		heat += 1
		emit_signal("risk_tier_changed", heat)

	# Temptation spawn
	if t_since_temptation >= temptation_interval:
		t_since_temptation = 0.0
		emit_signal("spawn_temptation")

	# Shrine spawn
	if t_since_shrine >= shrine_interval:
		t_since_shrine = 0.0
		emit_signal("spawn_shrine")

	# Boss Pulse
	if t_since_pulse >= pulse_interval:
		t_since_pulse = 0.0
		emit_signal("pulse_started")

func pulse_end(success: bool) -> void:
	emit_signal("pulse_finished", success)
	if success:
		# Reward Golden Biscuit via Pickup spawner
		pass

func add_unbanked(amount: int) -> void:
	unbanked += max(amount, 0)
	emit_signal("coins_changed", unbanked)

func add_unbankedf(amountf: float) -> void:
	var a := int(amountf)
	if a != 0:
		add_unbanked(a)

func add_bm(delta_bm: float) -> void:
	bm = max(1.0, bm + delta_bm)
	emit_signal("bm_changed", bm)

func bank_unbanked_full_extract() -> void:
	if unbanked <= 0:
		end_run(true)
		return
	banked += unbanked
	Save.add_bank(unbanked)
	unbanked = 0
	emit_signal("coins_changed", unbanked)
	emit_signal("banked_changed", banked)
	end_run(true)

func bank_at_shrine() -> void:
	if unbanked <= 0:
		return
	var amt := int(round(unbanked * (1.0 - shrine_tax)))
	banked += amt
	Save.add_bank(amt)
	unbanked = 0
	emit_signal("coins_changed", unbanked)
	emit_signal("banked_changed", banked)
	# Reset BM only on bank/extract
	bm = 1.0
	emit_signal("bm_changed", bm)

# Temptations
func apply_temptation(id: String) -> void:
	match id:
		"blood_for_batter":
			emit_signal("request_player_hp_delta", -0.25) # Player interprets as % current HP
			add_bm(0.6)
		"bring_the_heat":
			# PatternController listens to trigger an elite burst and drop
			get_tree().call_group("pattern_controller", "trigger_elite_burst")
		"squeeze_the_circle":
			# Arena listens to shrink and coin rate +20%
			coin_rate_bonus += (base_coin_rate + coin_rate_bonus) * 0.2
			get_tree().call_group("arena", "shrink_arena", 0.10)
		_:
			pass
