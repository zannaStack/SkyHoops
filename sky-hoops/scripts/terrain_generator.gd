extends Node2D

const HOOP_SCENE: PackedScene = preload("res://scenes/hoop.tscn")
const COIN_SCENE: PackedScene = preload("res://scenes/coin.tscn")
const SPIKE_SCENE: PackedScene = preload("res://scenes/obstacle_spike.tscn")
const BIRD_SCENE: PackedScene = preload("res://scenes/bird.tscn")
const ENERGY_SCENE: PackedScene = preload("res://scenes/pickup_energy.tscn")
const SPRING_PAD_SCENE: PackedScene = preload("res://scenes/spring_pad.tscn")
const DEFENDER_DUMMY_SCENE: PackedScene = preload("res://scenes/defender_dummy.tscn")

@export var player_node: Node2D = null

# Parametri matematici del terreno ondulato
var chunk_width: float = 1200.0
var step_x: float = 24.0 # 1200 / 24 = esattamente 50 passi senza residuo o interruzioni
var current_generated_x: float = 0.0

var active_chunks: Array[Node2D] = []
var has_spawned_record_marker: bool = false
var radial_light_texture: Texture2D = null

func get_terrain_y(x: float) -> float:
	# 0 - 80m (0 - 4000 px): Pianura perfettamente orizzontale a quota 520.0 per prendere confidenza
	if x <= 4000.0:
		return 520.0
	
	# Profilo collinare procedurale completo per l'endless running oltre i 500m
	var proc_wave: float = 520.0 + sin(x * 0.003) * 90.0 + cos(x * 0.006) * 40.0
	
	# 80 - 400m (4000 - 20000 px): Onde dolci e progressive senza salite ripide
	var intro_wave: float = 520.0 + sin((x - 4000.0) * 0.0025) * 55.0
	
	if x < 20000.0:
		return intro_wave
	elif x < 25000.0:
		# 400 - 500m (20000 - 25000 px): Raccordo smoothstep continuo verso le onde procedurali
		var t: float = smoothstep(20000.0, 25000.0, x)
		return lerp(intro_wave, proc_wave, t)
	else:
		# 500m+ (25000 px+): Onde procedurali complete infinite
		return proc_wave

func get_terrain_slope_angle(x: float) -> float:
	# Calcolo numerico della derivata (differenze finite): continuo ed esatto su qualsiasi formula
	var dy: float = get_terrain_y(x + 2.0) - get_terrain_y(x - 2.0)
	return atan2(dy / 4.0, 1.0)

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
	var chunk_index: int = int(round(start_x / chunk_width))
	
	var chunk_root = Node2D.new()
	chunk_root.name = "Chunk_" + str(int(start_x))
	chunk_root.set_meta("end_x", end_x)
	add_child(chunk_root)
	active_chunks.append(chunk_root)

	# I primi 500 metri (Chunk 0 - 20) sono curati a mano con progressione di gameplay dedicata
	if chunk_index <= 20:
		generate_handcrafted_chunk(chunk_root, start_x, end_x, chunk_index)
	else:
		generate_procedural_chunk(chunk_root, start_x, end_x)

	# Spawna Traguardo Fisico del Record Personale con cartello e coriandoli (Feature 6)
	check_and_spawn_record_marker(chunk_root, start_x, end_x)

	current_generated_x = end_x

