extends Area2D

var has_popped_up: bool = false
var has_hit_player: bool = false
var is_flattened: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var collision_shape: CollisionShape2D = $CollisionShape2D
@onready var proximity_area: Area2D = get_node_or_null("ProximityArea")
@onready var block_particles: CPUParticles2D = get_node_or_null("BlockParticles")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	if proximity_area:
		proximity_area.body_entered.connect(_on_proximity_entered)
		
	# Inizia accovacciato/compresso a terra
	scale = Vector2(0.95, 0.45)

func _on_proximity_entered(body: Node2D) -> void:
	if has_popped_up:
		return
	if body is CharacterBody2D: # Player si avvicina
		has_popped_up = true
		pop_up()

func pop_up() -> void:
	# Scatto verso l'alto a molla con oscillazione elastica
	var tween = create_tween()
	tween.tween_property(self, "scale", Vector2(0.92, 1.25), 0.12).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2(1.0, 1.0), 0.14).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
	
	# Leggero sbandamento laterale della molla
	var w_tween = create_tween()
	w_tween.tween_property(sprite, "rotation", 0.18, 0.10)
	w_tween.tween_property(sprite, "rotation", -0.12, 0.12)
	w_tween.tween_property(sprite, "rotation", 0.0, 0.14)

func _on_body_entered(body: Node2D) -> void:
	if is_flattened:
		return
		
	if body is RigidBody2D: # Pallone da basket
		deflect_ball(body)
	elif body is CharacterBody2D: # Giocatore
		handle_player_contact(body)

func deflect_ball(ball: RigidBody2D) -> void:
	# Mura la palla respingendola indietro
	ball.linear_velocity = Vector2(-280.0, 220.0)
	if "bounce_count" in ball:
		ball.bounce_count += 1
		
	GameManager.vibrate_medium()
	
	if block_particles:
		block_particles.restart()
		block_particles.emitting = true
		
	show_floating_text("🚫 STOPPATA! (BLOCKED!)", Color(1.0, 0.35, 0.2))
	
	# Animazione d'impatto sul cartonato
	var tween = create_tween()
	tween.tween_property(sprite, "rotation", 0.25, 0.08)
	tween.tween_property(sprite, "rotation", -0.15, 0.12)
	tween.tween_property(sprite, "rotation", 0.0, 0.15)
	
	var player = get_tree().get_first_node_in_group("player")
	if player and player.has_method("add_camera_trauma"):
		player.add_camera_trauma(0.30)

func handle_player_contact(player: CharacterBody2D) -> void:
	if has_hit_player:
		return
	has_hit_player = true
	
	# Immunità Aura Dorata: travolge la sagoma come un treno!
	if player.get("is_golden_aura") == true or player.get("is_golden_immune") == true:
		is_flattened = true
		show_floating_text("💥 POSTERIZZATO!", Color(1.0, 0.90, 0.25))
		GameManager.vibrate_light()
		
		# La sagoma viene schiacciata a terra
		var f_tween = create_tween()
		f_tween.tween_property(sprite, "scale", Vector2(1.4, 0.15), 0.12)
		f_tween.tween_property(self, "modulate:a", 0.0, 0.25)
		f_tween.tween_callback(queue_free)
		return
		
	# Contatto normale: inciampo e sottrazione moderata di stamina
	if "stamina" in player:
		player.stamina = max(0.0, player.stamina - 12.0)
		if "hud" in player and player.hud and player.hud.has_method("flash_stamina_damage"):
			player.hud.flash_stamina_damage(0.4)
			
	if player.has_method("add_camera_trauma"):
		player.add_camera_trauma(0.35)
	GameManager.vibrate_medium()
	
	show_floating_text("⚠️ FALLO IN ATTACCO! -12", Color(1.0, 0.4, 0.3))
	
	# La sagoma oscilla violentemente all'indietro
	var tween = create_tween()
	tween.tween_property(sprite, "rotation", 0.45, 0.10)
	tween.tween_property(sprite, "rotation", -0.20, 0.16)
	tween.tween_property(sprite, "rotation", 0.0, 0.20)
	
	# Cooldown per non infliggere danno continuo
	var timer = get_tree().create_timer(1.2)
	timer.timeout.connect(func(): has_hit_player = false)

func show_floating_text(text: String, color: Color) -> void:
	var label = Label.new()
	label.text = text
	label.position = Vector2(-80, -95)
	label.modulate = color
	label.add_theme_font_size_override("font_size", 18)
	add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", -145.0, 0.75).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.75)
	tween.tween_callback(label.queue_free)
