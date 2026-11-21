extends Node

const SAVE_FILE_PATH: String = "user://save_game.json"

# Dati persistenti del giocatore
var coins: int = 0
var power_level: int = 1
var aim_level: int = 1
var high_score: int = 0

func _ready() -> void:
	load_game()

# Calcolo del costo dinamico degli upgrade
func get_power_upgrade_cost() -> int:
	return power_level * 5

func get_aim_upgrade_cost() -> int:
	return aim_level * 5

func add_coins(amount: int) -> void:
	coins += amount
	save_game()

func upgrade_power() -> bool:
	var cost = get_power_upgrade_cost()
	if coins >= cost:
		coins -= cost
		power_level += 1
		save_game()
		return true
	return false

func upgrade_aim() -> bool:
	var cost = get_aim_upgrade_cost()
	if coins >= cost:
		coins -= cost
		aim_level += 1
		save_game()
		return true
	return false

func update_high_score(distance: int) -> void:
	if distance > high_score:
		high_score = distance
		save_game()

# Salvataggio su file JSON
func save_game() -> void:
	var data = {
		"coins": coins,
		"power_level": power_level,
		"aim_level": aim_level,
		"high_score": high_score
	}
	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.WRITE)
	if file:
		var json_string = JSON.stringify(data, "\t")
		file.store_string(json_string)

# Caricamento da file JSON
func load_game() -> void:
	if not FileAccess.file_exists(SAVE_FILE_PATH):
		return # Prima partita: usa i valori di default

	var file = FileAccess.open(SAVE_FILE_PATH, FileAccess.READ)
	if file:
		var content = file.get_as_text()
		var json = JSON.new()
		var parse_result = json.parse(content)
		if parse_result == OK:
			var data = json.data
			coins = data.get("coins", 0)
			power_level = data.get("power_level", 1)
			aim_level = data.get("aim_level", 1)
			high_score = data.get("high_score", 0)