# --- INTRODUZIONE CURATA A MANO (0 - 500m / Chunk 0 - 20) ---
func generate_handcrafted_chunk(chunk_root: Node2D, start_x: float, end_x: float, chunk_index: int) -> void:
	match chunk_index:
		0:
			# Chunk 0 (0 - 1200 px, 0 - 24m): Benvenuto e confidenza con i comandi base
			create_ground_segment(chunk_root, sample_surface_points(start_x, end_x), start_x, end_x)
			create_coin_line(chunk_root, 420.0, 4, 50.0, 48.0)

		1:
			# Chunk 1 (1200 - 2400 px, 24 - 48m): Allineamento al primo canestro
			create_ground_segment(chunk_root, sample_surface_points(start_x, end_x), start_x, end_x)
			create_coin_line(chunk_root, 1650.0, 3, 50.0, 48.0)

		2:
			# Chunk 2 (2400 - 3600 px, 48 - 72m): Hoop 1 (Primo canestro tutorial con traiettoria)
			create_ground_segment(chunk_root, sample_surface_points(start_x, end_x), start_x, end_x)
			create_hoop_at(chunk_root, 3000.0, 310.0, false, false, 0.0, 0.0, true)

		3:
			# Chunk 3 (3600 - 4800 px, 72 - 96m): Inizio lieve ondulazione a 4000px, sprint con aura dorata
			create_ground_segment(chunk_root, sample_surface_points(start_x, end_x), start_x, end_x)
			create_coin_line(chunk_root, 4120.0, 4, 45.0, 48.0)

		4:
			# Chunk 4 (4800 - 6000 px, 96 - 120m): Introduzione alla Molla / Trampolino (Spring Pad 1)
			create_ground_segment(chunk_root, sample_surface_points(start_x, end_x), start_x, end_x)
			create_coin_line(chunk_root, 5150.0, 3, 45.0, 48.0)
			create_spring_pad_at(chunk_root, 5450.0)

		5:
			# Chunk 5 (6000 - 7200 px, 120 - 144m): Hoop 2 (Canestro alto "Sky Basket" raggiungibile con super salto)
			create_ground_segment(chunk_root, sample_surface_points(start_x, end_x), start_x, end_x)
			create_hoop_at(chunk_root, 6450.0, 395.0, false, false, 0.0, 0.0, true)

		6:
			# Chunk 6 (7200 - 8400 px, 144 - 168m): Dosso collinare con scia di monete
			create_ground_segment(chunk_root, sample_surface_points(start_x, end_x), start_x, end_x)
			create_coin_line(chunk_root, 7650.0, 4, 50.0, 48.0)

		7:
			# Chunk 7 (8400 - 9600 px, 168 - 192m): Introduzione all'Energy Drink per ricarica stamina
			create_ground_segment(chunk_root, sample_surface_points(start_x, end_x), start_x, end_x)
			create_energy_at(chunk_root, 8900.0)
			create_coin_line(chunk_root, 9100.0, 3, 45.0, 48.0)

		8:
			# Chunk 8 (9600 - 10800 px, 192 - 216m): Primo Baratro (Gap 1) - 140px con arco monete guida
			var g1_start: float = 10130.0
			var g1_end: float = 10270.0
			create_ground_segment(chunk_root, sample_surface_points(start_x, g1_start), start_x, g1_start)
			create_ground_segment(chunk_root, sample_surface_points(g1_end, end_x), g1_end, end_x)
			spawn_gap_coin_arc(chunk_root, g1_start, g1_end)

		9:
			# Chunk 9 (10800 - 12000 px, 216 - 240m): Introduzione al primo Spuntone / Ostacolo a terra
			create_ground_segment(chunk_root, sample_surface_points(start_x, end_x), start_x, end_x)
			create_spike_at(chunk_root, 11400.0)
			var sy = get_terrain_y(11400.0)
			spawn_single_coin(chunk_root, Vector2(11340.0, sy - 65.0))
			spawn_single_coin(chunk_root, Vector2(11400.0, sy - 90.0))
			spawn_single_coin(chunk_root, Vector2(11460.0, sy - 65.0))

		10:
			# Chunk 10 (12000 - 13200 px, 240 - 264m): Hoop 3 (Tiro tecnico su collina)
			create_ground_segment(chunk_root, sample_surface_points(start_x, end_x), start_x, end_x)
			create_hoop_at(chunk_root, 12600.0, 325.0, false, false, 0.0, 0.0, true)

		11:
			# Chunk 11 (13200 - 14400 px, 264 - 288m): Ripresa ritmo collinare
			create_ground_segment(chunk_root, sample_surface_points(start_x, end_x), start_x, end_x)
			create_coin_line(chunk_root, 13700.0, 4, 50.0, 48.0)

		12:
			# Chunk 12 (14400 - 15600 px, 288 - 312m): Introduzione alla Sagoma Difensiva (D-Man)
			create_ground_segment(chunk_root, sample_surface_points(start_x, end_x), start_x, end_x)
			create_coin_line(chunk_root, 14650.0, 3, 45.0, 48.0)
			create_defender_at(chunk_root, 15000.0)

		13:
			# Chunk 13 (15600 - 16800 px, 312 - 336m): Hoop 4 (Tiro ad arco alto sopra il difensore superato)
			create_ground_segment(chunk_root, sample_surface_points(start_x, end_x), start_x, end_x)
			create_hoop_at(chunk_root, 16250.0, 335.0, false, false, 0.0, 0.0, true)

		14:
			# Chunk 14 (16800 - 18000 px, 336 - 360m): Secondo Baratro (Gap 2) - 150px
			var g2_start: float = 17325.0
			var g2_end: float = 17475.0
			create_ground_segment(chunk_root, sample_surface_points(start_x, g2_start), start_x, g2_start)
			create_ground_segment(chunk_root, sample_surface_points(g2_end, end_x), g2_end, end_x)
			spawn_gap_coin_arc(chunk_root, g2_start, g2_end)

		15:
			# Chunk 15 (18000 - 19200 px, 360 - 384m): Spring Pad 2 con serie aerea di monete
			create_ground_segment(chunk_root, sample_surface_points(start_x, end_x), start_x, end_x)
			create_spring_pad_at(chunk_root, 18500.0)
			var spy = get_terrain_y(18500.0)
			spawn_single_coin(chunk_root, Vector2(18600.0, spy - 160.0))
			spawn_single_coin(chunk_root, Vector2(18670.0, spy - 200.0))
			spawn_single_coin(chunk_root, Vector2(18740.0, spy - 160.0))

		16:
			# Chunk 16 (19200 - 20400 px, 384 - 408m): Inizio zona raccordo, primo Canestro Oscillante
			create_ground_segment(chunk_root, sample_surface_points(start_x, end_x), start_x, end_x)
			create_hoop_at(chunk_root, 19800.0, 345.0, false, true, 36.0, 1.7, true)

		17:
			# Chunk 17 (20400 - 21600 px, 408 - 432m): Introduzione al primo Ostacolo Volante (Uccello) + Energy Drink
			create_ground_segment(chunk_root, sample_surface_points(start_x, end_x), start_x, end_x)
			create_energy_at(chunk_root, 20800.0)
			create_bird_at(chunk_root, 21400.0, 260.0)

		18:
			# Chunk 18 (21600 - 22800 px, 432 - 456m): Terzo Baratro (Gap 3) - 160px con Spuntone a terra dopo l'atterraggio
			var g3_start: float = 22120.0
			var g3_end: float = 22280.0
			create_ground_segment(chunk_root, sample_surface_points(start_x, g3_start), start_x, g3_start)
			create_ground_segment(chunk_root, sample_surface_points(g3_end, end_x), g3_end, end_x)
			spawn_gap_coin_arc(chunk_root, g3_start, g3_end)
			create_spike_at(chunk_root, 22620.0)

		19:
			# Chunk 19 (22800 - 24000 px, 456 - 480m): Micro-Hoop Dorato di "Graduazione" (premia la precisione)
			create_ground_segment(chunk_root, sample_surface_points(start_x, end_x), start_x, end_x)
			create_hoop_at(chunk_root, 23400.0, 360.0, true, false, 0.0, 0.0, true)

		20:
			# Chunk 20 (24000 - 25200 px, 480 - 504m): Trampolino di lancio verso l'endless procedurale
			create_ground_segment(chunk_root, sample_surface_points(start_x, end_x), start_x, end_x)
			create_spring_pad_at(chunk_root, 24450.0)
			create_coin_line(chunk_root, 24650.0, 5, 45.0, 50.0)

