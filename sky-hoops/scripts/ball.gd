extends RigidBody2D

@export var launch_force: float = 12.0
@export var max_drag_distance: float = 200.0

# Parametri del Mirino (collegati al futuro sistema di Upgrade!)
@export var trajectory_points_count: int = 25 # Quanti punti compongono la linea
@export var time_step: float = 0.03            # Intervallo tra i punti campionati

@onready var trajectory_line: Line2D = $TrajectoryLine

var is_dragging: bool = false
var drag_start_position: Vector2 = Vector2.ZERO
var current_drag_vector: Vector2 = Vector2.ZERO

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			start_drag(event.position)
		else:
			if is_dragging:
				release_drag()

	elif event is InputEventMouseMotion and is_dragging:
		update_drag(event.position)

func start_drag(screen_pos: Vector2) -> void:
	is_dragging = true
	drag_start_position = screen_pos
	Engine.time_scale = 0.2

func update_drag(screen_pos: Vector2) -> void:
	var raw_drag: Vector2 = drag_start_position - screen_pos
	current_drag_vector = raw_drag.limit_length(max_drag_distance)
	
	# Aggiorna la linea di mira a ogni movimento del mouse/dito
	draw_trajectory()

func release_drag() -> void:
	is_dragging = false
	Engine.time_scale = 1.0
	
	# Cancella la linea del mirino al rilascio
	trajectory_line.clear_points()
	
	if current_drag_vector.length() > 10.0:
		var impulse: Vector2 = current_drag_vector * launch_force
		apply_central_impulse(impulse)
		
	current_drag_vector = Vector2.ZERO

func draw_trajectory() -> void:
	trajectory_line.clear_points()
	
	# 1. Recupera la gravità globale del motore 2D di Godot
	var gravity: Vector2 = get_gravity()
	
	# 2. Velocità iniziale teorica: v0 = impulso / massa
	var initial_velocity: Vector2 = (current_drag_vector * launch_force) / mass
	var start_pos: Vector2 = global_position
	
	# 3. Calcola i punti futuri lungo la parabola cinematica
	for i in range(trajectory_points_count):
		var t: float = i * time_step
		# Formula: P(t) = P0 + V0*t + 0.5*g*t^2
		var point: Vector2 = start_pos + (initial_velocity * t) + (0.5 * gravity * t * t)
		trajectory_line.add_point(point)
