extends Area2D

signal boss_died(points: int, pos: Vector2)
signal health_changed(pct: float)

var health: int = 40
var max_health: int = 40
var points: int = 5000
var phase: int = 1
var minions_spawned: bool = false

var move_speed: float = 85.0
var move_dir: float = 1.0
var shoot_timer: float = 0.0
var shoot_cooldown: float = 0.8

var player_ref: Node2D = null
var eb_scene: PackedScene = preload("res://entities/enemy_bullet/enemy_bullet.tscn")

func _ready() -> void:
	var root = get_tree().get_root()
	if root.has_node("GameManager/Player"):
		player_ref = root.get_node("GameManager/Player")

func _process(delta: float) -> void:
	# Phase transitions
	if health <= int(max_health * 0.6) and phase == 1:
		phase = 2
		shoot_cooldown = 0.55
		move_speed = 130.0
	if health <= int(max_health * 0.3) and phase == 2:
		phase = 3
		shoot_cooldown = 0.4
		if not minions_spawned:
			minions_spawned = true
			var gm = get_tree().get_root().get_node_or_null("GameManager")
			if gm:
				gm.spawn_boss3_minions()

	# Movement
	position.x += move_dir * move_speed * delta
	if position.x >= 340.0 or position.x <= 60.0:
		move_dir *= -1.0
	position.y = move_toward(position.y, 85.0, 50.0 * delta)

	shoot_timer -= delta
	if shoot_timer <= 0.0:
		shoot_timer = shoot_cooldown
		_shoot()

func _shoot() -> void:
	var bn = _get_bullets_node()
	if bn == null:
		return
	var spread_count = 3 if phase == 1 else (5 if phase == 2 else 7)
	var angle_step = 20.0
	var start_angle = -(spread_count / 2) * angle_step
	for i in range(spread_count):
		var angle = deg_to_rad(start_angle + i * angle_step)
		var dir = Vector2(sin(angle), cos(angle))
		var b = eb_scene.instantiate()
		b.global_position = global_position + Vector2(0, 40)
		b.direction = dir
		b.speed = 230.0
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
