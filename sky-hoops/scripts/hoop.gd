extends Area2D

signal goal_scored(is_micro: bool, bonus_coins: int)

@export var is_micro: bool = false
@export var is_oscillating: bool = false
@export var oscillation_amplitude: float = 45.0
@export var oscillation_speed: float = 2.0

var initial_y: float = 0.0
var time_passed: float = 0.0
var has_scored: bool = false
var hit_backboard: bool = false

@onready var visual_sprite: Sprite2D = $VisualSprite
@onready var goal_particles: CPUParticles2D = $GoalParticles
@onready var backboard_sensor: Area2D = get_node_or_null("Backboard/BackboardSensor")
@onready var hoop_light: PointLight2D = get_node_or_null("HoopLight")

func _ready() -> void:
	add_to_group("hoops")
	initial_y = position.y
	time_passed = randf_range(0.0, PI * 2)
	body_entered.connect(_on_body_entered)
	
	if backboard_sensor:
		backboard_sensor.body_entered.connect(_on_backboard_entered)
		
	if is_micro:
		scale = Vector2(0.65, 0.65)
		modulate = Color(1.0, 0.85, 0.15)

func _process(delta: float) -> void:
	if is_oscillating:
		time_passed += delta
		position.y = initial_y + sin(time_passed * oscillation_speed) * oscillation_amplitude

func _on_backboard_entered(body: Node2D) -> void:
	if body is RigidBody2D:
		hit_backboard = true

func _on_body_entered(body: Node2D) -> void:
	if body is RigidBody2D and not has_scored:
		# Controlla che la palla stia entrando dall'alto verso il basso e sia centrata nel ferro
		var rel_x = abs(body.global_position.x - global_position.x)
		var is_dunk: bool = body.get("is_dunk") == true
		
		if (body.linear_velocity.y > -20.0 and rel_x < 34.0) or is_dunk:
			has_scored = true
			if "has_scored" in body:
				body.has_scored = true
			if "has_reported_result" in body:
				body.has_reported_result = true
			
			# FISICA DELLA RETINA: frena l'inerzia orizzontale e accompagna la palla verso il basso
			body.linear_velocity.x *= 0.15
			body.linear_velocity.y = max(body.linear_velocity.y, 200.0 if is_dunk else 170.0)
			
			# Rilevamento Trick Shot, Ricochet e Dunk
			var hit_bird: bool = body.get("hit_bird") == true
			var bounce_cnt: int = body.get("bounce_count") if body.get("bounce_count") != null else 0
			
			var bonus: int = 1
			var text_msg: String = "🏀 SWISH! +1 🪙"
			
			if is_dunk:
				bonus = 5
				text_msg = "💥 SLAM DUNK! +5 🪙"
				GameManager.vibrate_double()
			elif hit_bird:
				bonus = 4
				text_msg = "🐦 OFF THE BIRD! +4 🪙"
				GameManager.vibrate_double()
			elif bounce_cnt > 0:
				bonus = 3
				text_msg = "🤹 TRICK SHOT (" + str(bounce_cnt) + "x Rimbalzo)! +3 🪙"
				GameManager.vibrate_medium()
			elif is_micro:
				bonus = 3
				text_msg = "🔥 MICRO SWISH! +3 🪙"
				GameManager.vibrate_double()
			elif hit_backboard:
				bonus = 2
				text_msg = "🎯 BANK SHOT! +2 🪙"
				GameManager.vibrate_medium()
			else:
				bonus = 2
				text_msg = "✨ PERFECT SWISH! +2 🪙"
				GameManager.vibrate_double()

			print("🏀 CANESTRO CONVALIDATO: ", text_msg)
			goal_scored.emit(is_micro, bonus)
			
			# Particelle oro / arancio ad alta intensità
			if goal_particles:
				if is_dunk or is_micro or hit_bird:
					goal_particles.color = Color(1.0, 0.9, 0.15)
					goal_particles.amount = 48
				elif not hit_backboard:
					goal_particles.color = Color(1.0, 0.82, 0.25)
					goal_particles.amount = 32
				else:
					goal_particles.color = Color(1.0, 0.55, 0.1)
					goal_particles.amount = 26
				goal_particles.restart()
				
			show_floating_text(text_msg)
			
			# Flash luminoso al canestro
			if hoop_light:
				var l_tween = create_tween()
				l_tween.tween_property(hoop_light, "energy", 2.8, 0.06)
				l_tween.tween_property(hoop_light, "energy", 0.9, 0.35)
			
			# Effetto Swish a molla (Squash & Stretch della retina)
			if visual_sprite:
				var stretch_target = Vector2(0.65, 1.85) if is_dunk else Vector2(0.82, 1.45)
				var tween = create_tween()
				tween.tween_property(visual_sprite, "scale", stretch_target, 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
				tween.tween_property(visual_sprite, "scale", Vector2(1.18, 0.82), 0.12).set_trans(Tween.TRANS_SINE)
				tween.tween_property(visual_sprite, "scale", Vector2(1.0, 1.0), 0.24).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func show_floating_text(custom_text: String) -> void:
	var label = Label.new()
	label.text = custom_text
	label.position = Vector2(-75, -75)
	label.modulate = Color(1.0, 0.9, 0.2)
	label.add_theme_font_size_override("font_size", 19)
	add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", -130.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.9)
	tween.tween_callback(label.queue_free)
