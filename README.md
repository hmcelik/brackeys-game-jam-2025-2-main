# Crumbs & Catacombs: Arena — Godot 4.4 Starter Kit

Jam-ready scaffolding for Godot **4.4** (Desktop + Web). Includes folder layout, autoloads, core scenes, pooled bullets, key systems (Risk, Biscuit Multiplier, Temptations, Shrine, Boss Pulse), basic UI, and export presets. Copy files as indicated and wire scenes following the node trees.

---

## 0) Folder Layout

```
res://
  addons/               # (optional)
  art/
  audio/
  scenes/
	Arena.tscn
	Player.tscn
	Bullet.tscn
	Pickup.tscn
	UI.tscn
	Shrine.tscn
	Shop.tscn
  scripts/
	autoload/
	  GameState.gd
	  Save.gd
	  RNG.gd
	gameplay/
	  Bullet.gd
	  BulletPool.gd
	  PatternController.gd
	  Player.gd
	  Pickup.gd
	  Shrine.gd
	  TemptationSpawner.gd
	  Specials.gd
	ui/
	  UI.gd
	  TemptationModal.gd
	  RunSummary.gd
	  Shop.gd
  shaders/
  fonts/
  export_presets.cfg    # provided below
```

---

## 1) Project Settings (Pixel-Perfect & Inputs)

**Render & 2D**

* Rendering → Textures: `Default Texture Filter: Nearest`, Mipmaps: Off
* Rendering → 2D: Enable **Use Pixel Snap**
* Display → Window → Stretch: Mode **canvas\_items**, Aspect **keep**, Allow Hidpi **On**
* Physics → Common: `physics_ticks_per_second = 60`

**Input Map** (Project → Project Settings → Input Map)

```
move_up:      W, Up
move_down:    S, Down
move_left:    A, Left
move_right:   D, Right
Dash:         Space, Gamepad B
Focus:        Shift, Gamepad L2
CashOut:      E, Gamepad Y
Special:      Q, Gamepad X
Confirm:      Enter, Gamepad A
Cancel:       Esc, Gamepad B
```

---

## 2) Autoloads (Project → Project Settings → Autoload)

Add the following as **Singletons** (names are nodes in /root and MUST NOT collide with script class names):

* `res://scripts/autoload/GameState.gd` (Name: **GameState**)
* `res://scripts/autoload/Save.gd` (Name: **Save**)
* `res://scripts/autoload/RNG.gd` (Name: **RNG**)

> Note: In this kit, `GameState.gd` uses `class_name GameStateData` and `RNG.gd` uses `class_name RNGService` to avoid autoload name collisions.

### scripts/autoload/RNG.gd

```gdscript
extends Node
class_name RNGService

var _rng := RandomNumberGenerator.new()

func _ready() -> void:
	_rng.randomize()

func seed_with(value: int) -> void:
	_rng.seed = value

func randi_range(a: int, b: int) -> int:
	return _rng.randi_range(a, b)

func randf() -> float:
	return _rng.randf()

func randf_range(a: float, b: float) -> float:
	return _rng.randf_range(a, b)
```

### scripts/autoload/Save.gd

```gdscript
extends Node
# NOTE: Do NOT give this script a `class_name` if your autoload is also named "Save".
# That avoids the class-vs-singleton name collision.

const SAVE_PATH := "user://save.json"

# Explicitly type the dictionary to avoid "inferred from Variant" warnings.
var data: Dictionary = {
	"coins_banked": 0,
	"upgrades": {
		"hp": 1, "dash_iframes": 0, "move": 0,
		"coin_rate": 0, "cashout": 0, "free_hit": 0
	},
	"streak": 0,
	"best": {"survival": 0.0, "peak_bm": 1.0, "biscuits": 0},
	"options": {"screenshake": true, "reduced_flash": false, "insurance": false}
}

func _ready() -> void:
	load_game()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		save_game()
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f:
		var txt: String = f.get_as_text()
		var parsed: Variant = JSON.parse_string(txt)
		if typeof(parsed) == TYPE_DICTIONARY:
			data = (parsed as Dictionary)

func save_game() -> void:
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	f.store_string(JSON.stringify(data))

func add_bank(amount: int) -> void:
	var safe_amount: int = max(amount, 0)
	var current: int = int(data.get("coins_banked", 0))
	data["coins_banked"] = current + safe_amount
	save_game()

func set_option(key: String, value: Variant) -> void:
	var opts: Dictionary = (data.get("options", {}) as Dictionary)
	opts[key] = value
	data["options"] = opts
	save_game()

func get_upgrade(key: String) -> int:
	var ups: Dictionary = (data.get("upgrades", {}) as Dictionary)
	return int(ups.get(key, 0))

func inc_upgrade(key: String) -> void:
	var ups: Dictionary = (data.get("upgrades", {}) as Dictionary)
	ups[key] = int(ups.get(key, 0)) + 1
	data["upgrades"] = ups
	save_game()
```

