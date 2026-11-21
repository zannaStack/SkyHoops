extends Node2D

const HOOP_SCENE: PackedScene = preload("res://scenes/hoop.tscn")

@export var player_node: Node2D = null

# Parametri matematici del terreno ondulato
var chunk_width: float = 1200.0
var step_x: float = 40.0 # Risoluzione della curva
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
	chunk_root.set_meta("end_x", end_x) # <-- Aggiungi questa riga per memorizzare la coordinata reale!
	add_child(chunk_root)
	active_chunks.append(chunk_root)

	# Calcola i punti della superficie ondulata
	var surface_points: Array[Vector2] = []
	var x = start_x
	while x <= end_x:
		# Combinazione di onde per generare colline armoniche e dossi naturali
		var y = 500.0 + sin(x * 0.003) * 110.0 + cos(x * 0.007) * 45.0
		surface_points.append(Vector2(x, y))
		x += step_x

	# 1. Corpo Fisico del Terreno (CollisionPolygon2D)
	var static_body = StaticBody2D.new()
	var col_poly = CollisionPolygon2D.new()
	
	var polygon_points: Array[Vector2] = []
	polygon_points.append_array(surface_points)
	# Chiude il poligono in basso per dare massa solida
	polygon_points.append(Vector2(end_x, 1400.0))
	polygon_points.append(Vector2(start_x, 1400.0))
	col_poly.polygon = PackedVector2Array(polygon_points)
	
	static_body.add_child(col_poly)
	chunk_root.add_child(static_body)

	# 2. Linea Visiva Verde della Collina (Line2D)
	var line = Line2D.new()
	line.points = PackedVector2Array(surface_points)
	line.width = 6.0
	line.default_color = Color(0.18, 0.65, 0.25)
	chunk_root.add_child(line)

	# 3. Spawna un Canestro in questo Chunk (eccetto nei primissimi 800 pixel)
	if start_x > 800.0:
		spawn_hoop_in_chunk(chunk_root, start_x, end_x)

	current_generated_x = end_x

func spawn_hoop_in_chunk(parent_chunk: Node2D, start_x: float, end_x: float) -> void:
	var hoop = HOOP_SCENE.instantiate()
	
	# Posizione casuale lungo il chunk
	var hoop_x = randf_range(start_x + 300.0, end_x - 200.0)
	var terrain_y = 500.0 + sin(hoop_x * 0.003) * 110.0 + cos(hoop_x * 0.007) * 45.0
	
	# 25% di probabilità che sia un canestro Micro (più alto e sfidante!)
	var is_micro_hoop = randf() < 0.25
	hoop.is_micro = is_micro_hoop
	
	# Canestro sospeso tra 120 e 240 pixel sopra il terreno
	var height_offset = randf_range(130.0, 220.0) if not is_micro_hoop else randf_range(180.0, 260.0)
	hoop.position = Vector2(hoop_x, terrain_y - height_offset)
	
	# Collega il canestro al turbo del player
	if player_node:
		hoop.goal_scored.connect(player_node._on_hoop_goal_scored)
		
	parent_chunk.add_child(hoop)
