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

func get_terrain_slope_angle(x: float) -> float:
	# Derivata analitica di get_terrain_y(x) per allineare perfettamente gli ostacoli alla pendenza
	var dy_dx: float = (90.0 * 0.003 * cos(x * 0.003)) - (40.0 * 0.006 * sin(x * 0.006))
	return atan2(dy_dx, 1.0)

# Calcola una coordinata X garantita su terreno solido (MAI sospesa nel vuoto di un burrone)
func get_safe_ground_x(start_x: float, end_x: float, has_gap: bool, gap_start: float, gap_end: float, margin: float = 80.0) -> float:
	if not has_gap:
		return randf_range(start_x + margin, end_x - margin)

	var min_clearance: float = 75.0
	var seg_a_start = start_x + margin
	var seg_a_end = gap_start - min_clearance
	var seg_b_start = gap_end + min_clearance
	var seg_b_end = end_x - margin

	var len_a = max(0.0, seg_a_end - seg_a_start)
	var len_b = max(0.0, seg_b_end - seg_b_start)

	if len_a <= 0.0 and len_b <= 0.0:
		return start_x + margin

	var pick_a = randf() < (len_a / (len_a + len_b))
	if pick_a and len_a > 0.0:
		return randf_range(seg_a_start, seg_a_end)
	elif len_b > 0.0:
		return randf_range(seg_b_start, seg_b_end)
	else:
		return randf_range(seg_a_start, seg_a_end)

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

		# 1. Spawna un arco guida ideale di monete sopra il burrone (4-5 monete)
		spawn_gap_coin_arc(chunk_root, gap_start_x, gap_end_x)

	# 2. Spawna un Canestro in questo Chunk con la sua traiettoria di tiro a canestro
	if start_x >= 600.0 or (start_x == 0.0 and randf() < 0.85):
		spawn_hoop_in_chunk(chunk_root, start_x, end_x, has_gap, gap_start_x, gap_end_x)

	# 3. Spawna Ostacoli Spuntoni/Mine sul terreno solido (più frequenti, almeno 2x ricariche stamina, mai nel vuoto)
	if start_x > 350.0:
		spawn_spikes_in_chunk(chunk_root, start_x, end_x, has_gap, gap_start_x, gap_end_x)

	# 4. Spawna Uccelli in volo che intercettano la palla (25% probabilità dopo 700m)
	if start_x > 700.0 and randf() < 0.25:
		spawn_bird_in_chunk(chunk_root, start_x, end_x)

	# 5. Spawna Rara Ricarica Energetica Stamina (probabilità ridotta a 12% dopo 1000m, MAI nel vuoto)
	if start_x > 1000.0 and randf() < 0.12:
		spawn_energy_in_chunk(chunk_root, start_x, end_x, has_gap, gap_start_x, gap_end_x)

	current_generated_x = end_x

func spawn_hoop_in_chunk(parent_chunk: Node2D, start_x: float, end_x: float, has_gap: bool, gap_start: float, gap_end: float) -> void:
	var hoop = HOOP_SCENE.instantiate()
	
	# Posizione orizzontale del canestro
	var hoop_x: float
	if has_gap:
		# Se c'è un burrone, posiziona preferibilmente oltre il salto dove c'è ampio spazio per correre e tirare
		var min_b_x = gap_end + 260.0
		var max_b_x = end_x - 120.0
		if max_b_x > min_b_x:
			hoop_x = randf_range(min_b_x, max_b_x)
		else:
			hoop_x = randf_range(start_x + 150.0, gap_start - 120.0)
	else:
		if start_x == 0.0:
			hoop_x = randf_range(720.0, end_x - 180.0)
		else:
			hoop_x = randf_range(start_x + 360.0, end_x - 180.0)

	var terrain_y = get_terrain_y(hoop_x)
	
	# 25% di probabilità che sia un canestro Micro (dorato, più piccolo e più alto)
	var is_micro_hoop = randf() < 0.25
	hoop.is_micro = is_micro_hoop
	
	# Oltre 1500px, 35% di probabilità che il canestro sia mobile/oscillante verticalmente
	if start_x > 1500.0 and randf() < 0.35:
		hoop.is_oscillating = true
		hoop.oscillation_amplitude = randf_range(35.0, 65.0)
		hoop.oscillation_speed = randf_range(1.6, 2.6)
	
	# Quota aerea elevata per tiri a campana ("Sky Hoops")
	var height_offset = randf_range(220.0, 310.0) if not is_micro_hoop else randf_range(280.0, 380.0)
	hoop.position = Vector2(hoop_x, terrain_y - height_offset)
	
	# Collega il canestro al turbo del player
	if player_node:
		hoop.goal_scored.connect(player_node._on_hoop_goal_scored)
		
	parent_chunk.add_child(hoop)

	# Spawna l'arco di monete solo su alcuni canestri (~45% di probabilità, garantito al primo canestro introduttivo)
	var should_spawn_trajectory = (start_x == 0.0) or (randf() < 0.45)
	if should_spawn_trajectory:
		spawn_hoop_trajectory_coins(parent_chunk, hoop_x, hoop.position.y)

