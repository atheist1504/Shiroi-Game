extends Node

# Màn đêm đầu (nhiệm vụ "Sống sót đến sáng"), thiết kế ở docs/NHIEM_VU.md.
# Trước khi tối: trời chạng vạng, tập phím trên cọc gỗ (đi, chạy, lướt, chém,
# E, R). Tập xong nhấn Enter khi sẵn sàng thì màn đêm buông, bầy sói 3 con và
# Sói Đầu Đàn xuất hiện ngay trong vùng sáng quanh nhân vật, rớt răng nanh,
# hướng dẫn F để nhặt. Slime và Thủ Lĩnh Slime chỉ ra sau khi trời sáng.
# Sói và cọc không được lưu: tải save giữa chừng thì làm lại từ bước đang dở
# (đang tập thì tập lại từ đầu, đã vào đêm thì quay về bước Sẵn sàng).

signal stage_changed(stage: int)
signal night_finished

enum Stage { IDLE, MOVE, SWORD, SKILL_E, SKILL_R, READY, PACK, LOOT, ENDING, DONE }
enum SkyMode { DAY, DUSK, NIGHT }

const QUEST_ID: StringName = &"sys_00_first_night"
const QUEST_COMPLETED: int = 4
const WOLF_REGION: StringName = &"first_night"
const DAY_ONLY_REGION: StringName = &"forest_clearing"
const FANG_ID: StringName = &"wolf_fang"
const ENEMY_SCENE: PackedScene = preload("res://slime.tscn")
const DUMMY_SCRIPT: Script = preload("res://scripts/training_dummy.gd")
const NIGHT_COLOR := Color(0.06, 0.07, 0.13)
const DUSK_COLOR := Color(0.95, 0.85, 0.8)
const LIGHT_RADIUS: float = 150.0
const SYSTEM_COLOR := Color(0.45, 0.95, 0.85)
const MAP_MIN := Vector2(48, 48)
const MAP_MAX := Vector2(2512, 1392)
const DUMMY_OFFSET := Vector2(60, 0)
# Bầy sói đứng trong vùng sáng (LIGHT_RADIUS) để người chơi thấy ngay.
const PACK_DISTANCE: float = 90.0
const R_COOLDOWN_CAP: float = 3.0
const LOOT_TIMEOUT: float = 20.0
const REWARD_MESSAGE := "[HỆ THỐNG]\nHoàn thành nhiệm vụ. Nhận 10 Tinh Vẫn."

# Bước tập trên cọc: chiêu cần dùng và số lần trúng.
const HIT_GOALS: Dictionary = {
	Stage.SWORD: ["Sword", 3],
	Stage.SKILL_E: ["E", 1],
	Stage.SKILL_R: ["R", 1],
}

var stage: int = Stage.IDLE
var _hits: int = 0
var _dodged: bool = false
var _sprint_time: float = 0.0
var _fang_collected: bool = false
var _fang_hint_shown: bool = false
var _loot_time: float = 0.0
var _spawn_counter: int = 0
var _dummy: Node2D
var _pack: Array[Node2D] = []
var _player: CharacterBody2D
var _skill: Node
var _narrative: Node
var _canvas_modulate: CanvasModulate
var _light: PointLight2D
var _ui: CanvasLayer
var _title_label: Label
var _hint_label: Label
var _message_timer: SceneTreeTimer
var _wrong_method: String = ""

func _ready() -> void:
	_player = get_parent().get_node_or_null("Player") as CharacterBody2D
	_skill = _player.get_node_or_null("SkillComponent") if _player else null
	if _skill:
		_skill.skill_hit.connect(_on_skill_hit)
	_narrative = get_parent().get_node_or_null("NarrativeUI")
	if _narrative and _narrative.has_signal("sequence_finished"):
		_narrative.sequence_finished.connect(_on_narrative_finished)
	get_node("/root/EventBus").item_collected.connect(_on_item_collected)
	get_node("/root/SaveManager").load_completed.connect(_on_load_completed)
	_build_ui()
	# Màn bắt đầu (title_menu.gd) gọi start_if_needed() khi người chơi chọn
	# Chơi mới hoặc Tiếp tục; kiểm thử headless tự gọi.

func is_night_done() -> bool:
	return int(get_node("/root/QuestManager").get_quest_status(QUEST_ID)) == QUEST_COMPLETED

