extends Node2D

# ── Preloads ──────────────────────────────────────────────────────────────
var scout_scene     := preload("res://entities/enemies/enemy_scout.tscn")
var tank_scene      := preload("res://entities/enemies/enemy_tank.tscn")
var kamikaze_scene  := preload("res://entities/enemies/enemy_kamikaze.tscn")
var boss1_scene     := preload("res://entities/boss/boss1.tscn")
var boss2_scene     := preload("res://entities/boss/boss2.tscn")
var boss2mini_scene := preload("res://entities/boss/boss2_mini.tscn")
var boss3_scene     := preload("res://entities/boss/boss3.tscn")
var powerup_scene   := preload("res://entities/powerup/powerup.tscn")
var asteroid_scene  := preload("res://entities/asteroid/asteroid.tscn")
var warpgate_scene  := preload("res://entities/warpgate/warpgate.tscn")

# ── Node refs ─────────────────────────────────────────────────────────────
@onready var player        : Area2D   = $Player
@onready var bullets_node  : Node2D   = $Bullets
@onready var enemy_bullets : Node2D   = $EnemyBullets
@onready var enemies_node  : Node2D   = $Enemies
@onready var powerups_node : Node2D   = $Powerups
@onready var hazards_node  : Node2D   = $Hazards
@onready var camera        : Camera2D = $Camera2D
@onready var bg_sprite     : Sprite2D = $BackgroundSprite
@onready var score_label   : Label    = $UI/ScoreLabel
@onready var combo_label   : Label    = $UI/ComboLabel
@onready var level_label   : Label    = $UI/LevelLabel
@onready var message_label : Label    = $UI/MessageLabel
@onready var health_bar    : Node     = $UI/HealthBar
@onready var boss_bar_cont : Control  = $UI/BossBarContainer
@onready var boss_bar      : TextureProgressBar = $UI/BossBarContainer/BossBar
@onready var boss_label    : Label    = $UI/BossBarContainer/BossLabel
@onready var pu_bar        : TextureProgressBar = $UI/PowerupBar
@onready var pu_icon_label : Label    = $UI/PowerupIconLabel
@onready var pause_menu    : Control  = $UI/PauseMenu

# ── State ─────────────────────────────────────────────────────────────────
var score         : int  = 0
var high_score    : int  = 0
var current_level : int  = 1
var kills_total   : int  = 0
var game_over     : bool = false
var paused        : bool = false

enum State { INTRO, SPAWNING, WAITING_CLEAR, BOSS, BOSS_DEAD, VICTORY, GAME_OVER }
var state       : State = State.INTRO
var state_timer : float = 0.0

# Wave tracking
var wave_index      : int   = 0
var waves_per_level : Array = [3, 3, 4]
var enemies_alive   : int   = 0
var spawn_queue     : Array = []
var spawn_timer     : float = 0.0
var spawn_interval  : float = 0.65
var miniboss_count  : int   = 0

# Combo
var combo         : int   = 0
var combo_timer   : float = 0.0
var combo_timeout : float = 3.0
var multiplier    : int   = 1

# Hazards
var asteroid_timer    : float = 3.5
var asteroid_interval : float = 3.5
var warpgate_timer    : float = 12.0
var warpgate_interval : float = 12.0
var warpgate_active   : Node2D = null

# Powerup bar
var pu_timer_max : float = 0.0
var pu_timer_cur : float = 0.0

var backgrounds := [
	"res://assest/background-purple.png",
	"res://assest/background-red.png",
	"res://assest/background-black.png",
]

# Powerup drop weights [type, weight]
# 8 types: double, triple, speed, shield, life, lightning, rapid, nuke
var powerup_pool := [
	["double",    30],
	["triple",    20],
	["speed",     15],
	["shield",    15],
	["life",      10],
	["lightning",  5],
	["rapid",      4],
	["nuke",       1],
]

var heart_tex : Texture2D = null

# ── Ready ─────────────────────────────────────────────────────────────────
func _ready() -> void:
	heart_tex = load("res://assest/spacepixels-0.1.0/spacepixels-0.1.0/horizontal_bar_red.png")
	_load_high_score()
	player.connect("player_died",   _on_player_died)
	player.connect("health_changed", _on_health_changed)
	$UI/PauseMenu/ResumeBtn.pressed.connect(resume_game)
	$UI/PauseMenu/RestartBtn.pressed.connect(restart_game)
	$UI/PauseMenu/QuitBtn.pressed.connect(quit_game)
	_begin_level(1)

