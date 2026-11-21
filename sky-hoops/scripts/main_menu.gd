extends Control

# Dati per il carosello degli Sport
var sports_data: Array[Dictionary] = [
	{
		"name": "BASKET",
		"preview": preload("res://assets/preview_basket.svg"),
		"status": "DISPONIBILE",
		"locked": false
	},
	{
		"name": "CALCIO",
		"preview": preload("res://assets/preview_soccer.svg"),
		"status": "🔒 COMING SOON",
		"locked": true
	},
	{
		"name": "TENNIS",
		"preview": preload("res://assets/preview_soccer.svg"),
		"status": "🔒 COMING SOON",
		"locked": true
	}
]

# Dati per il carosello dei Campi/Paesaggi
var stages_data: Array[Dictionary] = [
	{
		"name": "COLLINE VERDI",
		"preview": preload("res://assets/preview_hills.svg"),
		"status": "DISPONIBILE",
		"locked": false
	},
	{
		"name": "DESERTO",
		"preview": preload("res://assets/preview_desert.svg"),
		"status": "🔒 COMING SOON",
		"locked": true
	},
	{
		"name": "CITTA' NOTTURNA",
		"preview": preload("res://assets/preview_desert.svg"),
		"status": "🔒 COMING SOON",
		"locked": true
	}
]

enum MenuTab { SPORT, STAGE, TUNE }
var current_tab: MenuTab = MenuTab.SPORT

var selected_sport_idx: int = 0
var selected_stage_idx: int = 0

# Riferimenti nodi UI
var coin_label: Label = null
var header_title: Label = null
var record_label: Label = null

var center_card_area: Control = null
var card_image: TextureRect = null
var card_title: Label = null
var card_subtitle: Label = null
var btn_prev: Button = null
var btn_next: Button = null

var upgrade_area: Panel = null
var btn_power: Button = null
var btn_aim: Button = null

var tab_sport: Button = null
var tab_stage: Button = null
var tab_tune: Button = null
var btn_start: Button = null

func _ready() -> void:
	_ensure_nodes()

	# Collega i pulsanti freccia del carosello
	if btn_prev and not btn_prev.pressed.is_connected(_on_prev_pressed):
		btn_prev.pressed.connect(_on_prev_pressed)
	if btn_next and not btn_next.pressed.is_connected(_on_next_pressed):
		btn_next.pressed.connect(_on_next_pressed)

	# Collega le tab inferiori
	if tab_sport and not tab_sport.pressed.is_connected(_on_tab_sport_pressed):
		tab_sport.pressed.connect(_on_tab_sport_pressed)
	if tab_stage and not tab_stage.pressed.is_connected(_on_tab_stage_pressed):
		tab_stage.pressed.connect(_on_tab_stage_pressed)
	if tab_tune and not tab_tune.pressed.is_connected(_on_tab_tune_pressed):
		tab_tune.pressed.connect(_on_tab_tune_pressed)
	if btn_start and not btn_start.pressed.is_connected(_on_start_pressed):
		btn_start.pressed.connect(_on_start_pressed)

	# Collega i potenziamenti dell'officina
	if btn_power and not btn_power.pressed.is_connected(_on_power_pressed):
		btn_power.pressed.connect(_on_power_pressed)
	if btn_aim and not btn_aim.pressed.is_connected(_on_aim_pressed):
		btn_aim.pressed.connect(_on_aim_pressed)

	# Aggiorna dati e schermata iniziale
	refresh_top_bar()
	set_tab(MenuTab.SPORT)

func _ensure_nodes() -> void:
	if not card_image: card_image = find_child("CardImage", true, false)
	if not card_title: card_title = find_child("CardTitle", true, false)
	if not card_subtitle: card_subtitle = find_child("CardSubtitle", true, false)
	if not btn_prev: btn_prev = find_child("BtnPrev", true, false)
	if not btn_next: btn_next = find_child("BtnNext", true, false)
	if not btn_start: btn_start = find_child("BtnStart", true, false)
	if not coin_label: coin_label = find_child("CoinLabel", true, false)
	if not header_title: header_title = find_child("HeaderTitle", true, false)
	if not record_label: record_label = find_child("RecordLabel", true, false)
	if not center_card_area: center_card_area = find_child("CenterCardArea", true, false)
	if not upgrade_area: upgrade_area = find_child("UpgradeArea", true, false)
	if not btn_power: btn_power = find_child("BtnPower", true, false)
	if not btn_aim: btn_aim = find_child("BtnAim", true, false)
	if not tab_sport: tab_sport = find_child("TabSport", true, false)
	if not tab_stage: tab_stage = find_child("TabStage", true, false)
	if not tab_tune: tab_tune = find_child("TabTune", true, false)

