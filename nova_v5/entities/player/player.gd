extends Area2D

signal player_died
signal health_changed(new_health: int)

# ── Stats ──────────────────────────────────────────────────────────────────
var speed     : float = 300.0
var max_health: int   = 5
var health    : int   = 3

# ── Shooting ──────────────────────────────────────────────────────────────
var shoot_cooldown : float  = 0.28
var shoot_timer    : float  = 0.0
var shoot_mode     : String = "single"

# ── Invincibility ─────────────────────────────────────────────────────────
var invincible    : bool  = false
var inv_timer     : float = 0.0
var inv_duration  : float = 2.0
var blink_timer   : float = 0.0

# ── Shield ────────────────────────────────────────────────────────────────
var shield_active : bool = false

# ── Lightning ─────────────────────────────────────────────────────────────
var lightning_active : bool  = false
var lightning_timer  : float = 0.0
var lightning_duration: float = 6.0
var lightning_tick   : float = 0.0   # fires every 0.18s

# ── Nuke ──────────────────────────────────────────────────────────────────
var nuke_ready : bool = false

# ── Powerup timers ─────────────────────────────────────────────────────────
var double_timer : float = 0.0
var triple_timer : float = 0.0
var speed_timer  : float = 0.0
var rapid_timer  : float = 0.0   # rapid fire

# ── Node refs ─────────────────────────────────────────────────────────────
@onready var thruster_sprite : Sprite2D = $ThrusterSprite
@onready var shield_sprite   : Sprite2D = $ShieldSprite
@onready var ship_sprite     : Sprite2D = $ShipSprite

var bullet_scene : PackedScene = preload("res://entities/bullet/bullet.tscn")

var thruster_frames  : Array = []
var thruster_idx     : int   = 0
var thruster_timer   : float = 0.0
var thruster_speed   : float = 0.07

func _ready() -> void:
	shield_sprite.visible = false
	thruster_frames = [
		load("res://assest/spacepixels-0.1.0/spacepixels-0.1.0/thruster-1.png"),
		load("res://assest/spacepixels-0.1.0/spacepixels-0.1.0/thruster-2.png"),
		load("res://assest/spacepixels-0.1.0/spacepixels-0.1.0/thruster-3.png"),
		load("res://assest/spacepixels-0.1.0/spacepixels-0.1.0/thruster-4.png"),
		load("res://assest/spacepixels-0.1.0/spacepixels-0.1.0/thruster-5.png"),
	]
	thruster_sprite.texture = thruster_frames[0]

func _process(delta: float) -> void:
	_handle_invincibility(delta)
	_handle_powerup_timers(delta)
	_handle_movement(delta)
	_handle_shooting(delta)
	_handle_lightning(delta)
	_animate_thruster(delta)

func _handle_invincibility(delta: float) -> void:
	if invincible:
		inv_timer  -= delta
		blink_timer += delta
		ship_sprite.visible = int(blink_timer * 10.0) % 2 == 0
		if inv_timer <= 0.0:
			invincible = false
			ship_sprite.visible = true

func _handle_powerup_timers(delta: float) -> void:
	if double_timer > 0.0:
		double_timer -= delta
		if double_timer <= 0.0 and shoot_mode == "double":
			shoot_mode = "single"
	if triple_timer > 0.0:
		triple_timer -= delta
		if triple_timer <= 0.0 and shoot_mode == "triple":
			shoot_mode = "single"
	if speed_timer > 0.0:
		speed_timer -= delta
		if speed_timer <= 0.0:
			speed = 300.0
	if rapid_timer > 0.0:
		rapid_timer -= delta
		if rapid_timer <= 0.0:
			shoot_cooldown = 0.28

func _handle_movement(delta: float) -> void:
	var vel := Vector2.ZERO
	if Input.is_action_pressed("move_left"):  vel.x -= 1.0
	if Input.is_action_pressed("move_right"): vel.x += 1.0
	if Input.is_action_pressed("move_up"):    vel.y -= 1.0
	if Input.is_action_pressed("move_down"):  vel.y += 1.0
	if vel.length() > 0: vel = vel.normalized()
	position += vel * speed * delta
	position.x = clamp(position.x, 18.0, 382.0)
	position.y = clamp(position.y, 40.0, 575.0)

