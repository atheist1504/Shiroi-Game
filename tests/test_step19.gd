extends SceneTree

const TEST_SLOT: int = 98
var _passed: int = 0
var _total: int = 0
var _test_save_path: String = "user://saves/slot_98.json"
var _backup_save_path: String = "user://saves/slot_98.step19_test_backup"
var _had_previous_save: bool = false

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	_prepare_test_slot()
	for entry in [
		["EventBus", "res://scripts/event_bus.gd"],
		["WorldState", "res://scripts/world_state.gd"],
		["QuestManager", "res://scripts/quest_manager.gd"],
		["InventoryManager", "res://scripts/inventory_manager.gd"],
		["NotificationManager", "res://scripts/notification_manager.gd"],
		["CraftingManager", "res://scripts/crafting_manager.gd"],
		["BaseManager", "res://scripts/base_manager.gd"],
		["SaveManager", "res://scripts/save_manager.gd"]
	]:
		var node := Node.new()
		node.name = entry[0]
		node.set_script(load(entry[1]))
		root.add_child(node)
		await process_frame

	var main_packed_scene := load("res://main.tscn") as PackedScene
	var scene := main_packed_scene.instantiate()
	current_scene = scene
	root.add_child(scene)
	await process_frame
	await physics_frame
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var save_manager := root.get_node("SaveManager")
	var base_manager := root.get_node("BaseManager")
	var inventory := root.get_node("InventoryManager")
	var player := scene.get_node("Player") as Node2D
	var slime := scene.get_node("Slime1")
	var bus := root.get_node("EventBus")
	var quest_manager := root.get_node("QuestManager")
	var placed_events := [0]
	bus.connect("building_placed", func(_id, _type, _base): placed_events[0] += 1)

	# E1/E2 and health bar synchronization.
	slime.set("current_health", 30.0)
	_check(await _save_and_load(save_manager, 30.0, 10.0, slime), "Enemy HP roundtrip restores saved 30/60 HP")
	_check(is_equal_approx((slime.get_node("HealthBar") as ProgressBar).value, 30.0), "Slime health bar updates on restore")

	# E3/E5: enemy saved alive returns alive; loot is rolled back to save snapshot.
	slime.set("current_health", 40.0)
	_check(await _save(save_manager), "Save alive Slime snapshot")
	var loot_count_at_save := get_nodes_in_group("pickup_items").size()
	slime.set("current_health", 0.0)
	slime.call("_die")
	await create_timer(0.45).timeout
	_check(get_nodes_in_group("pickup_items").size() >= loot_count_at_save, "Death may create loot after save")
	_check(await _load(save_manager), "Load alive Slime snapshot")
	_check(not bool(slime.get("is_dead")) and is_equal_approx(float(slime.get("current_health")), 40.0), "Killed-after-save Slime returns alive without death rewards")
	_check(get_nodes_in_group("pickup_items").size() == loot_count_at_save, "Post-save loot is replaced by saved loot snapshot")

	# E4/E6/E7: saved-dead state remains dead, repeated loads are idempotent and silent.
	var defeated_events := [0]
	bus.connect("enemy_defeated", func(_id, _region): defeated_events[0] += 1)
	quest_manager.call("activate_quest", &"main_clear_slimes")
	slime.set("current_health", 0.0)
	slime.call("_die")
	await create_timer(0.45).timeout
	_check(await _save(save_manager), "Save dead Slime snapshot")
	var defeated_before_load: int = int(defeated_events[0])
	var quest_kills_before_load := int(quest_manager.call("get_objective_progress", &"main_clear_slimes", &"defeat_3_slimes"))
	for i in 3:
		_check(await _load(save_manager), "Repeated enemy load %d" % (i + 1))
	_check(bool(slime.get("is_dead")) and is_equal_approx(float(slime.get("current_health")), 0.0), "Enemy dead before save stays dead")
	_check(defeated_events[0] == defeated_before_load, "Load does not emit enemy_defeated or increment quest kills")
	_check(int(quest_manager.call("get_objective_progress", &"main_clear_slimes", &"defeat_3_slimes")) == quest_kills_before_load, "Load leaves saved quest kill count unchanged")
	_check(get_nodes_in_group("enemies").size() == 8, "Repeated loads do not duplicate scene-authored enemies")

	# Boss HP uses the same persistence path.
	var boss := scene.get_node("TestBoss")
	boss.set("current_health", 115.0)
	_check(await _save(save_manager), "Save boss HP snapshot")
	boss.set("current_health", 35.0)
	_check(await _load(save_manager), "Load boss HP snapshot")
	_check(is_equal_approx(float(boss.get("current_health")), 115.0) and is_equal_approx((boss.get_node("BossUI/HealthBar") as ProgressBar).value, 115.0), "Boss HP and health bar restore")

	# Base unlock/build, exact material transaction, collision overlap, and load idempotence.
	_check(not bool(base_manager.call("is_base_unlocked")), "Hope Valley base starts locked")
	var toggle_build := InputEventKey.new()
	toggle_build.pressed = true
	toggle_build.physical_keycode = KEY_G
	player.global_position = Vector2(700, 544)
	base_manager.call("_input", toggle_build)
	_check(not bool(base_manager.get("is_build_mode")), "G cannot open a locked base")
	_check(bool(base_manager.call("unlock_base_for_debug")), "Debug unlocks Hope Valley")
	player.global_position = Vector2(640, 360)
	base_manager.call("_input", toggle_build)
	_check(not bool(base_manager.get("is_build_mode")), "G outside Hope Valley does not enter Build Mode")
	player.global_position = Vector2(700, 544)
	inventory.call("_init_empty_slots")
	inventory.call("add_item", &"wooden_plank", 4)
	inventory.call("add_item", &"processed_stone", 2)
	base_manager.call("_input", toggle_build)
	_check(bool(base_manager.get("is_build_mode")) and bool(base_manager.call("select_building", &"storage")), "G build mode can select Storage")
	_check(bool(base_manager.get("_build_ui").get("visible")), "Build Mode CanvasLayer is visible after pressing G")
	_check(InputMap.has_action("toggle_build_mode") and _inventory_uses_b(), "Build mode adds G while preserving B inventory")
	_check(_action_uses_key("quick_load", KEY_F9), "F9 remains mapped to quick load")
	var storage_grid := Vector2i(50, 34)
	_check(bool(base_manager.call("can_place_at", &"storage", storage_grid)), "Storage footprint is clear inside the base")
	_check(bool(base_manager.call("place_building", &"storage", storage_grid)), "Storage placement commits successfully")
	_check(int(inventory.call("get_item_count", &"wooden_plank")) == 0 and int(inventory.call("get_item_count", &"processed_stone")) == 0, "Storage consumes exact material costs")
	_check(int(base_manager.call("get_building_count")) == 1 and placed_events[0] == 1, "Successful placement emits one building_placed signal")
	_check(not bool(base_manager.call("can_place_at", &"storage", storage_grid)), "Overlapping building placement is rejected")
	_check(not bool(base_manager.call("can_place_at", &"storage", Vector2i(50, 38))), "Essential base walkway is kept clear")
	_check(_has_costs(&"house", {"wooden_plank": 6, "processed_stone": 4}), "House definition has specified costs")
	_check(_has_costs(&"watchtower", {"wooden_plank": 6, "processed_stone": 6, "basic_building_kit": 1}), "Watchtower definition has specified costs")
	_check(_has_costs(&"fence", {"wooden_plank": 2}), "Fence definition has specified costs")
	var right_click := InputEventMouseButton.new()
	right_click.pressed = true
	right_click.button_index = MOUSE_BUTTON_RIGHT
	base_manager.call("_unhandled_input", right_click)
	_check(bool(base_manager.get("is_build_mode")) and base_manager.get("_selected_type") == StringName(), "Right click cancels placement without leaving Build Mode")
	_check(await _save(save_manager), "Save base and building snapshot")
	var player_pos_at_save: Vector2 = player.global_position
	player.global_position = Vector2(100, 100)
	inventory.call("add_item", &"wood", 5)
	for building in get_nodes_in_group("placed_buildings"):
		building.get_parent().remove_child(building)
		building.free()
	_check(await _load(save_manager), "Load base and building snapshot")
	_check(int(base_manager.call("get_building_count")) == 1 and placed_events[0] == 1, "Building loads once without placement event")
	_check(player.global_position.distance_to(player_pos_at_save) < 0.1 and int(inventory.call("get_item_count", &"wood")) == 0, "Unified load restores player and inventory snapshot")
	for i in 3:
		_check(await _load(save_manager), "Repeated building load %d" % (i + 1))
	_check(int(base_manager.call("get_building_count")) == 1, "Repeated loads do not duplicate buildings")
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.physical_keycode = KEY_ESCAPE
	base_manager.call("_input", escape)
	_check(not bool(base_manager.get("is_build_mode")) and not paused, "Esc leaves build mode without opening Pause")
	_check(not bool(base_manager.get("_build_ui").get("visible")), "Build Mode CanvasLayer hides after exiting")

	# Migration policy: pre-Step-19 snapshots have no enemy/base fields; loading
	# keeps enemy runtime because HP was never recorded and clears new buildings.
	_check(await _save(save_manager), "Prepare migration snapshot")
	var legacy_data: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(_test_save_path))
	legacy_data.erase("enemy_states")
	legacy_data.erase("base_state")
	var legacy_file := FileAccess.open(_test_save_path, FileAccess.WRITE)
	legacy_file.store_string(JSON.stringify(legacy_data))
	legacy_file.close()
	slime.set("current_health", 17.0)
	_check(await _load(save_manager), "Legacy save without Step 19 fields loads safely")
	_check(is_equal_approx(float(slime.get("current_health")), 17.0) and int(base_manager.call("get_building_count")) == 0, "Legacy migration preserves unrecorded enemy state and resets new buildings")
	legacy_data["enemy_states"] = {"forest_clearing": [{"persistent_id": ""}]}
	var invalid_file := FileAccess.open(_test_save_path, FileAccess.WRITE)
	invalid_file.store_string(JSON.stringify(legacy_data))
	invalid_file.close()
	var invalid_text := FileAccess.get_file_as_string(_test_save_path)
	slime.set("current_health", 23.0)
	_check(not (await _load(save_manager)), "Malformed enemy snapshot is rejected")
	_check(is_equal_approx(float(slime.get("current_health")), 23.0) and FileAccess.get_file_as_string(_test_save_path) == invalid_text, "Rejected load leaves runtime and save file untouched")

	var debug_panel := scene.get_node("DebugPanel")
	debug_panel.call("_on_btn_spawn_loot_pressed")
	await process_frame
	var dropped_processed_stone := false
	for pickup in get_nodes_in_group("pickup_items"):
		if pickup.get("item_id") == &"processed_stone" and int(pickup.get("amount")) == 2:
			dropped_processed_stone = true
			break
	_check(dropped_processed_stone, "Debug loot button creates two processed stones")

	_print_results()
	_restore_test_slot()
	quit(0 if _passed == _total else 1)

