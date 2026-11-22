extends CharacterBody2D

const BALL_SCENE: PackedScene = preload("res://scenes/ball.tscn")

# Parametri base
@export var base_speed: float = 280.0
@export var jump_force: float = 480.0
@export var max_drag_distance: float = 200.0
@export var dot_time_step: float = 0.065
@export var max_stamina: float = 100.0
@export var stamina_decay_rate: float = 0.0

# Parametri dinamici (influenzati da GameManager)
var launch_force: float = 12.0
var boost_speed: float = 500.0
var max_visible_dots: int = 2

@onready var ball_visual: Sprite2D = $BallVisual
@onready var trajectory_dots: Node2D = $TrajectoryDots
@onready var dust_particles: CPUParticles2D = $DustParticles
@onready var fire_particles: CPUParticles2D = $FireParticles
@onready var fire_light: PointLight2D = get_node_or_null("FireLight")
@onready var camera: Camera2D = $Camera2D

var can_dunk: bool = false
var current_dunk_hoop: Node2D = null
var was_on_floor: bool = true
var dribble_timer: float = 0.0
const BASE_PLAYER_SCALE: Vector2 = Vector2(0.50, 0.50)
var base_ball_scale: Vector2 = Vector2(0.40, 0.40)

# Parametri Combo e modalità "On Fire"
var combo_count: int = 0
var combo_timer: float = 0.0
const COMBO_TIMEOUT: float = 7.5
var is_on_fire: bool = false
const ON_FIRE_THRESHOLD: int = 2

# Parametri Camera Shake (Trauma-based model)
var base_camera_offset: Vector2 = Vector2(180, -120)
var trauma: float = 0.0
var trauma_decay: float = 2.2
var max_shake_offset: Vector2 = Vector2(14.0, 8.0)

var current_speed: float = 280.0
var is_boosting: bool = false
var boost_timer: float = 0.0

var stamina: float = 100.0
var is_game_over: bool = false

# Statistiche partita corrente (per resoconto post-partita)
var shots_taken: int = 0
var shots_scored: int = 0
var perfect_swishes: int = 0
var coins_earned_this_run: int = 0

# Rilevamento Nuovo Record in corsa
var old_high_score: int = 0
var record_celebrated: bool = false

var has_ball: bool = true
var is_dragging: bool = false
var is_button_charging: bool = false
var drag_start_position: Vector2 = Vector2.ZERO
var current_drag_vector: Vector2 = Vector2.ZERO

var hud: CanvasLayer = null

func _ready() -> void:
	old_high_score = GameManager.high_score
	if camera:
		base_camera_offset = camera.offset
	stamina = max_stamina
	apply_upgrades_from_manager()
	
	hud = get_parent().get_node_or_null("HUD")
	if hud:
		hud.update_stamina(stamina, max_stamina)
		hud.update_distance(0)
		hud.update_coins(GameManager.coins)
		
		# Pulsante Salto (sinistra)
		var jump_btn = hud.get_node_or_null("JumpButton")
		if jump_btn:
			jump_btn.focus_mode = Control.FOCUS_NONE
			if not jump_btn.pressed.is_connected(jump):
				jump_btn.pressed.connect(jump)
			
		# Pulsante Tiro + Slow Motion (destra)
		var shoot_btn = hud.get_node_or_null("ShootButton")
		if shoot_btn:
			shoot_btn.focus_mode = Control.FOCUS_NONE
			if not shoot_btn.button_down.is_connected(_on_shoot_button_down):
				shoot_btn.button_down.connect(_on_shoot_button_down)
			if not shoot_btn.button_up.is_connected(_on_shoot_button_up):
				shoot_btn.button_up.connect(_on_shoot_button_up)

func apply_upgrades_from_manager() -> void:
	launch_force = 12.0 + (GameManager.power_level * 1.5)
	boost_speed = 500.0 + (GameManager.power_level * 25.0)
	max_visible_dots = clamp(GameManager.aim_level + 1, 2, 10)
	jump_force = 480.0 + ((GameManager.jump_level - 1) * 32.0)
	max_stamina = 100.0 + ((GameManager.stamina_level - 1) * 20.0)
	stamina = max_stamina
	stamina_decay_rate = 3.5 / (1.0 + (GameManager.stamina_level - 1) * 0.12)

