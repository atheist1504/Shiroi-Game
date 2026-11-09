extends CanvasLayer

@onready var health_bar: ProgressBar = $StatusContainer/HealthContainer/HealthBar
@onready var health_label: Label = $StatusContainer/HealthContainer/HealthLabel

@onready var stamina_bar: ProgressBar = $StatusContainer/StaminaContainer/StaminaBar
@onready var stamina_label: Label = $StatusContainer/StaminaContainer/StaminaLabel

@onready var energy_bar: ProgressBar = $StatusContainer/EnergyContainer/EnergyBar
@onready var energy_label: Label = $StatusContainer/EnergyContainer/EnergyLabel

@onready var slot_e_cd: Label = $SkillContainer/SlotE/CooldownLabel
@onready var slot_e_overlay: ColorRect = $SkillContainer/SlotE/CooldownOverlay

@onready var slot_r_cd: Label = $SkillContainer/SlotR/CooldownLabel
@onready var slot_r_overlay: ColorRect = $SkillContainer/SlotR/CooldownOverlay
@onready var slot_r_cost: Label = $SkillContainer/SlotR/VBox/CostLabel
@onready var slot_r_panel: PanelContainer = $SkillContainer/SlotR

@onready var slot_e_key: Label = $SkillContainer/SlotE/VBox/KeyLabel
@onready var slot_e_desc: Label = $SkillContainer/SlotE/VBox/DescLabel
@onready var slot_r_key: Label = $SkillContainer/SlotR/VBox/KeyLabel

@onready var feedback_label: Label = $SkillFeedbackLabel

@onready var game_over_panel: PanelContainer = $GameOverPanel
@onready var retry_button: Button = $GameOverPanel/VBoxContainer/RetryButton

const RESPAWN_POSITION: Vector2 = Vector2(640, 360)

var feedback_tween: Tween = null
var current_energy_cache: float = 0.0

func _ready() -> void:
	if game_over_panel:
		game_over_panel.visible = false

	if feedback_label:
		feedback_label.modulate.a = 0.0

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

		# Kết nối SkillComponent
		var skill_comp: Node = player.get_node_or_null("SkillComponent")
		if skill_comp:
			if skill_comp.has_signal("energy_changed"):
				skill_comp.energy_changed.connect(_on_energy_changed)
				_on_energy_changed(skill_comp.current_energy, skill_comp.max_energy)
			if skill_comp.has_signal("cooldown_changed"):
				skill_comp.cooldown_changed.connect(_on_cooldown_changed)
			if skill_comp.has_signal("skill_feedback"):
				skill_comp.skill_feedback.connect(_show_skill_feedback)
			if skill_comp.has_signal("kit_changed"):
				skill_comp.kit_changed.connect(_on_kit_changed)
				_on_kit_changed(skill_comp.e_skill_name, skill_comp.r_skill_name, skill_comp.e_damage)

func _process(_delta: float) -> void:
	# Cập nhật hiển thị đếm ngược thời gian hồi chiêu
	var player: Node = get_parent().get_node_or_null("Player")
	if not player:
		player = get_tree().get_first_node_in_group("player")
	if not player:
		return

	# F9 sau khi chết cũng phải đóng bảng thua.
	if game_over_panel and game_over_panel.visible and not bool(player.get("is_dead")):
		game_over_panel.visible = false

	var skill_comp: Node = player.get_node_or_null("SkillComponent")
	if not skill_comp:
		return

	# Cập nhật E
	var e_cd_var = skill_comp.get("e_cooldown_timer")
	var e_cd: float = float(e_cd_var) if e_cd_var != null else 0.0
	if e_cd > 0.0:
		if slot_e_cd:
			slot_e_cd.text = "%.1fs" % e_cd
			slot_e_cd.visible = true
		if slot_e_overlay:
			slot_e_overlay.visible = true
	else:
		if slot_e_cd:
			slot_e_cd.visible = false
		if slot_e_overlay:
			slot_e_overlay.visible = false

	# Cập nhật R
	var r_cd_var = skill_comp.get("r_cooldown_timer")
	var r_cd: float = float(r_cd_var) if r_cd_var != null else 0.0
	var energy_var = skill_comp.get("current_energy")
	var energy: float = float(energy_var) if energy_var != null else 0.0
	var cost_var = skill_comp.get("r_energy_cost")
	var cost: float = float(cost_var) if cost_var != null else 100.0

	if r_cd > 0.0:
		if slot_r_cd:
			slot_r_cd.text = "%.1fs" % r_cd
			slot_r_cd.visible = true
		if slot_r_overlay:
			slot_r_overlay.visible = true
	else:
		if slot_r_cd:
			slot_r_cd.visible = false
		if slot_r_overlay:
			slot_r_overlay.visible = (energy < cost) # Mờ đi nếu chưa đủ 100 NL

	# Đổi màu nhãn 100 NL khi sẵn sàng
	if slot_r_cost:
		if energy >= cost and r_cd <= 0.0:
			slot_r_cost.add_theme_color_override("font_color", Color(0.3, 1.0, 0.85, 1.0))
			slot_r_cost.text = "SẴN SÀNG"
		else:
			slot_r_cost.add_theme_color_override("font_color", Color(0.8, 0.8, 0.85, 0.7))
			slot_r_cost.text = "100 NL"

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

func _on_energy_changed(current: float, maximum: float) -> void:
	current_energy_cache = current
	if energy_bar:
		energy_bar.max_value = maximum
		energy_bar.value = current
	if energy_label:
		energy_label.text = "Năng lượng: %d / %d" % [roundi(current), roundi(maximum)]

func _on_cooldown_changed(skill_name: String, remaining: float, _total: float) -> void:
	if skill_name == "E":
		if slot_e_cd:
			slot_e_cd.visible = (remaining > 0.0)
			if remaining > 0.0:
				slot_e_cd.text = "%.1fs" % remaining
		if slot_e_overlay:
			slot_e_overlay.visible = (remaining > 0.0)
	elif skill_name == "R":
		if slot_r_cd:
			slot_r_cd.visible = (remaining > 0.0)
			if remaining > 0.0:
				slot_r_cd.text = "%.1fs" % remaining
		if slot_r_overlay:
			slot_r_overlay.visible = (remaining > 0.0 or current_energy_cache < 100.0)

func _on_kit_changed(e_name: String, r_name: String, e_damage_value: float) -> void:
	slot_e_key.text = "[ E ] %s" % e_name
	slot_e_desc.text = "%d ST (5s)" % roundi(e_damage_value)
	slot_r_key.text = "[ R ] %s" % r_name

# Hiển thị thông báo phản hồi khi kỹ năng chưa sẵn sàng hoặc thiếu năng lượng
func _show_skill_feedback(msg: String) -> void:
	if not feedback_label:
		return

	feedback_label.text = msg
	if feedback_tween and feedback_tween.is_valid():
		feedback_tween.kill()

	feedback_label.modulate.a = 1.0
	feedback_tween = create_tween()
	feedback_tween.tween_interval(0.8)
	feedback_tween.tween_property(feedback_label, "modulate:a", 0.0, 0.4)

func _on_player_died() -> void:
	if game_over_panel:
		game_over_panel.visible = true

func _on_retry_button_pressed() -> void:
	# Không tải lại scene: công trình và thợ là node trong scene, tải lại sẽ mất cả căn cứ.
	var player: Node = get_parent().get_node_or_null("Player")
	if player and player.has_method("respawn_at"):
		player.call("respawn_at", RESPAWN_POSITION)
	if game_over_panel:
		game_over_panel.visible = false
