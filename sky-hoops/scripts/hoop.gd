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

func _ready() -> void:
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
		if body.linear_velocity.y > -20.0 and rel_x < 32.0:
			has_scored = true
			
			# FISICA DELLA RETINA: frena l'inerzia orizzontale e accompagna la palla verso il basso
			body.linear_velocity.x *= 0.15
			body.linear_velocity.y = max(body.linear_velocity.y, 170.0)
			
			# Determina tipologia di canestro e monete bonus
			var bonus: int = 1
			var text_msg: String = "🏀 SWISH! +1 🪙"
			
			if is_micro:
				bonus = 3
				text_msg = "🔥 MICRO SWISH! +3 🪙"
			elif hit_backboard:
				bonus = 2
				text_msg = "🎯 BANK SHOT! +2 🪙"
			else:
				bonus = 2
				text_msg = "✨ PERFECT SWISH! +2 🪙"

			print("🏀 CANESTRO CONVALIDATO: ", text_msg)
			goal_scored.emit(is_micro, bonus)
			
			# Particelle
			if goal_particles:
				if is_micro or not hit_backboard:
					goal_particles.color = Color(1.0, 0.88, 0.2)
				else:
					goal_particles.color = Color(1.0, 0.55, 0.1)
				goal_particles.restart()
				
			show_floating_text(text_msg)
			
			# Effetto Swish elastico della retina
			if visual_sprite:
				var tween = create_tween()
				tween.tween_property(visual_sprite, "scale", Vector2(0.85, 1.35), 0.1)
				tween.tween_property(visual_sprite, "scale", Vector2(1.0, 1.0), 0.2)

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