### scripts/autoload/GameState.gd

````gdscript
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
```gdscript
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
````

---

## 3) Core Scenes & Scripts

### scenes/Bullet.tscn

Node tree:

```
Area2D (Bullet)
  ├─ CollisionShape2D
  └─ Sprite2D
```

Attach `scripts/gameplay/Bullet.gd`:

```gdscript
extends Area2D
class_name Bullet

@export var speed := 140.0
var velocity := Vector2.ZERO
var lifetime := 4.0
var alive := false

func fire(pos: Vector2, vel: Vector2, life: float) -> void:
	global_position = pos
	velocity = vel
	lifetime = life
	alive = true
	visible = true
	monitoring = true

func _physics_process(delta: float) -> void:
	if not alive:
		return
	lifetime -= delta
	if lifetime <= 0.0:
		_despawn()
		return
	global_position += velocity * delta

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		_despawn()

func _despawn() -> void:
	alive = false
	visible = false
	monitoring = false
```

### scripts/gameplay/BulletPool.gd

```gdscript
extends Node
class_name BulletPool

const MAX_BULLETS := 400
@export var bullet_scene: PackedScene
var pool: Array[Bullet] = []

func _ready() -> void:
	pool.resize(MAX_BULLETS)
	for i in range(MAX_BULLETS):
		var b := bullet_scene.instantiate() as Bullet
		b.visible = false
		b.monitoring = false
		add_child(b)
		pool[i] = b

func get_bullet() -> Bullet:
	for b in pool:
		if not b.alive:
			return b
	return null

func fire(pos: Vector2, vel: Vector2, life: float) -> void:
	var b := get_bullet()
	if b:
		b.fire(pos, vel, life)
```

### scenes/Player.tscn

Node tree:

```
CharacterBody2D (Player)
  ├─ Sprite2D
  ├─ CollisionShape2D (hurtbox)
  ├─ Area2D (Magnet)
  │   └─ CollisionShape2D (Circle; radius ~64)
  └─ Node2D (CoreDot)
```

Attach `scripts/gameplay/Player.gd`:

```gdscript
extends CharacterBody2D
class_name Player

@onready var save: Node = get_node("/root/Save")
@onready var gs: GameStateData = get_node("/root/GameState") as GameStateData

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
```

### scenes/Pickup.tscn

Node tree:

```
Area2D (Pickup)
  ├─ CollisionShape2D
  └─ Sprite2D
```

Attach `scripts/gameplay/Pickup.gd`:

```gdscript
extends Area2D
class_name Pickup

@onready var gs: GameStateData = get_node("/root/GameState") as GameStateData

enum Kind { COIN, CRUMB, HEART, GOLDEN }
@export var kind := Kind.COIN
@export var value := 1
var attracted := false
var target: Node2D

func _physics_process(delta: float) -> void:
	if attracted and target:
		var dir := (target.global_position - global_position).normalized()
		global_position += dir * 300.0 * delta

func attract_to(p: Node2D) -> void:
	attracted = true
	target = p

func _on_body_entered(body: Node) -> void:
	if not body.is_in_group("player"): return
	match kind:
		Kind.COIN:
			gs.add_unbanked(int(round(value * gs.bm)))
		Kind.CRUMB:
			get_tree().call_group("specials", "add_crumb", 1)
		Kind.HEART:
			body.hp = min(body.hp + 1, body.max_hp)
		Kind.GOLDEN:
			gs.add_unbanked(value) # golden paid at extract; here we add raw
	queue_free()