# --- GENERAZIONE PROCEDURALE INFINITA (500m+) ---
func generate_procedural_chunk(chunk_root: Node2D, start_x: float, end_x: float) -> void:
	var distance_m: float = start_x / 50.0

	# --- FEATURE 3: BURRONI CALIBRATI (ATTIVI FIN DAI PRIMI METRI PROCEDURALI) ---
	# 500 - 800m: 28% probabilità, burrone medio (145 - 170px)
	# 800m+: 32% probabilità max, larghezza moderata (160 - 185px, sempre accessibile)
	var has_gap: bool = false
	var gap_width: float = 140.0
	
	if distance_m >= 800.0:
		has_gap = (randf() < 0.32)
		gap_width = randf_range(160.0, 185.0)
	elif distance_m >= 350.0:
		has_gap = (randf() < 0.28)
		gap_width = randf_range(145.0, 170.0)
	elif distance_m >= 80.0:
		has_gap = (randf() < 0.22)
		gap_width = randf_range(130.0, 155.0)

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

		# 1. Spawna un arco guida ideale di monete sopra il burrone (3 monete)
		spawn_gap_coin_arc(chunk_root, gap_start_x, gap_end_x)

	# 2. Spawna un Canestro in questo Chunk con la sua traiettoria di tiro a canestro
	spawn_hoop_in_chunk(chunk_root, start_x, end_x, has_gap, gap_start_x, gap_end_x)

	# 3. Spawna Ostacoli Spuntoni/Mine sul terreno solido (mai nel vuoto)
	spawn_spikes_in_chunk(chunk_root, start_x, end_x, has_gap, gap_start_x, gap_end_x)

	# 4. Spawna Uccelli in volo che intercettano la palla (dopo 700m)
	if distance_m > 700.0 and randf() < 0.28:
		spawn_bird_in_chunk(chunk_root, start_x, end_x)

	# 5. Spawna Rara Ricarica Energetica Stamina (probabilità 12% dopo 1000m, MAI nel vuoto)
	if distance_m > 1000.0 and randf() < 0.12:
		spawn_energy_in_chunk(chunk_root, start_x, end_x, has_gap, gap_start_x, gap_end_x)

	# 6. Spawna Molle/Trampolini (Spring Pads) per super salti acrobatici (dopo 400m)
	if distance_m >= 400.0 and randf() < 0.32:
		spawn_spring_pad_in_chunk(chunk_root, start_x, end_x, has_gap, gap_start_x, gap_end_x)

	# 7. Spawna Sagome Difensive "D-Man" con pop-up a molla che murano tiri bassi (dopo 500m)
	if distance_m >= 500.0 and randf() < (0.30 if distance_m < 1200.0 else 0.42):
		spawn_defender_in_chunk(chunk_root, start_x, end_x, has_gap, gap_start_x, gap_end_x)

	# 8. Spawna Lampioni da Pista/Stadio Notturno oltre 600m per illuminare il percorso (Feature 4)
	if distance_m >= 600.0 and randf() < 0.85:
		spawn_floodlight_in_chunk(chunk_root, start_x, end_x, has_gap, gap_start_x, gap_end_x)

	current_generated_x = end_x

