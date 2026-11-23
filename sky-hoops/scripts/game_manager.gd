extends Node

const SAVE_FILE_PATH: String = "user://save_game.json"

const MAX_STAT_LEVEL: int = 10
const BASE_STAT_COST: int = 100

# Dati persistenti del giocatore
var coins: int = 0
var speed_level: int = 1
var aim_level: int = 1
var jump_level: int = 1
var stamina_level: int = 1

# Alias per retrocompatibilità
var power_level: int:
	get: return speed_level
	set(val): speed_level = val

# Livello abilità speciali: 0 = nessuna, 1 = Calamita, 2 = Stamina 1000m, 3 = Volo 1000m
var special_ability_level: int = 0
var high_score: int = 0

func _ready() -> void:
	load_game()

# Calcolo del costo dinamico con raddoppio ad ogni livello (100 -> 200 -> 400 ... fino a Lv 10)
func get_stat_cost(level: int) -> int:
	if level >= MAX_STAT_LEVEL:
		return -1 # Livello Massimo Raggiunto
	return BASE_STAT_COST * int(pow(2, level - 1))

func get_speed_upgrade_cost() -> int:
	return get_stat_cost(speed_level)

func get_power_upgrade_cost() -> int:
	return get_speed_upgrade_cost()

func get_aim_upgrade_cost() -> int:
	return get_stat_cost(aim_level)

func get_jump_upgrade_cost() -> int:
	return get_stat_cost(jump_level)

func get_stamina_upgrade_cost() -> int:
	return get_stat_cost(stamina_level)

# Gestione Abilità Speciali (5000 -> 10000 -> 20000)
func get_special_ability_cost() -> int:
	match special_ability_level:
		0: return 5000  # Calamita Monete
		1: return 10000 # Stamina Piena primi 1000m
		2: return 20000 # Volo Aereo primi 1000m
		_: return -1    # Tutte e 3 sbloccate!

func get_special_ability_name() -> String:
	match special_ability_level:
		0: return "🧲 CALAMITA MONETE"
		1: return "⚡ STAMINA 1000M"
		2: return "✈️ VOLO AEREO 1000M"
		_: return "✨ TUTTE SBLOCCATE (MAX)"

func add_coins(amount: int) -> void:
	coins += amount
	save_game()

func upgrade_speed() -> bool:
	var cost = get_speed_upgrade_cost()
	if cost > 0 and coins >= cost and speed_level < MAX_STAT_LEVEL:
		coins -= cost
		speed_level += 1
		save_game()
		return true
	return false

func upgrade_power() -> bool:
	return upgrade_speed()

func upgrade_aim() -> bool:
	var cost = get_aim_upgrade_cost()
	if cost > 0 and coins >= cost and aim_level < MAX_STAT_LEVEL:
		coins -= cost
		aim_level += 1
		save_game()
		return true
	return false

func upgrade_jump() -> bool:
	var cost = get_jump_upgrade_cost()
	if cost > 0 and coins >= cost and jump_level < MAX_STAT_LEVEL:
		coins -= cost
		jump_level += 1
		save_game()
		return true
	return false

func upgrade_stamina() -> bool:
	var cost = get_stamina_upgrade_cost()
	if cost > 0 and coins >= cost and stamina_level < MAX_STAT_LEVEL:
		coins -= cost
		stamina_level += 1
		save_game()
		return true
	return false

func unlock_special_ability() -> bool:
	var cost = get_special_ability_cost()
	if cost > 0 and coins >= cost and special_ability_level < 3:
		coins -= cost
		special_ability_level += 1
		save_game()
		return true
	return false

func update_high_score(distance: int) -> void:
	if distance > high_score:
		high_score = distance
		save_game()

# Salvataggio persistente su JSON
func save_game() -> void:
	var data = {
		"coins": coins,
		"speed_level": speed_level,
		"aim_level": aim_level,
		"jump_level": jump_level,
		"stamina_level": stamina_level,
		"special_ability_level": special_ability_level,
		"high_score": high_score
	}
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(data, "\t")
		file.store_string(json_string)

# Caricamento da JSON con fallback
func load_game() -> void:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return

	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var json = JSON.new()
		var parse_result = json.parse(content)
		if parse_result == OK:
			var data = json.data
			coins = data.get("coins", 0)
			speed_level = clamp(data.get("speed_level", data.get("power_level", 1)), 1, MAX_STAT_LEVEL)
			aim_level = clamp(data.get("aim_level", 1), 1, MAX_STAT_LEVEL)
			jump_level = clamp(data.get("jump_level", 1), 1, MAX_STAT_LEVEL)
			stamina_level = clamp(data.get("stamina_level", 1), 1, MAX_STAT_LEVEL)
			special_ability_level = clamp(data.get("special_ability_level", 0), 0, 3)
			high_score = data.get("high_score", 0)

# --- FEEDBACK APTICO / VIBRAZIONE MOBILE (Android / iOS) ---
func vibrate(duration_ms: int = 25) -> void:
	if OS.has_feature("mobile") or OS.get_name() in ["Android", "iOS"]:
		Input.vibrate_handheld(duration_ms)

func vibrate_light() -> void:
	vibrate(15)

func vibrate_medium() -> void:
	vibrate(35)

func vibrate_heavy() -> void:
	vibrate(65)

func vibrate_double() -> void:
	vibrate(30)
	var tree = Engine.get_main_loop() as SceneTree
	if tree:
		var timer = tree.create_timer(0.08)
		timer.timeout.connect(func(): vibrate(35))
