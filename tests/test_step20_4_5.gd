extends SceneTree

var _passed: int = 0
var _total: int = 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
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
	var player := scene.get_node("Player") as CharacterBody2D
	var storage_a := &"step20_45_storage_a"
	var storage_b := &"step20_45_storage_b"
	var fixture := _building_fixture(storage_a, storage_b)
	_check(bool(base.call("load_from_dict", fixture)), "Create two storage buildings with stable independent IDs")
	player.global_position = Vector2(1008, 650)
	_check(bool(base.call("open_storage_interaction", storage_a)), "Open Storage UI for transaction tests")
	inventory.call("_init_empty_slots")
	inventory.call("add_item", &"wood", 200)
	_check(not bool(base.call("deposit_item", storage_a, &"wood", 0)), "Reject zero transfer quantity")
	_check(not bool(base.call("deposit_item", storage_a, &"wood", -1)), "Reject negative transfer quantity")
	_check(not bool(base.call("deposit_item", storage_a, &"missing", 1)), "Reject unknown item ID")
	_check(not bool(base.call("deposit_item", &"not_a_building", &"wood", 1)), "Reject unknown storage building ID")
	_check(not bool(base.call("deposit_item", storage_a, &"wood", 201)), "Reject transfer above player-owned quantity")
	_check(base.call("_get_storage_transfer_failure_message", true, &"missing", 1) == "Không thể chuyển vật phẩm!", "Unclassified transfer failures use the safe generic Vietnamese message")
	_check(bool(base.call("deposit_item", storage_a, &"wood", 98)), "Deposit near stack limit")
	_check(bool(base.call("deposit_item", storage_a, &"wood", 1)), "Fill the existing stack to its exact limit")
	_check(bool(base.call("deposit_item", storage_a, &"wood", 1)), "A full stack rolls into a new storage slot")
	var contents_a: Array = base.call("get_storage_contents", storage_a)
	_check(int(contents_a[0]["amount"]) == 99 and int(contents_a[1]["amount"]) == 1, "Storage respects max stack without losing items")
	_check(_total_wood(base, inventory, storage_a) == 200, "Inventory-to-Storage transfers conserve the total item count")
	_check(not bool(base.call("withdraw_item", storage_a, &"wood", 0)), "Reject zero withdrawal")
	_check(not bool(base.call("withdraw_item", storage_a, &"wood", 101)), "Reject withdrawal above stored amount")
	_check(bool(base.call("withdraw_item", storage_a, &"wood", 1)), "Withdraw from the partial stack")
	for _index in 10:
		_check(bool(base.call("deposit_item", storage_a, &"wood", 1)), "Repeated deposit succeeds")
		_check(bool(base.call("withdraw_item", storage_a, &"wood", 1)), "Repeated withdrawal succeeds")
	_check(_total_wood(base, inventory, storage_a) == 200, "Repeated transfers neither duplicate nor lose items")
	_check(_count(base.call("get_storage_contents", storage_b), &"wood") == 0, "Transfers to Storage A do not affect Storage B")

	# Fill every Storage slot with full stacks and ensure a rejected UI/API transfer is unchanged.
	var full_slots: Array[Dictionary] = []
	for _index in 30:
		full_slots.append({"item_id": &"wood", "amount": 99})
	var storage_map: Dictionary = base.get("_storage_inventories")
	storage_map[storage_a] = full_slots
	base.set("_storage_inventories", storage_map)
	base.emit_signal("storage_changed", storage_a)
	_check(not bool(base.call("can_deposit", storage_a, &"wood", 1)), "Reject deposit when all Storage slots and stacks are full")
	_check(not bool(base.call("deposit_item", storage_a, &"wood", 1)), "Full Storage deposit is all-or-nothing")
	_check(int(inventory.call("get_item_count", &"wood")) == 101 and _count(base.call("get_storage_contents", storage_a), &"wood") == 2970, "Failed full-Storage deposit preserves both inventories")
	_check(base.call("_get_storage_transfer_failure_message", true, &"wood", 1) == "Kho đã đầy!", "Full Storage provides a specific Vietnamese reason")
	var player_slots: Array = base.get("_player_storage_slots")
	player_slots[0].emit_signal("pressed")
	base.get("_storage_deposit_button").emit_signal("pressed")
	await create_timer(0.22).timeout
	_check(base.get("_storage_feedback_label").get("text") == "Kho đã đầy!", "Storage UI displays the full-Storage message")

	# Put one item in Storage, then fill every player inventory slot with full stacks.
	storage_map = base.get("_storage_inventories")
	var one_slot: Array[Dictionary] = base.call("_create_empty_storage_slots")
	one_slot[0] = {"item_id": &"wood", "amount": 1}
	storage_map[storage_a] = one_slot
	base.set("_storage_inventories", storage_map)
	base.emit_signal("storage_changed", storage_a)
	inventory.call("_init_empty_slots")
	inventory.call("add_item", &"wood", 24 * 99)
	_check(not bool(base.call("can_withdraw", storage_a, &"wood", 1)), "Reject withdrawal when all 24 player slots are full")
	_check(not bool(base.call("withdraw_item", storage_a, &"wood", 1)), "Full player inventory withdrawal is all-or-nothing")
	_check(int(inventory.call("get_item_count", &"wood")) == 24 * 99 and _count(base.call("get_storage_contents", storage_a), &"wood") == 1, "Failed full-inventory withdrawal preserves both inventories")
	_check(base.call("_get_storage_transfer_failure_message", false, &"wood", 1) == "Túi đồ đã đầy!", "Full player inventory has a specific Vietnamese reason")
	_check(base.call("_get_storage_transfer_failure_message", false, &"stone", 1) == "Không đủ vật phẩm!", "Missing stored item has a specific Vietnamese reason")
	var storage_slots: Array = base.get("_base_storage_slots")
	storage_slots[0].emit_signal("pressed")
	base.get("_storage_withdraw_button").emit_signal("pressed")
	await create_timer(0.22).timeout
	_check(base.get("_storage_feedback_label").get("text") == "Túi đồ đã đầy!", "Storage UI displays the full-inventory message")

	# Exercise the panel transfer button and its duplicate-click guard.
	inventory.call("_init_empty_slots")
	inventory.call("add_item", &"wood", 2)
	player_slots = base.get("_player_storage_slots")
	player_slots[0].emit_signal("pressed")
	inventory.call("remove_item", &"wood", 2)
	base.set("_selected_storage_source", &"player")
	base.set("_selected_storage_slot", 0)
	base.get("_storage_deposit_button").emit_signal("pressed")
	_check(base.get("_storage_feedback_label").get("text") == "Không đủ vật phẩm!", "Storage UI explains when the selected item has disappeared")
	inventory.call("add_item", &"wood", 2)
	storage_map = base.get("_storage_inventories")
	storage_map[storage_a] = base.call("_create_empty_storage_slots")
	base.set("_storage_inventories", storage_map)
	base.emit_signal("storage_changed", storage_a)
	var deposit_button: Button = base.get("_storage_deposit_button")
	player_slots[0].emit_signal("pressed")
	deposit_button.emit_signal("pressed")
	deposit_button.emit_signal("pressed")
	_check(int(inventory.call("get_item_count", &"wood")) == 1 and _count(base.call("get_storage_contents", storage_a), &"wood") == 1, "Rapid double click performs only one item transfer")
	_check(bool(base.get("_storage_transfer_pending")) and bool(deposit_button.get("disabled")), "Transfer button is briefly locked against accidental repeats")
	await create_timer(0.22).timeout
	_check(not bool(base.get("_storage_transfer_pending")), "Transfer button unlocks after the short debounce")
	base.call("close_storage_interaction")

	# Save-model roundtrip verifies exact storage IDs/stacks without touching user save files.
	inventory.call("_init_empty_slots")
	inventory.call("add_item", &"wood", 7)
	inventory.call("add_item", &"stone", 4)
	storage_map = base.get("_storage_inventories")
	storage_map[storage_a] = base.call("_create_empty_storage_slots")
	storage_map[storage_b] = base.call("_create_empty_storage_slots")
	base.set("_storage_inventories", storage_map)
	_check(bool(base.call("deposit_item", storage_a, &"wood", 5)), "Prepare first Storage for serialization")
	_check(bool(base.call("deposit_item", storage_b, &"stone", 2)), "Prepare second Storage for serialization")
	var base_snapshot: Dictionary = base.call("to_dict")
	var inventory_snapshot: Dictionary = inventory.call("to_dict")
	_check(bool(base.call("load_from_dict", base_snapshot)), "Reload saved building and Storage snapshot")
	_check(bool(inventory.call("load_from_dict", inventory_snapshot)), "Reload player Inventory snapshot")
	_check(_count(base.call("get_storage_contents", storage_a), &"wood") == 5 and _count(base.call("get_storage_contents", storage_b), &"stone") == 2, "Two Storage inventories restore independently")
	_check(int(inventory.call("get_item_count", &"wood")) == 2 and int(inventory.call("get_item_count", &"stone")) == 2, "Inventory snapshot restores exact remaining amounts")
	_check(bool(base.call("load_from_dict", base_snapshot)), "Loading the same building snapshot again succeeds")
	_check(_count(base.call("get_storage_contents", storage_a), &"wood") == 5 and _count(base.call("get_storage_contents", storage_b), &"stone") == 2, "Repeated load does not duplicate or mix stored items")
	var legacy := {"schema_version": 1, "buildings": fixture["buildings"], "next_instance_number": 1}
	_check(bool(base.call("load_from_dict", legacy)), "Legacy Step 19 building snapshot remains loadable")
	_check(_count(base.call("get_storage_contents", storage_a), &"wood") == 0 and _count(base.call("get_storage_contents", storage_b), &"stone") == 0, "Legacy buildings initialize empty Storage without changing their IDs")
	base.call("close_storage_interaction")
	print("Step 20.4 + 20.5 checks: %d / %d passed" % [_passed, _total])
	quit(0 if _passed == _total else 1)

func _building_fixture(storage_a: StringName, storage_b: StringName) -> Dictionary:
	return {"schema_version": 2, "buildings": [
		{"instance_id": str(storage_a), "building_type_id": "storage", "base_id": "hope_valley_base", "grid_x": 63, "grid_y": 38},
		{"instance_id": str(storage_b), "building_type_id": "storage", "base_id": "hope_valley_base", "grid_x": 67, "grid_y": 38}
	], "next_instance_number": 3}

func _count(slots: Array, item_id: StringName) -> int:
	var total := 0
	for slot in slots:
		if StringName(str(slot.get("item_id", ""))) == item_id:
			total += int(slot.get("amount", 0))
	return total

func _total_wood(base: Node, inventory: Node, storage_id: StringName) -> int:
	return int(inventory.call("get_item_count", &"wood")) + _count(base.call("get_storage_contents", storage_id), &"wood")

func _check(ok: bool, description: String) -> void:
	_total += 1
	if ok:
		_passed += 1
		print("PASS: " + description)
	else:
		printerr("FAIL: " + description)