# ── Level ─────────────────────────────────────────────────────────────────
func _begin_level(lvl: int) -> void:
	current_level = lvl
	wave_index    = 0
	enemies_alive = 0
	spawn_queue.clear()

	bg_sprite.texture = load(backgrounds[lvl - 1])

	for c in enemies_node.get_children():  c.queue_free()
	for c in enemy_bullets.get_children(): c.queue_free()
	for c in bullets_node.get_children():  c.queue_free()
	for c in powerups_node.get_children(): c.queue_free()
	for c in hazards_node.get_children():  c.queue_free()

	warpgate_active        = null
	boss_bar_cont.visible  = false
	pu_bar.visible         = false
	pu_icon_label.text     = ""
	level_label.text       = "LVL %d" % lvl
	_rebuild_hearts(player.health)

	message_label.text    = "WORLD  %d" % lvl
	message_label.visible = true
	state       = State.INTRO
	state_timer = 2.0

# ── Process ───────────────────────────────────────────────────────────────
func _process(delta: float) -> void:
	if game_over or paused: return

	match state:
		State.INTRO:
			state_timer -= delta
			if state_timer <= 0.0:
				message_label.visible = false
				_launch_next_wave()

		State.SPAWNING:
			state_timer -= delta
			if state_timer <= 0.0:
				message_label.visible = false
			if not spawn_queue.is_empty():
				spawn_timer -= delta
				if spawn_timer <= 0.0:
					spawn_timer = spawn_interval
					var data = spawn_queue.pop_front()
					_spawn_enemy(data["type"], data["x"])
			else:
				state = State.WAITING_CLEAR
			_update_hazards(delta)
			_check_collisions()
			_update_combo(delta)
			_update_powerup_bar(delta)

		State.WAITING_CLEAR:
			_update_hazards(delta)
			_check_collisions()
			_update_combo(delta)
			_update_powerup_bar(delta)
			if enemies_alive <= 0:
				_on_wave_cleared()

		State.BOSS:
			_check_collisions()
			_update_hazards(delta)
			_update_combo(delta)
			_update_powerup_bar(delta)

		State.BOSS_DEAD:
			state_timer -= delta
			if state_timer <= 0.0:
				if current_level < 3:
					_begin_level(current_level + 1)
				else:
					_trigger_victory()

		State.VICTORY, State.GAME_OVER:
			pass

# ── Wave ──────────────────────────────────────────────────────────────────
func _launch_next_wave() -> void:
	wave_index += 1
	if wave_index > waves_per_level[current_level - 1]:
		_trigger_boss()
		return

	var pattern = (wave_index - 1) % 3
	var count   = 6 + (current_level - 1) * 3 + (wave_index - 1) * 2
	var xs      = _formation_x(count, pattern)
	spawn_queue.clear()
	for i in range(count):
		spawn_queue.append({"type": _pick_enemy_type(), "x": xs[i]})

	enemies_alive = spawn_queue.size()
	spawn_timer   = 1.0
	state         = State.SPAWNING
	state_timer   = 1.2
	message_label.text    = "── WAVE  %d ──" % wave_index
	message_label.visible = true

func _pick_enemy_type() -> String:
	if current_level == 1:
		return "scout"
	elif current_level == 2:
		var r = randf()
		return "scout" if r < 0.45 else ("tank" if r < 0.75 else "kamikaze")
	else:
		var r = randf()
		return "scout" if r < 0.33 else ("tank" if r < 0.60 else "kamikaze")

func _on_wave_cleared() -> void:
	message_label.text    = "WAVE CLEAR! ✔"
	message_label.visible = true
	state       = State.INTRO
	state_timer = 1.5

func _formation_x(count: int, pattern: int) -> Array:
	var out := []
	match pattern:
		0:
			var half = count / 2
			for i in range(count):
				var t = float(i - half) / float(max(half, 1))
				out.append(200.0 + t * 160.0)
		1:
			for i in range(count):
				out.append(40.0 + float(i) * (320.0 / float(max(count - 1, 1))))
		2:
			for i in range(count):
				out.append(randf_range(40.0, 360.0))
	return out

