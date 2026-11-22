extends Node2D

const HOOP_SCENE: PackedScene = preload("res://scenes/hoop.tscn")
const COIN_SCENE: PackedScene = preload("res://scenes/coin.tscn")
const SPIKE_SCENE: PackedScene = preload("res://scenes/obstacle_spike.tscn")
const BIRD_SCENE: PackedScene = preload("res://scenes/bird.tscn")
const ENERGY_SCENE: PackedScene = preload("res://scenes/pickup_energy.tscn")

@export var player_node: Node2D = null

# Parametri matematici del terreno ondulato
var chunk_width: float = 1200.0
var step_x: float = 24.0 # 1200 / 24 = esattamente 50 passi senza residuo o interruzioni
var current_generated_x: float = 0.0

var active_chunks: Array[Node2D] = []

func get_terrain_y(x: float) -> float:
	return 520.0 + sin(x * 0.003) * 90.0 + cos(x * 0.006) * 40.0

# Campiona i punti della collina garantendo continuità matematica assoluta tra i chunk
func sample_surface_points(from_x: float, to_x: float) -> Array[Vector2]:
	var points: Array[Vector2] = []
	var x: float = from_x
	while x < to_x:
		points.append(Vector2(x, get_terrain_y(x)))
		x += step_x
	# Punto finale obbligatorio esattamente al confine to_x
	points.append(Vector2(to_x, get_terrain_y(to_x)))
	return points

func _ready() -> void:
	if not player_node:
		player_node = get_parent().get_node_or_null("Player")
	
	# Genera subito i primi 3 segmenti di colline (3600 pixel di mappa iniziale)
	for i in range(3):
		generate_next_chunk()

func _physics_process(_delta: float) -> void:
	if not player_node:
		return

	# Se il player si avvicina alla fine della mappa generata, crea un nuovo tratto
	if player_node.global_position.x + 2000.0 > current_generated_x:
		generate_next_chunk()

	# Rimuove solo i chunk che sono realmente finiti 2000 pixel alle spalle del giocatore
	if active_chunks.size() > 0:
		var first_chunk = active_chunks[0]
		var chunk_end_x = first_chunk.get_meta("end_x", 0.0)
		if chunk_end_x > 0.0 and chunk_end_x < player_node.global_position.x - 2000.0:
			active_chunks.pop_front()
			first_chunk.queue_free()

func generate_next_chunk() -> void:
	var start_x = current_generated_x
	var end_x = start_x + chunk_width
	
	var chunk_root = Node2D.new()
	chunk_root.name = "Chunk_" + str(int(start_x))
	chunk_root.set_meta("end_x", end_x)
	add_child(chunk_root)
	active_chunks.append(chunk_root)

	# Decide se in questo chunk c'è un baratro (25% di probabilità oltre 900m)
	var has_gap: bool = (start_x > 900.0 and randf() < 0.25)
	var gap_width: float = 170.0
	var gap_center_x: float = start_x + (chunk_width * 0.5)
	var gap_start_x: float = gap_center_x - (gap_width * 0.5)
	var gap_end_x: float = gap_center_x + (gap_width * 0.5)

	if not has_gap:
		var surface_points = sample_surface_points(start_x, end_x)
		create_ground_segment(chunk_root, surface_points, start_x, end_x)
	else:
		# Sezione A (prima del baratro)
		var surface_A = sample_surface_points(start_x, gap_start_x)
		create_ground_segment(chunk_root, surface_A, start_x, gap_start_x)

		# Sezione B (dopo il baratro)
		var surface_B = sample_surface_points(gap_end_x, end_x)
		create_ground_segment(chunk_root, surface_B, gap_end_x, end_x)

		# Spawna un arco guida di monete direttamente sopra il baratro
		spawn_gap_coin_arc(chunk_root, gap_start_x, gap_end_x)

	# 4. Spawna un Canestro in questo Chunk (eccetto nei primissimi 800 pixel)
	if start_x > 800.0:
		spawn_hoop_in_chunk(chunk_root, start_x, end_x)

	# 5. Spawna archi parabolici di monetine fluttuanti
	if start_x > 400.0:
		spawn_coin_arc_in_chunk(chunk_root, start_x, end_x)

	# 6. Spawna Ostacoli Spuntoni sul terreno (30% probabilità dopo 500m)
	if start_x > 500.0 and randf() < 0.30:
		spawn_spike_in_chunk(chunk_root, start_x, end_x)

	# 7. Spawna Uccelli in volo che intercettano la palla (25% probabilità dopo 700m)
	if start_x > 700.0 and randf() < 0.25:
		spawn_bird_in_chunk(chunk_root, start_x, end_x)

	# 8. Spawna Raro Power-Up Energetico (18% probabilità dopo 800m)
	if start_x > 800.0 and randf() < 0.18:
		spawn_energy_in_chunk(chunk_root, start_x, end_x)

	current_generated_x = end_x

func spawn_hoop_in_chunk(parent_chunk: Node2D, start_x: float, end_x: float) -> void:
	var hoop = HOOP_SCENE.instantiate()
	
	# Posizione casuale lungo il chunk
	var hoop_x = randf_range(start_x + 300.0, end_x - 200.0)
	var terrain_y = 520.0 + sin(hoop_x * 0.003) * 90.0 + cos(hoop_x * 0.006) * 40.0
	
	# 25% di probabilità che sia un canestro Micro (dorato, più piccolo e più alto)
	var is_micro_hoop = randf() < 0.25
	hoop.is_micro = is_micro_hoop
	
	# Oltre 1500px, 35% di probabilità che il canestro sia mobile/oscillante verticalmente
	if start_x > 1500.0 and randf() < 0.35:
		hoop.is_oscillating = true
		hoop.oscillation_amplitude = randf_range(35.0, 65.0)
		hoop.oscillation_speed = randf_range(1.6, 2.6)
	
	# Quota aerea elevata per costringere a veri tiri a campana in cielo ("Sky Hoops")
	var height_offset = randf_range(220.0, 320.0) if not is_micro_hoop else randf_range(280.0, 390.0)
	hoop.position = Vector2(hoop_x, terrain_y - height_offset)
	
	# Collega il canestro al turbo del player
	if player_node:
		hoop.goal_scored.connect(player_node._on_hoop_goal_scored)
		
	parent_chunk.add_child(hoop)

