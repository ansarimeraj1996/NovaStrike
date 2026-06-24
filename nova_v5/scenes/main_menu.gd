extends Node2D

var high_score: int = 0
var selected: int = 0  # 0 = START, 1 = QUIT

@onready var hs_label   : Label  = $UI/HighScoreLabel
@onready var start_btn  : Button = $UI/StartBtn
@onready var quit_btn   : Button = $UI/QuitBtn

func _ready() -> void:
	if FileAccess.file_exists("user://highscore.dat"):
		var f = FileAccess.open("user://highscore.dat", FileAccess.READ)
		high_score = f.get_32()
		f.close()
	hs_label.text = "Best: %d" % high_score
	# Connect buttons directly in code — bulletproof
	start_btn.pressed.connect(_start_game)
	quit_btn.pressed.connect(_quit_game)

func _start_game() -> void:
	get_tree().change_scene_to_file("res://game_manager.tscn")

func _quit_game() -> void:
	get_tree().quit()

func _input(event: InputEvent) -> void:
	# Also allow Enter/Space to start
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_ENTER or event.keycode == KEY_SPACE:
			_start_game()