func _spawn_enemy(tp: String, x: float) -> void:
	var scene: PackedScene
	match tp:
		"scout":    scene = scout_scene
		"tank":     scene = tank_scene
		"kamikaze": scene = kamikaze_scene
		_:          scene = scout_scene
	var e = scene.instantiate()
	e.position = Vector2(x, -30.0)
	if tp == "scout"  and current_level >= 2: e.health = 2
	if tp == "tank"   and current_level >= 2: e.health = 5
	e.connect("enemy_died",    _on_enemy_died)
	e.connect("enemy_escaped", _on_enemy_escaped)
	enemies_node.add_child(e)

# ── Boss ──────────────────────────────────────────────────────────────────
func _trigger_boss() -> void:
	state                 = State.BOSS
	boss_bar_cont.visible = true
	boss_bar.value        = 100.0
	message_label.text    = "⚠  BOSS  ⚠"
	message_label.visible = true

	var boss
	match current_level:
		1:
			boss            = boss1_scene.instantiate()
			boss_label.text = "GUARDIAN  —  Blue Station"
		2:
			boss            = boss2_scene.instantiate()
			boss_label.text = "SPLITTER  —  Green Station"
		3:
			boss            = boss3_scene.instantiate()
			boss_label.text = "OVERLORD  —  Red Station"

	boss.position = Vector2(200.0, -60.0)
	boss.connect("boss_died",      _on_boss_died)
	boss.connect("health_changed", _on_boss_health_changed)
	enemies_node.add_child(boss)

func _trigger_victory() -> void:
	state     = State.VICTORY
	game_over = true
	_save_high_score()
	message_label.text    = "YOU WIN! 🏆\n\nFinal Score: %d\nBest:  %d\n\nPress  R  to restart" % [score, high_score]
	message_label.visible = true

# ── Hazards ───────────────────────────────────────────────────────────────
func _update_hazards(delta: float) -> void:
	if current_level != 2:
		asteroid_timer -= delta
		if asteroid_timer <= 0.0:
			asteroid_timer = asteroid_interval
			var a = asteroid_scene.instantiate()
			a.position = Vector2(randf_range(20, 380), -20)
			a.connect("asteroid_destroyed", _on_asteroid_destroyed)
			hazards_node.add_child(a)

	if current_level >= 2:
		if warpgate_active == null or not is_instance_valid(warpgate_active):
			warpgate_timer -= delta
			if warpgate_timer <= 0.0:
				warpgate_timer = warpgate_interval
				var w = warpgate_scene.instantiate()
				w.position = Vector2(randf_range(80, 320), randf_range(150, 320))
				warpgate_active = w
				hazards_node.add_child(w)

# ── Collisions ────────────────────────────────────────────────────────────
func _check_collisions() -> void:
	_col_bullets_enemies()
	_col_bullets_asteroids()
	_col_ebullets_player()
	_col_enemies_player()
	_col_powerups_player()
	_col_asteroids_player()
	_col_bullets_warpgate()

func _col_bullets_enemies() -> void:
	for b in bullets_node.get_children():
		if not is_instance_valid(b): continue
		for e in enemies_node.get_children():
			if not is_instance_valid(e): continue
			if b.global_position.distance_to(e.global_position) < 28.0:
				b.queue_free()
				if e.has_method("take_damage"): e.take_damage(1)
				_screen_shake(3.0, 0.1)
				break

func _col_bullets_asteroids() -> void:
	for b in bullets_node.get_children():
		if not is_instance_valid(b): continue
		for a in hazards_node.get_children():
			if not is_instance_valid(a): continue
			if not a.has_method("take_damage"): continue
			if b.global_position.distance_to(a.global_position) < 24.0:
				b.queue_free()
				a.take_damage(1)
				break

func _col_ebullets_player() -> void:
	if not is_instance_valid(player) or player.invincible: return
	for eb in enemy_bullets.get_children():
		if not is_instance_valid(eb): continue
		if eb.global_position.distance_to(player.global_position) < 16.0:
			eb.queue_free()
			player.take_damage()
			_screen_shake(6.0, 0.18)
			return

func _col_enemies_player() -> void:
	if not is_instance_valid(player) or player.invincible: return
	for e in enemies_node.get_children():
		if not is_instance_valid(e): continue
		if e.global_position.distance_to(player.global_position) < 22.0:
			player.take_damage()
			if e.has_method("take_damage"): e.take_damage(99)
			_screen_shake(8.0, 0.22)
			return

