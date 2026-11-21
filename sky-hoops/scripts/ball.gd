extends RigidBody2D

# La palla è ora un puro proiettile fisico lanciato dal Player.
# Si autodistrugge dopo 6 secondi per liberare memoria se finisce fuori mappa.
func _ready() -> void:
	get_tree().create_timer(6.0).timeout.connect(queue_free)
