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
	inventory.call("_init_empty_slots")
	var storage_a := &"step20_storage_a"
	var storage_b := &"step20_storage_b"
	var buildings: Array[Dictionary] = [
		{"instance_id": str(storage_a), "building_type_id": "storage", "base_id": "hope_valley_base", "grid_x": 50, "grid_y": 33},
		{"instance_id": str(storage_b), "building_type_id": "storage", "base_id": "hope_valley_base", "grid_x": 52, "grid_y": 33}
	]
	var initial_data := {"schema_version": 2, "buildings": buildings, "next_instance_number": 1}
	_check(bool(base.call("load_from_dict", initial_data)), "Create two storage buildings for isolated test")
	_check(base.call("get_storage_contents", storage_a).size() == 30, "Each storage exposes 30 slots")
	_check(base.call("get_storage_contents", storage_b).size() == 30, "Second storage starts with its own 30 empty slots")
	_check(not bool(base.call("can_deposit", storage_a, &"wood", 0)), "Zero quantity is rejected")
	_check(not bool(base.call("can_deposit", storage_a, &"wood", -1)), "Negative quantity is rejected")
	_check(not bool(base.call("can_deposit", storage_a, &"invalid_item", 1)), "Unknown item ID is rejected")
	_check(not bool(base.call("can_deposit", &"missing_storage", &"wood", 1)), "Unknown building ID is rejected")

	inventory.call("add_item", &"wood", 103)
	_check(bool(base.call("can_deposit", storage_a, &"wood", 103)), "Storage accepts a valid transfer across stack boundary")
	_check(bool(base.call("deposit_item", storage_a, &"wood", 98)), "First deposit succeeds")
	_check(bool(base.call("deposit_item", storage_a, &"wood", 5)), "Second deposit fills existing stack before using another slot")
	_check(int(inventory.call("get_item_count", &"wood")) == 0, "Successful deposits remove exactly the transferred items from player inventory")
	var contents_a: Array = base.call("get_storage_contents", storage_a)
	_check(int(contents_a[0]["amount"]) == 99 and int(contents_a[1]["amount"]) == 4, "Storage obeys ItemDefinition max_stack and stacks correctly")
	_check(_storage_count(contents_a, &"wood") == 103, "Stored total matches the two deposits")
	contents_a[0]["amount"] = 1
	_check(_storage_count(base.call("get_storage_contents", storage_a), &"wood") == 103, "Returned contents are a defensive copy")
	_check(not bool(base.call("deposit_item", storage_a, &"wood", 1)), "Deposit without player items fails")
	_check(_storage_count(base.call("get_storage_contents", storage_a), &"wood") == 103, "Failed deposit leaves storage unchanged")
	_check(bool(base.call("can_withdraw", storage_a, &"wood", 40)), "Valid withdrawal is accepted")
	_check(bool(base.call("withdraw_item", storage_a, &"wood", 40)), "Valid withdrawal succeeds")
	_check(_storage_count(base.call("get_storage_contents", storage_a), &"wood") == 63 and int(inventory.call("get_item_count", &"wood")) == 40, "Withdrawal moves the exact quantity without loss or duplication")
	_check(not bool(base.call("withdraw_item", storage_a, &"wood", 64)), "Withdrawal above stored quantity fails")
	_check(not bool(base.call("can_withdraw", storage_a, &"invalid_item", 1)), "Withdrawal rejects unknown item IDs")

	inventory.call("add_item", &"stone", 7)
	_check(bool(base.call("deposit_item", storage_b, &"stone", 7)), "Second storage accepts its own item transfer")
	_check(_storage_count(base.call("get_storage_contents", storage_a), &"stone") == 0 and _storage_count(base.call("get_storage_contents", storage_b), &"stone") == 7, "Storage inventories remain independent by building ID")

	var before_roundtrip: Dictionary = base.call("to_dict")
	_check(before_roundtrip.has("storage_inventories") and before_roundtrip["storage_inventories"].size() == 2, "Save data serializes one storage inventory per stable storage ID")
	_check(bool(base.call("load_from_dict", before_roundtrip)), "Storage contents load from the base snapshot")
	_check(_storage_count(base.call("get_storage_contents", storage_a), &"wood") == 63 and _storage_count(base.call("get_storage_contents", storage_b), &"stone") == 7, "Save/load roundtrip restores separate storage contents")
	inventory.call("set_debug_fill", true)
	_check(not bool(base.call("can_withdraw", storage_a, &"wood", 1)), "Withdrawal is rejected when all player slots and stacks are full")
	_check(not bool(base.call("withdraw_item", storage_a, &"wood", 1)), "Full player inventory cannot partially withdraw")
	_check(_storage_count(base.call("get_storage_contents", storage_a), &"wood") == 63, "Failed full-inventory withdrawal leaves stored items unchanged")
	inventory.call("restore_debug_snapshot")

	var full_data: Dictionary = base.call("to_dict")
	var full_slots: Array[Dictionary] = []
	for index in 30:
		full_slots.append({"slot": index, "id": "wood", "amount": 99})
	full_data["storage_inventories"][str(storage_a)] = {"schema_version": 1, "max_slots": 30, "slots": full_slots}
	_check(bool(base.call("load_from_dict", full_data)), "Load full 30-slot storage snapshot")
	inventory.call("_init_empty_slots")
	inventory.call("add_item", &"wood", 1)
	_check(not bool(base.call("can_deposit", storage_a, &"wood", 1)), "Full storage rejects deposits even when item stacks exist")
	_check(not bool(base.call("deposit_item", storage_a, &"wood", 1)), "Full storage deposit is rejected")
	_check(int(inventory.call("get_item_count", &"wood")) == 1 and _storage_count(base.call("get_storage_contents", storage_a), &"wood") == 2970, "Full-capacity failure preserves both sides of the transfer")

	var legacy_data := {"schema_version": 1, "buildings": buildings, "next_instance_number": 1}
	_check(bool(base.call("validate_save_data", legacy_data)), "Legacy Step 19 base save without storage data remains valid")
	_check(bool(base.call("load_from_dict", legacy_data)), "Legacy Step 19 save loads with empty storage inventories")
	_check(_storage_count(base.call("get_storage_contents", storage_a), &"wood") == 0, "Legacy storage starts empty without changing old building records")
	var malformed := legacy_data.duplicate(true)
	malformed["storage_inventories"] = {str(storage_a): {"schema_version": 1, "max_slots": 30, "slots": [{"slot": 0, "id": "not_real", "amount": 1}]}}
	_check(not bool(base.call("validate_save_data", malformed)), "Malformed storage item snapshot is rejected")

	# F3 loot should draw from the registered MATERIAL definitions rather than a fixed item.
	var debug_panel := scene.get_node("DebugPanel")
	var material_ids: Array[StringName] = inventory.call("get_item_ids_by_category", ItemDefinition.Category.MATERIAL)
	seed(24680)
	var spawned_ids: Dictionary = {}
	var seen_pickups: Dictionary = {}
	for pickup in get_nodes_in_group("pickup_items"):
		seen_pickups[StringName(str(pickup.get("pickup_id")))] = true
	for _index in 10:
		debug_panel.call("_on_btn_spawn_loot_pressed")
		await process_frame
		var pickups := get_nodes_in_group("pickup_items")
		for pickup in pickups:
			var pickup_id := StringName(str(pickup.get("pickup_id")))
			if seen_pickups.has(pickup_id):
				continue
			seen_pickups[pickup_id] = true
			var item_id := StringName(str(pickup.get("item_id")))
			spawned_ids[item_id] = true
			_check(material_ids.has(item_id) and int(pickup.get("amount")) == 2, "Debug loot is a valid material stack")
	_check(spawned_ids.size() > 1, "Repeated F3 loot spawns vary material types")

	# Hit flash is red immediately and returns to the sprite's normal tint shortly after.
	var player := scene.get_node("Player")
	var sprite := player.get_node("Sprite2D") as Sprite2D
	player.call("take_damage", 1.0)
	_check(sprite.modulate.r > 0.99 and sprite.modulate.g < 0.5 and sprite.modulate.b < 0.5, "Player turns red when hit")
	await create_timer(0.2).timeout
	_check(is_equal_approx(sprite.modulate.r, 1.0) and is_equal_approx(sprite.modulate.g, 1.0) and is_equal_approx(sprite.modulate.b, 1.0), "Player tint returns to normal after the hit flash")

	print("Step 20.1 checks: %d / %d passed" % [_passed, _total])
	quit(0 if _passed == _total else 1)

func _storage_count(slots: Array, item_id: StringName) -> int:
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