func spawn_hoop_in_chunk(parent_chunk: Node2D, start_x: float, end_x: float, has_gap: bool, gap_start: float, gap_end: float) -> void:
	var hoop = HOOP_SCENE.instantiate()
	var distance_m: float = start_x / 50.0
	
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
	
	# --- FEATURE 4: SFIDE DI TIRO EVOLUTE & CANESTRI MOBILI PER DISTANZA ---
	var is_micro_hoop: bool = false
	var height_offset: float = 230.0
	var should_spawn_trajectory: bool = false
	
	if distance_m >= 1600.0:
		# NOTTE (1600m+): 80% canestri mobili con moto ellittico o rapido, 45% micro, quote aeree estreme
		is_micro_hoop = (randf() < 0.45)
		if randf() < 0.80:
			hoop.is_oscillating = true
			hoop.oscillation_amplitude = randf_range(50.0, 78.0)
			hoop.oscillation_speed = randf_range(2.3, 3.2)
			hoop.oscillation_mode = 1 if randf() < 0.50 else 0
		height_offset = randf_range(375.0, 460.0) if not is_micro_hoop else randf_range(425.0, 510.0)
		should_spawn_trajectory = (randf() < 0.08)
		
	elif distance_m >= 1000.0:
		# CREPUSCOLO (1000 - 1600m): 60% canestri oscillanti (anche ellittici), 35% micro
		is_micro_hoop = (randf() < 0.35)
		if randf() < 0.60:
			hoop.is_oscillating = true
			hoop.oscillation_amplitude = randf_range(42.0, 65.0)
			hoop.oscillation_speed = randf_range(2.0, 2.7)
			hoop.oscillation_mode = 1 if randf() < 0.40 else 0
		height_offset = randf_range(355.0, 430.0) if not is_micro_hoop else randf_range(400.0, 475.0)
		should_spawn_trajectory = (randf() < 0.14)
		
	elif distance_m >= 500.0:
		# TRAMONTO (500 - 1000m): 35% canestri oscillanti verticali moderati, 20% micro
		is_micro_hoop = (randf() < 0.20)
		if randf() < 0.35:
			hoop.is_oscillating = true
			hoop.oscillation_amplitude = randf_range(30.0, 48.0)
			hoop.oscillation_speed = randf_range(1.6, 2.2)
			hoop.oscillation_mode = 0
		height_offset = randf_range(335.0, 400.0) if not is_micro_hoop else randf_range(375.0, 445.0)
		should_spawn_trajectory = (randf() < 0.22)
		
	else:
		# GIORNO (0 - 500m): Livello base, canestri rialzati a quota atletica ("Sky Hoops")
		is_micro_hoop = false
		hoop.is_oscillating = false
		height_offset = randf_range(310.0, 365.0)
		should_spawn_trajectory = (start_x == 0.0) or (randf() < 0.35)

	hoop.is_micro = is_micro_hoop
	hoop.position = Vector2(hoop_x, terrain_y - height_offset)
	
	# Collega il canestro al turbo del player
	if player_node:
		hoop.goal_scored.connect(player_node._on_hoop_goal_scored)
		
	parent_chunk.add_child(hoop)

	if should_spawn_trajectory:
		spawn_hoop_trajectory_coins(parent_chunk, hoop_x, hoop.position.y)

