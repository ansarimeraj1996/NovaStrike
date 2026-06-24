extends Area2D

signal boss_died(points: int, pos: Vector2)
signal health_changed(pct: float)

var health: int = 25
var max_health: int = 25
var points: int = 2000
var phase: int = 1
var split_done: bool = false

var move_speed: float = 90.0
var move_dir: float = 1.0
var shoot_timer: float = 0.0
var shoot_cooldown: float = 1.2

var eb_scene: PackedScene = preload("res://entities/enemy_bullet/enemy_bullet.tscn")

func _ready() -> void:
	pass

func _process(delta: float) -> void:
	if phase == 1 and health <= max_health / 2 and not split_done:
		_do_split()
		return

	position.x += move_dir * move_speed * delta
	if position.x >= 340.0 or position.x <= 60.0:
		move_dir *= -1.0
	position.y = move_toward(position.y, 90.0, 40.0 * delta)

	shoot_timer -= delta
	if shoot_timer <= 0.0:
		shoot_timer = shoot_cooldown
		_shoot_spread()

func _shoot_spread() -> void:
	var bn = _get_bullets_node()
	if bn == null:
		return
	for d in [Vector2(-0.5, 1.0).normalized(), Vector2.DOWN, Vector2(0.5, 1.0).normalized()]:
		var b = eb_scene.instantiate()
		b.global_position = global_position + Vector2(0, 36)
		b.direction = d
		b.speed = 220.0
		bn.add_child(b)

func _do_split() -> void:
	split_done = true
	phase = 2
	# Notify game manager to spawn 2 mini bosses
	var gm = get_tree().get_root().get_node_or_null("GameManager")
	if gm:
		gm.spawn_minibosses(global_position)
	emit_signal("boss_died", 0, global_position)
	queue_free()

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
