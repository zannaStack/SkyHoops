extends CanvasLayer

const COIN_ICON: Texture2D = preload("res://assets/coin.svg")

const COLOR_STAMINA_GREEN: Color = Color(0.2, 0.85, 0.35)
const COLOR_STAMINA_YELLOW: Color = Color(0.96, 0.82, 0.16)
const COLOR_STAMINA_RED: Color = Color(0.95, 0.22, 0.22)
const COLOR_DAMAGE_FLASH: Color = Color(1.0, 0.1, 0.1)

var stamina_fill_style: StyleBoxFlat = null
var damage_flash_timer: float = 0.0

@onready var stamina_bar: ProgressBar = $StaminaBar
@onready var distance_label: Label = $DistanceLabel
@onready var coin_label: Label = $CoinContainer/CoinLabel
@onready var combo_container: HBoxContainer = get_node_or_null("ComboContainer")
@onready var combo_label: Label = get_node_or_null("ComboContainer/ComboLabel") if has_node("ComboContainer/ComboLabel") else get_node_or_null("ComboLabel")
@onready var pause_button: Button = $PauseButton
@onready var pause_panel: Panel = $PausePanel
@onready var resume_button: Button = $PausePanel/PauseButtons/ResumeButton
@onready var pause_menu_button: Button = $PausePanel/PauseButtons/PauseMenuButton
@onready var record_banner: Label = $RecordBanner
@onready var impact_flash: ColorRect = get_node_or_null("ImpactFlash")
@onready var fire_border: Panel = get_node_or_null("FireBorder")
@onready var shoot_button: Button = get_node_or_null("ShootButton")

@onready var game_over_panel: Panel = $GameOverPanel
@onready var game_over_label: Label = $GameOverPanel/GameOver
@onready var game_over_coin_label: Label = get_node_or_null("GameOverPanel/GameOverCoinContainer/GameOverCoinLabel")
@onready var stats_label: Control = $GameOverPanel/StatsLabel
@onready var speed_button: Button = get_node_or_null("GameOverPanel/UpgradesGrid/SpeedButton")
@onready var power_button: Button = speed_button
@onready var aim_button: Button = $GameOverPanel/UpgradesGrid/AimButton
@onready var jump_button: Button = $GameOverPanel/UpgradesGrid/JumpButton
@onready var stamina_button: Button = $GameOverPanel/UpgradesGrid/StaminaButton
@onready var retry_button: Button = $GameOverPanel/ButtonsRow/RetryButton
@onready var menu_button: Button = $GameOverPanel/ButtonsRow/MenuButton

func _ready() -> void:
	_ensure_nodes()
	
	if stamina_bar:
		stamina_bar.pivot_offset = Vector2(200, 12)
		var fill_box = stamina_bar.get_theme_stylebox("fill")
		if fill_box is StyleBoxFlat:
			stamina_fill_style = fill_box.duplicate()
			stamina_bar.add_theme_stylebox_override("fill", stamina_fill_style)

	if game_over_panel:
		game_over_panel.visible = false
	
	if pause_panel:
		pause_panel.visible = false
	if record_banner:
		record_banner.visible = false

	if pause_button:
		pause_button.focus_mode = Control.FOCUS_NONE
		if not pause_button.pressed.is_connected(_on_pause_pressed):
			pause_button.pressed.connect(_on_pause_pressed)
	var j_btn = get_node_or_null("JumpButton")
	if j_btn: j_btn.focus_mode = Control.FOCUS_NONE
	if shoot_button: shoot_button.focus_mode = Control.FOCUS_NONE
	if resume_button and not resume_button.pressed.is_connected(_on_resume_pressed):
		resume_button.pressed.connect(_on_resume_pressed)
	if pause_menu_button and not pause_menu_button.pressed.is_connected(_on_menu_pressed):
		pause_menu_button.pressed.connect(_on_menu_pressed)

	if retry_button and not retry_button.pressed.is_connected(_on_retry_pressed):
		retry_button.pressed.connect(_on_retry_pressed)
	if menu_button and not menu_button.pressed.is_connected(_on_menu_pressed):
		menu_button.pressed.connect(_on_menu_pressed)
	if speed_button and not speed_button.pressed.is_connected(_on_speed_pressed):
		speed_button.pressed.connect(_on_speed_pressed)
	if aim_button and not aim_button.pressed.is_connected(_on_aim_pressed):
		aim_button.pressed.connect(_on_aim_pressed)
	if jump_button and not jump_button.pressed.is_connected(_on_jump_pressed):
		jump_button.pressed.connect(_on_jump_pressed)
	if stamina_button and not stamina_button.pressed.is_connected(_on_stamina_pressed):
		stamina_button.pressed.connect(_on_stamina_pressed)
	
	update_coins(GameManager.coins)

