extends SceneTree

# Trại: vùng xây là vòng tròn quanh đống lửa, nở rộng theo cấp Nhà ở; tháp canh bắn quái, hàng rào chặn quái.
# Gọi hàm trực tiếp, không mô phỏng chuột.

var _passed := 0
var _total := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	await physics_frame
	var base: Node = root.get_node("BaseManager")
	var inventory: Node = root.get_node("InventoryManager")
	var center: Vector2 = base.CAMP_CENTER
	base.unlock_base_for_debug()
	_check(base.BASE_NAME == "Trại", "Khu căn cứ tên là Trại")
	_check(is_equal_approx(base.get_camp_radius(), base.CAMP_RADIUS_START), "Chưa xây gì thì Trại có bán kính khởi đầu")
	_check(base.is_in_camp(center + Vector2(150, 0)) and not base.is_in_camp(center + Vector2(260, 0)), "Trong/ngoài Trại tính theo vòng tròn quanh đống lửa")
	var near_fire: String = base._get_placement_block_reason(&"fence", Vector2i((center / 16.0).floor()))
	_check(near_fire.contains("đống lửa"), "Không xây sát đống lửa")
	var far_grid := Vector2i(((center + Vector2(0, -205)) / 16.0).floor())
	_check(base._get_placement_block_reason(&"fence", far_grid).contains("vòng Trại"), "Ngoài vòng Trại thì chưa xây được")
	var station := scene.get_node("CraftingStation") as Node2D
	_check(base.is_in_camp(station.global_position), "Bàn chế tạo nằm trong Trại")
	var station_grid := Vector2i((station.global_position / 16.0).round())
	_check(base._get_placement_block_reason(&"fence", station_grid).contains("bàn chế tạo"), "Không xây đè lên bàn chế tạo")
	# Hàng rào, tháp canh không làm Trại rộng; chỉ Nhà ở và cấp nhà mới làm Trại rộng.
	inventory.add_item(&"wooden_plank", 60)
	inventory.add_item(&"processed_stone", 30)
	inventory.add_item(&"basic_building_kit", 2)
	(scene.get_node("Player") as Node2D).global_position = center + Vector2(60, 0)
	# Quái đi lang thang có thể đứng chắn chỗ xây; dọn quái trong Trại cho bài thử ổn định.
	for enemy in base.get_tree().get_nodes_in_group("enemies"):
		if (enemy as Node2D).global_position.distance_to(center) < 320.0:
			enemy.free()
	base._enter_build_mode()
	var fence_ok: bool = base.place_building(&"fence", Vector2i(((center + Vector2(60, 130)) / 16.0).floor()))
	var tower_ok: bool = base.place_building(&"watchtower", Vector2i(((center + Vector2(110, -60)) / 16.0).floor()))
	_check(fence_ok and tower_ok, "Xây được hàng rào và tháp canh trong Trại")
	_check(is_equal_approx(base.get_camp_radius(), base.CAMP_RADIUS_START), "Hàng rào, tháp canh không làm Trại rộng ra")
	# Lúc Trại còn nhỏ: quái trong tầm tháp nhưng ngoài vòng Trại thì tháp không bắn.
	for node in base.get_tree().get_nodes_in_group("placed_buildings"):
		if node.building_type_id == &"watchtower":
			var outsider := (load("res://slime.tscn") as PackedScene).instantiate() as Node2D
			scene.add_child(outsider)
			outsider.set_physics_process(false)
			outsider.global_position = node.global_position + ((node.global_position - center).normalized() * 100.0)
			_check(not base.is_in_camp(outsider.global_position) and node._find_tower_target() == null, "Tháp canh không bắn quái ngoài Trại")
			outsider.free()
	_check(base.place_building(&"house", Vector2i(((center + Vector2(-80, -80)) / 16.0).floor())), "Xây được Nhà ở trong Trại")
	_check(is_equal_approx(base.get_camp_radius(), base.CAMP_RADIUS_START + base.CAMP_RADIUS_STEP), "Nhà ở cấp 1 làm Trại rộng thêm một bậc")
	base._exit_build_mode()
	var house: BaseBuilding = null
	var tower: BaseBuilding = null
	var fence: BaseBuilding = null
	for node in base.get_tree().get_nodes_in_group("placed_buildings"):
		match node.building_type_id:
			&"house": house = node
			&"watchtower": tower = node
			&"fence": fence = node
	_check(base.upgrade_house(house) and house.level == 2, "Nâng Nhà ở lên cấp 2")
	_check(is_equal_approx(base.get_camp_radius(), base.CAMP_RADIUS_START + base.CAMP_RADIUS_STEP * 2), "Nâng cấp nhà làm Trại rộng thêm")
	_check(base._get_placement_block_reason(&"fence", far_grid).is_empty() or not base._get_placement_block_reason(&"fence", far_grid).contains("vòng Trại"), "Trại rộng ra thì chỗ cũ ngoài vòng giờ xây được")
	_check(base.upgrade_house(house) and house.level == 3, "Nâng Nhà ở lên cấp 3")
	_check(not base.upgrade_house(house) and house.level == 3, "Cấp 3 là tối đa")
	_check(base.get_camp_radius() <= base.CAMP_RADIUS_MAX, "Trại không rộng quá giới hạn")
	var saved: Dictionary = base.to_dict()
	_check(base.load_from_dict(saved), "Tải lại công trình từ save")
	await process_frame
	var loaded_level := 0
	for node in base.get_tree().get_nodes_in_group("placed_buildings"):
		if node.building_type_id == &"house":
			loaded_level = node.level
		elif node.building_type_id == &"watchtower":
			tower = node
		elif node.building_type_id == &"fence":
			fence = node
	_check(loaded_level == 3, "Save giữ cấp Nhà ở")
	var old_save: Dictionary = saved.duplicate(true)
	for entry in old_save["buildings"]:
		entry.erase("level")
	_check(base.validate_save_data(old_save), "Save cũ chưa có cấp nhà vẫn tải được")

	# Dọn đất: tài nguyên còn thì chặn xây; đã khai thác thì xây lên được và mất hẳn.
	# (2026-11-17) Trại không còn cục đá: thử bằng cây trong Trại.
	var rock: Node2D = scene.get_node("ResourceNodes/BaseTree02")
	var rock_grid := Vector2i((rock.global_position / 16.0).round())
	_check(base._get_placement_block_reason(&"fence", rock_grid).contains("tài nguyên"), "Tài nguyên chưa khai thác chặn xây")
	rock.set_harvested(true, false)
	base._enter_build_mode()
	_check(base.place_building(&"fence", rock_grid), "Xây được lên chỗ tài nguyên đã khai thác")
	base._exit_build_mode()
	_check(rock.is_cleared() and not rock.visible, "Xây lên thì tài nguyên bị dọn hẳn")
	rock.set_harvested(false, false)
	_check(rock.is_harvested and not rock.is_processing(), "Chỗ đã dọn không mọc lại")
	var world_save: Dictionary = root.get_node("WorldState").to_dict()
	_check(str(world_save).contains("cleared_hv_tree_02"), "Cờ dọn đất nằm trong dữ liệu lưu của thế giới")

	# Tháp canh bắn quái đã vào Trại, không bắn quái ngoài Trại.
	var slime_scene := load("res://slime.tscn") as PackedScene
	var intruder := slime_scene.instantiate() as Node2D
	scene.add_child(intruder)
	intruder.global_position = tower.global_position + Vector2(-60, 20)
	intruder.set_physics_process(false)
	await process_frame
	var hp_before: float = intruder.current_health
	tower._tower_timer = 0.0
	for i in 60:
		await physics_frame
	_check(intruder.current_health < hp_before, "Tháp canh bắn trúng quái trong Trại")
	intruder.queue_free()

	# Quái đột kích không nhắm hàng rào, nhưng bị rào chặn thì phá rào.
	var raider := slime_scene.instantiate() as Node2D
	scene.add_child(raider)
	raider.global_position = fence.global_position + Vector2(0, 40)
	raider.enable_raid_mode()
	_check(raider._find_nearest_building() != fence, "Quái đột kích không chọn hàng rào làm mục tiêu")
	raider._raid_target = fence
	raider._raid_retarget_timer = 0.0
	raider._process_raid()
	_check(raider._raid_target == fence, "Đang phá rào thì không bỏ rào đi chỗ khác")
	raider.queue_free()
	var plot: Node2D = scene.get_node("Environment/HopeValleyBasePlot")
	_check(plot.global_position + plot.get_camp_center_local() == center, "Đống lửa vẽ đúng tâm Trại")
	var npc_rect: Rect2 = scene.get_node("NPCManager").get_base_rect()
	_check(npc_rect.has_point(center + Vector2(base.CAMP_RADIUS_MAX - 4, 0)), "Dân làng đi lại được khắp vòng Trại lớn nhất")
	_finish()

func _check(ok: bool, description: String) -> void:
	_total += 1
	if ok:
		_passed += 1
		print("PASS: " + description)
	else:
		printerr("FAIL: " + description)

func _finish() -> void:
	print("Camp checks: %d/%d passed" % [_passed, _total])
	quit(0 if _passed == _total else 1)