```

### scripts/gameplay/TemptationSpawner.gd (UI + logic)

````gdscript
extends Control
class_name TemptationSpawner

@onready var gs: GameStateData = get_node("/root/GameState") as GameStateData
@onready var modal: TemptationModal = $"../TemptationModal"

func _ready() -> void:
	gs.connect("spawn_temptation", _on_spawn)
	if not modal.chosen.is_connected(on_choice):
		modal.chosen.connect(on_choice)

func _on_spawn() -> void:
	modal.show_options([
		{"id":"blood_for_batter", "title":"Blood for Batter", "desc":"Lose 25% HP → +0.6 BM"},
		{"id":"bring_the_heat", "title":"Bring the Heat", "desc":"Elite burst now → +1 drop"},
		{"id":"squeeze_the_circle", "title":"Squeeze the Circle", "desc":"Arena −10% → +20% coin"},
	])

func on_choice(id: String) -> void:
	gs.apply_temptation(id)
```gdscript
extends Control
class_name TemptationSpawner

@onready var gs: GameStateData = get_node("/root/GameState") as GameStateData
@onready var modal := $TemptationModal

func _ready() -> void:
	gs.connect("spawn_temptation", _on_spawn)
	if not modal.chosen.is_connected(on_choice):
		modal.chosen.connect(on_choice)

func _on_spawn() -> void:
	modal.show_options([
		{"id":"blood_for_batter", "title":"Blood for Batter", "desc":"Lose 25% HP → +0.6 BM"},
		{"id":"bring_the_heat", "title":"Bring the Heat", "desc":"Elite burst now → +1 drop"},
		{"id":"squeeze_the_circle", "title":"Squeeze the Circle", "desc":"Arena −10% → +20% coin"},
	])

func on_choice(id: String) -> void:
	gs.apply_temptation(id)
````

### scripts/ui/TemptationModal.gd

```gdscript
extends Control
class_name TemptationModal

signal chosen(id: String)

func show_options(options: Array) -> void:
	visible = true
	# Populate buttons (assumes 3 Button children)
	for i in range(min(options.size(), get_child_count())):
		var btn := get_child(i) as Button
		btn.text = options[i]["title"] + "
" + options[i]["desc"]
		btn.pressed.connect(func(): _choose(options[i]["id"]))

func _choose(id: String) -> void:
	visible = false
	emit_signal("chosen", id)
```

### scenes/Shrine.tscn

Node tree:

```
Area2D (Shrine)
  ├─ CollisionShape2D
  └─ Sprite2D (beam/bell)
```

Attach `scripts/gameplay/Shrine.gd`:

```gdscript
extends Area2D
class_name Shrine

@onready var gs: GameStateData = get_node("/root/GameState") as GameStateData

@export var active_time := 6.0

func _ready() -> void:
	gs.connect("spawn_shrine", _on_spawn)

func _on_spawn() -> void:
	visible = true
	monitoring = true
	$CollisionShape2D.disabled = false
	await get_tree().create_timer(active_time).timeout
	_despawn()

func _on_body_entered(body: Node) -> void:
	if body.is_in_group("player"):
		gs.bank_at_shrine()
		_despawn()

func _despawn() -> void:
	visible = false
	monitoring = false
	$CollisionShape2D.disabled = true
```

### scripts/gameplay/PatternController.gd

