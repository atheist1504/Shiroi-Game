extends Node

# Màn đêm đầu (nhiệm vụ "Sống sót đến sáng"), thiết kế ở docs/NHIEM_VU.md.
# Sói con một đòn là chết để tập điều khiển: lướt và chạy, chém hạ 1, E hạ 2, R hạ 3.
# Sau đó 3 sói và Sói Đầu Đàn kéo đến, rớt răng nanh, hướng dẫn F để nhặt.
# Đêm tối chỉ thấy quanh mình; slime và Thủ Lĩnh Slime chỉ ra sau khi trời sáng.
# Sói không được lưu: tải save giữa đêm thì đêm bắt đầu lại từ đầu.

signal stage_changed(stage: int)
signal night_finished

enum Stage { IDLE, MOVE, SWORD, SKILL_E, SKILL_R, PACK, LOOT, ENDING, DONE }

const QUEST_ID: StringName = &"sys_00_first_night"
const QUEST_COMPLETED: int = 4
const WOLF_REGION: StringName = &"first_night"
const DAY_ONLY_REGION: StringName = &"forest_clearing"
const FANG_ID: StringName = &"wolf_fang"
const ENEMY_SCENE: PackedScene = preload("res://slime.tscn")
const NIGHT_COLOR := Color(0.06, 0.07, 0.13)
const LIGHT_RADIUS: float = 110.0
const SYSTEM_COLOR := Color(0.45, 0.95, 0.85)
const MAP_MIN := Vector2(48, 48)
const MAP_MAX := Vector2(2512, 1392)
const RESPAWN_DELAY: float = 0.8
const R_COOLDOWN_CAP: float = 3.0
const LOOT_TIMEOUT: float = 20.0
const REWARD_MESSAGE := "[HỆ THỐNG]\nHoàn thành nhiệm vụ. Nhận 10 Tinh Vẫn."

# Chặng thử chiêu: cách hạ cần dùng và số sói con phải hạ.
const KILL_GOALS: Dictionary = {
	Stage.SWORD: ["Sword", 1],
	Stage.SKILL_E: ["E", 2],
	Stage.SKILL_R: ["R", 3],
}

var stage: int = Stage.IDLE
var _kills: int = 0
var _dodged: bool = false
var _sprint_time: float = 0.0
var _fang_collected: bool = false
var _fang_hint_shown: bool = false
var _loot_time: float = 0.0
var _spawn_counter: int = 0
var _pups: Array[Node2D] = []
var _pack: Array[Node2D] = []
var _kill_method: Dictionary = {} # instance_id -> "Sword"/"E"/"R"
var _player: CharacterBody2D
var _skill: Node
var _narrative: Node
var _canvas_modulate: CanvasModulate
var _light: PointLight2D
var _ui: CanvasLayer
var _title_label: Label
var _hint_label: Label
var _message_timer: SceneTreeTimer

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
	# Kiểm thử headless tự gọi start_if_needed() để các bài thử cũ không bị đêm che.
	if DisplayServer.get_name() != "headless":
		start_if_needed.call_deferred()

func is_night_done() -> bool:
	return int(get_node("/root/QuestManager").get_quest_status(QUEST_ID)) == QUEST_COMPLETED

func is_night_active() -> bool:
	return stage != Stage.IDLE and stage != Stage.DONE

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

func get_pups() -> Array[Node2D]:
	return _alive(_pups)

func get_pack() -> Array[Node2D]:
	return _alive(_pack)

func _alive(wolves: Array[Node2D]) -> Array[Node2D]:
	var result: Array[Node2D] = []
	for wolf in wolves:
		if is_instance_valid(wolf) and not wolf.get("is_dead"):
			result.append(wolf)
	return result

func get_kill_count() -> int:
	return _kills

func _begin_night() -> void:
	_clear_wolves()
	_set_day_enemies_visible(false)
	_set_darkness(true)
	_dodged = false
	_sprint_time = 0.0
	_fang_collected = false
	_fang_hint_shown = false
	_loot_time = 0.0
	_ui.visible = true
	_set_stage(Stage.MOVE)

func _set_stage(new_stage: int) -> void:
	stage = new_stage
	_kills = 0
	match new_stage:
		Stage.MOVE, Stage.SWORD:
			_ensure_pups(1)
		Stage.SKILL_E:
			_ensure_pups(2)
		Stage.SKILL_R:
			_ensure_pups(3)
			if _skill:
				_skill.add_energy(float(_skill.get("max_energy")))
				_cap_r_cooldown(0.0)
		Stage.PACK:
			_clear_wolves()
			_spawn_pack()
		Stage.LOOT:
			_loot_time = 0.0
	_update_hint()
	stage_changed.emit(new_stage)

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
		Stage.SKILL_R:
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

# --- Sói ---

func _ensure_pups(count: int) -> void:
	var alive := get_pups()
	_pups = alive
	var base_angle := randf() * TAU
	for i in range(alive.size(), count):
		# Xếp gần một hướng để E dễ xuyên qua, R dễ gom.
		var angle := base_angle + (i - count * 0.5) * 0.35
		var pup := _spawn_wolf(&"wolf_pup", _player.global_position + Vector2.from_angle(angle) * (110.0 + i * 18.0))
		pup.set("max_health", 1.0)
		pup.set("move_speed", 50.0)
		pup.set("attack_damage", 3.0)
		pup.set("aggro_range", 320.0)
		pup.set("COLOR_NORMAL", Color(0.66, 0.6, 0.55))
		pup.set("SCALE_NORMAL", Vector2(0.15, 0.12))
		_add_wolf(pup)
		_pups.append(pup)
		pup.died.connect(_on_pup_died.bind(pup))

