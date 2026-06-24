extends Area2D

var frame_textures: Array = []
var frame_idx: int = 0
var anim_timer: float = 0.0
var anim_speed: float = 0.15
var lifetime: float = 8.0

func _ready() -> void:
	frame_textures = [
		load("res://assest/spacepixels-0.1.0/spacepixels-0.1.0/warpgate_1.png"),
		load("res://assest/spacepixels-0.1.0/spacepixels-0.1.0/warpgate_2.png"),
		load("res://assest/spacepixels-0.1.0/spacepixels-0.1.0/warpgate_3.png"),
	]
	$Sprite2D.texture = frame_textures[0]

func _process(delta: float) -> void:
	lifetime -= delta
	if lifetime <= 0.0:
		queue_free()
		return
	# Animate frames
	anim_timer += delta
	if anim_timer >= anim_speed:
		anim_timer = 0.0
		frame_idx = (frame_idx + 1) % frame_textures.size()
		$Sprite2D.texture = frame_textures[frame_idx]
	# Rotate slowly
	rotation += delta * 0.8

func teleport_object(obj: Node2D) -> void:
	obj.global_position = Vector2(randf_range(30, 370), randf_range(60, 400))
