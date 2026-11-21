extends Area2D

@export var value: int = 1

var is_collected: bool = false
@onready var sprite: Sprite2D = $Sprite2D
@onready var spark_particles: CPUParticles2D = $SparkParticles

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	start_spin_animation()

func _physics_process(delta: float) -> void:
	if is_collected:
		return
	# Abilità Speciale 1: Calamita Monete
	if GameManager.special_ability_level >= 1:
		var player = get_tree().root.find_child("Player", true, false)
		if player:
			var dist = global_position.distance_to(player.global_position)
			if dist < 280.0:
				var dir = (player.global_position - global_position).normalized()
				var speed = lerp(420.0, 950.0, 1.0 - (dist / 280.0))
				global_position += dir * speed * delta

func start_spin_animation() -> void:
	# Finto 3D coin spin animando scale.x e leggera oscillazione verticale
	var tween = create_tween().set_loops()
	tween.tween_property(sprite, "scale:x", 0.15, 0.45).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale:x", 0.35, 0.45).set_trans(Tween.TRANS_SINE)

func _on_body_entered(body: Node2D) -> void:
	if is_collected:
		return
	if body is CharacterBody2D: # Player
		is_collected = true
		
		# Moltiplicatore se il giocatore è in stato "On Fire"
		var multiplier: int = 1
		if "is_on_fire" in body and body.is_on_fire:
			multiplier = 2

		var total_coins: int = value * multiplier
		GameManager.add_coins(total_coins)
		
		# Aggiorna la HUD se presente
		var hud = get_tree().root.find_child("HUD", true, false)
		if hud and hud.has_method("update_coins"):
			hud.update_coins(GameManager.coins)
		
		# Particelle di scintillio dorato
		if spark_particles:
			spark_particles.emitting = true
		
		# Animazione di raccolta (salita, ingrandimento e fade-out)
		var tween = create_tween()
		tween.tween_property(self, "position:y", position.y - 45.0, 0.3).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(sprite, "scale", Vector2(0.55, 0.55), 0.3)
		tween.parallel().tween_property(self, "modulate:a", 0.0, 0.3)
		tween.tween_callback(queue_free)
