extends Area2D

var has_triggered: bool = false
@onready var sprite: Sprite2D = $Sprite2D

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if has_triggered:
		return
	if body is CharacterBody2D: # Player
		has_triggered = true
		
		# Sottrae 25 punti stamina
		if "stamina" in body:
			body.stamina = max(0.0, body.stamina - 25.0)
		
		# Camera shake per impatto doloroso
		if body.has_method("add_camera_trauma"):
			body.add_camera_trauma(0.55)
			
		# Flash rosso del player per segnalare il danno
		var player_sprite = body.get_node_or_null("Sprite2D")
		if player_sprite:
			var tween = create_tween()
			tween.tween_property(player_sprite, "modulate", Color(1.0, 0.2, 0.2), 0.08)
			tween.tween_property(player_sprite, "modulate", Color(1.0, 1.0, 1.0), 0.25)
		
		# Testo di avviso fluttuante
		show_damage_text()
		
		# Lo spuntone si ritrae o sgretola leggermente per evitare multi-hit
		var spike_tween = create_tween()
		spike_tween.tween_property(sprite, "scale", Vector2(0.5, 0.1), 0.2)
		spike_tween.tween_property(self, "modulate:a", 0.0, 0.3)
		spike_tween.tween_callback(queue_free)

func show_damage_text() -> void:
	var label = Label.new()
	label.text = "💥 -25 STAMINA!"
	label.position = Vector2(-70, -50)
	label.modulate = Color(1.0, 0.25, 0.25)
	label.add_theme_font_size_override("font_size", 18)
	add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", -100.0, 0.8).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.8)
	tween.tween_callback(label.queue_free)