func _ensure_nodes() -> void:
	if not stamina_bar:
		stamina_bar = get_node_or_null("StaminaBar")
	if not distance_label:
		distance_label = get_node_or_null("DistanceLabel")
	if not coin_label:
		coin_label = find_child("CoinLabel", true, false)
	if not pause_button:
		pause_button = get_node_or_null("PauseButton")
	if not pause_panel:
		pause_panel = get_node_or_null("PausePanel")
	if pause_panel:
		if not resume_button:
			resume_button = pause_panel.get_node_or_null("PauseButtons/ResumeButton")
		if not pause_menu_button:
			pause_menu_button = pause_panel.get_node_or_null("PauseButtons/PauseMenuButton")
	if not record_banner:
		record_banner = get_node_or_null("RecordBanner")
	if not combo_container:
		combo_container = get_node_or_null("ComboContainer")
	if not combo_label:
		if combo_container:
			combo_label = combo_container.get_node_or_null("ComboLabel")
		else:
			combo_label = get_node_or_null("ComboLabel")
	if not impact_flash:
		impact_flash = get_node_or_null("ImpactFlash")
	if not fire_border:
		fire_border = get_node_or_null("FireBorder")
	if not shoot_button:
		shoot_button = get_node_or_null("ShootButton")
	if not game_over_panel:
		game_over_panel = get_node_or_null("GameOverPanel")
	if game_over_panel:
		if not game_over_label:
			game_over_label = game_over_panel.get_node_or_null("GameOver")
		if not game_over_coin_label:
			game_over_coin_label = game_over_panel.get_node_or_null("GameOverCoinContainer/GameOverCoinLabel")
		if not stats_label:
			stats_label = game_over_panel.get_node_or_null("StatsLabel")
		if not speed_button:
			speed_button = game_over_panel.get_node_or_null("UpgradesGrid/SpeedButton")
			if not speed_button:
				speed_button = game_over_panel.get_node_or_null("UpgradesGrid/PowerButton")
			power_button = speed_button
		if not aim_button:
			aim_button = game_over_panel.get_node_or_null("UpgradesGrid/AimButton")
		if not jump_button:
			jump_button = game_over_panel.get_node_or_null("UpgradesGrid/JumpButton")
		if not stamina_button:
			stamina_button = game_over_panel.get_node_or_null("UpgradesGrid/StaminaButton")
		if not retry_button:
			retry_button = game_over_panel.get_node_or_null("ButtonsRow/RetryButton")
		if not menu_button:
			menu_button = game_over_panel.get_node_or_null("ButtonsRow/MenuButton")

func _process(delta: float) -> void:
	if damage_flash_timer > 0.0:
		damage_flash_timer -= delta
		if stamina_fill_style:
			stamina_fill_style.bg_color = COLOR_DAMAGE_FLASH
		if damage_flash_timer <= 0.0:
			update_stamina_color()

func update_stamina(value: float, max_val: float = -1.0) -> void:
	_ensure_nodes()
	if stamina_bar:
		if max_val > 0.0:
			stamina_bar.max_value = max_val
		stamina_bar.value = value
		if damage_flash_timer <= 0.0:
			update_stamina_color()

func update_stamina_color() -> void:
	if not stamina_bar or not stamina_fill_style:
		return
	var pct: float = stamina_bar.value / max(stamina_bar.max_value, 1.0)
	if pct > 0.50:
		stamina_fill_style.bg_color = COLOR_STAMINA_GREEN
	elif pct > 0.15:
		stamina_fill_style.bg_color = COLOR_STAMINA_YELLOW
	else:
		stamina_fill_style.bg_color = COLOR_STAMINA_RED

