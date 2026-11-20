extends Area2D

signal goal_scored(is_micro: bool)

@export var is_micro: bool = false

var has_scored: bool = false

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if is_micro:
		scale = Vector2(0.6, 0.6)
		modulate = Color(1.0, 0.8, 0.2)

func _on_body_entered(body: Node2D) -> void:
	# Controlla che sia la palla e che stia scendendo (Vy > 0)
	if body is RigidBody2D and not has_scored:
		if body.linear_velocity.y > 0:
			has_scored = true
			print("🏀 GOAL! Canestro effettuato! Micro: ", is_micro)
			goal_scored.emit(is_micro)
			
			# Mostra scritta a schermo direttamente sopra il canestro!
			show_floating_text()
			
			# Flash verde sul canestro
			var tween = create_tween()
			tween.tween_property(self, "modulate", Color(0.2, 1.0, 0.2), 0.1)
			tween.tween_property(self, "modulate", Color.WHITE if not is_micro else Color(1.0, 0.8, 0.2), 0.4)

func show_floating_text() -> void:
	var label = Label.new()
	label.text = "🏀 GOAL!" if not is_micro else "🔥 MICRO GOAL! +3"
	label.position = Vector2(-40, -40)
	label.modulate = Color(1, 0.8, 0.2)
	add_child(label)
	
	# Animazione elegante: il testo sale e sfuma via
	var tween = create_tween()
	tween.tween_property(label, "position:y", -80.0, 0.8)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)