# Spawna una parabola di monete che illustra al giocatore l'arco ideale di tiro dentro al canestro
func spawn_hoop_trajectory_coins(parent_chunk: Node2D, hoop_x: float, hoop_y: float) -> void:
	var num_coins: int = 5
	var shot_distance: float = randf_range(260.0, 310.0)
	var start_x: float = hoop_x - shot_distance
	var start_y: float = get_terrain_y(start_x) - 45.0 # Altezza rilascio palla dal runner
	
	var target_x: float = hoop_x - 10.0
	var target_y: float = hoop_y - 12.0 # Entrata nel ferro dall'alto
	
	var apex_x: float = hoop_x - randf_range(85.0, 115.0)
	var apex_y: float = hoop_y - randf_range(65.0, 95.0)
	
	# Punti di controllo della curva quadratica di Bezier passante per l'apice
	var p0 = Vector2(start_x, start_y)
	var p2 = Vector2(target_x, target_y)
	var p1 = Vector2(apex_x, 2.0 * apex_y - 0.5 * (p0.y + p2.y))
	
	for i in range(num_coins):
		var t: float = lerp(0.20, 0.88, float(i) / float(num_coins - 1))
		var coin_pos = (1.0 - t) * (1.0 - t) * p0 + 2.0 * (1.0 - t) * t * p1 + t * t * p2
		
		var coin = COIN_SCENE.instantiate()
		coin.position = coin_pos
		parent_chunk.add_child(coin)

func spawn_gap_coin_arc(parent_chunk: Node2D, gap_start: float, gap_end: float) -> void:
	var num_coins: int = 5
	var margin: float = 25.0
	var arc_start_x = gap_start - margin
	var arc_end_x = gap_end + margin
	var total_dist = arc_end_x - arc_start_x
	
	var start_y = get_terrain_y(gap_start)
	var end_y = get_terrain_y(gap_end)

	for i in range(num_coins):
		var t = float(i) / float(num_coins - 1)
		var x = arc_start_x + (t * total_dist)
		var base_y = lerp(start_y, end_y, t)
		# Parabola guida del salto atletico sopra il burrone
		var arc_h = 75.0 * 4.0 * t * (1.0 - t)
		var coin = COIN_SCENE.instantiate()
		coin.position = Vector2(x, base_y - 45.0 - arc_h)
		parent_chunk.add_child(coin)

func spawn_spikes_in_chunk(parent_chunk: Node2D, start_x: float, end_x: float, has_gap: bool, gap_start: float, gap_end: float) -> void:
	# Probabilità base del 65% di generare un ostacolo spuntone/mina
	if randf() > 0.65:
		return

	var x1 = get_safe_ground_x(start_x, end_x, has_gap, gap_start, gap_end, 90.0)
	create_spike_at(parent_chunk, x1)

	# Oltre 1000m, 35% di probabilità di avere un secondo ostacolo nel chunk
	if start_x > 1000.0 and randf() < 0.35:
		var x2 = get_safe_ground_x(start_x, end_x, has_gap, gap_start, gap_end, 90.0)
		if abs(x2 - x1) > 220.0:
			create_spike_at(parent_chunk, x2)

func create_spike_at(parent_chunk: Node2D, spike_x: float) -> void:
	var spike = SPIKE_SCENE.instantiate()
	var terrain_y = get_terrain_y(spike_x)
	spike.position = Vector2(spike_x, terrain_y)
	spike.rotation = get_terrain_slope_angle(spike_x)
	parent_chunk.add_child(spike)

func spawn_bird_in_chunk(parent_chunk: Node2D, start_x: float, end_x: float) -> void:
	var bird = BIRD_SCENE.instantiate()
	var bird_x = end_x + randf_range(50.0, 200.0)
	var bird_y = randf_range(200.0, 320.0)
	bird.position = Vector2(bird_x, bird_y)
	parent_chunk.add_child(bird)

func spawn_energy_in_chunk(parent_chunk: Node2D, start_x: float, end_x: float, has_gap: bool, gap_start: float, gap_end: float) -> void:
	var en_x = get_safe_ground_x(start_x, end_x, has_gap, gap_start, gap_end, 120.0)
	var terrain_y = get_terrain_y(en_x)
	var energy = ENERGY_SCENE.instantiate()
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