func is_night_active() -> bool:
	return stage != Stage.IDLE and stage != Stage.DONE

func is_practicing() -> bool:
	return stage >= Stage.MOVE and stage <= Stage.READY

func start_if_needed() -> bool:
	if is_night_done():
		_apply_day()
		return false
	_begin_night()
	return true

# Bỏ qua đêm đầu (kiểm thử, gỡ lỗi): trả nhiệm vụ, không chiếu màn chữ.
func skip_night() -> void:
	_clear_wolves()
	_complete_quest()
	_apply_day()

func get_dummy() -> Node2D:
	return _dummy if is_instance_valid(_dummy) else null

func get_pack() -> Array[Node2D]:
	var result: Array[Node2D] = []
	for wolf in _pack:
		if is_instance_valid(wolf) and not wolf.get("is_dead"):
			result.append(wolf)
	return result

func get_hit_count() -> int:
	return _hits

func _begin_night(from_stage: int = Stage.MOVE) -> void:
	_clear_wolves()
	_set_day_enemies_visible(false)
	_dodged = false
	_sprint_time = 0.0
	_fang_collected = false
	_fang_hint_shown = false
	_loot_time = 0.0
	_ui.visible = true
	_set_stage(from_stage)

func _set_stage(new_stage: int) -> void:
	stage = new_stage
	_hits = 0
	_wrong_method = ""
	if is_practicing():
		_set_sky(SkyMode.DUSK)
		if new_stage != Stage.MOVE:
			_ensure_dummy()
	match new_stage:
		Stage.SKILL_R:
			if _skill:
				_skill.add_energy(float(_skill.get("max_energy")))
				_cap_r_cooldown(0.0)
		Stage.PACK:
			_clear_wolves()
			_set_sky(SkyMode.NIGHT)
			_spawn_pack()
		Stage.LOOT:
			_loot_time = 0.0
	_update_hint()
	stage_changed.emit(new_stage)

# Đã tập xong và sẵn sàng: màn đêm buông, bầy sói tới.
func start_darkness() -> bool:
	if stage != Stage.READY:
		return false
	_set_stage(Stage.PACK)
	return true

func _unhandled_input(event: InputEvent) -> void:
	if stage != Stage.READY or get_tree().paused:
		return
	var key := event as InputEventKey
	if key and key.pressed and not key.echo and key.physical_keycode in [KEY_ENTER, KEY_KP_ENTER] and not key.alt_pressed:
		start_darkness()
		get_viewport().set_input_as_handled()

func _physics_process(delta: float) -> void:
	if not _player:
		return
	match stage:
		Stage.MOVE:
			if bool(_player.get("is_dodging")):
				_dodged = true
			if _player.velocity.length() > float(_player.get("walk_speed")) + 5.0:
				_sprint_time += delta
			_update_hint()
			if _dodged and _sprint_time >= 0.4:
				_set_stage(Stage.SWORD)
		Stage.SKILL_R, Stage.READY:
			if _skill:
				if float(_skill.get("current_energy")) < float(_skill.get("r_energy_cost")):
					_skill.add_energy(float(_skill.get("r_energy_cost")))
				_cap_r_cooldown(R_COOLDOWN_CAP)
		Stage.PACK:
			if get_pack().is_empty():
				_set_stage(Stage.LOOT)
		Stage.LOOT:
			_loot_time += delta
			# Đồ rơi được thêm vào scene trễ một nhịp nên chờ chút mới coi là không có.
			if _fang_collected or (_loot_time > 0.3 and not _fang_on_ground()) or _loot_time >= LOOT_TIMEOUT:
				_finish_night()

func _cap_r_cooldown(cap: float) -> void:
	if float(_skill.get("r_cooldown_timer")) > cap:
		_skill.set("r_cooldown_timer", cap)
		_skill.cooldown_changed.emit("R", cap, float(_skill.get("r_cooldown")))

# --- Cọc gỗ ---

func _ensure_dummy() -> void:
	if is_instance_valid(_dummy):
		return
	_dummy = CharacterBody2D.new()
	_dummy.set_script(DUMMY_SCRIPT)
	_dummy.name = "TrainingDummy"
	_dummy.position = (_player.global_position + DUMMY_OFFSET).clamp(MAP_MIN, MAP_MAX)
	get_parent().add_child(_dummy)