```gdscript
extends Node2D
class_name PatternController

@onready var rng: RNGService = get_node("/root/RNG") as RNGService
@onready var gs: GameStateData = get_node("/root/GameState") as GameStateData

@export var bullet_pool_path: NodePath
var pool: BulletPool
var active_types: Array[String] = []
var elite_pending := false

func _ready() -> void:
	add_to_group("pattern_controller")
	pool = get_node(bullet_pool_path) as BulletPool
	gs.connect("risk_tier_changed", _on_heat)
	gs.connect("pulse_started", _on_pulse_started)

func trigger_elite_burst() -> void:
	elite_pending = true

func _process(_delta: float) -> void:
	# Simple scheduler: decide patterns based on heat and time
	if active_types.size() < 1:
		_start_pattern(_pick_pattern())
	if gs.heat >= 1 and active_types.size() < 2 and rng.randf() < 0.005:
		_start_pattern(_pick_pattern())

func _start_pattern(kind: String) -> void:
	if active_types.has(kind):
		return
	if active_types.size() >= 2:
		return
	active_types.append(kind)
	match kind:
		"radial": await _radial_burst()
		"spiral": await _spiral_stream()
		"aimed": await _aimed_volley()
		"wall": await _wall_sweep()
		"orbit": await _orbit_mines()
		"flower": await _flower_pulse()
	active_types.erase(kind)

func _pick_pattern() -> String:
	var all := ["radial","spiral","aimed","wall","orbit","flower"]
	return all[rng.randi_range(0, all.size()-2 + int(gs.heat>1))]

func _on_heat(_tier: int) -> void:
	pass

func _on_pulse_started() -> void:
	await _flower_pulse(true)
	gs.pulse_end(true)

# --- Pattern Implementations ---
func _radial_burst() -> void:
	var n := 12 + gs.heat * 6
	var speed := 120.0 + gs.heat * 30.0
	var pos := global_position
	for i in range(n):
		var ang := TAU * (float(i)/n)
		pool.fire(pos, Vector2.RIGHT.rotated(ang) * speed, 4.0)
	await get_tree().create_timer(1.0).timeout

func _spiral_stream() -> void:
	var pos := global_position
	var rpm := 60.0 + gs.heat * 20.0
	var speed := 100.0 + gs.heat * 25.0
	var t := 0.0
	var dur := 2.0
	while t < dur:
		var ang := deg_to_rad((t * rpm) * 6.0)
		pool.fire(pos, Vector2.RIGHT.rotated(ang) * speed, 4.0)
		t += 0.08
		await get_tree().create_timer(0.08).timeout

func _aimed_volley() -> void:
	var player := get_tree().get_first_node_in_group("player") as Node2D
	if not player: return
	var pos := global_position
	var spread := deg_to_rad(10.0 + gs.heat * 5.0)
	var dir := (player.global_position - pos).angle()
	for angle in [dir-spread, dir, dir+spread]:
		pool.fire(pos, Vector2.RIGHT.rotated(angle) * 180.0, 4.0)
	await get_tree().create_timer(0.6).timeout

func _wall_sweep() -> void:
	# Versatile wall pattern: random orientation & origin with moving gaps
	# Modes: 0=top→down, 1=bottom→up, 2=left→right, 3=right→left,
	#        4=center→sides (horizontal), 5=center→up&down (vertical)
	var rect := get_viewport_rect()
	var size := rect.size
	var top := rect.position.y
	var left := rect.position.x
	var right := left + size.x
	var bottom := top + size.y
	var center := rect.position + size * 0.5

	var heat := gs.heat
	var cols := 10 + heat * 2       # grid density
	var rows := 6 + heat            # pulses
	var speed := 140.0 + heat * 30.0
	var row_interval := 0.16        # time between pulses

	var col_spacing := size.x / float(cols + 1)
	var row_spacing := size.y / float(rows + 1)

	var mode := rng.randi_range(0, 5)

	if mode == 0:
		# Top → Down
		var life := (size.y + 120.0) / speed
		var gap := rng.randi_range(0, cols - 1)
		var gap2 := gap if heat < 2 else (gap + rng.randi_range(1, max(1, cols - 1))) % cols
		for step in range(rows):
			if heat >= 1: gap = clamp(gap + rng.randi_range(-1, 1), 0, cols - 1)
			if heat >= 2: gap2 = clamp(gap2 + rng.randi_range(-1, 1), 0, cols - 1)
			for c in range(cols):
				if c == gap or c == gap2: continue
				var x_pos := left + (c + 1) * col_spacing
				var pos := Vector2(x_pos, top - 40.0)
				pool.fire(pos, Vector2(0, speed), life)
			await get_tree().create_timer(row_interval).timeout
	elif mode == 1:
		# Bottom → Up
		var life := (size.y + 120.0) / speed
		var gap := rng.randi_range(0, cols - 1)
		var gap2 := gap if heat < 2 else (gap + rng.randi_range(1, max(1, cols - 1))) % cols
		for step in range(rows):
			if heat >= 1: gap = clamp(gap + rng.randi_range(-1, 1), 0, cols - 1)
			if heat >= 2: gap2 = clamp(gap2 + rng.randi_range(-1, 1), 0, cols - 1)
			for c in range(cols):
				if c == gap or c == gap2: continue
				var x_pos := left + (c + 1) * col_spacing
				var pos := Vector2(x_pos, bottom + 40.0)
				pool.fire(pos, Vector2(0, -speed), life)
			await get_tree().create_timer(row_interval).timeout
	elif mode == 2:
		# Left → Right
		var life := (size.x + 120.0) / speed
		var gap := rng.randi_range(0, rows - 1)
		var gap2 := gap if heat < 2 else (gap + rng.randi_range(1, max(1, rows - 1))) % rows
		for step in range(cols):
			if heat >= 1: gap = clamp(gap + rng.randi_range(-1, 1), 0, rows - 1)
			if heat >= 2: gap2 = clamp(gap2 + rng.randi_range(-1, 1), 0, rows - 1)
			for r in range(rows):
				if r == gap or r == gap2: continue
				var y_pos := top + (r + 1) * row_spacing
				var pos := Vector2(left - 40.0, y_pos)
				pool.fire(pos, Vector2(speed, 0), life)
			await get_tree().create_timer(row_interval).timeout
	elif mode == 3:
		# Right → Left
		var life := (size.x + 120.0) / speed
		var gap := rng.randi_range(0, rows - 1)
		var gap2 := gap if heat < 2 else (gap + rng.randi_range(1, max(1, rows - 1))) % rows
		for step in range(cols):
			if heat >= 1: gap = clamp(gap + rng.randi_range(-1, 1), 0, rows - 1)
			if heat >= 2: gap2 = clamp(gap2 + rng.randi_range(-1, 1), 0, rows - 1)
			for r in range(rows):
				if r == gap or r == gap2: continue
				var y_pos := top + (r + 1) * row_spacing
				var pos := Vector2(right + 40.0, y_pos)
				pool.fire(pos, Vector2(-speed, 0), life)
			await get_tree().create_timer(row_interval).timeout
	elif mode == 4:
		# Center → Sides (Horizontal explosion)
		var life := (size.x * 0.5 + 120.0) / speed
		var gap := rng.randi_range(0, rows - 1)
		var gap2 := gap if heat < 2 else (gap + rng.randi_range(1, max(1, rows - 1))) % rows
		for step in range(cols):
			if heat >= 1: gap = clamp(gap + rng.randi_range(-1, 1), 0, rows - 1)
			if heat >= 2: gap2 = clamp(gap2 + rng.randi_range(-1, 1), 0, rows - 1)
			for r in range(rows):
				if r == gap or r == gap2: continue
				var y_pos := top + (r + 1) * row_spacing
				var p := Vector2(center.x, y_pos)
				pool.fire(p, Vector2(speed, 0), life)
				pool.fire(p, Vector2(-speed, 0), life)
			await get_tree().create_timer(row_interval).timeout
	else:
		# Center → Up & Down (Vertical explosion)
		var life := (size.y * 0.5 + 120.0) / speed
		var gap := rng.randi_range(0, cols - 1)
		var gap2 := gap if heat < 2 else (gap + rng.randi_range(1, max(1, cols - 1))) % cols
		for step in range(rows):
			if heat >= 1: gap = clamp(gap + rng.randi_range(-1, 1), 0, cols - 1)
			if heat >= 2: gap2 = clamp(gap2 + rng.randi_range(-1, 1), 0, cols - 1)
			for c in range(cols):
				if c == gap or c == gap2: continue
				var x_pos := left + (c + 1) * col_spacing
				var p := Vector2(x_pos, center.y)
				pool.fire(p, Vector2(0, speed), life)
				pool.fire(p, Vector2(0, -speed), life)
			await get_tree().create_timer(row_interval).timeout

func _orbit_mines() -> void:
	# spawn mines that detach
	var center := global_position
	var count := 2 + gs.heat
	for i in range(count):
		var ang := TAU * (float(i)/count)
		var pos := center + Vector2.RIGHT.rotated(ang) * 60.0
		pool.fire(pos, Vector2.ZERO, 2.0)
		await get_tree().create_timer(0.5).timeout
	# detach phase
	for i in range(count):
		var ang := TAU * (float(i)/count)
		pool.fire(center, Vector2.RIGHT.rotated(ang) * 140.0, 3.0)
	await get_tree().create_timer(0.8).timeout

func _flower_pulse(boss := false) -> void:
	var petals := 16 if boss else 10
	var speed := 160.0 if boss else 120.0
	var waves := 12 if boss else 6
	for w in range(waves):
		var phase := w * 0.35
		for i in range(petals):
			var ang := TAU * i/float(petals) + phase
			pool.fire(global_position, Vector2.RIGHT.rotated(ang) * speed, 5.0)
		await get_tree().create_timer(0.25).timeout
```