func flash_stamina_damage(duration: float = 0.5) -> void:
	damage_flash_timer = duration
	if stamina_fill_style:
		stamina_fill_style.bg_color = COLOR_DAMAGE_FLASH
	if stamina_bar:
		var tween = create_tween()
		tween.tween_property(stamina_bar, "scale", Vector2(1.04, 1.16), 0.08).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(stamina_bar, "scale", Vector2(1.0, 1.0), 0.14)

func flash_stamina_heal(duration: float = 0.4) -> void:
	if stamina_fill_style:
		stamina_fill_style.bg_color = Color(0.18, 1.0, 0.45)
	if stamina_bar:
		var tween = create_tween()
		tween.tween_property(stamina_bar, "scale", Vector2(1.06, 1.20), 0.09).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
		tween.tween_property(stamina_bar, "scale", Vector2(1.0, 1.0), 0.15)

func update_distance(distance_meters: int) -> void:
	_ensure_nodes()
	if distance_label:
		distance_label.text = str(distance_meters) + " m"

func update_coins(total_coins: int) -> void:
	_ensure_nodes()
	if coin_label:
		coin_label.text = str(total_coins)

func trigger_impact_flash(color: Color = Color(1.0, 0.88, 0.35, 0.35)) -> void:
	_ensure_nodes()
	if not impact_flash:
		return
	impact_flash.color = color
	var tween = create_tween()
	tween.tween_property(impact_flash, "color:a", 0.0, 0.22).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)

func set_dunk_mode(active: bool) -> void:
	_ensure_nodes()
	if not shoot_button:
		return
	if active:
		shoot_button.text = "💥 DUNK!"
		shoot_button.modulate = Color(1.0, 0.35, 0.2)
	else:
		shoot_button.text = "TIRO 🎯"
		shoot_button.modulate = Color(1.0, 1.0, 1.0)

func update_combo(combo_count: int, is_on_fire: bool) -> void:
	_ensure_nodes()
	
	if fire_border:
		fire_border.visible = is_on_fire and combo_count >= 2
			
	var target_display: CanvasItem = combo_container if combo_container else combo_label
	if not target_display:
		return
		
	if is_on_fire and combo_count >= 1:
		if not target_display.visible:
			trigger_impact_flash(Color(1.0, 0.45, 0.1, 0.35))
		target_display.visible = true
		
		var mult: int = clamp(combo_count, 1, 5)
		if combo_label:
			if combo_count == 1:
				combo_label.text = "🎯 STREAK: 1 (x1 🪙)"
			elif mult < 5:
				combo_label.text = "🔥 ON FIRE! " + str(combo_count) + " CANESTRI (x" + str(mult) + " 🪙)"
			else:
				combo_label.text = "🔥🔥 MAX FIRE! " + str(combo_count) + " STREAK (x5 🪙 MAX!)"
				
		var tween = create_tween()
		tween.tween_property(target_display, "scale", Vector2(1.22, 1.22), 0.08)
		tween.tween_property(target_display, "scale", Vector2(1.0, 1.0), 0.14)
	else:
		target_display.visible = false

func show_new_record_banner(distance: int) -> void:
	_ensure_nodes()
	if not record_banner:
		return
	GameManager.vibrate_double()
	trigger_impact_flash(Color(1.0, 0.9, 0.2, 0.4))
	record_banner.text = "🏆 NUOVO RECORD: " + str(distance) + " m! 🏆"
	record_banner.visible = true
	record_banner.modulate.a = 1.0
	record_banner.scale = Vector2(0.7, 0.7)
	
	var tween = create_tween()
	tween.tween_property(record_banner, "scale", Vector2(1.15, 1.15), 0.25).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(record_banner, "scale", Vector2(1.0, 1.0), 0.2)
	tween.tween_interval(1.8)
	tween.tween_property(record_banner, "modulate:a", 0.0, 0.6)
	tween.tween_callback(func(): record_banner.visible = false)

