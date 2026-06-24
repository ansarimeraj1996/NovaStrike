extends Area2D

signal boss_died(points: int, pos: Vector2)
signal health_changed(pct: float)

var health: int = 12
var max_health: int = 12
var points: int = 1000
var move_speed: float = 110.0
var move_dir: float = 1.0
var shoot_timer: float = 0.0
var shoot_cooldown: float = 1.0

var eb_scene: PackedScene = preload("res://entities/enemy_bullet/enemy_bullet.tscn")

func _process(delta: float) -> void:
	position.x += move_dir * move_speed * delta
	if position.x >= 360.0 or position.x <= 20.0:
		move_dir *= -1.0
	position.y = move_toward(position.y, 110.0, 50.0 * delta)

	shoot_timer -= delta
	if shoot_timer <= 0.0:
		shoot_timer = shoot_cooldown
		_shoot()

func _shoot() -> void:
	var bn = _get_bullets_node()
	if bn == null:
		return
	var b = eb_scene.instantiate()
	b.global_position = global_position + Vector2(0, 28)
	b.direction = Vector2.DOWN
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
