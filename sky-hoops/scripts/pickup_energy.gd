extends Area2D

var is_collected: bool = false
@onready var sprite: Sprite2D = $Sprite2D
@onready var glow_particles: CPUParticles2D = $GlowParticles

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	start_hover_animation()

func start_hover_animation() -> void:
	var tween = create_tween().set_loops()
	tween.tween_property(sprite, "position:y", -6.0, 0.6).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "position:y", 6.0, 0.6).set_trans(Tween.TRANS_SINE)

func _on_body_entered(body: Node2D) -> void:
	if is_collected:
		return
	if body is CharacterBody2D: # Player
		is_collected = true
		
		# Ripristina 50 punti di stamina al corridore
		if "stamina" in body and "max_stamina" in body:
			body.stamina = min(body.max_stamina, body.stamina + 50.0)
			
		if glow_particles:
			glow_particles.emitting = true
			
		show_pickup_text()
		
		var tween = create_tween()
		tween.tween_property(self, "position:y", position.y - 40.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(sprite, "scale", Vector2(0.65, 0.65), 0.3)
		tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3)
		tween.tween_callback(queue_free)

func show_pickup_text() -> void:
	var label = Label.new()
	label.text = "⚡ +50 STAMINA!"
	label.position = Vector2(-70, -45)
	label.modulate = Color(0.2, 1.0, 0.7)
	label.add_theme_font_size_override("font_size", 18)
	add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", -95.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)
