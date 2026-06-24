extends Area2D

signal enemy_died(points: int, pos: Vector2)
signal enemy_escaped()

var health: int = 1
var points: int = 150
var speed: float = 0.0
var max_speed: float = 210.0
var accel: float = 180.0
var player_ref: Node2D = null
var direction: Vector2 = Vector2.DOWN

func _ready() -> void:
	var root = get_tree().get_root()
	if root.has_node("GameManager/Player"):
		player_ref = root.get_node("GameManager/Player")

func _process(delta: float) -> void:
	speed = min(speed + accel * delta, max_speed)
	if player_ref and is_instance_valid(player_ref):
		direction = (player_ref.global_position - global_position).normalized()
	position += direction * speed * delta
	if position.y > 640 or position.x < -60 or position.x > 460:
		emit_signal("enemy_escaped")
		queue_free()

func take_damage(dmg: int = 1) -> void:
	health -= dmg
	if health <= 0:
		emit_signal("enemy_died", points, global_position)
		queue_free()