func create_hoop_at(parent_chunk: Node2D, hoop_x: float, height_offset: float = 330.0, is_micro: bool = false, is_oscillating: bool = false, osc_amp: float = 35.0, osc_speed: float = 1.8, with_coins: bool = true) -> Node2D:
	var hoop = HOOP_SCENE.instantiate()
	var terrain_y = get_terrain_y(hoop_x)
	hoop.is_micro = is_micro
	hoop.is_oscillating = is_oscillating
	hoop.oscillation_amplitude = osc_amp
	hoop.oscillation_speed = osc_speed
	hoop.position = Vector2(hoop_x, terrain_y - height_offset)
	if player_node:
		hoop.goal_scored.connect(player_node._on_hoop_goal_scored)
	parent_chunk.add_child(hoop)
	if with_coins:
		spawn_hoop_trajectory_coins(parent_chunk, hoop_x, hoop.position.y)
	return hoop

func spawn_single_coin(parent_chunk: Node2D, pos: Vector2) -> void:
	var coin = COIN_SCENE.instantiate()
	coin.position = pos
	parent_chunk.add_child(coin)

func create_coin_line(parent_chunk: Node2D, start_x: float, count: int = 3, spacing: float = 45.0, height_above_ground: float = 48.0) -> void:
	for i in range(count):
		var cx = start_x + (float(i) * spacing)
		var cy = get_terrain_y(cx) - height_above_ground
		spawn_single_coin(parent_chunk, Vector2(cx, cy))

# Spawna una parabola di monete che illustra al giocatore l'arco ideale di tiro dentro al canestro
func spawn_hoop_trajectory_coins(parent_chunk: Node2D, hoop_x: float, hoop_y: float) -> void:
	var num_coins: int = 3
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
		var t: float = lerp(0.25, 0.85, float(i) / float(num_coins - 1))
		var coin_pos = (1.0 - t) * (1.0 - t) * p0 + 2.0 * (1.0 - t) * t * p1 + t * t * p2
		
		var coin = COIN_SCENE.instantiate()
		coin.position = coin_pos
		parent_chunk.add_child(coin)

func spawn_gap_coin_arc(parent_chunk: Node2D, gap_start: float, gap_end: float) -> void:
	var num_coins: int = 3
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
	var distance_m: float = start_x / 50.0
	if distance_m > 1000.0 and randf() < 0.35:
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
	var bird_x = end_x + randf_range(50.0, 200.0)
	var bird_y = randf_range(200.0, 320.0)
	create_bird_at(parent_chunk, bird_x, bird_y)

