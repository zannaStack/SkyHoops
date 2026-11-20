extends RigidBody2D

# Proprietà esportate: saranno visibili e modificabili direttamente dall'Inspector di Godot!
@export var launch_force: float = 12.0      # Moltiplicatore di potenza del tiro
@export var max_drag_distance: float = 200.0 # Limite massimo di allungamento della fionda

var is_dragging: bool = false
var drag_start_position: Vector2 = Vector2.ZERO
var current_drag_vector: Vector2 = Vector2.ZERO

func _input(event: InputEvent) -> void:
	# 1. Rileva il click/tocco iniziale
	if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.is_pressed():
			start_drag(event.position)
		else:
			if is_dragging:
				release_drag()

	# 2. Se stiamo trascinando, aggiorna la posizione corrente
	elif event is InputEventMouseMotion and is_dragging:
		update_drag(event.position)

func start_drag(screen_pos: Vector2) -> void:
	is_dragging = true
	drag_start_position = screen_pos
	# Attiva il Bullet Time: rallenta il tempo al 20%
	Engine.time_scale = 0.2

func update_drag(screen_pos: Vector2) -> void:
	# Calcola il vettore tra il punto iniziale e il dito
	var raw_drag: Vector2 = drag_start_position - screen_pos
	# Limita la lunghezza massima del vettore per non dare potenza infinita
	current_drag_vector = raw_drag.limit_length(max_drag_distance)

func release_drag() -> void:
	is_dragging = false
	# Ripristina il tempo a velocità normale
	Engine.time_scale = 1.0
	
	# Se il trascinamento è stato significativo, scaglia la palla
	if current_drag_vector.length() > 10.0:
		# Calcola l'impulso finale
		var impulse: Vector2 = current_drag_vector * launch_force
		apply_central_impulse(impulse)
		
	current_drag_vector = Vector2.ZERO