### scenes/UI.tscn

Node tree (match these exact names):

```
CanvasLayer (Ui)
  ├─ Control (Hud)
  │   ├─ Label (HP)
  │   ├─ Label (Banked)
  │   ├─ Label (Unbanked)
  │   ├─ Label (BM)
  │   └─ ProgressBar (Risk)
  ├─ TemptationModal (Control, script: TemptationModal.gd)  # has 3 Button children
  └─ TemptationSpawner (Control, script: TemptationSpawner.gd)
```

Attach `scripts/ui/UI.gd` to **CanvasLayer (Ui)**:

```gdscript
extends CanvasLayer

var gs: GameStateData
var hp_label: Label
var banked_label: Label
var unbanked_label: Label
var bm_label: Label
var risk_bar: ProgressBar

func _ready() -> void:
	gs = get_node("/root/GameState") as GameStateData
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
```

### scenes/Arena.tscn

Node tree:

```
Node2D (Arena)
  ├─ TileMap
  ├─ Player (Player.tscn)
  ├─ BulletPool (BulletPool.gd) [bullet_scene = Bullet.tscn]
  ├─ PatternController (PatternController.gd) [bullet_pool_path -> ../BulletPool]
  ├─ Shrine (Shrine.tscn)
  └─ Ui (UI.tscn)   # contains Hud, TemptationModal, TemptationSpawner
```

