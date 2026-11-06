extends CanvasLayer

@onready var stamina_bar: ProgressBar = $StaminaContainer/StaminaBar
@onready var stamina_label: Label = $StaminaContainer/StaminaLabel

func _ready() -> void:
	# Tìm Player trong scene để lắng nghe sự thay đổi thể lực
	var player := get_parent().get_node_or_null("Player")
	if player and player.has_signal("stamina_changed"):
		player.stamina_changed.connect(_on_player_stamina_changed)
		_on_player_stamina_changed(player.stamina, player.max_stamina)

func _on_player_stamina_changed(current: float, maximum: float) -> void:
	if stamina_bar:
		stamina_bar.max_value = maximum
		stamina_bar.value = current
	if stamina_label:
		stamina_label.text = "Thể lực: %d / %d" % [roundi(current), roundi(maximum)]