func spawn_coin_arc_in_chunk(parent_chunk: Node2D, start_x: float, end_x: float) -> void:
	# 80% di probabilità di avere un arco di monete in questo chunk
	if randf() > 0.80:
		return

	var num_coins: int = randi_range(5, 7)
	var arc_width: float = randf_range(240.0, 320.0)
	var arc_height: float = randf_range(70.0, 110.0)
	
	# Centro dell'arco ben posizionato all'interno del chunk
	var arc_center_x: float = randf_range(start_x + arc_width * 0.6, end_x - arc_width * 0.6)
	var arc_start_x: float = arc_center_x - (arc_width * 0.5)
	
	for i in range(num_coins):
		var t: float = float(i) / float(num_coins - 1) # Normalizzato tra 0.0 e 1.0
		var x: float = arc_start_x + (t * arc_width)
		
		# Quota base del terreno in quel punto
		var terrain_y: float = 520.0 + sin(x * 0.003) * 90.0 + cos(x * 0.006) * 40.0
		
		# Parabola standard invertita: 4 * h * t * (1 - t)
		var parabola_offset: float = 4.0 * arc_height * t * (1.0 - t)
		var base_clearance: float = 45.0 # Altezza da terra per il punto più basso
		
		var coin = COIN_SCENE.instantiate()
		coin.position = Vector2(x, terrain_y - base_clearance - parabola_offset)
		parent_chunk.add_child(coin)

func spawn_spike_in_chunk(parent_chunk: Node2D, start_x: float, end_x: float) -> void:
	var spike = SPIKE_SCENE.instantiate()
	var spike_x = randf_range(start_x + 180.0, end_x - 180.0)
	var terrain_y = 520.0 + sin(spike_x * 0.003) * 90.0 + cos(spike_x * 0.006) * 40.0
	spike.position = Vector2(spike_x, terrain_y)
	parent_chunk.add_child(spike)

func spawn_bird_in_chunk(parent_chunk: Node2D, start_x: float, end_x: float) -> void:
	var bird = BIRD_SCENE.instantiate()
	var bird_x = end_x + randf_range(50.0, 200.0)
	var bird_y = randf_range(200.0, 320.0)
	bird.position = Vector2(bird_x, bird_y)
	parent_chunk.add_child(bird)

func spawn_energy_in_chunk(parent_chunk: Node2D, start_x: float, end_x: float) -> void:
	var energy = ENERGY_SCENE.instantiate()
	var en_x = randf_range(start_x + 220.0, end_x - 220.0)
	var terrain_y = 520.0 + sin(en_x * 0.003) * 90.0 + cos(en_x * 0.006) * 40.0
	energy.position = Vector2(en_x, terrain_y - 75.0)
	parent_chunk.add_child(energy)

func create_ground_segment(parent: Node2D, points: Array[Vector2], seg_start: float, seg_end: float) -> void:
	if points.size() < 2:
		return

	# Poligono solido continuo con fondo a 1800 (fondamentale per aderenza e floor snap di Godot 4)
	var poly: Array[Vector2] = []
	poly.append_array(points)
	poly.append(Vector2(seg_end, 1800.0))
	poly.append(Vector2(seg_start, 1800.0))

	# 1. Collisione solida affidabile
	var static_body = StaticBody2D.new()
	var col_poly = CollisionPolygon2D.new()
	col_poly.polygon = PackedVector2Array(poly)
	static_body.add_child(col_poly)
	parent.add_child(static_body)

	# 2. Riempimento visivo terra sottostante
	var ground_fill = Polygon2D.new()
	ground_fill.polygon = PackedVector2Array(poly)
	ground_fill.color = Color(0.38, 0.22, 0.13)
	parent.add_child(ground_fill)

	# 3. Superficie d'erba verde continua con giunture arrotondate
	var grass_line = Line2D.new()
	grass_line.points = PackedVector2Array(points)
	grass_line.width = 9.0
	grass_line.default_color = Color(0.24, 0.72, 0.30)
	grass_line.joint_mode = Line2D.LINE_JOINT_ROUND
	grass_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	grass_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	parent.add_child(grass_line)

func spawn_gap_coin_arc(parent_chunk: Node2D, gap_start: float, gap_end: float) -> void:
	var num_coins: int = 5
	var gap_dist = gap_end - gap_start
	var start_y = 520.0 + sin(gap_start * 0.003) * 90.0 + cos(gap_start * 0.006) * 40.0
	var end_y = 520.0 + sin(gap_end * 0.003) * 90.0 + cos(gap_end * 0.006) * 40.0

	for i in range(num_coins):
		var t = float(i) / float(num_coins - 1)
		var x = gap_start + (t * gap_dist)
		var base_y = lerp(start_y, end_y, t)
		# Parabola guida del salto sopra il burrone
		var arc_h = 70.0 * 4.0 * t * (1.0 - t)
		var coin = COIN_SCENE.instantiate()
		coin.position = Vector2(x, base_y - 45.0 - arc_h)
		parent_chunk.add_child(coin)
