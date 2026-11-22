extends RigidBody2D

signal shot_missed()

var bounce_count: int = 0
var hit_bird: bool = false
var is_dunk: bool = false
var has_scored: bool = false
var has_reported_result: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var light: PointLight2D = get_node_or_null("PointLight2D")

func _ready() -> void:
	body_entered.connect(_on_body_entered)
	# Dopo 3.0 secondi dal tiro, avvia la dissolvenza se non è già distrutto
	get_tree().create_timer(3.0).timeout.connect(fade_out_and_destroy)

func _physics_process(_delta: float) -> void:
	# Se il pallone cade sotto il limite inferiore senza aver fatto canestro, è un tiro fallito
	if global_position.y > 780.0 and not has_scored and not has_reported_result and not is_dunk:
		has_reported_result = true
		shot_missed.emit()
		queue_free()

func _on_body_entered(body: Node) -> void:
	bounce_count += 1
	GameManager.vibrate_light()
	apply_squash_and_stretch()
	
	# Se tocca il terreno (layer 1) senza aver fatto canestro, il tiro è fallito immediatamente
	if body is CollisionObject2D and (body.collision_layer & 1) != 0:
		if not has_scored and not has_reported_result and not is_dunk:
			has_reported_result = true
			shot_missed.emit()

func apply_squash_and_stretch() -> void:
	if not sprite:
		return
	
	# Calcola asse di deformazione in base alla velocità
	var is_mostly_vertical: bool = abs(linear_velocity.y) > abs(linear_velocity.x)
	var squash_scale: Vector2 = Vector2(0.52, 0.28) if is_mostly_vertical else Vector2(0.28, 0.52)
	
	var tween = create_tween()
	tween.tween_property(sprite, "scale", squash_scale, 0.04).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	tween.tween_property(sprite, "scale", Vector2(0.44, 0.36), 0.07).set_trans(Tween.TRANS_SINE)
	tween.tween_property(sprite, "scale", Vector2(0.4, 0.4), 0.12).set_trans(Tween.TRANS_ELASTIC).set_ease(Tween.EASE_OUT)

func fade_out_and_destroy() -> void:
	if not has_scored and not has_reported_result and not is_dunk:
		has_reported_result = true
		shot_missed.emit()
		
	var tween = create_tween()
	tween.tween_property(self, "modulate:a", 0.0, 0.45)
	if light:
		tween.parallel().tween_property(light, "energy", 0.0, 0.45)
	tween.tween_callback(queue_free)
