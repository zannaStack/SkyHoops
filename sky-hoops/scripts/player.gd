extends CharacterBody2D

# Scena della palla fisica da istanziare e scagliare
const BALL_SCENE: PackedScene = preload("res://scenes/ball.tscn")

# Parametri di movimento
@export var base_speed: float = 280.0
@export var boost_speed: float = 550.0

# Parametri di tiro
@export var launch_force: float = 14.0
@export var max_drag_distance: float = 200.0
@export var trajectory_points_count: int = 25
@export var time_step: float = 0.03

# Parametri Stamina & Gioco
@export var max_stamina: float = 100.0
@export var stamina_decay_rate: float = 12.0 # Punti stamina persi al secondo

@onready var ball_visual: Sprite2D = $BallVisual
@onready var trajectory_line: Line2D = $TrajectoryLine

var current_speed: float = 280.0
var is_boosting: bool = false
var boost_timer: float = 0.0

# Stato Stamina e Game Over
var stamina: float = 100.0
var is_game_over: bool = false

# Stato del tiro
var has_ball: bool = true
var is_dragging: bool = false
var drag_start_position: Vector2 = Vector2.ZERO
var current_drag_vector: Vector2 = Vector2.ZERO

var hud: CanvasLayer = null

func _ready() -> void:
	stamina = max_stamina
	# Cerca il nodo HUD nella scena principale
	hud = get_parent().get_node_or_null("HUD")
	if hud:
		hud.update_stamina(stamina)
		hud.update_distance(0)

func _physics_process(delta: float) -> void:
	# Se la partita è finita, ferma il personaggio
	if is_game_over:
		velocity.x = 0
		if not is_on_floor():
			velocity += get_gravity() * delta
		move_and_slide()
		return

	# 1. Gestione Gravità
	if not is_on_floor():
		velocity += get_gravity() * delta

	# 2. Gestione Turbo Boost
	if is_boosting:
		boost_timer -= delta
		if boost_timer <= 0:
			is_boosting = false
			current_speed = base_speed
	else:
		current_speed = base_speed

	# 3. Consumo continuo di Stamina
	stamina -= stamina_decay_rate * delta
	if stamina <= 0:
		stamina = 0
		trigger_game_over()

	# 4. Aggiornamento HUD
	if hud:
		hud.update_stamina(stamina)
		var distance_meters: int = max(0, int(global_position.x / 50.0))
		hud.update_distance(distance_meters)

	# 5. Movimento sui pendii
	velocity.x = current_speed
	floor_snap_length = 12.0
	move_and_slide()

func _input(event: InputEvent) -> void:
	if is_game_over:
		return

	# Possiamo mirare solo se abbiamo la palla in mano!
	if not has_ball:
		return

	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			start_aim(event.position)
		else:
			if is_dragging:
				release_shot()

	elif event is InputEventMouseMotion and is_dragging:
		update_aim(event.position)

func start_aim(screen_pos: Vector2) -> void:
	is_dragging = true
	drag_start_position = screen_pos
	Engine.time_scale = 0.2 # Bullet Time!

func update_aim(screen_pos: Vector2) -> void:
	var raw_drag: Vector2 = drag_start_position - screen_pos
	current_drag_vector = raw_drag.limit_length(max_drag_distance)
	draw_trajectory()

func release_shot() -> void:
	is_dragging = false
	Engine.time_scale = 1.0 # Ripristina velocità normale
	trajectory_line.clear_points()
	
	if current_drag_vector.length() > 15.0:
		shoot_ball()
	
	current_drag_vector = Vector2.ZERO

func shoot_ball() -> void:
	has_ball = false
	ball_visual.visible = false
	
	# Istanzia la palla fisica nel mondo
	var ball: RigidBody2D = BALL_SCENE.instantiate()
	ball.global_position = ball_visual.global_position
	get_parent().add_child(ball)
	
	# Calcola l'impulso totale: forza del tiro + inerzia della corsa del player
	var impulse: Vector2 = (current_drag_vector * launch_force) + Vector2(velocity.x * 0.5, 0)
	ball.apply_central_impulse(impulse)
	
	# Timer di ricarica: riottiene la palla dopo 1.5 secondi
	get_tree().create_timer(1.5).timeout.connect(reload_ball)

func reload_ball() -> void:
	if is_game_over:
		return
	has_ball = true
	ball_visual.visible = true

func draw_trajectory() -> void:
	trajectory_line.clear_points()
	var gravity: Vector2 = get_gravity()
	var initial_velocity: Vector2 = current_drag_vector * launch_force + Vector2(velocity.x * 0.5, 0)
	var start_pos: Vector2 = ball_visual.global_position
	
	for i in range(trajectory_points_count):
		var t: float = i * time_step
		var point: Vector2 = start_pos + (initial_velocity * t) + (0.5 * gravity * t * t)
		trajectory_line.add_point(point)

func trigger_boost(is_micro: bool) -> void:
	if is_game_over:
		return

	is_boosting = true
	boost_timer = 2.0 if not is_micro else 3.5
	current_speed = boost_speed if not is_micro else boost_speed * 1.3
	print("🚀 TURBO ATTIVATO! Velocità: ", current_speed)
	
	# Ricarica la stamina ad ogni canestro!
	var recharge: float = 35.0 if not is_micro else 60.0
	stamina = min(max_stamina, stamina + recharge)
	
	# Ricarica subito la palla per continuare la serie
	reload_ball()
	
	var tween = create_tween()
	tween.tween_property($Sprite2D, "scale", Vector2(0.45, 0.25), 0.1)
	tween.tween_property($Sprite2D, "scale", Vector2(0.35, 0.35), 0.2)

func trigger_game_over() -> void:
	is_game_over = true
	Engine.time_scale = 1.0
	trajectory_line.clear_points()
	var distance_meters: int = max(0, int(global_position.x / 50.0))
	print("💀 GAME OVER! Metri percorsi: ", distance_meters)
	if hud:
		hud.show_game_over(distance_meters)

func _on_hoop_goal_scored(is_micro: bool) -> void:
	trigger_boost(is_micro)