func _on_skill_hit(skill_name: String, target: Node2D, _damage: float) -> void:
	if not is_instance_valid(target) or target != _dummy or not HIT_GOALS.has(stage):
		return
	var goal: Array = HIT_GOALS[stage]
	if skill_name != goal[0]:
		_wrong_method = skill_name
		_update_hint()
		return
	_wrong_method = ""
	_hits += 1
	if _hits >= int(goal[1]):
		_set_stage(stage + 1)
	else:
		_update_hint()

# --- Sói ---

func _spawn_pack() -> void:
	var side := Vector2.from_angle(randf() * TAU)
	var center := _player.global_position + side * PACK_DISTANCE
	for i in 3:
		var wolf := _spawn_wolf(&"wolf", center + side.orthogonal() * (i - 1) * 40.0)
		wolf.set("max_health", 50.0)
		wolf.set("move_speed", 72.0)
		wolf.set("attack_damage", 7.0)
		wolf.set("aggro_range", 420.0)
		wolf.set("drop_item_id", FANG_ID)
		wolf.set("drop_item_chance", 0.6)
		wolf.set("COLOR_NORMAL", Color(0.48, 0.48, 0.54))
		wolf.set("SCALE_NORMAL", Vector2(0.24, 0.19))
		_add_wolf(wolf)
		_pack.append(wolf)
	var alpha := _spawn_wolf(&"wolf_alpha", center + side * 30.0)
	alpha.set("max_health", 220.0)
	alpha.set("move_speed", 66.0)
	alpha.set("attack_damage", 13.0)
	alpha.set("attack_cooldown", 1.6)
	alpha.set("aggro_range", 420.0)
	alpha.set("attack_range", 50.0)
	alpha.set("stop_distance", 36.0)
	alpha.set("hit_radius", 52.0)
	alpha.set("drop_item_id", FANG_ID)
	alpha.set("drop_item_chance", 1.0)
	alpha.set("drop_item_amount", 2)
	alpha.set("COLOR_NORMAL", Color(0.32, 0.32, 0.42))
	alpha.set("SCALE_NORMAL", Vector2(0.36, 0.29))
	_add_wolf(alpha)
	_pack.append(alpha)
	for wolf in _pack:
		wolf.died.connect(_on_pack_wolf_died)

func _spawn_wolf(enemy_id: StringName, at: Vector2) -> Node2D:
	_spawn_counter += 1
	var wolf := ENEMY_SCENE.instantiate() as Node2D
	wolf.name = "FirstNight_%s_%d" % [enemy_id, _spawn_counter]
	wolf.set("enemy_id", enemy_id)
	wolf.set("region_id", WOLF_REGION)
	wolf.set("persistent_id", StringName("first_night_%d" % _spawn_counter))
	wolf.set("is_runtime_spawn", true)
	wolf.set("gel_drop_chance", 0.0)
	wolf.set("crystal_drop_chance", 0.0)
	wolf.position = at.clamp(MAP_MIN, MAP_MAX)
	wolf.add_to_group("no_save")
	wolf.add_to_group("first_night_wolves")
	return wolf

func _add_wolf(wolf: Node2D) -> void:
	get_parent().add_child(wolf)

# Xóa sói và cọc gỗ (cọc cũng ở nhóm first_night_wolves).
func _clear_wolves() -> void:
	for wolf in get_tree().get_nodes_in_group("first_night_wolves"):
		wolf.queue_free()
	_dummy = null
	_pack.clear()

func _on_pack_wolf_died() -> void:
	_check_fang_hint.call_deferred()
	_update_hint.call_deferred()

func _check_fang_hint() -> void:
	if not _fang_hint_shown and _fang_on_ground():
		_fang_hint_shown = true
		_update_hint()

func _fang_on_ground() -> bool:
	for pickup in get_tree().get_nodes_in_group("pickup_items"):
		if pickup.get("item_id") == FANG_ID and not pickup.get("is_being_picked"):
			return true
	return false

func _on_item_collected(item_id: StringName, _amount: int) -> void:
	if item_id == FANG_ID and is_night_active():
		_fang_collected = true

# --- Kết thúc đêm ---

