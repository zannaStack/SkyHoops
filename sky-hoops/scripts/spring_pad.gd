extends Area2D

@export var bounce_power_multiplier: float = 1.55
var is_cooling_down: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var bounce_particles: CPUParticles2D = get_node_or_null("BounceParticles")

func _ready() -> void:
	body_entered.connect(_on_body_entered)

func _on_body_entered(body: Node2D) -> void:
	if is_cooling_down:
		return
		
	if body is CharacterBody2D: # Player
		is_cooling_down = true
		trigger_player_bounce(body)
	elif body is RigidBody2D: # Basketball
		is_cooling_down = true
		trigger_ball_bounce(body)

func trigger_player_bounce(player: CharacterBody2D) -> void:
	# Super Salto verso l'alto
	var base_force = player.get("jump_force")
	var force: float = 480.0
	if base_force != null:
		force = float(base_force)
		
	player.velocity.y = -force * bounce_power_multiplier
	if "has_jumped_in_air" in player:
		player.has_jumped_in_air = true
	if "jumped_with_ball" in player and "has_ball" in player:
		player.jumped_with_ball = bool(player.has_ball)
	
	# Animazione salto immediata
	var anim_player = player.get_node_or_null("AnimationPlayer")
	if anim_player:
		anim_player.play("jump", 0.05)
		
	# Effetto Squash & Stretch sull'atleta
	var rig = player.get_node_or_null("Rig")
	if rig:
		var p_tween = create_tween()
		p_tween.tween_property(rig, "scale", Vector2(0.70, 1.38), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		p_tween.tween_property(rig, "scale", Vector2(1.0, 1.0), 0.16)

	if player.has_method("add_camera_trauma"):
		player.add_camera_trauma(0.30)
		
	GameManager.vibrate_medium()
	play_spring_animation()
	show_bounce_text("🚀 BOING! SUPER SALTO")
	
	# Cooldown breve per evitare trigger multipli nello stesso fotogramma
	var cd_timer = get_tree().create_timer(0.25)
	cd_timer.timeout.connect(func(): is_cooling_down = false)

func trigger_ball_bounce(ball: RigidBody2D) -> void:
	# Rimbalzo elastico potente del pallone
	ball.linear_velocity.y = -680.0
	ball.linear_velocity.x = max(ball.linear_velocity.x, 240.0)
	
	GameManager.vibrate_light()
	play_spring_animation()
	show_bounce_text("🏀 MEGA RIMBALZO!")
	
	var cd_timer = get_tree().create_timer(0.25)
	cd_timer.timeout.connect(func(): is_cooling_down = false)

func play_spring_animation() -> void:
	if bounce_particles:
		bounce_particles.restart()
		bounce_particles.emitting = true
		
	if sprite:
		var tween = create_tween()
		# Compressione iniziale verso il basso
		tween.tween_property(sprite, "scale", Vector2(1.35, 0.40), 0.05).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# Scatto elastico verso l'alto
		tween.tween_property(sprite, "scale", Vector2(0.85, 1.40), 0.10).set_trans(Tween.TRANS_SINE)
		# Rientro morbido
		tween.tween_property(sprite, "scale", Vector2(1.0, 1.0), 0.14)

func show_bounce_text(text: String) -> void:
	var label = Label.new()
	label.text = text
	label.position = Vector2(-75, -55)
	label.modulate = Color(1.0, 0.88, 0.15)
	label.add_theme_font_size_override("font_size", 18)
	add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", -110.0, 0.7).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.7)
	tween.tween_callback(label.queue_free)
