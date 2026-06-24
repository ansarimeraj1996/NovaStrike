extends Area2D

var speed: float = 260.0
var direction: Vector2 = Vector2.DOWN
var homing: bool = false
var homing_strength: float = 80.0
var player_ref: Node2D = null

func _process(delta: float) -> void:
	if homing and player_ref and is_instance_valid(player_ref):
		var target_dir = (player_ref.global_position - global_position).normalized()
		direction = direction.lerp(target_dir, homing_strength * delta * 0.02).normalized()
	position += direction * speed * delta
	if position.y > 620 or position.y < -20 or position.x < -20 or position.x > 420:
		queue_free()