func _finish_night() -> void:
	stage = Stage.ENDING
	_complete_quest()
	_apply_day()
	stage = Stage.ENDING
	if _narrative and _narrative.has_method("play"):
		_narrative.play(_narrative.FIRST_NIGHT_END_PAGES)
	else:
		_on_narrative_finished([])

func _on_narrative_finished(pages: Array[Dictionary]) -> void:
	if stage != Stage.ENDING:
		return
	if _narrative and pages != _narrative.FIRST_NIGHT_END_PAGES and not pages.is_empty():
		return
	stage = Stage.DONE
	_show_message(REWARD_MESSAGE, 5.0)
	night_finished.emit()

func _complete_quest() -> void:
	var quests := get_node("/root/QuestManager")
	if is_night_done():
		return
	quests.report_objective("first_night")
	quests.complete_quest(QUEST_ID)

func _apply_day() -> void:
	_clear_wolves()
	_set_sky(SkyMode.DAY)
	_set_day_enemies_visible(true)
	stage = Stage.DONE
	_ui.visible = false

func _set_day_enemies_visible(show: bool) -> void:
	var group := "night_hidden" if show else "enemies"
	for node in get_tree().get_nodes_in_group(group):
		var enemy := node as Node2D
		if not enemy or enemy.get("region_id") != DAY_ONLY_REGION or enemy.is_in_group("first_night_wolves"):
			continue
		var dead := bool(enemy.get("is_dead"))
		if show:
			enemy.remove_from_group("night_hidden")
			enemy.add_to_group("enemies")
			enemy.process_mode = Node.PROCESS_MODE_INHERIT
		else:
			enemy.remove_from_group("enemies")
			enemy.add_to_group("night_hidden")
			enemy.process_mode = Node.PROCESS_MODE_DISABLED
		enemy.visible = show and not dead
		var shape := enemy.get_node_or_null("CollisionShape2D") as CollisionShape2D
		if shape:
			shape.set_deferred("disabled", not show or dead)

# Chạng vạng: phủ màu cam nhạt, chưa cần đèn. Đêm: tối hẳn, chỉ sáng quanh nhân vật.
func _set_sky(sky: int) -> void:
	if sky == SkyMode.DAY:
		if is_instance_valid(_canvas_modulate):
			_canvas_modulate.queue_free()
		_canvas_modulate = null
	elif not is_instance_valid(_canvas_modulate):
		_canvas_modulate = CanvasModulate.new()
		_canvas_modulate.name = "NightModulate"
		get_parent().add_child.call_deferred(_canvas_modulate)
	if is_instance_valid(_canvas_modulate):
		_canvas_modulate.color = NIGHT_COLOR if sky == SkyMode.NIGHT else DUSK_COLOR
	if sky == SkyMode.NIGHT:
		if not is_instance_valid(_light) and _player:
			_light = PointLight2D.new()
			_light.name = "NightLight"
			_light.texture = _make_light_texture()
			_light.texture_scale = LIGHT_RADIUS * 2.0 / 256.0
			_light.energy = 1.1
			_light.color = Color(1.0, 0.95, 0.85)
			_player.add_child(_light)
	else:
		if is_instance_valid(_light):
			_light.queue_free()
		_light = null

func is_dark() -> bool:
	return is_instance_valid(_canvas_modulate) and _canvas_modulate.color == NIGHT_COLOR

func is_dusk() -> bool:
	return is_instance_valid(_canvas_modulate) and _canvas_modulate.color == DUSK_COLOR

func _make_light_texture() -> Texture2D:
	var gradient := Gradient.new()
	gradient.set_color(0, Color(1, 1, 1, 1))
	gradient.set_color(1, Color(1, 1, 1, 0))
	gradient.add_point(0.6, Color(1, 1, 1, 0.75))
	var texture := GradientTexture2D.new()
	texture.gradient = gradient
	texture.fill = GradientTexture2D.FILL_RADIAL
	texture.fill_from = Vector2(0.5, 0.5)
	texture.fill_to = Vector2(1.0, 0.5)
	texture.width = 256
	texture.height = 256
	return texture

func _on_load_completed(_slot_id: int, success: bool, _message: String) -> void:
	if not success:
		return
	# SaveManager đã xóa sói (quái tạo lúc chạy, không có trong save).
	if is_night_done():
		_apply_day()
	elif stage != Stage.IDLE:
		_begin_night(Stage.READY if stage >= Stage.READY else Stage.MOVE)

