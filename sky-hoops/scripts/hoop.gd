extends Area2D

signal goal_scored(is_micro: bool, bonus_coins: int)

@export var is_micro: bool = false
@export var is_oscillating: bool = false
@export var oscillation_amplitude: float = 45.0
@export var oscillation_speed: float = 2.0
@export var oscillation_mode: int = 0 # 0 = Solo Verticale, 1 = Moto Ellittico (X + Y)

var initial_x: float = 0.0
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
	initial_x = position.x
	initial_y = position.y
	time_passed = randf_range(0.0, PI * 2)
	body_entered.connect(_on_body_entered)
	
	if backboard_sensor:
		backboard_sensor.body_entered.connect(_on_backboard_entered)
		
	if is_micro:
		scale = Vector2(0.85, 0.85)
		modulate = Color(1.0, 0.85, 0.15)
	else:
		scale = Vector2(1.10, 1.10)
	
	# Bersaglio mobile: illumina con alone ciano/oro dinamico per risaltare a distanza
	if is_oscillating and hoop_light:
		hoop_light.color = Color(0.35, 0.88, 1.0) if oscillation_mode == 1 else Color(1.0, 0.82, 0.25)
		hoop_light.energy = 1.4

func _process(delta: float) -> void:
	if is_oscillating:
		time_passed += delta
		position.y = initial_y + sin(time_passed * oscillation_speed) * oscillation_amplitude
		if oscillation_mode == 1:
			position.x = initial_x + cos(time_passed * oscillation_speed * 0.70) * (oscillation_amplitude * 0.45)
		
		# Pulsazione cinetica della luce
		if hoop_light:
			hoop_light.energy = 1.25 + sin(time_passed * 3.8) * 0.35

func _on_backboard_entered(body: Node2D) -> void:
	if body is RigidBody2D:
		hit_backboard = true

func _on_body_entered(body: Node2D) -> void:
	if body is RigidBody2D and not has_scored:
		var is_dunk: bool = body.get("is_dunk") == true
		
		# Se è una schiacciata (Slam Dunk), è già pre-validata dal sistema dunk a due mani
		if is_dunk:
			_execute_goal(body, true)
			return

		# VALIDAZIONE RIGOROSA CANESTRO:
		# 1. La palla deve scendere verso il basso (downward velocity reale, non risalita o rimbalzo)
		var is_moving_down: bool = body.linear_velocity.y > 45.0
		# 2. La palla deve essere allineata orizzontalmente all'interno del ferro
		var rel_x = abs(body.global_position.x - global_position.x)
		var max_allowed_x = 26.0 * scale.x
		var is_centered_x: bool = rel_x <= max_allowed_x
		# 3. La palla deve provenire dall'alto del ferro (non dal basso o da sotto la retina)
		var is_from_above: bool = body.global_position.y <= (global_position.y + 16.0 * scale.y)

		if is_moving_down and is_centered_x and is_from_above:
			_execute_goal(body, false)

func _execute_goal(body: RigidBody2D, is_dunk: bool) -> void:
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
	
	# Calcolo Moltiplicatore On Fire progressivo basato sui canestri consecutivi (fino a x=5)
	var player = get_tree().get_first_node_in_group("player")
	var current_streak: int = 1
	if player != null and "combo_count" in player:
		current_streak = player.combo_count + 1
	var mult: int = clamp(current_streak, 1, 5)

	var base_coins: int = 25
	var text_msg: String = ""
	
	if is_dunk:
		base_coins = 65
		text_msg = "💥 SLAM DUNK!"
		GameManager.vibrate_double()
	elif hit_bird:
		base_coins = 55
		text_msg = "🐦 OFF THE BIRD!"
		GameManager.vibrate_double()
	elif bounce_cnt > 0:
		base_coins = 50
		text_msg = "🤹 TRICK SHOT (" + str(bounce_cnt) + "x)!"
		GameManager.vibrate_medium()
	elif is_micro:
		base_coins = 45
		text_msg = "🔥 MICRO SWISH!"
		GameManager.vibrate_double()
	elif hit_backboard:
		base_coins = 25
		text_msg = "🎯 BANK SHOT!"
		GameManager.vibrate_medium()
	else:
		base_coins = 35
		text_msg = "✨ PERFECT SWISH!"
		GameManager.vibrate_double()

	var total_coins: int = base_coins * mult
	text_msg += " +" + str(total_coins) + " 🪙"

	if mult >= 5:
		text_msg += " (MAX FIRE x5! 🔥🔥🔥)"
	elif mult > 1:
		text_msg += " (ON FIRE x" + str(mult) + "! 🔥)"

	print("🏀 CANESTRO CONVALIDATO: ", text_msg)
	goal_scored.emit(is_micro, total_coins)
	
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
		l_tween.tween_property(hoop_light, "energy", 3.2, 0.05)
		l_tween.tween_property(hoop_light, "energy", 0.9, 0.35)
	
	# FISICA MOLEGGIATA DEL FERRO & RETINA (Feature 1 - Rim & Net Juice)
	trigger_rim_juice(is_dunk)

	# MICRO SLOW-MOTION CINEMATICO SUI TIRI EPICI (Feature 7)
	var is_critical_shot: bool = (is_dunk or hit_bird or bounce_cnt > 0 or is_micro or (player != null and player.get("stamina") != null and player.stamina < 20.0))
	if is_critical_shot:
		trigger_cinematic_slowmo(0.20 if is_dunk else 0.28, 0.12 if is_dunk else 0.10)