func _handle_shooting(delta: float) -> void:
	shoot_timer += delta
	if Input.is_action_pressed("shoot") and shoot_timer >= shoot_cooldown:
		shoot_timer = 0.0
		match shoot_mode:
			"single":
				_spawn_bullet(Vector2.ZERO, Vector2.UP)
			"double":
				_spawn_bullet(Vector2(-12, 0), Vector2.UP)
				_spawn_bullet(Vector2( 12, 0), Vector2.UP)
			"triple":
				_spawn_bullet(Vector2.ZERO,    Vector2.UP)
				_spawn_bullet(Vector2(-10, 0), Vector2(-0.25, -1.0).normalized())
				_spawn_bullet(Vector2( 10, 0), Vector2( 0.25, -1.0).normalized())

func _handle_lightning(delta: float) -> void:
	if not lightning_active: return
	lightning_timer -= delta
	lightning_tick  -= delta
	if lightning_tick <= 0.0:
		lightning_tick = 0.18
		_fire_lightning_bolt()
	if lightning_timer <= 0.0:
		lightning_active = false
		modulate = Color.WHITE

func _fire_lightning_bolt() -> void:
	# Hit ALL enemies on screen simultaneously — chain lightning!
	var gm = get_tree().get_root().get_node_or_null("GameManager")
	if gm == null: return
	for enemy in gm.enemies_node.get_children():
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.take_damage(1)
	# Visual — flash the ship cyan
	modulate = Color(0.3, 1.0, 1.0)
	await get_tree().create_timer(0.08).timeout
	if lightning_active:
		modulate = Color(0.7, 0.9, 1.0)

func _spawn_bullet(offset: Vector2, dir: Vector2) -> void:
	var b = bullet_scene.instantiate()
	b.direction = dir
	b.global_position = global_position + offset + Vector2(0, -28)
	get_tree().get_root().get_node("GameManager/Bullets").add_child(b)

func _animate_thruster(delta: float) -> void:
	var moving = Input.is_action_pressed("move_left")  or \
				 Input.is_action_pressed("move_right") or \
				 Input.is_action_pressed("move_up")    or \
				 Input.is_action_pressed("move_down")
	if moving:
		thruster_timer += delta
		if thruster_timer >= thruster_speed:
			thruster_timer = 0.0
			thruster_idx = (thruster_idx + 1) % thruster_frames.size()
			thruster_sprite.texture = thruster_frames[thruster_idx]
	else:
		thruster_idx = 0
		thruster_sprite.texture = thruster_frames[0]

func take_damage() -> void:
	if invincible: return
	if shield_active:
		shield_active = false
		shield_sprite.visible = false
		modulate = Color.WHITE
		return
	health -= 1
	emit_signal("health_changed", health)
	if health <= 0:
		emit_signal("player_died")
		visible = false
		set_process(false)
	else:
		invincible  = true
		inv_timer   = inv_duration
		blink_timer = 0.0

func apply_powerup(type: String) -> void:
	match type:
		"double":
			shoot_mode   = "double"
			double_timer = 8.0
			triple_timer = 0.0
		"triple":
			shoot_mode   = "triple"
			triple_timer = 5.0
			double_timer = 0.0
		"speed":
			speed       = 430.0
			speed_timer = 6.0
		"shield":
			shield_active = true
			shield_sprite.visible = true
			modulate = Color(0.6, 0.8, 1.0)
		"life":
			if health < max_health:
				health += 1
				emit_signal("health_changed", health)
		"lightning":
			lightning_active  = true
			lightning_timer   = lightning_duration
			lightning_tick    = 0.0
			modulate          = Color(0.7, 0.9, 1.0)
		"rapid":
			shoot_cooldown = 0.10
			rapid_timer    = 7.0
		"nuke":
			nuke_ready = true
			_use_nuke()

func _use_nuke() -> void:
	# Destroy ALL enemies on screen instantly
	var gm = get_tree().get_root().get_node_or_null("GameManager")
	if gm == null: return
	var killed = 0
	for enemy in gm.enemies_node.get_children():
		if is_instance_valid(enemy) and enemy.has_method("take_damage"):
			enemy.take_damage(999)
			killed += 1
	# Flash screen white
	modulate = Color(2.0, 2.0, 2.0)
	await get_tree().create_timer(0.15).timeout
	modulate = Color.WHITE
	nuke_ready = false
