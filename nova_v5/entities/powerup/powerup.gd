extends Area2D

var powerup_type : String = "double"
var fall_speed   : float  = 115.0
var wobble_seed  : float  = 0.0

# All 8 powerup types with colors for label
const TYPE_COLORS = {
	"double":    Color(0.3, 0.6, 1.0),
	"triple":    Color(0.5, 0.3, 1.0),
	"speed":     Color(1.0, 0.9, 0.1),
	"shield":    Color(0.2, 0.8, 1.0),
	"life":      Color(1.0, 0.3, 0.3),
	"lightning": Color(0.9, 1.0, 0.1),
	"rapid":     Color(1.0, 0.5, 0.0),
	"nuke":      Color(1.0, 0.2, 0.2),
}

const TYPE_LABELS = {
	"double":    "2x SHOT",
	"triple":    "3x SHOT",
	"speed":     "SPEED",
	"shield":    "SHIELD",
	"life":      "LIFE ♥",
	"lightning": "LIGHTNING",
	"rapid":     "RAPID",
	"nuke":      "NUKE ☢",
}

const TYPE_ASSETS = {
	"double":    "res://assest/spacepixels-0.1.0/spacepixels-0.1.0/pixel_laser_blue.png",
	"triple":    "res://assest/spacepixels-0.1.0/spacepixels-0.1.0/pixel_laser_small_blue.png",
	"speed":     "res://assest/spacepixels-0.1.0/spacepixels-0.1.0/pixel_laser_yellow.png",
	"shield":    "res://assest/spacepixels-0.1.0/spacepixels-0.1.0/horizontal_bar_blue.png",
	"life":      "res://assest/spacepixels-0.1.0/spacepixels-0.1.0/pixel_laser_green.png",
	"lightning": "res://assest/spacepixels-0.1.0/spacepixels-0.1.0/pixel_laser_yellow.png",
	"rapid":     "res://assest/spacepixels-0.1.0/spacepixels-0.1.0/pixel_laser_red.png",
	"nuke":      "res://assest/spacepixels-0.1.0/spacepixels-0.1.0/pixel_laser_red.png",
}

@onready var sprite : Sprite2D = $Sprite2D
@onready var label  : Label    = $Label

func _ready() -> void:
	wobble_seed = randf() * 10.0
	# Set sprite texture
	if TYPE_ASSETS.has(powerup_type):
		sprite.texture = load(TYPE_ASSETS[powerup_type])
	# Set label text and color
	if TYPE_LABELS.has(powerup_type):
		label.text = TYPE_LABELS[powerup_type]
	if TYPE_COLORS.has(powerup_type):
		label.modulate = TYPE_COLORS[powerup_type]
		sprite.modulate = TYPE_COLORS[powerup_type]

func _process(delta: float) -> void:
	position.y += fall_speed * delta
	position.x += sin(Time.get_ticks_msec() * 0.003 + wobble_seed) * 0.6
	if position.y > 640:
		queue_free()
