extends CanvasLayer

@onready var stamina_bar: ProgressBar = $StaminaBar
@onready var distance_label: Label = $DistanceLabel
@onready var game_over_panel: Panel = $GameOverPanel
@onready var retry_button: Button = $GameOverPanel/RetryButton

func _ready() -> void:
	if not game_over_panel:
		game_over_panel = get_node_or_null("GameOverPanel")
	if not retry_button:
		retry_button = get_node_or_null("GameOverPanel/RetryButton")
		
	if game_over_panel:
		game_over_panel.visible = false
	if retry_button and not retry_button.pressed.is_connected(_on_retry_pressed):
		retry_button.pressed.connect(_on_retry_pressed)

func update_stamina(value: float) -> void:
	if not stamina_bar:
		stamina_bar = get_node_or_null("StaminaBar")
	if stamina_bar:
		stamina_bar.value = value

func update_distance(distance_meters: int) -> void:
	if not distance_label:
		distance_label = get_node_or_null("DistanceLabel")
	if distance_label:
		distance_label.text = str(distance_meters) + " m"

func show_game_over(final_distance: int) -> void:
	if not game_over_panel:
		game_over_panel = get_node_or_null("GameOverPanel")
	if game_over_panel:
		game_over_panel.visible = true
		var label = game_over_panel.get_node_or_null("GameOver")
		if label:
			label.text = "GAME OVER!\nMetri percorsi: " + str(final_distance) + " m"

func _on_retry_pressed() -> void:
	Engine.time_scale = 1.0
	get_tree().reload_current_scene()