func _process(delta: float) -> void:
	if not camera:
		return
	if trauma > 0.0:
		trauma = max(trauma - trauma_decay * delta, 0.0)
		var shake: float = trauma * trauma
		camera.offset = base_camera_offset + Vector2(
			randf_range(-1.0, 1.0) * max_shake_offset.x * shake,
			randf_range(-1.0, 1.0) * max_shake_offset.y * shake
		)
	elif camera.offset != base_camera_offset:
		camera.offset = base_camera_offset

func add_camera_trauma(amount: float) -> void:
	trauma = clamp(trauma + amount, 0.0, 1.0)

func _physics_process(delta: float) -> void:
	# Caduta nel baratro
	if global_position.y > 850.0 and not is_game_over:
		stamina = 0
		trigger_game_over()

	if is_game_over:
		velocity.x = 0
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		return

	var distance_meters: int = max(0, int(global_position.x / 50.0))

	# ABILITÀ SPECIALE 3: Volo Aereo per i primi 1000 metri!
	var is_flying: bool = (GameManager.special_ability_level >= 3 and distance_meters < 1000)
	if is_flying:
		# Plana in quota fissa a mezz'aria fluttuando dolcemente
		var target_flight_y: float = 330.0 + sin(Time.get_ticks_msec() * 0.003) * 20.0
		global_position.y = lerp(global_position.y, target_flight_y, 4.0 * delta)
		velocity.y = 0
		current_speed = (boost_speed if is_boosting else base_speed) * 1.35
		if fire_particles:
			fire_particles.emitting = true
	else:
		if not is_on_floor():
			velocity += get_gravity() * delta
		if not is_on_fire and fire_particles:
			fire_particles.emitting = false

	if is_boosting:
		boost_timer -= delta
		if boost_timer <= 0:
			is_boosting = false
			if not is_flying:
				current_speed = base_speed
	else:
		if not is_flying:
			current_speed = base_speed

	# Decadimento timer Combo / On Fire
	if combo_timer > 0.0:
		combo_timer -= delta
		if combo_timer <= 0.0:
			reset_combo()

	# ABILITÀ SPECIALE 2: Stamina sempre piena per i primi 1000 metri!
	if GameManager.special_ability_level >= 2 and distance_meters < 1000:
		stamina = max_stamina
	else:
		stamina -= stamina_decay_rate * delta
		if stamina <= 0:
			stamina = 0
			trigger_game_over()

	if hud:
		hud.update_stamina(stamina, max_stamina)
		hud.update_distance(distance_meters)

	# Celebrazione Nuovo Record in tempo reale durante la corsa!
	if old_high_score > 0 and distance_meters > old_high_score and not record_celebrated:
		record_celebrated = true
		add_camera_trauma(0.5)
		if hud and hud.has_method("show_new_record_banner"):
			hud.show_new_record_banner(distance_meters)

	# Se stiamo caricando col pulsante destro, disegna la traiettoria standard
	if is_button_charging and has_ball:
		draw_trajectory()

	# Luce On Fire dinamica
	if fire_light:
		fire_light.enabled = (is_on_fire or is_flying)

	# Controllo opportunità di Schiacciata (Slam Dunk)
	check_dunk_opportunity()

	# Palleggio fisico e dinamico del basket (Dribbling realistico)
	update_ball_dribble(delta)

	velocity.x = current_speed
	floor_snap_length = 12.0
	move_and_slide()

	# Squash & Stretch all'atterraggio dopo un salto
	if not was_on_floor and is_on_floor() and not is_game_over:
		var land_tween = create_tween()
		land_tween.tween_property($Sprite2D, "scale", Vector2(0.58, 0.42), 0.06).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		land_tween.tween_property($Sprite2D, "scale", BASE_PLAYER_SCALE, 0.12).set_trans(Tween.TRANS_SINE)
		GameManager.vibrate_light()
	was_on_floor = is_on_floor()

	# Animazione Procedurale: allineamento pendenza colline e bobbing di corsa
	if is_on_floor() and not is_game_over:
		var floor_normal: Vector2 = get_floor_normal()
		var target_rotation: float = floor_normal.angle() + PI / 2.0
		rotation = lerp_angle(rotation, target_rotation, 14.0 * delta)
		$Sprite2D.position.y = -6.0 + sin(global_position.x * 0.08) * 3.5
		$Sprite2D.rotation = sin(global_position.x * 0.08) * 0.08
	else:
		rotation = lerp_angle(rotation, 0.0, 6.0 * delta)
		$Sprite2D.position.y = lerp($Sprite2D.position.y, -6.0, 8.0 * delta)
		$Sprite2D.rotation = lerp($Sprite2D.rotation, 0.0, 8.0 * delta)

	# Gestione polvere ai piedi in base al contatto col suolo e movimento
	if dust_particles:
		var is_running_on_ground: bool = is_on_floor() and not is_game_over and velocity.x > 10.0
		dust_particles.emitting = is_running_on_ground

