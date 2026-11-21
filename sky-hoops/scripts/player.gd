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

var current_speed: float = 280.0
var is_boosting: bool = false
var boost_timer: float = 0.0

var stamina: float = 100.0
var is_game_over: bool = false

var has_ball: bool = true
var is_dragging: bool = false
var is_button_charging: bool = false
var drag_start_position: Vector2 = Vector2.ZERO
var current_drag_vector: Vector2 = Vector2.ZERO

var hud: CanvasLayer = null

func _ready() -> void:
	stamina = max_stamina
	apply_upgrades_from_manager()
	
	hud = get_parent().get_node_or_null("HUD")
	if hud:
		hud.update_stamina(stamina)
		hud.update_distance(0)
		hud.update_coins(GameManager.coins)
		
		# Pulsante Salto (sinistra)
		var jump_btn = hud.get_node_or_null("JumpButton")
		if jump_btn and not jump_btn.pressed.is_connected(jump):
			jump_btn.pressed.connect(jump)
			
		# Pulsante Tiro + Slow Motion (destra)
		var shoot_btn = hud.get_node_or_null("ShootButton")
		if shoot_btn:
			if not shoot_btn.button_down.is_connected(_on_shoot_button_down):
				shoot_btn.button_down.connect(_on_shoot_button_down)
			if not shoot_btn.button_up.is_connected(_on_shoot_button_up):
				shoot_btn.button_up.connect(_on_shoot_button_up)

func apply_upgrades_from_manager() -> void:
	launch_force = 12.0 + (GameManager.power_level * 1.5)
	boost_speed = 500.0 + (GameManager.power_level * 25.0)
	max_visible_dots = clamp(GameManager.aim_level * 2, 2, 10)

func _physics_process(delta: float) -> void:
	if is_game_over:
		velocity.x = 0
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		return

	if not is_on_floor():
		velocity += get_gravity() * delta

	if is_boosting:
		boost_timer -= delta
		if boost_timer <= 0:
			is_boosting = false
			current_speed = base_speed
	else:
		current_speed = base_speed

	stamina -= stamina_decay_rate * delta
	if stamina <= 0:
		stamina = 0
		trigger_game_over()

	if hud:
		hud.update_stamina(stamina)
		var distance_meters: int = max(0, int(global_position.x / 50.0))
		hud.update_distance(distance_meters)

	# Se stiamo caricando col pulsante destro, disegna la traiettoria standard
	if is_button_charging and has_ball:
		draw_trajectory()

	velocity.x = current_speed
	floor_snap_length = 12.0
	move_and_slide()

# Supporto salto da tastiera
func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed:
		if event.keycode == KEY_SPACE or event.keycode == KEY_UP:
			jump()

func jump() -> void:
	if is_on_floor() and not is_game_over:
		velocity.y = -jump_force
		var tween = create_tween()
		tween.tween_property($Sprite2D, "scale", Vector2(0.35, 0.55), 0.08)
		tween.tween_property($Sprite2D, "scale", Vector2(0.45, 0.45), 0.15)

# --- GESTIONE PULSANTE TIRO DESTRO ---
func _on_shoot_button_down() -> void:
	if is_game_over or not has_ball:
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
	var raw_drag: Vector2 = drag_start_position - screen_pos
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
	has_ball = false
	ball_visual.visible = false
	
	var ball: RigidBody2D = BALL_SCENE.instantiate()
	ball.global_position = ball_visual.global_position
	get_parent().add_child(ball)
	
	var impulse: Vector2 = (current_drag_vector * launch_force) + Vector2(velocity.x * 0.5, 0)
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
	var initial_velocity: Vector2 = current_drag_vector * launch_force + Vector2(velocity.x * 0.5, 0)
	var start_pos: Vector2 = ball_visual.global_position
	
	for i in range(max_visible_dots):
		var t: float = (i + 1) * dot_time_step
		var point: Vector2 = start_pos + (initial_velocity * t) + (0.5 * gravity * t * t)
		dots_array.append(point)
	
	trajectory_dots.update_dots(dots_array)

func trigger_boost(is_micro: bool) -> void:
	if is_game_over:
		return

	is_boosting = true
	boost_timer = 2.0 if not is_micro else 3.5
	current_speed = boost_speed if not is_micro else boost_speed * 1.3
	
	var earned_coins: int = 1 if not is_micro else 3
	GameManager.add_coins(earned_coins)
	if hud:
		hud.update_coins(GameManager.coins)
	
	stamina = min(max_stamina, stamina + (35.0 if not is_micro else 60.0))
	reload_ball()
	
	var tween = create_tween()
	tween.tween_property($Sprite2D, "scale", Vector2(0.55, 0.35), 0.1)
	tween.tween_property($Sprite2D, "scale", Vector2(0.45, 0.45), 0.2)

func trigger_game_over() -> void:
	is_game_over = true
	Engine.time_scale = 1.0
	trajectory_dots.clear_dots()
	var distance_meters: int = max(0, int(global_position.x / 50.0))
	GameManager.update_high_score(distance_meters)
	if hud:
		hud.show_game_over(distance_meters)

func _on_hoop_goal_scored(is_micro: bool) -> void:
	trigger_boost(is_micro)