# --- Dòng hướng dẫn ---
# Khung gọn dưới bản đồ nhỏ: một dòng bước, một-hai dòng phím cần bấm.

const METHOD_NAMES: Dictionary = {"Sword": "chuột trái", "E": "E", "R": "R"}
const STEP_COUNT: int = 7
const PANEL_WIDTH: float = 200.0

func _update_hint() -> void:
	if not is_instance_valid(_hint_label):
		return
	var step := 0
	var heading := ""
	var text := ""
	match stage:
		Stage.MOVE:
			step = 1
			heading = "Di chuyển"
			text = "WASD: đi lại\n[%s] Giữ chuột phải: chạy\n[%s] Space: lướt né" % ["x" if _sprint_time >= 0.4 else " ", "x" if _dodged else " "]
		Stage.SWORD:
			step = 2
			heading = "Đánh thường"
			text = "Chuột trái: chém về phía con trỏ.\nChém trúng cọc gỗ (%d/3)" % _hits
		Stage.SKILL_E:
			step = 3
			heading = "Kỹ năng E"
			text = "E: lưỡi gió bay xuyên tới con trỏ.\nBắn trúng cọc (%d/1)" % _hits
		Stage.SKILL_R:
			step = 4
			heading = "Kỹ năng R"
			text = "R: lốc xoáy hút quái tại con trỏ.\nĐặt trỏ lên cọc rồi nhấn R (%d/1)" % _hits
		Stage.READY:
			step = 5
			heading = "Sẵn sàng"
			text = "Đánh cọc thêm tùy ý.\nEnter: vào đêm, bầy sói kéo đến"
		Stage.PACK:
			step = 6
			heading = "Bầy sói"
			text = "Hạ cả bầy (%d/4). Đầu Đàn đánh đau: lướt né." % (_pack.size() - get_pack().size())
			if _fang_hint_shown:
				text += "\nF: nhặt đồ rơi"
		Stage.LOOT:
			step = 7
			heading = "Nhặt đồ"
			text = "Đứng gần răng nanh, F: nhặt\nB: xem túi"
	if not _wrong_method.is_empty() and HIT_GOALS.has(stage):
		text += "\nSai chiêu, bước này cần %s." % METHOD_NAMES[HIT_GOALS[stage][0]]
	_title_label.text = "Bước %d/%d · %s" % [step, STEP_COUNT, heading] if step > 0 else "[HỆ THỐNG]"
	_hint_label.text = text

func _show_message(text: String, seconds: float) -> void:
	_ui.visible = true
	_title_label.text = text
	_hint_label.text = ""
	_message_timer = get_tree().create_timer(seconds, false)
	var timer := _message_timer
	timer.timeout.connect(func() -> void:
		if _message_timer == timer and stage == Stage.DONE:
			_ui.visible = false
	)

func _build_ui() -> void:
	_ui = CanvasLayer.new()
	_ui.name = "FirstNightHint"
	_ui.layer = 20
	_ui.visible = false
	add_child(_ui)
	# Khung nền tối để chữ không lẫn vào bản đồ.
	var panel := PanelContainer.new()
	# Góc trên bên phải, dưới bản đồ nhỏ, tránh thanh máu và năng lượng bên trái.
	panel.set_anchors_preset(Control.PRESET_TOP_RIGHT)
	panel.position = Vector2(-PANEL_WIDTH - 6.0, 112)
	panel.custom_minimum_size = Vector2(PANEL_WIDTH, 0)
	panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.03, 0.04, 0.08, 0.82)
	style.border_color = Color(SYSTEM_COLOR, 0.6)
	style.set_border_width_all(1)
	style.set_corner_radius_all(4)
	style.set_content_margin_all(5)
	panel.add_theme_stylebox_override("panel", style)
	_ui.add_child(panel)
	var box := VBoxContainer.new()
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_theme_constant_override("separation", 3)
	panel.add_child(box)
	_title_label = _make_label(SYSTEM_COLOR, 10)
	_hint_label = _make_label(Color(0.95, 0.96, 1.0), 9)
	box.add_child(_title_label)
	box.add_child(_hint_label)

func _make_label(color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(PANEL_WIDTH - 10.0, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 1.0))
	label.add_theme_constant_override("outline_size", 4)
	return label