func show_game_over(final_distance: int, stats: Dictionary = {}) -> void:
	_ensure_nodes()
	if game_over_panel:
		game_over_panel.visible = true
	if game_over_label:
		game_over_label.text = "GAME OVER!"
		
	if game_over_coin_label:
		game_over_coin_label.text = str(GameManager.coins)
	
	if stats_label:
		var shots_taken = stats.get("shots_taken", 0)
		var shots_scored = stats.get("shots_scored", 0)
		var swishes = stats.get("perfect_swishes", 0)
		var coins_earned = stats.get("coins_earned", 0)
		var accuracy = int((float(shots_scored) / float(max(1, shots_taken))) * 100.0) if shots_taken > 0 else 0
		
		var stats_text = "[center]Metri: " + str(final_distance) + " m | Record: " + str(GameManager.high_score) + " m\n"
		stats_text += "Canestri: " + str(shots_scored) + "/" + str(shots_taken) + " (" + str(accuracy) + "%) | Swish: " + str(swishes) + " | Monete: +" + str(coins_earned) + " [img=16]res://assets/coin.svg[/img][/center]"
		
		if "text" in stats_label:
			stats_label.text = stats_text
		
	refresh_upgrade_buttons()

func _on_pause_pressed() -> void:
	_ensure_nodes()
	get_tree().paused = true
	if pause_panel:
		pause_panel.visible = true

func _on_resume_pressed() -> void:
	_ensure_nodes()
	get_tree().paused = false
	if pause_panel:
		pause_panel.visible = false

func refresh_upgrade_buttons() -> void:
	_ensure_nodes()
	if speed_button:
		var sp_cost = GameManager.get_speed_upgrade_cost()
		if sp_cost == -1:
			speed_button.text = "VELOCITA' (Lv. 10/10) - MAX"
			speed_button.icon = null
			speed_button.disabled = true
		else:
			speed_button.text = "VELOCITA' (Lv. " + str(GameManager.speed_level) + "/10) - " + str(sp_cost)
			speed_button.icon = COIN_ICON
			speed_button.disabled = (GameManager.coins < sp_cost)
	
	if aim_button:
		var a_cost = GameManager.get_aim_upgrade_cost()
		if a_cost == -1:
			aim_button.text = "MIRINO (Lv. 10/10) - MAX"
			aim_button.icon = null
			aim_button.disabled = true
		else:
			aim_button.text = "MIRINO (Lv. " + str(GameManager.aim_level) + "/10) - " + str(a_cost)
			aim_button.icon = COIN_ICON
			aim_button.disabled = (GameManager.coins < a_cost)

	if jump_button:
		var j_cost = GameManager.get_jump_upgrade_cost()
		if j_cost == -1:
			jump_button.text = "SALTO (Lv. 10/10) - MAX"
			jump_button.icon = null
			jump_button.disabled = true
		else:
			jump_button.text = "SALTO (Lv. " + str(GameManager.jump_level) + "/10) - " + str(j_cost)
			jump_button.icon = COIN_ICON
			jump_button.disabled = (GameManager.coins < j_cost)

	if stamina_button:
		var s_cost = GameManager.get_stamina_upgrade_cost()
		if s_cost == -1:
			stamina_button.text = "STAMINA (Lv. 10/10) - MAX"
			stamina_button.icon = null
			stamina_button.disabled = true
		else:
			stamina_button.text = "STAMINA (Lv. " + str(GameManager.stamina_level) + "/10) - " + str(s_cost)
			stamina_button.icon = COIN_ICON
			stamina_button.disabled = (GameManager.coins < s_cost)

func _on_speed_pressed() -> void:
	if GameManager.upgrade_speed():
		update_coins(GameManager.coins)
		if game_over_coin_label:
			game_over_coin_label.text = str(GameManager.coins)
		refresh_upgrade_buttons()

func _on_power_pressed() -> void:
	_on_speed_pressed()

func _on_aim_pressed() -> void:
	if GameManager.upgrade_aim():
		update_coins(GameManager.coins)
		if game_over_coin_label:
			game_over_coin_label.text = str(GameManager.coins)
		refresh_upgrade_buttons()

func _on_jump_pressed() -> void:
	if GameManager.upgrade_jump():
		update_coins(GameManager.coins)
		if game_over_coin_label:
			game_over_coin_label.text = str(GameManager.coins)
		refresh_upgrade_buttons()

func _on_stamina_pressed() -> void:
	if GameManager.upgrade_stamina():
		update_coins(GameManager.coins)
		if game_over_coin_label:
			game_over_coin_label.text = str(GameManager.coins)
		refresh_upgrade_buttons()

func _on_retry_pressed() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()

func _on_menu_pressed() -> void:
	get_tree().paused = false
	Engine.time_scale = 1.0
	get_tree().change_scene_to_file("res://scenes/main_menu.tscn")
