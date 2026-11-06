extends CanvasLayer

@onready var health_bar: ProgressBar = $StatusContainer/HealthContainer/HealthBar
@onready var health_label: Label = $StatusContainer/HealthContainer/HealthLabel

@onready var stamina_bar: ProgressBar = $StatusContainer/StaminaContainer/StaminaBar
@onready var stamina_label: Label = $StatusContainer/StaminaContainer/StaminaLabel

@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var retry_button: Button = $GameOverPanel/VBoxContainer/RetryButton

func _ready() -> void:
	if game_over_panel:
		game_over_panel.visible = false

	if retry_button:
		retry_button.pressed.connect(_on_retry_button_pressed)

	var player: Node = get_parent().get_node_or_null("Player")
	if not player:
		player = get_tree().get_first_node_in_group("player")

	if player:
		if player.has_signal("health_changed"):
			player.health_changed.connect(_on_player_health_changed)
			_on_player_health_changed(player.current_health, player.max_health)
		if player.has_signal("stamina_changed"):
			player.stamina_changed.connect(_on_player_stamina_changed)
			_on_player_stamina_changed(player.stamina, player.max_stamina)
		if player.has_signal("player_died"):
			player.player_died.connect(_on_player_died)

func _on_player_health_changed(current: float, maximum: float) -> void:
	if health_bar:
		health_bar.max_value = maximum
		health_bar.value = current
	if health_label:
		health_label.text = "Máu: %d / %d" % [roundi(current), roundi(maximum)]

func _on_player_stamina_changed(current: float, maximum: float) -> void:
	if stamina_bar:
		stamina_bar.max_value = maximum
		stamina_bar.value = current
	if stamina_label:
		stamina_label.text = "Thể lực: %d / %d" % [roundi(current), roundi(maximum)]

func _on_player_died() -> void:
	if game_over_panel:
		game_over_panel.visible = true

func _on_retry_button_pressed() -> void:
	get_tree().reload_current_scene()