# Supporto tastiera (Salto con Spazio/Su/W, Tiro con F/E)
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_UP or event.keycode == KEY_W:
			jump()
		elif event.keycode == KEY_F or event.keycode == KEY_E:
			if can_dunk and current_dunk_hoop:
				perform_slam_dunk(current_dunk_hoop)
			elif has_ball and not is_button_charging:
				_on_shoot_button_down()
	elif event is InputEventKey and not event.pressed:
		if event.keycode == KEY_F or event.keycode == KEY_E:
			if is_button_charging:
				_on_shoot_button_up()

func jump() -> void:
	if is_on_floor() and not is_game_over:
		velocity.y = -jump_force
		var tween = create_tween()
		tween.tween_property($Sprite2D, "scale", Vector2(0.40, 0.62), 0.08)
		tween.tween_property($Sprite2D, "scale", BASE_PLAYER_SCALE, 0.15)

# --- SISTEMA PALLEGGIO FISICO REALISTICO (DRIBBLING) ---
func update_ball_dribble(delta: float) -> void:
	if not has_ball or not ball_visual or not ball_visual.visible:
		return

	# Rotazione naturale rotolamento della palla in corsa
	ball_visual.rotation += (current_speed / 48.0) * delta

	# 1. In fase di caricamento tiro (Aim con slow-motion)
	if is_dragging or is_button_charging:
		var aim_x = -18.0 if current_drag_vector.x < -10.0 else 22.0
		var target_aim_pos = Vector2(aim_x, -24.0)
		ball_visual.position = ball_visual.position.lerp(target_aim_pos, 16.0 * delta)
		ball_visual.scale = ball_visual.scale.lerp(base_ball_scale, 14.0 * delta)
		return

	# 2. In Schiacciata pronta (Slam Dunk range)
	if can_dunk:
		var target_dunk_pos = Vector2(16.0, -32.0)
		ball_visual.position = ball_visual.position.lerp(target_dunk_pos, 14.0 * delta)
		ball_visual.scale = ball_visual.scale.lerp(base_ball_scale, 14.0 * delta)
		return

	# 3. In salto / a mezz'aria o in volo
	var is_flying: bool = (GameManager.special_ability_level >= 3 and int(global_position.x / 50.0) < 1000)
	if not is_on_floor() or is_flying:
		# Palla raccolta al petto/in controllo durante il balzo
		var air_pos = Vector2(20.0, -8.0 + sin(Time.get_ticks_msec() * 0.007) * 3.0)
		ball_visual.position = ball_visual.position.lerp(air_pos, 12.0 * delta)
		ball_visual.scale = ball_visual.scale.lerp(base_ball_scale, 12.0 * delta)
		return

	# 4. Corsa a terra -> PALLEGGIO RITMICO (Dribble tra mano e asfalto/erba)
	var speed_factor = current_speed / base_speed
	dribble_timer += delta * 13.0 * speed_factor

	# Ciclo rimbalzo: 0 = mano in alto, 1 = tocco del suolo in basso
	var cycle: float = abs(sin(dribble_timer))
	var dribble_y: float = lerp(-2.0, 22.0, cycle)
	var dribble_x: float = lerp(18.0, 26.0, cycle)

	ball_visual.position.x = dribble_x
	ball_visual.position.y = dribble_y

	# Micro Squash & Stretch al contatto col suolo
	if cycle > 0.88:
		ball_visual.scale = Vector2(base_ball_scale.x * 1.14, base_ball_scale.y * 0.84)
	else:
		ball_visual.scale = Vector2(base_ball_scale.x * 0.95, base_ball_scale.y * 1.05)