Attach a tiny script to Arena to handle arena shrink and start the run:

```gdscript
extends Node2D
class_name Arena

@onready var gs: GameStateData = get_node("/root/GameState") as GameStateData

var shrink_level := 0.0

func _ready() -> void:
	add_to_group("arena")
	gs.start_run()

func shrink_arena(amount: float) -> void:
	shrink_level = clamp(shrink_level + amount, 0.0, 0.3)
	scale = Vector2(1.0 - shrink_level, 1.0 - shrink_level)
```

Node2D (Arena)
├─ TileMap
├─ Player (Player.tscn)
├─ BulletPool (BulletPool.gd) \[bullet\_scene = Bullet.tscn]
├─ PatternController (PatternController.gd) \[bullet\_pool\_path -> ../BulletPool]
├─ Shrine (Shrine.tscn)
├─ UI (UI.tscn)
└─ TemptationSpawner (TemptationSpawner.gd)

````

Attach a tiny script to Arena to handle arena shrink and start the run:

```gdscript
extends Node2D
class_name Arena

@onready var gs: GameStateData = get_node("/root/GameState") as GameStateData

var shrink_level := 0.0

func _ready() -> void:
	add_to_group("arena")
	gs.start_run()

func shrink_arena(amount: float) -> void:
	shrink_level = clamp(shrink_level + amount, 0.0, 0.3)
	scale = Vector2(1.0 - shrink_level, 1.0 - shrink_level)
````

### scripts/gameplay/Specials.gd (run-only specials using crumbs)

```gdscript
extends Node
class_name Specials

var crumbs := 0
var shield_time := 0.0

func _ready() -> void:
	add_to_group("specials")

func add_crumb(n: int) -> void:
	crumbs += n

func use_shield() -> bool:
	if crumbs < 1: return false
	crumbs -= 1
	shield_time = 10.0
	return true

func use_bomb() -> bool:
	if crumbs < 1: return false
	crumbs -= 1
	get_tree().call_group("pattern_controller", "_radial_burst")
	return true

func use_slow() -> bool:
	if crumbs < 2: return false
	crumbs -= 2
	Engine.time_scale = 0.4
	await get_tree().create_timer(3.0, true, false, true).timeout
	Engine.time_scale = 1.0
	return true
```

---

## 4) Shop (Meta Upgrades) — Minimal

### scenes/Shop.tscn

Simple `Control` with Buttons for each upgrade and a label for banked coins. Attach `scripts/ui/Shop.gd`:

```gdscript
extends Control