func trigger_rim_juice(dunk_mode: bool) -> void:
	if visual_sprite:
		var drop_y: float = 20.0 if dunk_mode else 8.0
		var tilt_rot: float = 0.18 if dunk_mode else 0.06
		var stretch_target: Vector2 = Vector2(1.24, 1.80) if dunk_mode else Vector2(1.10, 1.45)
		
		var tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		# 1. Piega violenta verso il basso con allargamento elastico della retina
		tween.parallel().tween_property(visual_sprite, "position:y", drop_y, 0.06)
		tween.parallel().tween_property(visual_sprite, "rotation", tilt_rot, 0.06)
		tween.parallel().tween_property(visual_sprite, "scale", stretch_target, 0.06)
		
		# 2. Rimbalzo elastico verso l'alto (smorzamento a molla)
		tween.tween_property(visual_sprite, "position:y", -drop_y * 0.45, 0.10).set_trans(Tween.TRANS_SINE)
		tween.parallel().tween_property(visual_sprite, "rotation", -tilt_rot * 0.5, 0.10)
		tween.parallel().tween_property(visual_sprite, "scale", Vector2(0.92, 0.88), 0.10)
		
		# 3. Oscillazione secondaria smorzata
		tween.tween_property(visual_sprite, "position:y", drop_y * 0.20, 0.08)
		tween.parallel().tween_property(visual_sprite, "rotation", tilt_rot * 0.25, 0.08)
		
		# 4. Ritorno perfetto al riposo
		tween.tween_property(visual_sprite, "position:y", 0.0, 0.16).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)
		tween.parallel().tween_property(visual_sprite, "rotation", 0.0, 0.16)
		tween.parallel().tween_property(visual_sprite, "scale", Vector2(1.0, 1.0), 0.18).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

	# Shockwave ring radiale che si espande dal ferro
	spawn_shockwave(dunk_mode)

func spawn_shockwave(dunk_mode: bool) -> void:
	var ring = Line2D.new()
	ring.width = 5.0 if dunk_mode else 2.5
	ring.default_color = Color(1.0, 0.82, 0.15, 0.9) if dunk_mode else Color(1.0, 1.0, 1.0, 0.8)
	
	var pts: Array[Vector2] = []
	var num_pts = 24
	var base_r = 16.0
	for i in range(num_pts + 1):
		var angle = float(i) / float(num_pts) * TAU
		pts.append(Vector2(cos(angle), sin(angle)) * base_r)
	ring.points = PackedVector2Array(pts)
	ring.position = Vector2(0, 10)
	add_child(ring)
	
	var max_scale = 3.8 if dunk_mode else 2.2
	var s_tween = create_tween().set_parallel(true)
	s_tween.tween_property(ring, "scale", Vector2(max_scale, max_scale), 0.28).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	s_tween.tween_property(ring, "modulate:a", 0.0, 0.28)
	s_tween.chain().tween_callback(ring.queue_free)

func trigger_cinematic_slowmo(intensity: float = 0.22, duration: float = 0.12) -> void:
	Engine.time_scale = intensity
	var sm_tween = create_tween()
	sm_tween.tween_interval(duration)
	sm_tween.tween_property(Engine, "time_scale", 1.0, 0.16).set_trans(Tween.TRANS_SINE).set_ease(Tween.EASE_OUT)
	
	var player = get_tree().get_first_node_in_group("player")
	if player and player.get("camera"):
		var cam: Camera2D = player.camera
		var c_tween = create_tween().set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		c_tween.tween_property(cam, "zoom", Vector2(1.07, 1.07), 0.06)
		c_tween.tween_property(cam, "zoom", Vector2(1.0, 1.0), 0.22)
		if player.has_method("add_camera_trauma"):
			player.add_camera_trauma(0.35)

func show_floating_text(custom_text: String) -> void:
	var label = Label.new()
	label.text = custom_text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.position = Vector2(-150, -75)
	label.size = Vector2(300, 30)
	label.modulate = Color(1.0, 0.9, 0.2)
	label.add_theme_font_size_override("font_size", 19)
	add_child(label)
	
	var tween = create_tween()
	tween.tween_property(label, "position:y", -130.0, 0.9).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.parallel().tween_property(label, "modulate:a", 0.0, 0.9)
	tween.tween_callback(label.queue_free)
