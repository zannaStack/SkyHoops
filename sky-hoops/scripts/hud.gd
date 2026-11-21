extends CanvasLayer

@onready var stamina_bar: ProgressBar = $StaminaBar
@onready var distance_label: Label = $DistanceLabel
@onready var coin_label: Label = $CoinLabel
@onready var combo_label: Label = $ComboLabel

@onready var game_over_panel: Panel = $GameOverPanel
@onready var game_over_label: Label = $GameOverPanel/GameOver
@onready var power_button: Button = $GameOverPanel/PowerButton
@onready var aim_button: Button = $GameOverPanel/AimButton
@onready var retry_button: Button = $GameOverPanel/ButtonsRow/RetryButton
@onready var menu_button: Button = $GameOverPanel/ButtonsRow/MenuButton

func _ready() -> void:
	_ensure_nodes()
	
	if game_over_panel:
		game_over_panel.visible = false
	
	if retry_button and not retry_button.pressed.is_connected(_on_retry_pressed):
		retry_button.pressed.connect(_on_retry_pressed)
	if menu_button and not menu_button.pressed.is_connected(_on_menu_pressed):
		menu_button.pressed.connect(_on_menu_pressed)
	if power_button and not power_button.pressed.is_connected(_on_power_pressed):
		power_button.pressed.connect(_on_power_pressed)
	if aim_button and not aim_button.pressed.is_connected(_on_aim_pressed):
		aim_button.pressed.connect(_on_aim_pressed)
	
	update_coins(GameManager.coins)

func _ensure_nodes() -> void:
	if not stamina_bar:
		stamina_bar = get_node_or_null("StaminaBar")
	if not distance_label:
		distance_label = get_node_or_null("DistanceLabel")
	if not coin_label:
		coin_label = get_node_or_null("CoinLabel")
	if not game_over_panel:
		game_over_panel = get_node_or_null("GameOverPanel")
	if game_over_panel:
		if not game_over_label:
			game_over_label = game_over_panel.get_node_or_null("GameOver")
		if not power_button:
			power_button = game_over_panel.get_node_or_null("PowerButton")
		if not aim_button:
			aim_button = game_over_panel.get_node_or_null("AimButton")
		if not retry_button:
			retry_button = game_over_panel.get_node_or_null("ButtonsRow/RetryButton")
		if not menu_button:
			menu_button = game_over_panel.get_node_or_null("ButtonsRow/MenuButton")

func update_stamina(value: float) -> void:
	_ensure_nodes()
	if stamina_bar:
		stamina_bar.value = value

func update_distance(distance_meters: int) -> void:
	_ensure_nodes()
	if distance_label:
		distance_label.text = str(distance_meters) + " m"

func update_coins(total_coins: int) -> void:
	_ensure_nodes()
	if coin_label:
		coin_label.text = "🪙 " + str(total_coins)

func update_combo(combo_count: int, is_on_fire: bool) -> void:
	_ensure_nodes()
	if not combo_label:
		combo_label = get_node_or_null("ComboLabel")
	if not combo_label:
		return
	if is_on_fire and combo_count >= 2:
		combo_label.visible = true
		combo_label.text = "🔥 ON FIRE! x" + str(combo_count) + " (x2 🪙)"
		combo_label.modulate = Color(1.0, 0.85, 0.2)
		var tween = create_tween()
		tween.tween_property(combo_label, "scale", Vector2(1.25, 1.25), 0.1)
		tween.tween_property(combo_label, "scale", Vector2(1.0, 1.0), 0.15)
	else:
		combo_label.visible = false

func show_game_over(final_distance: int) -> void:
	_ensure_nodes()
	if game_over_panel:
		game_over_panel.visible = true
	if game_over_label:
		game_over_label.text = "GAME OVER!\nMetri: " + str(final_distance) + " m | Record: " + str(GameManager.high_score) + " m"
	refresh_upgrade_buttons()

func refresh_upgrade_buttons() -> void:
	_ensure_nodes()
	if power_button:
		var p_cost = GameManager.get_power_upgrade_cost()
		power_button.text = "FORZA (Lv. " + str(GameManager.power_level) + ") - " + str(p_cost) + " 🪙"
		power_button.disabled = (GameManager.coins < p_cost)
	
	if aim_button:
		var a_cost = GameManager.get_aim_upgrade_cost()
		aim_button.text = "MIRINO (Lv. " + str(GameManager.aim_level) + ") - " + str(a_cost) + " 🪙"
		aim_button.disabled = (GameManager.coins < a_cost)

func _on_power_pressed() -> void:
	if GameManager.upgrade_power():
		update_coins(GameManager.coins)
		refresh_upgrade_buttons()

func _on_aim_pressed() -> void:
	if GameManager.upgrade_aim():
		update_coins(GameManager.coins)
		refresh_upgrade_buttons()

func _on_retry_pressed() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
