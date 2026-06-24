extends Area2D

signal enemy_died(points: int, pos: Vector2)
signal enemy_escaped()

var health: int = 1
var points: int = 100
var speed: float = 130.0
var shoot_cooldown: float = 2.5
var shoot_timer: float = 0.0

var zigzag_speed: float = 55.0
var zigzag_dir: float = 1.0
var zigzag_range: float = 45.0
var start_x: float = 0.0

var eb_scene: PackedScene = preload("res://entities/enemy_bullet/enemy_bullet.tscn")

func _ready() -> void:
	start_x = position.x
	shoot_timer = randf_range(0.5, 2.0)
	zigzag_dir = 1.0 if randf() > 0.5 else -1.0

func _process(delta: float) -> void:
	position.y += speed * delta
	position.x += zigzag_dir * zigzag_speed * delta
	if abs(position.x - start_x) >= zigzag_range:
		zigzag_dir *= -1.0
	position.x = clamp(position.x, 15.0, 385.0)

	shoot_timer -= delta
	if shoot_timer <= 0.0:
		shoot_timer = shoot_cooldown
		_shoot()

	if position.y > 630:
		emit_signal("enemy_escaped")
		queue_free()

func _shoot() -> void:
	var bn = _get_bullets_node()
	if bn == null: return
	var b = eb_scene.instantiate()
	b.global_position = global_position + Vector2(0, 16)
	b.direction = Vector2.DOWN
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