func create_bird_at(parent_chunk: Node2D, bird_x: float, bird_y: float = 260.0) -> void:
	var bird = BIRD_SCENE.instantiate()
	bird.position = Vector2(bird_x, bird_y)
	parent_chunk.add_child(bird)

func spawn_energy_in_chunk(parent_chunk: Node2D, start_x: float, end_x: float, has_gap: bool, gap_start: float, gap_end: float) -> void:
	var en_x = get_safe_ground_x(start_x, end_x, has_gap, gap_start, gap_end, 120.0)
	create_energy_at(parent_chunk, en_x)

func create_energy_at(parent_chunk: Node2D, en_x: float) -> void:
	var terrain_y = get_terrain_y(en_x)
	var energy = ENERGY_SCENE.instantiate()
	energy.position = Vector2(en_x, terrain_y - 75.0)
	parent_chunk.add_child(energy)

func spawn_spring_pad_in_chunk(parent_chunk: Node2D, start_x: float, end_x: float, has_gap: bool, gap_start: float, gap_end: float) -> void:
	var sp_x = get_safe_ground_x(start_x, end_x, has_gap, gap_start, gap_end, 120.0)
	create_spring_pad_at(parent_chunk, sp_x)

func create_spring_pad_at(parent_chunk: Node2D, sp_x: float) -> void:
	var terrain_y = get_terrain_y(sp_x)
	var spring = SPRING_PAD_SCENE.instantiate()
	spring.position = Vector2(sp_x, terrain_y)
	spring.rotation = get_terrain_slope_angle(sp_x)
	parent_chunk.add_child(spring)

func spawn_defender_in_chunk(parent_chunk: Node2D, start_x: float, end_x: float, has_gap: bool, gap_start: float, gap_end: float) -> void:
	var def_x = get_safe_ground_x(start_x, end_x, has_gap, gap_start, gap_end, 100.0)
	create_defender_at(parent_chunk, def_x)

func create_defender_at(parent_chunk: Node2D, def_x: float) -> void:
	var terrain_y = get_terrain_y(def_x)
	var dummy = DEFENDER_DUMMY_SCENE.instantiate()
	dummy.position = Vector2(def_x, terrain_y)
	dummy.rotation = get_terrain_slope_angle(def_x)
	parent_chunk.add_child(dummy)

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

	# Calcolo dinamico colori terreno per ciclo Giorno / Tramonto / Notte (Feature 4)
	var dist_m: float = seg_start / 50.0
	var grass_col: Color
	var dirt_col: Color
	
	if dist_m < 350.0:
		# Giorno solare
		grass_col = Color(0.24, 0.76, 0.32)
		dirt_col = Color(0.38, 0.22, 0.13)
	elif dist_m < 900.0:
		# Tramonto dorato
		var t = clamp((dist_m - 350.0) / 550.0, 0.0, 1.0)
		grass_col = Color(0.24, 0.76, 0.32).lerp(Color(0.58, 0.72, 0.22), t)
		dirt_col = Color(0.38, 0.22, 0.13).lerp(Color(0.44, 0.22, 0.16), t)
	elif dist_m < 1600.0:
		# Crepuscolo porpora
		var t = clamp((dist_m - 900.0) / 700.0, 0.0, 1.0)
		grass_col = Color(0.58, 0.72, 0.22).lerp(Color(0.25, 0.82, 0.58), t)
		dirt_col = Color(0.44, 0.22, 0.16).lerp(Color(0.25, 0.16, 0.26), t)
	else:
		# Notte illuminata (erba verde-smeraldo brillante ad altissima visibilità)
		grass_col = Color(0.22, 0.86, 0.64)
		dirt_col = Color(0.20, 0.14, 0.24)

	# 2. Riempimento visivo terra sottostante
	var ground_fill = Polygon2D.new()
	ground_fill.polygon = PackedVector2Array(poly)
	ground_fill.color = dirt_col
	parent.add_child(ground_fill)

	# 3. Superficie d'erba illuminata e perfettamente leggibile
	var grass_line = Line2D.new()
	grass_line.points = PackedVector2Array(points)
	grass_line.width = 9.0
	grass_line.default_color = grass_col
	grass_line.joint_mode = Line2D.LINE_JOINT_ROUND
	grass_line.begin_cap_mode = Line2D.LINE_CAP_ROUND
	grass_line.end_cap_mode = Line2D.LINE_CAP_ROUND
	parent.add_child(grass_line)