# --- SISTEMA SCHIACCIATA (SLAM DUNK) & CONTROLLI ---
func check_dunk_opportunity() -> void:
	if is_game_over or not has_ball or is_on_floor():
		set_dunk_available(null)
		return

	var hoops = get_tree().get_nodes_in_group("hoops")
	var best_hoop: Node2D = null
	var min_dist: float = 999999.0

	for hoop in hoops:
		if not is_instance_valid(hoop) or hoop.has_scored:
			continue
		var dx: float = hoop.global_position.x - global_position.x
		var dy: float = hoop.global_position.y - global_position.y
		# Raggio di schiacciata: da -30 a 240px orizzontali e tra -140 e 150px verticali
		if dx > -30.0 and dx < 240.0 and abs(dy) < 160.0:
			var dist = Vector2(dx, dy).length()
			if dist < min_dist:
				min_dist = dist
				best_hoop = hoop

	set_dunk_available(best_hoop)

func set_dunk_available(hoop: Node2D) -> void:
	current_dunk_hoop = hoop
	var now_can_dunk: bool = (hoop != null)
	if now_can_dunk != can_dunk:
		can_dunk = now_can_dunk
		if hud and hud.has_method("set_dunk_mode"):
			hud.set_dunk_mode(can_dunk)

func perform_slam_dunk(hoop: Node2D) -> void:
	if not is_instance_valid(hoop) or is_game_over or not has_ball:
		return

	has_ball = false
	ball_visual.visible = false
	can_dunk = false
	is_button_charging = false
	is_dragging = false
	current_drag_vector = Vector2.ZERO
	if trajectory_dots:
		trajectory_dots.clear_dots()
	if hud:
		if hud.has_method("set_dunk_mode"):
			hud.set_dunk_mode(false)
		if hud.has_method("trigger_impact_flash"):
			hud.trigger_impact_flash(Color(1.0, 0.88, 0.2, 0.45))
		var shoot_btn = hud.get_node_or_null("ShootButton")
		if shoot_btn:
			shoot_btn.release_focus()

	# Hitstop (Freeze Frame cinematico reale a mezz'aria)
	Engine.time_scale = 0.08
	get_tree().create_timer(0.12, true, false, true).timeout.connect(func():
		Engine.time_scale = 1.0
	)

	add_camera_trauma(0.85)
	GameManager.vibrate_double()

	# Posa atletica schiacciata: scatto acrobatico sopra il ferro
	var dunk_target: Vector2 = hoop.global_position + Vector2(-24.0, -38.0)
	var tween = create_tween()
	tween.tween_property(self, "global_position", dunk_target, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property($Sprite2D, "rotation", 0.35, 0.08)
	tween.parallel().tween_property($Sprite2D, "scale", Vector2(0.62, 0.42), 0.08)

	# Istanzia il pallone ad altissima velocità verso il basso
	var ball: RigidBody2D = BALL_SCENE.instantiate()
	ball.global_position = hoop.global_position + Vector2(0.0, -22.0)
	ball.is_dunk = true
	get_parent().add_child(ball)
	ball.linear_velocity = Vector2(10.0, 750.0)

	# Rebound acrobatico del corridore
	tween.tween_property($Sprite2D, "rotation", 0.0, 0.2)
	tween.parallel().tween_property($Sprite2D, "scale", BASE_PLAYER_SCALE, 0.2)
	velocity.y = -220.0

	get_tree().create_timer(1.2).timeout.connect(reload_ball)

# --- GESTIONE PULSANTE TIRO DESTRO ---
func _on_shoot_button_down() -> void:
	if is_game_over or not has_ball:
		return
	if can_dunk and current_dunk_hoop:
		perform_slam_dunk(current_dunk_hoop)
		return
	is_button_charging = true
	Engine.time_scale = 0.2 # Bullet Time immediato!
	# Vettore di tiro standard verso l'alto e in avanti a 45 gradi
	current_drag_vector = Vector2(140.0, -110.0)

func _on_shoot_button_up() -> void:
	if is_button_charging:
		is_button_charging = false
		release_shot()

# --- GESTIONE TOUCH / DRAG LIBERO ---
func _input(event: InputEvent) -> void:
	if is_game_over or not has_ball or is_button_charging:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			# Evita zone pulsanti in basso
			if event.position.y > 580 and (event.position.x < 180 or event.position.x > 1100):
				return
			if can_dunk and current_dunk_hoop:
				perform_slam_dunk(current_dunk_hoop)
				return
			start_aim(event.position)
		else:
			if is_dragging:
				release_shot()

	elif event is InputEventMouseMotion and is_dragging:
		update_aim(event.position)

func start_aim(screen_pos: Vector2) -> void:
	is_dragging = true
	drag_start_position = screen_pos
	Engine.time_scale = 0.2

func update_aim(screen_pos: Vector2) -> void:
	# Punta e Spara Diretto: trascini nella direzione esatta in cui vuoi tirare!
	var raw_drag: Vector2 = screen_pos - drag_start_position
	current_drag_vector = raw_drag.limit_length(max_drag_distance)
	draw_trajectory()

func release_shot() -> void:
	is_dragging = false
	Engine.time_scale = 1.0
	trajectory_dots.clear_dots()
	
	if current_drag_vector.length() > 15.0:
		shoot_ball()
	
	current_drag_vector = Vector2.ZERO

func shoot_ball() -> void:
	shots_taken += 1
	has_ball = false
	ball_visual.visible = false
	
	var ball: RigidBody2D = BALL_SCENE.instantiate()
	ball.global_position = ball_visual.global_position
	get_parent().add_child(ball)
	
	var impulse: Vector2 = current_drag_vector * launch_force
	ball.apply_central_impulse(impulse)
	get_tree().create_timer(1.5).timeout.connect(reload_ball)

func reload_ball() -> void:
	if is_game_over:
		return
	has_ball = true
	ball_visual.visible = true

func draw_trajectory() -> void:
	var dots_array: Array[Vector2] = []
	var gravity: Vector2 = get_gravity()
	var initial_velocity: Vector2 = current_drag_vector * launch_force
	var start_pos: Vector2 = ball_visual.global_position
	
	for i in range(max_visible_dots):
		var t: float = (i + 1) * dot_time_step
		var point: Vector2 = start_pos + (initial_velocity * t) + (0.5 * gravity * t * t)
		dots_array.append(point)
	
	trajectory_dots.update_dots(dots_array)

func trigger_boost(is_micro: bool, bonus_coins: int = 1) -> void:
	if is_game_over:
		return

	# Statistiche tiri e canestri
	shots_scored += 1
	if bonus_coins >= 2:
		perfect_swishes += 1

	# Incrementa la serie di canestri consecutivi
	combo_count += 1
	combo_timer = COMBO_TIMEOUT
	if combo_count >= ON_FIRE_THRESHOLD:
		is_on_fire = true
		if fire_particles:
			fire_particles.emitting = true
	
	if hud and hud.has_method("update_combo"):
		hud.update_combo(combo_count, is_on_fire)

	is_boosting = true
	boost_timer = 2.0 if not is_micro else 3.5
	current_speed = boost_speed if not is_micro else boost_speed * 1.3
	add_camera_trauma(0.45 if not is_micro else 0.70)
	
	var base_coins: int = bonus_coins if bonus_coins > 1 else (1 if not is_micro else 3)
	var earned_coins: int = base_coins * (2 if is_on_fire else 1)
	coins_earned_this_run += earned_coins
	GameManager.add_coins(earned_coins)
	if hud:
		hud.update_coins(GameManager.coins)
	
	stamina = min(max_stamina, stamina + (35.0 if not is_micro else 60.0))
	reload_ball()
	
	var tween = create_tween()
	tween.tween_property($Sprite2D, "scale", Vector2(0.62, 0.40), 0.1)
	tween.tween_property($Sprite2D, "scale", BASE_PLAYER_SCALE, 0.2)

func reset_combo() -> void:
	combo_count = 0
	combo_timer = 0.0
	is_on_fire = false
	if fire_particles:
		fire_particles.emitting = false
	if hud and hud.has_method("update_combo"):
		hud.update_combo(0, false)

func trigger_game_over() -> void:
	is_game_over = true
	Engine.time_scale = 1.0
	reset_combo()
	trajectory_dots.clear_dots()
	var distance_meters: int = max(0, int(global_position.x / 50.0))
	GameManager.update_high_score(distance_meters)
	if hud:
		var stats: Dictionary = {
			"shots_taken": shots_taken,
			"shots_scored": shots_scored,
			"perfect_swishes": perfect_swishes,
			"coins_earned": coins_earned_this_run
		}
		hud.show_game_over(distance_meters, stats)

func _on_hoop_goal_scored(is_micro: bool, bonus_coins: int = 1) -> void:
	trigger_boost(is_micro, bonus_coins)