func _col_powerups_player() -> void:
	if not is_instance_valid(player): return
	for p in powerups_node.get_children():
		if not is_instance_valid(p): continue
		if p.global_position.distance_to(player.global_position) < 28.0:
			player.apply_powerup(p.powerup_type)
			_set_powerup_bar(p.powerup_type)
			p.queue_free()
			return

func _col_asteroids_player() -> void:
	if not is_instance_valid(player) or player.invincible: return
	for a in hazards_node.get_children():
		if not is_instance_valid(a): continue
		if not a.has_method("take_damage"): continue
		if a.global_position.distance_to(player.global_position) < 22.0:
			player.take_damage()
			a.take_damage(99)
			_screen_shake(6.0, 0.18)
			return

func _col_bullets_warpgate() -> void:
	if warpgate_active == null or not is_instance_valid(warpgate_active): return
	for b in bullets_node.get_children():
		if not is_instance_valid(b): continue
		if b.global_position.distance_to(warpgate_active.global_position) < 32.0:
			warpgate_active.teleport_object(b)

# ── Score & combo ─────────────────────────────────────────────────────────
func _add_score(pts: int) -> void:
	var earned = pts * multiplier
	score += earned
	score_label.text = "SCORE  %d" % score
	var old_m = (score - earned) / 5000
	var new_m = score / 5000
	if new_m > old_m:
		_drop_powerup(Vector2(randf_range(60, 340), 10.0), "life")

func _update_combo(delta: float) -> void:
	if combo > 0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			combo = 0
			multiplier = 1
			combo_label.text = ""

func _register_kill() -> void:
	combo += 1
	combo_timer = combo_timeout
	kills_total += 1
	if combo >= 5:
		multiplier = 3
		combo_label.text     = "COMBO  x3 🔥"
		combo_label.modulate = Color(1.0, 0.4, 0.1)
	elif combo >= 3:
		multiplier = 2
		combo_label.text     = "COMBO  x2 ⚡"
		combo_label.modulate = Color(1.0, 1.0, 0.2)
	else:
		multiplier = 1
		combo_label.text = ""
	# Every 10 kills → guaranteed life drop
	if kills_total % 10 == 0:
		_drop_powerup(player.global_position + Vector2(0, -50), "life")

# ── Powerup drops ─────────────────────────────────────────────────────────
func _weighted_random_powerup() -> String:
	var total = 0
	for entry in powerup_pool:
		total += entry[1]
	var roll = randi() % total
	var acc  = 0
	for entry in powerup_pool:
		acc += entry[1]
		if roll < acc:
			return entry[0]
	return "double"

func _drop_powerup(pos: Vector2, forced: String = "") -> void:
	var p = powerup_scene.instantiate()
	p.position = Vector2(clamp(pos.x, 30.0, 370.0), max(pos.y, 10.0))
	p.powerup_type = forced if forced != "" else _weighted_random_powerup()
	powerups_node.add_child(p)

func _set_powerup_bar(tp: String) -> void:
	const DURATIONS = {
		"double": 8.0, "triple": 5.0, "speed": 6.0,
		"lightning": 6.0, "rapid": 7.0,
	}
	const ICONS = {
		"double": "2x SHOT ▶", "triple": "3x SHOT ▶", "speed": "SPEED ▶",
		"shield": "SHIELD ●", "life": "LIFE ♥",
		"lightning": "LIGHTNING ⚡", "rapid": "RAPID FIRE ▶", "nuke": "NUKE ☢",
	}
	if DURATIONS.has(tp):
		pu_timer_max   = DURATIONS[tp]
		pu_timer_cur   = pu_timer_max
		pu_bar.visible = true
		pu_bar.value   = 100.0
	else:
		pu_bar.visible = false
	pu_icon_label.text = ICONS.get(tp, "")

func _update_powerup_bar(delta: float) -> void:
	if pu_timer_cur > 0.0:
		pu_timer_cur -= delta
		pu_bar.value  = (pu_timer_cur / pu_timer_max) * 100.0
		if pu_timer_cur <= 0.0:
			pu_bar.visible     = false
			pu_icon_label.text = ""

# ── Screen shake ──────────────────────────────────────────────────────────
func _screen_shake(intensity: float, duration: float) -> void:
	var tween = create_tween()
	var steps = int(duration / 0.03)
	for i in range(steps):
		var off = Vector2(randf_range(-intensity, intensity), randf_range(-intensity, intensity))
		tween.tween_property(camera, "offset", off, 0.03)
	tween.tween_property(camera, "offset", Vector2.ZERO, 0.05)

