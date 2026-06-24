extends Area2D

signal boss_died(points: int, pos: Vector2)
signal health_changed(pct: float)

var health: int = 15
var max_health: int = 15
var points: int = 1000
var phase: int = 1

var move_speed: float = 70.0
var move_dir: float = 1.0
var shoot_timer: float = 0.0
var shoot_cooldown: float = 1.5
var side_shoot_timer: float = 0.0

var player_ref: Node2D = null
var eb_scene: PackedScene = preload("res://entities/enemy_bullet/enemy_bullet.tscn")

func _ready() -> void:
	var root = get_tree().get_root()
	if root.has_node("GameManager/Player"):
		player_ref = root.get_node("GameManager/Player")

func _process(delta: float) -> void:
	# Phase check
	if phase == 1 and health <= max_health / 2:
		phase = 2
		shoot_cooldown = 0.9
		move_speed = 110.0

	# Movement
	position.x += move_dir * move_speed * delta
	if position.x >= 340.0 or position.x <= 60.0:
		move_dir *= -1.0
	position.y = move_toward(position.y, 90.0, 40.0 * delta)

	# Shoot homing
	shoot_timer -= delta
	if shoot_timer <= 0.0:
		shoot_timer = shoot_cooldown
		_shoot_homing()

	# Phase 2: side cannons
	if phase == 2:
		side_shoot_timer -= delta
		if side_shoot_timer <= 0.0:
			side_shoot_timer = 1.4
			_shoot_sides()

func _shoot_homing() -> void:
	var bn = _get_bullets_node()
	if bn == null:
		return
	var b = eb_scene.instantiate()
	b.global_position = global_position + Vector2(0, 36)
	b.direction = Vector2.DOWN
	b.homing = true
	b.speed = 140.0
	if player_ref and is_instance_valid(player_ref):
		b.player_ref = player_ref
	bn.add_child(b)

func _shoot_sides() -> void:
	var bn = _get_bullets_node()
	if bn == null:
		return
	for offset_x in [-30, 30]:
		var b = eb_scene.instantiate()
		b.global_position = global_position + Vector2(offset_x, 20)
		b.direction = Vector2(sign(offset_x) * 0.4, 1.0).normalized()
		b.speed = 200.0
		bn.add_child(b)

func _get_bullets_node() -> Node:
	var root = get_tree().get_root()
	if root.has_node("GameManager/EnemyBullets"):
		return root.get_node("GameManager/EnemyBullets")
	return null

func take_damage(dmg: int = 1) -> void:
	health -= dmg
	emit_signal("health_changed", float(health) / float(max_health))
	if health <= 0:
		emit_signal("boss_died", points, global_position)
		queue_free()