@onready var Save: Node = get_node("/root/Save")
@onready var coins_label := $Coins

func _ready() -> void:
	_refresh()

func _refresh() -> void:
	coins_label.text = "Banked: %d" % int(Save.data.get("coins_banked", 0))

func _buy_upgrade(key: String, costs: PackedFloat32Array) -> void:
	var level := Save.get_upgrade(key)
	if level >= costs.size(): return
	var cost := int(costs[level])
	var _banked: int = int(Save.data.get("coins_banked", 0))
	if _banked < cost:
		return
	Save.data["coins_banked"] = _banked - cost
	Save.inc_upgrade(key)
	Save.save_game()
	_refresh()
```

---

## 5) Wiring Notes

* Autoloads: add **GameState**, **Save**, **RNG** with those exact names (Project → Autoload).
* Ensure **Player** is in group `player`.
* **PatternController** can be positioned at arena center; patterns use its `global_position`.
* **BulletPool** Inspector → set **bullet\_scene** to `Bullet.tscn`.
* **PatternController** Inspector → set **bullet\_pool\_path** to the **BulletPool** node (drag it from the Scene tree).
* **TemptationSpawner** and **TemptationModal** are **siblings under Ui**; the spawner finds the modal via `"../TemptationModal"` and connects automatically.
* HUD labels use the **Ui/Hud** paths shown; if you rename nodes, update `UI.gd`.

## 6) Export Presets (Windows + Web)

Create `export_presets.cfg` at project root (or via Editor Export and then tweak):

```ini
[preset.0]
name="Windows Desktop"
platform="Windows Desktop"
runnable=true
custom_features=""
export_filter="all_resources"
include_filter=""
exclude_filter=""
export_path="build/Crumbs&Catacombs.exe"
script_export_mode=1

[preset.1]
name="Web"
platform="Web"
runnable=true
export_filter="all_resources"
export_path="build/web/index.html"