func _on_tab_sport_pressed() -> void:
	set_tab(MenuTab.SPORT)

func _on_tab_stage_pressed() -> void:
	set_tab(MenuTab.STAGE)

func _on_tab_tune_pressed() -> void:
	set_tab(MenuTab.TUNE)

func refresh_top_bar() -> void:
	_ensure_nodes()
	if coin_label:
		coin_label.text = "🪙 " + str(GameManager.coins)
	if record_label:
		record_label.text = "🏆 Record: " + str(GameManager.high_score) + " m"

func set_tab(tab: MenuTab) -> void:
	_ensure_nodes()
	current_tab = tab

	if current_tab == MenuTab.TUNE:
		if center_card_area: center_card_area.visible = false
		if upgrade_area: upgrade_area.visible = true
		if header_title: header_title.text = "POTENZIAMENTI"
		refresh_upgrade_buttons()
	else:
		if center_card_area: center_card_area.visible = true
		if upgrade_area: upgrade_area.visible = false
		if header_title:
			header_title.text = "SELEZIONE SPORT" if current_tab == MenuTab.SPORT else "SELEZIONE CAMPO"
		update_card_display()

func update_card_display() -> void:
	_ensure_nodes()
	var item: Dictionary
	if current_tab == MenuTab.SPORT:
		item = sports_data[selected_sport_idx]
	else:
		item = stages_data[selected_stage_idx]

	if card_image:
		card_image.texture = item["preview"]
	if card_title:
		card_title.text = item["name"]
	if card_subtitle:
		card_subtitle.text = item["status"]

	if btn_start:
		if item["locked"]:
			if card_subtitle:
				card_subtitle.set("theme_override_colors/font_color", Color(0.9, 0.3, 0.2))
			btn_start.disabled = true
			btn_start.text = "🔒 BLOCCATO"
		else:
			if card_subtitle:
				card_subtitle.set("theme_override_colors/font_color", Color(0.18, 0.8, 0.44))
			btn_start.disabled = false
			btn_start.text = "▶ GIOCA"

func _on_prev_pressed() -> void:
	if current_tab == MenuTab.SPORT:
		selected_sport_idx = (selected_sport_idx - 1 + sports_data.size()) % sports_data.size()
	elif current_tab == MenuTab.STAGE:
		selected_stage_idx = (selected_stage_idx - 1 + stages_data.size()) % stages_data.size()
	update_card_display()

func _on_next_pressed() -> void:
	if current_tab == MenuTab.SPORT:
		selected_sport_idx = (selected_sport_idx + 1) % sports_data.size()
	elif current_tab == MenuTab.STAGE:
		selected_stage_idx = (selected_stage_idx + 1) % stages_data.size()
	update_card_display()

func refresh_upgrade_buttons() -> void:
	_ensure_nodes()
	if btn_power:
		var p_cost = GameManager.get_power_upgrade_cost()
		btn_power.text = "FORZA (Lv. " + str(GameManager.power_level) + ") - " + str(p_cost) + " 🪙"
		btn_power.disabled = (GameManager.coins < p_cost)

	if btn_aim:
		var a_cost = GameManager.get_aim_upgrade_cost()
		btn_aim.text = "MIRINO (Lv. " + str(GameManager.aim_level) + ") - " + str(a_cost) + " 🪙"
		btn_aim.disabled = (GameManager.coins < a_cost)

func _on_power_pressed() -> void:
	if GameManager.upgrade_power():
		refresh_top_bar()
		refresh_upgrade_buttons()

func _on_aim_pressed() -> void:
	if GameManager.upgrade_aim():
		refresh_top_bar()
		refresh_upgrade_buttons()

func _on_start_pressed() -> void:
	get_tree().change_scene_to_file("res://scenes/main.tscn")
