extends Area2D

signal goal_scored(is_micro: bool)

@export var is_micro: bool = false
@export var is_oscillating: bool = false
@export var oscillation_amplitude: float = 45.0
@export var oscillation_speed: float = 2.0

var initial_y: float = 0.0
var time_passed: float = 0.0
var has_scored: bool = false
@onready var visual_sprite: Sprite2D = $VisualSprite
@onready var goal_particles: CPUParticles2D = $GoalParticles

func _ready() -> void:
	initial_y = position.y
	# Randomizza leggermente la fase iniziale per non farli oscillare tutti all'unisono
	time_passed = randf_range(0.0, PI * 2)
	body_entered.connect(_on_body_entered)
	if is_micro:
		scale = Vector2(0.65, 0.65)
		modulate = Color(1.0, 0.82, 0.15) # Tinta dorata brillante per i canestri micro

func _process(delta: float) -> void:
	if is_oscillating:
		time_passed += delta
		position.y = initial_y + sin(time_passed * oscillation_speed) * oscillation_amplitude

func _on_body_entered(body: Node2D) -> void:
	# Controlla che sia la palla fisica e che non abbiamo già segnato in questo canestro
	if body is RigidBody2D and not has_scored:
		# Valido se la palla sta scendendo o entra in arco parabolico (non dal basso verso l'alto)
		if body.linear_velocity.y > -50.0:
			has_scored = true
			print("🏀 GOAL! Canestro effettuato! Micro: ", is_micro)
			goal_scored.emit(is_micro)
			if goal_particles:
				if is_micro:
					goal_particles.color = Color(1.0, 0.85, 0.1) # Oro brillante per i micro
				else:
					goal_particles.color = Color(1.0, 0.55, 0.1) # Arancione per i normali
				goal_particles.restart() # Riavvia il ciclo one-shot da zero
			# Testo fluttuante sopra il canestro
			show_floating_text()
			
			# Effetto visivo "Swish" della retina: si allunga verso il basso e ritorna in posizione!
			if visual_sprite:
				var tween = create_tween()
				tween.tween_property(visual_sprite, "scale", Vector2(0.9, 1.25), 0.1)
				tween.tween_property(visual_sprite, "scale", Vector2(1.0, 1.0), 0.2)

func show_floating_text() -> void:
	var label = Label.new()
	label.text = "🏀 SWISH! +1 🪙" if not is_micro else "🔥 MICRO SWISH! +3 🪙"
	label.position = Vector2(-60, -70)
	label.modulate = Color(1.0, 0.85, 0.2)
	label.add_theme_font_size_override("font_size", 18)
	add_child(label)
	
	# Animazione elegante: il testo sale e sfuma via
	var tween = create_tween()
	tween.tween_property(label, "position:y", -120.0, 0.9)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.9)
	tween.tween_callback(label.queue_free)