[preset.1.options]
html/canvas_resize_policy=2
vram_texture_compression/for_desktop=true
threads/thread_model=1       # Multithreaded if supported
```

> **Tip (Web):** Keep shaders simple, avoid heavy particles, prefer sprites/Line2D. Test audio on first input to comply with browser autoplay.

---

## 7) Minimal Loop to Start (Day 1–2)

1. Make scenes per trees, attach scripts provided.
2. Set Autoloads.
3. Open `Arena.tscn` and press ▶️ — you should see player move, basic patterns spawn, coins trickle, and you can **CashOut** to end the run.
4. Temptation buttons are **auto‑wired** by `TemptationSpawner.gd` (no manual signal hookup).
5. Iterate tunables in `GameState` and `PatternController`.

---

## 8) Balancing Dials (where to tweak quickly)

* `GameState`: `base_coin_rate`, `risk_tier_period`, `shrine_interval`, `shrine_tax`, BM ticks.
* `PatternController`: bullet `speed`, counts, timers per pattern.
* `Player`: `BASE_SPEED`, `dash_iframes`, `cashout_time`.

---

## 9) To‑Do (Polish Pass / Stretch)

* Telegraph rings & color‑coded bullet families; screenshake + hitstop on bomb.
* Boss Pulse reward: spawn **Golden Biscuit** pickup and summary star.
* Run Summary: peak BM, Golden Biscuits, streak status.
* Contracts & Curses systems (stretch) piggyback on Temptations.
* Daily Seed: add date‑based RNG seed in `RNG`.

---

## 10) Asset Checklist (Jam‑Ready)

**Format:** PNG (32‑bit), nearest filter, no mipmaps. Use folders below so scenes load without edits.

### Player & Core

* `art/player/player_idle_32x32.png` — 1 frame, centered pivot.
* `art/player/player_walk_32x32.png` — **4 frames**, 8 fps.
* `art/player/player_dash_ghost_32x32.png` — **2 frames**, used during dash i‑frames.
* `art/player/core_dot_4x4.png` — 1 frame bright dot shown on Focus.

### Bullets & Mines

* `art/bullets/bullet_small_8x8.png` — 1–2 frame twinkle; **3 colorways** for families.
* `art/bullets/bullet_boss_12x12.png` — heavier boss bullets.
* `art/bullets/mine_orbit_16x16.png` — 2‑frame pulse orb.

### Pickups

* `art/pickups/coin_8x8.png` — 2‑frame shimmer.
* `art/pickups/crumb_8x8.png` — 1–2 frames sparkle.
* `art/pickups/heart_12x12.png` — 2‑frame bob; never drops at full HP.
* `art/pickups/golden_biscuit_16x16.png` — **4‑frame** glitter loop.

### Shrine & Telegraphs

* `art/shrine/shrine_base_32x48.png` — bell/altar base.
* `art/shrine/shrine_beam_32x64.png` — alpha‑gradient vertical beam.
* `art/telegraphs/cashout_ring_64x64.png` — circular channel ring.
* `art/telegraphs/warn_ring_48x48.png` — thin pre‑burst telegraph.

### Effects (VFX)

* `art/fx/near_miss_spark_8x8.png` — 4 frames radial spark.
* `art/fx/bomb_clear_96x96.png` — 6 frames expanding shockwave.
* `art/fx/hit_flash_32x32.png` — 2 frames white overlay.
* `art/fx/coin_pop_16x16.png` — 4 frames pickup pop.

### Arena & Tiles

* `art/tiles/arena_tileset_32x32.png` — 8–16 simple tiles + rim.
* `art/tiles/vignette_512x288.png` — subtle dark overlay.
* `art/tiles/solid_bg_1x1.png` — fallback solid color.

### UI & HUD

* `art/ui/9slice_panel_64x64.png` — rounded panel for modals.
* `art/ui/btn_idle_48x16.png`, `btn_hover_48x16.png`, `btn_press_48x16.png` — button states.
* `art/ui/icon_coin_12x12.png`, `icon_crumb_12x12.png`, `icon_heart_12x12.png`, `icon_bm_12x12.png`, `icon_risk_12x12.png`
* `art/ui/progress_fill_64x8.png` — risk bar fill.
* `art/ui/cursor_8x8.png` — optional.

### Music (OGG, seamless loops)

* `audio/music/loop_main.ogg` — 60–90s arcade loop.
* `audio/music/loop_danger.ogg` — additive layer for Heat ≥ 2.
* `audio/music/stinger_cashout.ogg` — 0.5–1.0s extract flourish.
* `audio/music/stinger_pulse_success.ogg` — 0.5–1.0s boss pulse success.

### SFX (WAV/OGG, short)

* Movement: `sfx/dash.wav`, `sfx/focus_on.wav`, `sfx/focus_off.wav`
* Hit/Death: `sfx/player_hit.wav`, `sfx/player_death.wav`
* Bullets: `sfx/bullet_spawn.wav`, `sfx/bullet_clear_bomb.wav`
* Pickups: `sfx/coin_pick.wav`, `sfx/crumb_pick.wav`, `sfx/heart_pick.wav`, `sfx/golden_pick.wav`
* Shrine/Temptation: `sfx/shrine_bell.wav`, `sfx/shrine_tick.wav`, `sfx/temptation_open.wav`, `sfx/temptation_select.wav`
* UI: `sfx/ui_hover.wav`, `sfx/ui_click.wav`, `sfx/modal_open.wav`
* Risk/BM: `sfx/heat_up.wav`, `sfx/bm_up.wav`, `sfx/bm_reset.wav`

### Fonts

* `fonts/pixel.ttf` — readable 8–12 px pixel font.
* `fonts/pixel_bold.ttf` — bold header font.

### Import Hints (Godot 4)

* Textures: **Filter Nearest**, **Mipmaps Off**, Repeat **Disabled**.
* VFX sheets: power‑of‑two sizes help Web.
* Music: trim heads/tails or add loop points; set loop in import.

### Minimal to Ship (if time is tight)

* Player: idle, walk(4), dash(2)
* Bullets: small (2 colorways), boss
* Pickups: coin(2), crumb(1), heart(2), golden(4)
* Shrine: base, beam
* VFX: bomb\_clear(6), coin\_pop(4), near\_miss(4)
* UI: 9‑slice panel, icons, progress fill
* Tiles: arena tileset or solid\_bg
* Audio: main loop, danger layer, dash, hit, coin, shrine bell, temptation open/select, bomb clear, BM up
