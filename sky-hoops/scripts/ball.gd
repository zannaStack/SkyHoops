extends RigidBody2D

func _ready() -> void:
	# Dopo 2.5 secondi dal tiro, avvia la dissolvenza
	get_tree().create_timer(2.5).timeout.connect(fade_out_and_destroy)

func fade_out_and_destroy() -> void:
	# Effetto elegante: riduce l'opacità a zero in 0.5 secondi e poi elimina la palla
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.5)
	tween.tween_callback(queue_free)
