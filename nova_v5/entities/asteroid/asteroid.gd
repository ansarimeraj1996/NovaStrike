extends Area2D

signal asteroid_destroyed(points: int, pos: Vector2)

var speed: float = 0.0
var rotation_speed: float = 0.0
var points: int = 50
var health: int = 1

func _ready() -> void:
	speed = randf_range(75.0, 145.0)
	rotation_speed = randf_range(-1.5, 1.5)

func _process(delta: float) -> void:
	position.y += speed * delta
	rotation += rotation_speed * delta
	if position.y > 640:
		queue_free()

func take_damage(dmg: int = 1) -> void:
	health -= dmg
	if health <= 0:
		emit_signal("asteroid_destroyed", points, global_position)
		queue_free()