# --- FEATURE 6: TRAGUARDO FISICO RECORD PERSONALE CON CARTIELLO E CORIANDOLI ---
func check_and_spawn_record_marker(parent_chunk: Node2D, start_x: float, end_x: float) -> void:
	if has_spawned_record_marker:
		return
	var record_m = GameManager.high_score
	if record_m <= 0:
		return
	
	var record_x: float = float(record_m) * 50.0
	if record_x >= start_x and record_x < end_x:
		has_spawned_record_marker = true
		spawn_record_marker(parent_chunk, record_x, record_m)

func spawn_record_marker(parent_chunk: Node2D, record_x: float, record_m: int) -> void:
	var terrain_y = get_terrain_y(record_x)
	var slope = get_terrain_slope_angle(record_x)
	
	var marker_root = Node2D.new()
	marker_root.name = "RecordMilestoneMarker"
	marker_root.position = Vector2(record_x, terrain_y)
	marker_root.rotation = slope
	parent_chunk.add_child(marker_root)
	
	# 1. Linea Traguardo su asfalto/erba (striscia oro/bianca riflettente)
	var finish_line = Line2D.new()
	finish_line.points = PackedVector2Array([Vector2(0, -6), Vector2(0, 24)])
	finish_line.width = 22.0
	finish_line.default_color = Color(1.0, 0.84, 0.1, 0.95)
	marker_root.add_child(finish_line)
	
	var white_stripe = Line2D.new()
	white_stripe.points = PackedVector2Array([Vector2(0, -5), Vector2(0, 22)])
	white_stripe.width = 8.0
	white_stripe.default_color = Color(1.0, 1.0, 1.0, 0.92)
	marker_root.add_child(white_stripe)
	
	# 2. Palo traguardo
	var pole = Line2D.new()
	pole.points = PackedVector2Array([Vector2(0, 0), Vector2(0, -135)])
	pole.width = 6.0
	pole.default_color = Color(0.85, 0.88, 0.92)
	marker_root.add_child(pole)
	
	# 3. Insegna Traguardo Record ("🏆 RECORD: {m}m 🏁")
	var sign_panel = Panel.new()
	sign_panel.position = Vector2(-110, -175)
	sign_panel.size = Vector2(220, 42)
	
	var style = StyleBoxFlat.new()
	style.bg_color = Color(0.08, 0.10, 0.16, 0.95)
	style.border_color = Color(1.0, 0.82, 0.15)
	style.set_border_width_all(2)
	style.set_corner_radius_all(6)
	sign_panel.add_theme_stylebox_override("panel", style)
	marker_root.add_child(sign_panel)
	
	var label = Label.new()
	label.text = "🏆 RECORD: " + str(record_m) + "m 🏁"
	label.size = Vector2(220, 42)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.modulate = Color(1.0, 0.88, 0.2)
	label.add_theme_font_size_override("font_size", 16)
	sign_panel.add_child(label)
	
	# 4. Fascio di luce dorata
	var light = PointLight2D.new()
	light.texture = get_radial_light_texture()
	light.texture_scale = 3.0
	light.energy = 1.3
	light.color = Color(1.0, 0.85, 0.25)
	light.position = Vector2(0, -70)
	marker_root.add_child(light)
	
	# 5. Cannone di coriandoli celebrativi
	var confetti = CPUParticles2D.new()
	confetti.name = "ConfettiParticles"
	confetti.emitting = false
	confetti.one_shot = true
	confetti.amount = 75
	confetti.lifetime = 2.4
	confetti.explosiveness = 0.95
	confetti.emission_shape = CPUParticles2D.EMISSION_SHAPE_RECTANGLE
	confetti.emission_rect_extents = Vector2(80, 20)
	confetti.direction = Vector2(0, -1)
	confetti.spread = 65.0
	confetti.gravity = Vector2(0, 180)
	confetti.initial_velocity_min = 160.0
	confetti.initial_velocity_max = 280.0
	confetti.scale_amount_min = 4.0
	confetti.scale_amount_max = 8.5
	confetti.position = Vector2(0, -90)
	
	var c_grad = Gradient.new()
	c_grad.colors = PackedColorArray([
		Color(1.0, 0.85, 0.15),
		Color(0.2, 0.8, 1.0),
		Color(1.0, 0.25, 0.4),
		Color(0.3, 1.0, 0.4),
		Color(1.0, 1.0, 1.0)
	])
	confetti.color_ramp = c_grad
	marker_root.add_child(confetti)
	
	# 6. Rilevatore attraversamento del giocatore
	var sensor = Area2D.new()
	sensor.collision_layer = 0
	sensor.collision_mask = 2 # Player
	var col = CollisionShape2D.new()
	var shape = RectangleShape2D.new()
	shape.size = Vector2(40, 260)
	col.shape = shape
	col.position = Vector2(0, -100)
	sensor.add_child(col)
	marker_root.add_child(sensor)
	
	var trigger_guard = [false]
	sensor.body_entered.connect(func(body):
		if trigger_guard[0]:
			return
		if body is CharacterBody2D:
			trigger_guard[0] = true
			confetti.restart()
			GameManager.vibrate_double()
			if body.has_method("add_camera_trauma"):
				body.add_camera_trauma(0.65)
			var hud = body.get("hud")
			if hud and hud.has_method("show_new_record_banner"):
				hud.show_new_record_banner(record_m)
			var s_tween = sign_panel.create_tween()
			s_tween.tween_property(sign_panel, "scale", Vector2(1.25, 1.25), 0.12).set_trans(Tween.TRANS_BACK)
			s_tween.tween_property(sign_panel, "scale", Vector2(1.0, 1.0), 0.18)
	)

