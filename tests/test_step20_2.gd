extends SceneTree

const TEST_SLOT: int = 97

var _passed: int = 0
var _total: int = 0
var _slot_path: String = ""
var _backup_path: String = ""
var _backed_up_slot: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_prepare_test_slot()
	var packed := load("res://main.tscn") as PackedScene
	var scene := packed.instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)

	var base := root.get_node("BaseManager")
	var inventory := root.get_node("InventoryManager")
	var save_manager := root.get_node("SaveManager")
	var player := scene.get_node("Player") as CharacterBody2D
	var storage_a := &"a_storage_for_interaction_test"
	var storage_b := &"z_storage_for_interaction_test"
	var buildings: Array[Dictionary] = [
		{"instance_id": str(storage_a), "building_type_id": "storage", "base_id": "hope_valley_base", "grid_x": 63, "grid_y": 38},
		{"instance_id": str(storage_b), "building_type_id": "storage", "base_id": "hope_valley_base", "grid_x": 67, "grid_y": 38}
	]
	var initial_data := {"schema_version": 2, "buildings": buildings, "next_instance_number": 1}
	_check(bool(base.call("load_from_dict", initial_data)), "Load two independent storage buildings")
	var building_a: BaseBuilding = base.call("_find_building_by_id", storage_a)
	var building_b: BaseBuilding = base.call("_find_building_by_id", storage_b)
	_check(building_a != null and building_b != null, "Storage buildings are discoverable through BaseManager")

	player.global_position = Vector2(1008, 668)
	await physics_frame
	base.call("_process", 0.0)
	_check(building_a.is_storage_prompt_visible() and not building_b.is_storage_prompt_visible(), "In-range nearest Storage shows the Vietnamese prompt")
	var f_key := _key_event(KEY_F)
	base.call("_input", f_key)
	_check(bool(base.get("is_storage_interaction_open")) and base.call("get_active_storage_building_id") == storage_a, "F opens the nearest Storage using its unique building ID")
	_check(bool(base.get("_storage_ui").get("visible")), "Storage interaction panel is visible")
	_check(str(base.get("_storage_panel").get_node("VBoxContainer/Title").get("text")) == "Kho chứa", "Storage panel title is localized")
	_check(str(base.get("_storage_status_label").get("text")) == "0/30 ô", "Storage panel shows used slots and capacity")
	_check(not building_a.is_storage_prompt_visible() and not building_b.is_storage_prompt_visible(), "Storage prompt hides while the panel is open")
	_check(bool(player.call("_is_ui_modal_open")), "Storage panel is treated as a gameplay modal")

	Input.action_press("move_right")
	player.attack_cooldown_timer = 0.2
	var position_while_open := player.global_position
	player.call("_physics_process", 1.0 / 60.0)
	_check(player.global_position.is_equal_approx(position_while_open) and is_equal_approx(player.attack_cooldown_timer, 0.2), "Movement and sword attacks are blocked while Storage is open")
	player.stamina = 100.0
	player.dodge_cooldown_timer = 0.0
	Input.action_press("dodge")
	player.call("_physics_process", 1.0 / 60.0)
	_check(not bool(player.get("is_dodging")), "Dodge is blocked while Storage is open")
	var skill := player.get_node("SkillComponent")	
	var energy_before := float(skill.get("current_energy"))
	skill.call("_unhandled_input", _key_event(KEY_E))
	skill.call("_unhandled_input", _key_event(KEY_R))
	_check(is_equal_approx(float(skill.get("current_energy")), energy_before), "E and R skills are blocked while Storage is open")
	Input.action_release("move_right")
	Input.action_release("dodge")

	# A nearby pickup keeps its existing priority and still receives F.
	var pickup_scene := load("res://scenes/pickup_item.tscn") as PackedScene
	var pickup := pickup_scene.instantiate()
	pickup.set("item_id", &"herb")
	pickup.set("amount", 1)
	scene.add_child(pickup)
	pickup.set("player_inside", true)
	base.call("close_storage_interaction")
	pickup.set("player_inside", true)
	base.call("_input", f_key)
	_check(not bool(base.get("is_storage_interaction_open")), "Existing pickup interaction keeps priority over Storage")
	var herbs_before := int(inventory.call("get_item_count", &"herb"))
	pickup.call("_unhandled_input", f_key)
	_check(int(inventory.call("get_item_count", &"herb")) == herbs_before + 1, "Existing F pickup continues to work")
	await create_timer(0.25).timeout

	# Deterministic tie-break: nearest equal-distance buildings use lexical stable ID.
	player.global_position = Vector2(1040, 668)
	await physics_frame
	base.call("_process", 0.0)
	_check(building_a.is_storage_prompt_visible(), "Equal-distance Storage selection uses stable building ID order")
	base.call("_input", f_key)
	_check(base.call("get_active_storage_building_id") == storage_a, "Equal-distance F target opens the deterministic Storage")
	var escape := _key_event(KEY_ESCAPE)
	base.call("_input", escape)
	_check(not bool(base.get("is_storage_interaction_open")) and not bool(base.get("_storage_ui").get("visible")), "Esc closes Storage without leaking to Pause")
	var position_after_close := player.global_position
	Input.action_press("move_right")
	player.call("_physics_process", 1.0 / 60.0)
	Input.action_release("move_right")
	_check(not player.global_position.is_equal_approx(position_after_close), "Player movement is restored after closing Storage")

	var close_button: Button = base.get("_storage_panel").get_node("VBoxContainer/CloseButton")
	player.global_position = Vector2(1072, 650)
	await physics_frame
	base.call("_input", f_key)
	_check(base.call("get_active_storage_building_id") == storage_b, "The second Storage opens its own building ID")
	close_button.emit_signal("pressed")
	_check(not bool(base.get("is_storage_interaction_open")), "Close button closes the Storage panel")

	player.global_position = Vector2(300, 300)
	await physics_frame
	base.call("_process", 0.0)
	_check(not building_a.is_storage_prompt_visible() and not building_b.is_storage_prompt_visible(), "Storage prompt disappears outside interaction range")
	base.call("_input", f_key)
	_check(not bool(base.get("is_storage_interaction_open")), "F outside Storage range does not open a panel")

	# Save through SaveManager, change runtime buildings, then reload and reopen each ID.
	inventory.call("_init_empty_slots")
	inventory.call("add_item", &"wood", 2)
	inventory.call("add_item", &"stone", 3)
	inventory.call("add_item", &"herb", 4)
	_check(bool(base.call("deposit_item", storage_a, &"wood", 2)), "Test setup deposits into the first Storage")
	_check(bool(base.call("deposit_item", storage_b, &"stone", 3)), "Test setup deposits into the second Storage")
	await create_timer(0.45).timeout
	_check(bool(save_manager.call("save_game", TEST_SLOT)), "F5-equivalent SaveManager call saves storage contents")
	_check(bool(base.call("load_from_dict", {"schema_version": 2, "buildings": [], "next_instance_number": 1})), "Clear runtime buildings before reload")
	await create_timer(0.45).timeout
	_check(bool(save_manager.call("load_game", TEST_SLOT)), "F9-equivalent SaveManager call reloads storage contents")
	var restored_a: BaseBuilding = base.call("_find_building_by_id", storage_a)
	var restored_b: BaseBuilding = base.call("_find_building_by_id", storage_b)
	_check(restored_a != null and restored_b != null, "Both Storage buildings return after save/load")
	_check(_count_items(base.call("get_storage_contents", storage_a), &"wood") == 2 and _count_items(base.call("get_storage_contents", storage_b), &"stone") == 3, "Save/load retains the correct independent inventories")
	_check(int(inventory.call("get_item_count", &"herb")) == 4, "F9 restores the player's remaining inventory as well as both storages")
	await create_timer(0.45).timeout
	_check(bool(save_manager.call("load_game", TEST_SLOT)), "Repeated F9 load succeeds")
	_check(int(base.call("get_building_count")) == 2 and int(inventory.call("get_item_count", &"herb")) == 4, "Repeated F9 does not duplicate buildings or player items")
	_check(_count_items(base.call("get_storage_contents", storage_a), &"wood") == 2 and _count_items(base.call("get_storage_contents", storage_b), &"stone") == 3, "Repeated F9 preserves independent Storage quantities")
	player.global_position = Vector2(1072, 668)
	await physics_frame
	base.call("_input", f_key)
	_check(base.call("get_active_storage_building_id") == storage_b, "Storage remains interactable by its stable ID after F9 load")
	base.call("close_storage_interaction")

	print("Step 20.2 checks: %d / %d passed" % [_passed, _total])
	_restore_test_slot()
	quit(0 if _passed == _total else 1)

func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = keycode
	return event

func _count_items(slots: Array, item_id: StringName) -> int:
	var total := 0
	for slot in slots:
		if StringName(str(slot.get("item_id", ""))) == item_id:
			total += int(slot.get("amount", 0))
	return total

func _check(ok: bool, description: String) -> void:
	_total += 1
	if ok:
		_passed += 1
		print("PASS: " + description)
	else:
		printerr("FAIL: " + description)

func _prepare_test_slot() -> void:
	var save_path := "user://saves/slot_%02d.json" % TEST_SLOT
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://saves"))
	_slot_path = ProjectSettings.globalize_path(save_path)
	if FileAccess.file_exists(_slot_path):
		_backup_path = _slot_path + ".step20_2_%d.bak" % Time.get_ticks_usec()
		if DirAccess.rename_absolute(_slot_path, _backup_path) == OK:
			_backed_up_slot = true

func _restore_test_slot() -> void:
	if not _slot_path.is_empty() and FileAccess.file_exists(_slot_path):
		DirAccess.remove_absolute(_slot_path)
	if _backed_up_slot and FileAccess.file_exists(_backup_path):
		DirAccess.rename_absolute(_backup_path, _slot_path)
