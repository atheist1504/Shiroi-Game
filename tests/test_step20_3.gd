extends SceneTree

var _passed: int = 0
var _total: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var packed := load("res://main.tscn") as PackedScene
	var scene := packed.instantiate()
	# Bỏ tài nguyên căn cứ để NPC đứng yên, không đi ngang ô đặt công trình của test.
	for resource_node in scene.get_node("ResourceNodes").get_children():
		if str(resource_node.get("node_id")).begins_with("hv_"):
			resource_node.free()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	for enemy in get_nodes_in_group("enemies"):
		enemy.set_physics_process(false)
	var base := root.get_node("BaseManager")
	var inventory := root.get_node("InventoryManager")
	var player := scene.get_node("Player") as CharacterBody2D
	var building_id := &"step20_3_storage"
	var second_building_id := &"step20_3_storage_second"
	var fixture := {"schema_version": 2, "buildings": [
		{"instance_id": str(building_id), "building_type_id": "storage", "base_id": "hope_valley_base", "grid_x": 63, "grid_y": 38},
		{"instance_id": str(second_building_id), "building_type_id": "storage", "base_id": "hope_valley_base", "grid_x": 67, "grid_y": 38}
	], "next_instance_number": 1}
	_check(bool(base.call("load_from_dict", fixture)), "Set up a uniquely identified Storage building")
	player.global_position = Vector2(1008, 650)
	inventory.call("_init_empty_slots")
	inventory.call("add_item", &"wood", 2)
	_check(bool(base.call("open_storage_interaction", building_id)), "Open the Storage interaction panel")
	var panel: Control = base.get("_storage_panel")
	_check(panel.get_node("VBoxContainer/Title").get("text") == "Kho chứa", "Panel title is localized")
	_check(base.get("_player_storage_slots").size() == 24 and base.get("_base_storage_slots").size() == 30, "Panel displays 24 player slots and 30 Storage slots")
	_check(panel.texture_filter == CanvasItem.TEXTURE_FILTER_NEAREST, "Storage panel keeps pixel art texture filtering crisp")
	_check(base.get("_storage_inventory_status").get("text") == "1/24 ô" and base.get("_storage_status_label").get("text") == "0/30 ô", "Both inventories show used and total slot counts")
	var player_slots: Array = base.get("_player_storage_slots")
	var storage_slots: Array = base.get("_base_storage_slots")
	player_slots[0].emit_signal("pressed")
	_check(not bool(base.get("_storage_deposit_button").get("disabled")), "Selected player item enables deposit")
	base.get("_storage_deposit_button").emit_signal("pressed")
	await create_timer(0.22).timeout
	_check(int(inventory.call("get_item_count", &"wood")) == 1 and _count(base.call("get_storage_contents", building_id), &"wood") == 1, "Deposit moves exactly one item and refreshes both sides")
	_check(base.get("_storage_inventory_status").get("text") == "1/24 ô" and base.get("_storage_status_label").get("text") == "1/30 ô", "Slot counts refresh immediately after deposit")
	storage_slots[0].emit_signal("pressed")
	_check(not bool(base.get("_storage_withdraw_button").get("disabled")), "Selected stored item enables withdrawal")
	base.get("_storage_withdraw_button").emit_signal("pressed")
	await create_timer(0.22).timeout
	_check(int(inventory.call("get_item_count", &"wood")) == 2 and _count(base.call("get_storage_contents", building_id), &"wood") == 0, "Withdrawal returns exactly one item and refreshes both sides")
	base.get("_storage_deposit_button").emit_signal("pressed")
	_check(int(inventory.call("get_item_count", &"wood")) == 2, "A stale or cleared selection cannot repeat a transfer")
	storage_slots[0].emit_signal("pressed")
	_check(bool(base.get("_storage_withdraw_button").get("disabled")), "Empty storage slots cannot be withdrawn")
	player_slots[0].emit_signal("pressed")
	var escape := InputEventKey.new()
	escape.pressed = true
	escape.physical_keycode = KEY_ESCAPE
	base.call("_input", escape)
	_check(not bool(base.get("is_storage_interaction_open")) and not bool(panel.get_parent().get("visible")), "Esc closes the storage panel")
	_check(bool(base.call("open_storage_interaction", building_id)), "Storage can be reopened without losing contents")
	base.call("close_storage_interaction")
	player.global_position = Vector2(1072, 650)
	base.call("_input", _key_event(KEY_F))
	_check(bool(base.get("is_storage_interaction_open")), "F opens the nearby second Storage")
	_check(base.call("get_active_storage_building_id") == second_building_id and base.get("_storage_status_label").get("text") == "0/30 ô", "Second Storage panel points at its independent inventory")
	base.call("close_storage_interaction")
	inventory.call("_init_empty_slots")
	inventory.call("add_item", &"wood", 3)
	inventory.call("add_item", &"stone", 2)
	_check(bool(base.call("deposit_item", building_id, &"wood", 2)), "Prepare contents for save/load roundtrip")
	_check(bool(base.call("deposit_item", second_building_id, &"stone", 1)), "Prepare separate contents for the second Storage")
	var saved_base: Dictionary = base.call("to_dict")
	var saved_inventory: Dictionary = inventory.call("to_dict")
	_check(saved_base.get("storage_inventories", {}).has(str(building_id)), "BaseManager serializes this Storage under its stable building ID")
	_check(saved_base.get("storage_inventories", {}).has(str(second_building_id)), "BaseManager serializes the second Storage under its own ID")
	inventory.call("_init_empty_slots")
	_check(bool(base.call("load_from_dict", saved_base)), "BaseManager restores Storage contents from its save data")
	_check(bool(inventory.call("load_from_dict", saved_inventory)), "InventoryManager restores player items from its save data")
	_check(int(inventory.call("get_item_count", &"wood")) == 1 and _count(base.call("get_storage_contents", building_id), &"wood") == 2, "Inventory and first Storage serialization restores exact amounts without duplication")
	_check(int(inventory.call("get_item_count", &"stone")) == 1 and _count(base.call("get_storage_contents", second_building_id), &"stone") == 1, "Second Storage serialization restores its independent contents")
	var restored: BaseBuilding = base.call("_find_building_by_id", building_id) as BaseBuilding
	_check(restored != null and bool(base.call("open_storage_interaction", building_id)), "Restored Storage remains available by its stable building ID")
	_check(_count(base.call("get_storage_contents", building_id), &"wood") == 2, "Reopening the restored Storage shows its own saved contents")
	base.call("close_storage_interaction")
	player.global_position = Vector2(1072, 650)
	base.call("_input", _key_event(KEY_F))
	_check(bool(base.get("is_storage_interaction_open")) and base.call("get_active_storage_building_id") == second_building_id, "Restored second Storage still opens by F and its own ID")
	_check(_count(base.call("get_storage_contents", second_building_id), &"stone") == 1, "Reopening the second Storage shows its own restored contents")
	base.call("close_storage_interaction")
	print("Step 20.3 checks: %d / %d passed" % [_passed, _total])
	quit(0 if _passed == _total else 1)

func _count(slots: Array, item_id: StringName) -> int:
	var total := 0
	for slot in slots:
		if StringName(str(slot.get("item_id", ""))) == item_id:
			total += int(slot.get("amount", 0))
	return total

func _key_event(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.pressed = true
	event.physical_keycode = keycode
	return event

func _check(ok: bool, description: String) -> void:
	_total += 1
	if ok:
		_passed += 1
		print("PASS: " + description)
	else:
		printerr("FAIL: " + description)