# --- FEATURE 4: LAMPIONI DA STADIO / PISTA ILLUMINATA PER CORSA NOTTURNA ---
func spawn_floodlight_in_chunk(parent_chunk: Node2D, start_x: float, end_x: float, has_gap: bool, gap_start: float, gap_end: float) -> void:
	var lamp_x = get_safe_ground_x(start_x, end_x, has_gap, gap_start, gap_end, 160.0)
	var terrain_y = get_terrain_y(lamp_x)
	var slope = get_terrain_slope_angle(lamp_x)
	
	var lamp_root = Node2D.new()
	lamp_root.position = Vector2(lamp_x, terrain_y)
	lamp_root.rotation = slope
	parent_chunk.add_child(lamp_root)
	
	# Palo del lampione inclinato alla pendenza
	var pole = Line2D.new()
	pole.points = PackedVector2Array([Vector2(0, 0), Vector2(0, -115), Vector2(24, -125)])
	pole.width = 4.5
	pole.default_color = Color(0.28, 0.32, 0.42)
	lamp_root.add_child(pole)
	
	# Plafoniera lampione
	var fixture = Polygon2D.new()
	fixture.polygon = PackedVector2Array([Vector2(16, -127), Vector2(34, -122), Vector2(32, -117), Vector2(18, -122)])
	fixture.color = Color(1.0, 0.95, 0.75)
	lamp_root.add_child(fixture)
	
	# Fascio di luce a terra (pista sempre ben illuminata)
	var light = PointLight2D.new()
	light.texture = get_radial_light_texture()
	light.texture_scale = 3.8
	light.energy = 1.35
	light.color = Color(1.0, 0.92, 0.72)
	light.position = Vector2(24, -120)
	lamp_root.add_child(light)

func get_radial_light_texture() -> Texture2D:
	if radial_light_texture:
		return radial_light_texture
	var grad = Gradient.new()
	grad.colors = PackedColorArray([Color(1.0, 1.0, 1.0, 1.0), Color(1.0, 0.92, 0.7, 0.65), Color(1.0, 0.8, 0.4, 0.0)])
	var tex = GradientTexture2D.new()
	tex.gradient = grad
	tex.fill = GradientTexture2D.FILL_RADIAL
	tex.fill_from = Vector2(0.5, 0.5)
	tex.fill_to = Vector2(0.85, 0.85)
	radial_light_texture = tex
	return radial_light_texture
