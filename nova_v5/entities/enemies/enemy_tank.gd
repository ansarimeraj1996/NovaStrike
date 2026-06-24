extends Area2D

signal enemy_died(points: int, pos: Vector2)
signal enemy_escaped()

var health: int = 3
var points: int = 200
var speed: float = 55.0
var shoot_cooldown: float = 2.0
var shoot_timer: float = 0.0

var eb_scene: PackedScene = preload("res://entities/enemy_bullet/enemy_bullet.tscn")

func _ready() -> void:
	shoot_timer = randf_range(0.5, 1.5)

func _process(delta: float) -> void:
	position.y += speed * delta
	shoot_timer -= delta
	if shoot_timer <= 0.0:
		shoot_timer = shoot_cooldown
		_shoot_spread()
	if position.y > 630:
		emit_signal("enemy_escaped")
		queue_free()

func _shoot_spread() -> void:
	var bn = _get_bullets_node()
	if bn == null: return
	for d in [Vector2(-0.3, 1.0).normalized(), Vector2.DOWN, Vector2(0.3, 1.0).normalized()]:
		var b = eb_scene.instantiate()
		b.global_position = global_position + Vector2(0, 18)
		b.direction = d
		bn.add_child(b)

func _get_bullets_node() -> Node:
	var root = get_tree().get_root()
	if root.has_node("GameManager/EnemyBullets"):
		return root.get_node("GameManager/EnemyBullets")
	return null

func take_damage(dmg: int = 1) -> void:
	health -= dmg
	if health <= 0:
		emit_signal("enemy_died", points, global_position)
		queue_free()
