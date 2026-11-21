extends Area2D

@export var flight_speed: float = 140.0
var is_deflected: bool = false
var time_passed: float = 0.0
var base_y: float = 0.0

@onready var sprite: Sprite2D = $Sprite2D
@onready var feather_particles: CPUParticles2D = $FeatherParticles

func _ready() -> void:
	base_y = position.y
	time_passed = randf_range(0.0, PI * 2)
	body_entered.connect(_on_body_entered)
	start_wing_flap()

func start_wing_flap() -> void:
	var tween = create_tween().set_loops()
	tween.tween_property(sprite, "scale:y", 0.65, 0.18).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale:y", 1.15, 0.18).set_trans(Tween.TRANS_SINE)

func _process(delta: float) -> void:
	if is_deflected:
		# Fugge rapidamente verso l'alto
		position.y -= 380.0 * delta
		position.x += 160.0 * delta
		return
		
	time_passed += delta
	# Vola da destra verso sinistra fluttuando su e giù
	position.x -= flight_speed * delta
	position.y = base_y + sin(time_passed * 2.8) * 18.0

func _on_body_entered(body: Node2D) -> void:
	if is_deflected:
		return
	if body is RigidBody2D: # Pallone da basket
		is_deflected = true
		
		# Devia con forza il pallone respingendolo verso il basso/indietro
		body.apply_central_impulse(Vector2(-280.0, 260.0))
		
		if feather_particles:
			feather_particles.emitting = true
			
		show_intercept_text()
		
		var tween = create_tween()
		tween.tween_property(self, "modulate:a", 0.0, 0.6)
		tween.tween_callback(queue_free)

func show_intercept_text() -> void:
	var label = Label.new()
	label.text = "🐦 TIRO INTERCETTATO!"
	label.position = Vector2(-80, -40)
	label.modulate = Color(0.4, 0.8, 1.0)
	label.add_theme_font_size_override("font_size", 18)
	add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", -90.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)
