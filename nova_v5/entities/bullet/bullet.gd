extends Area2D

var speed: float = 500.0
var direction: Vector2 = Vector2.UP
var damage: int = 1

func _process(delta: float) -> void:
	position += direction * speed * delta
	if position.y < -20 or position.y > 620 or position.x < -20 or position.x > 420:
		queue_free()