# ── Hearts ────────────────────────────────────────────────────────────────
func _rebuild_hearts(h: int) -> void:
	for c in health_bar.get_children(): c.queue_free()
	for i in range(h):
		var t = TextureRect.new()
		t.texture = heart_tex
		t.custom_minimum_size = Vector2(28, 14)
		t.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
		health_bar.add_child(t)

# ── Signal callbacks ──────────────────────────────────────────────────────
func _on_boss_health_changed(pct: float) -> void:
	boss_bar.value = pct * 100.0

func _on_enemy_died(pts: int, pos: Vector2) -> void:
	enemies_alive = max(enemies_alive - 1, 0)
	_register_kill()
	_add_score(pts)
	if randf() < 0.28: _drop_powerup(pos)
	_screen_shake(2.5, 0.08)

func _on_enemy_escaped() -> void:
	enemies_alive = max(enemies_alive - 1, 0)

func _on_boss_died(pts: int, pos: Vector2) -> void:
	_add_score(pts)
	_drop_powerup(pos, "life")
	_screen_shake(12.0, 0.5)
	boss_bar_cont.visible = false
	message_label.text    = "WORLD CLEAR! ✨"
	message_label.visible = true
	state       = State.BOSS_DEAD
	state_timer = 2.5
	_save_high_score()

func _on_miniboss_died(pts: int, pos: Vector2) -> void:
	_add_score(pts)
	_drop_powerup(pos)
	_screen_shake(8.0, 0.3)
	miniboss_count -= 1
	if miniboss_count <= 0:
		boss_bar_cont.visible = false
		message_label.text    = "WORLD CLEAR! ✨"
		message_label.visible = true
		state       = State.BOSS_DEAD
		state_timer = 2.5
		_save_high_score()

func _on_player_died() -> void:
	state     = State.GAME_OVER
	game_over = true
	_save_high_score()
	_screen_shake(14.0, 0.6)
	message_label.text    = "GAME OVER\n\nScore: %d\nBest:  %d\n\nPress  R  to restart" % [score, high_score]
	message_label.visible = true

func _on_health_changed(new_health: int) -> void:
	_rebuild_hearts(new_health)

func _on_asteroid_destroyed(pts: int, _pos: Vector2) -> void:
	_add_score(pts)
	_screen_shake(2.0, 0.07)

# ── Boss helpers ──────────────────────────────────────────────────────────
func spawn_minibosses(origin: Vector2) -> void:
	miniboss_count = 2
	for i in range(2):
		var mb = boss2mini_scene.instantiate()
		mb.position = origin + Vector2(-65.0 + i * 130.0, 0.0)
		mb.connect("boss_died",      _on_miniboss_died)
		mb.connect("health_changed", _on_boss_health_changed)
		enemies_node.add_child(mb)

func spawn_boss3_minions() -> void:
	for i in range(4):
		var e = scout_scene.instantiate()
		e.position = Vector2(randf_range(40, 360), -30)
		e.connect("enemy_died",    _on_enemy_died)
		e.connect("enemy_escaped", _on_enemy_escaped)
		enemies_node.add_child(e)

# ── Pause / Input ─────────────────────────────────────────────────────────
func _input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel") and not game_over:
		_toggle_pause()
	if game_over and event is InputEventKey and event.pressed:
		if event.keycode == KEY_R:
			get_tree().reload_current_scene()

func _toggle_pause() -> void:
	paused = !paused
	get_tree().paused = paused
	pause_menu.visible = paused

func resume_game() -> void:
	paused = false
	get_tree().paused = false
	pause_menu.visible = false

func restart_game() -> void:
	get_tree().paused = false
	get_tree().reload_current_scene()

func quit_game() -> void:
	get_tree().quit()

# ── High score ────────────────────────────────────────────────────────────
func _load_high_score() -> void:
	if FileAccess.file_exists("user://highscore.dat"):
		var f = FileAccess.open("user://highscore.dat", FileAccess.READ)
		high_score = f.get_32()
		f.close()

func _save_high_score() -> void:
	if score > high_score: high_score = score
	var f = FileAccess.open("user://highscore.dat", FileAccess.WRITE)
	f.store_32(high_score)
	f.close()