func _spawn_pack() -> void:
	var side := Vector2.from_angle(randf() * TAU)
	var center := _player.global_position + side * 170.0
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
	var alpha := _spawn_wolf(&"wolf_alpha", center + side * 40.0)
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

func _clear_wolves() -> void:
	for wolf in get_tree().get_nodes_in_group("first_night_wolves"):
		wolf.queue_free()
	_pups.clear()
	_pack.clear()
	_kill_method.clear()

func _on_skill_hit(skill_name: String, target: Node2D, _damage: float) -> void:
	if is_instance_valid(target) and target in _pups and target.get("is_dead") and not _kill_method.has(target.get_instance_id()):
		_kill_method[target.get_instance_id()] = skill_name

# Quái chết trước khi skill_hit phát, nên đợi hết khung hình mới biết bị hạ bằng gì.
func _on_pup_died(pup: Node2D) -> void:
	_resolve_pup_death.call_deferred(pup)

func _resolve_pup_death(pup: Node2D) -> void:
	if not is_instance_valid(pup) or not (pup in _pups):
		return
	var method: String = _kill_method.get(pup.get_instance_id(), "")
	_pups.erase(pup)
	_free_later(pup)
	var goal: Array = KILL_GOALS.get(stage, [])
	if not goal.is_empty() and method == goal[0]:
		_kills += 1
		if _kills >= int(goal[1]):
			_set_stage(stage + 1)
			return
		_update_hint()
		return
	# Hạ sai cách (hoặc lúc đang tập di chuyển): thả sói con khác ra.
	var waiting_stage := stage
	get_tree().create_timer(RESPAWN_DELAY, false).timeout.connect(func() -> void:
		if stage == waiting_stage:
			var needed := 1 if goal.is_empty() else int(goal[1]) - _kills
			_ensure_pups(needed)
	)

func _free_later(node: Node) -> void:
	# Giữ id thay vì tham chiếu: tải save có thể đã xóa node trước khi hẹn giờ chạy.
	var node_id := node.get_instance_id()
	get_tree().create_timer(1.0, false).timeout.connect(func() -> void:
		var target := instance_from_id(node_id) as Node
		if target:
			target.queue_free()
	)

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
	_set_darkness(false)
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

func _set_darkness(on: bool) -> void:
	if on:
		if not is_instance_valid(_canvas_modulate):
			_canvas_modulate = CanvasModulate.new()
			_canvas_modulate.name = "NightModulate"
			get_parent().add_child.call_deferred(_canvas_modulate)
		_canvas_modulate.color = NIGHT_COLOR
		if not is_instance_valid(_light) and _player:
			_light = PointLight2D.new()
			_light.name = "NightLight"
			_light.texture = _make_light_texture()
			_light.texture_scale = LIGHT_RADIUS * 2.0 / 256.0
			_light.energy = 1.1
			_light.color = Color(1.0, 0.95, 0.85)
			_player.add_child(_light)
	else:
		if is_instance_valid(_canvas_modulate):
			_canvas_modulate.queue_free()
		if is_instance_valid(_light):
			_light.queue_free()
		_canvas_modulate = null
		_light = null

func is_dark() -> bool:
	return is_instance_valid(_canvas_modulate)

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
		_begin_night()

# --- Dòng hướng dẫn ---

func _update_hint() -> void:
	if not is_instance_valid(_hint_label):
		return
	var text := ""
	match stage:
		Stage.MOVE:
			text = "Một con sói con đang tới.\nSpace: lướt né [%s]    Giữ chuột phải khi đi: chạy [%s]" % ["x" if _dodged else " ", "x" if _sprint_time >= 0.4 else " "]
		Stage.SWORD:
			text = "Chuột trái: chém.\nHạ 1 sói con bằng đòn chém."
		Stage.SKILL_E:
			text = "E: phóng chiêu xuyên theo đường thẳng.\nHạ 2 sói con bằng E (%d/2)." % _kills
		Stage.SKILL_R:
			text = "R: tạo lốc gom quái lại.\nHạ 3 sói con bằng R (%d/3)." % _kills
		Stage.PACK:
			text = "Bầy sói kéo đến. Hạ 3 sói và Sói Đầu Đàn (%d/4)." % (_pack.size() - get_pack().size())
			if _fang_hint_shown:
				text += "\nCó đồ rơi: đứng gần và nhấn F để nhặt."
		Stage.LOOT:
			text = "Nhấn F để nhặt răng nanh."
	_title_label.text = "[HỆ THỐNG] Sống sót đến sáng."
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
	var box := VBoxContainer.new()
	box.set_anchors_preset(Control.PRESET_CENTER_TOP)
	box.position = Vector2(-200, 40)
	box.size = Vector2(400, 40)
	box.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_ui.add_child(box)
	_title_label = _make_label(SYSTEM_COLOR, 9)
	_hint_label = _make_label(Color(0.92, 0.93, 0.97), 8)
	box.add_child(_title_label)
	box.add_child(_hint_label)

func _make_label(color: Color, font_size: int) -> Label:
	var label := Label.new()
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.custom_minimum_size = Vector2(400, 0)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	label.add_theme_font_size_override("font_size", font_size)
	label.add_theme_color_override("font_color", color)
	label.add_theme_color_override("font_outline_color", Color(0, 0, 0, 0.9))
	label.add_theme_constant_override("outline_size", 3)
	return label