func _save(save_manager: Node) -> bool:
	await create_timer(0.45).timeout
	return bool(save_manager.call("save_game", TEST_SLOT))

func _load(save_manager: Node) -> bool:
	await create_timer(0.45).timeout
	return bool(save_manager.call("load_game", TEST_SLOT))

func _save_and_load(save_manager: Node, saved_hp: float, changed_hp: float, enemy: Node) -> bool:
	_check(await _save(save_manager), "Save enemy with %.0f HP" % saved_hp)
	enemy.set("current_health", changed_hp)
	_check(await _load(save_manager), "Load enemy snapshot")
	return is_equal_approx(float(enemy.get("current_health")), saved_hp)

func _check(ok: bool, description: String) -> void:
	_total += 1
	if ok:
		_passed += 1
		print("PASS: " + description)
	else:
		printerr("FAIL: " + description)

func _inventory_uses_b() -> bool:
	return _action_uses_key("toggle_inventory", KEY_B)

func _has_costs(building_type_id: StringName, expected: Dictionary) -> bool:
	var base_manager := root.get_node("BaseManager")
	var definition: BuildingDefinition = base_manager.call("get_definition", building_type_id)
	return definition != null and definition.costs == expected

func _action_uses_key(action_name: StringName, keycode: Key) -> bool:
	if not InputMap.has_action(action_name):
		return false
	for event in InputMap.action_get_events(action_name):
		if event is InputEventKey and event.physical_keycode == keycode:
			return true
	return false

func _print_results() -> void:
	print("Step 19 automated checks: %d / %d passed" % [_passed, _total])

func _prepare_test_slot() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path("user://saves"))
	var absolute_path := ProjectSettings.globalize_path(_test_save_path)
	var absolute_backup := ProjectSettings.globalize_path(_backup_save_path)
	if FileAccess.file_exists(absolute_path):
		_had_previous_save = true
		DirAccess.rename_absolute(absolute_path, absolute_backup)

func _restore_test_slot() -> void:
	var absolute_path := ProjectSettings.globalize_path(_test_save_path)
	var absolute_backup := ProjectSettings.globalize_path(_backup_save_path)
	var replace_backup := absolute_path + ".replace_backup"
	if FileAccess.file_exists(absolute_path):
		DirAccess.remove_absolute(absolute_path)
	if FileAccess.file_exists(replace_backup):
		DirAccess.remove_absolute(replace_backup)
	if _had_previous_save and FileAccess.file_exists(absolute_backup):
		DirAccess.rename_absolute(absolute_backup, absolute_path)
