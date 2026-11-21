extends Node2D

const HOOP_SCENE: PackedScene = preload("res://scenes/hoop.tscn")
const COIN_SCENE: PackedScene = preload("res://scenes/coin.tscn")

@export var player_node: Node2D = null

# Parametri matematici del terreno ondulato
var chunk_width: float = 1200.0
var step_x: float = 35.0 # Risoluzione della curva per renderla ancora più morbida
var current_generated_x: float = 0.0

var active_chunks: Array[Node2D] = []

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

	# Calcola i punti della superficie ondulata
	var surface_points: Array[Vector2] = []
	var x = start_x
	while x <= end_x:
		# Pendenze fluide e naturali
		var y = 520.0 + sin(x * 0.003) * 90.0 + cos(x * 0.006) * 40.0
		surface_points.append(Vector2(x, y))
		x += step_x

	# 1. Corpo Fisico del Terreno (CollisionPolygon2D)
	var static_body = StaticBody2D.new()
	var col_poly = CollisionPolygon2D.new()
	
	var polygon_points: Array[Vector2] = []
	polygon_points.append_array(surface_points)
	# Chiude il poligono in basso per dare massa solida fino a y=1800
	polygon_points.append(Vector2(end_x, 1800.0))
	polygon_points.append(Vector2(start_x, 1800.0))
	col_poly.polygon = PackedVector2Array(polygon_points)
	
	static_body.add_child(col_poly)
	chunk_root.add_child(static_body)

	# 2. Riempimento Marrone Terra Sotteso al Percorso (Polygon2D)
	var ground_fill = Polygon2D.new()
	ground_fill.polygon = PackedVector2Array(polygon_points)
	ground_fill.color = Color(0.38, 0.22, 0.13) # Marrone terra caldo
	chunk_root.add_child(ground_fill)

	# 3. Linea Visiva Verde dell'Erba in superficie (Line2D)
	var grass_line = Line2D.new()
	grass_line.points = PackedVector2Array(surface_points)
	grass_line.width = 8.0
	grass_line.default_color = Color(0.24, 0.72, 0.30) # Verde erba brillante
	chunk_root.add_child(grass_line)

	# 4. Spawna un Canestro in questo Chunk (eccetto nei primissimi 800 pixel)
	if start_x > 800.0:
		spawn_hoop_in_chunk(chunk_root, start_x, end_x)

	# 5. Spawna archi parabolici di monetine fluttuanti
	if start_x > 400.0:
		spawn_coin_arc_in_chunk(chunk_root, start_x, end_x)

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
	
	var height_offset = randf_range(130.0, 210.0) if not is_micro_hoop else randf_range(170.0, 250.0)
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
