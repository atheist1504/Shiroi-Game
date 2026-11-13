extends SceneTree

# Ctrl + lăn chuột phóng to thu nhỏ trong giới hạn; bản đồ nhỏ.

var _passed := 0
var _total := 0

func _initialize() -> void:
	call_deferred("_run")

func _run() -> void:
	var scene := (load("res://main.tscn") as PackedScene).instantiate()
	root.add_child(scene)
	current_scene = scene
	await process_frame
	var player: Node2D = scene.get_node("Player")
	var camera: Camera2D = player.get_node("Camera2D")
	var minimap: Node = scene.get_node("Minimap")
	var terrain: Node = scene.get_node("Environment/Terrain")

	# Phóng to thu nhỏ.
	_check(camera.zoom == Vector2.ONE, "Mặc định zoom 1")
	camera._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_UP, false))
	_check(camera.zoom == Vector2.ONE, "Lăn chuột không giữ Ctrl thì không zoom")
	camera._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_UP, true))
	_check(camera.zoom.x > 1.0, "Ctrl + lăn lên thì phóng to")
	for _i in 20:
		camera._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_UP, true))
	_check(is_equal_approx(camera.zoom.x, camera.ZOOM_MAX), "Phóng to dừng ở mức tối đa")
	for _i in 20:
		camera._unhandled_input(_wheel(MOUSE_BUTTON_WHEEL_DOWN, true))
	_check(is_equal_approx(camera.zoom.x, camera.ZOOM_MIN) and camera.ZOOM_MIN < 1.0, "Thu nhỏ dừng ở mức tối thiểu")

	# Bản đồ nhỏ.
	var image: Image = minimap.build_map_image()
	_check(image.get_size() == Vector2i(160, 90), "Bản đồ nhỏ mỗi ô tile một điểm ảnh")
	var water := image.get_pixelv(Vector2i(Vector2(260, 1040) / 16.0))
	var grass := image.get_pixelv(Vector2i(10, 10))
	var dirt := image.get_pixelv(Vector2i(Vector2(900, 600) / 16.0))
	_check(water != grass and dirt != grass, "Nước, cỏ, đất trên bản đồ nhỏ khác màu nhau")
	_check(int(terrain.get_ground_at(Vector2(260, 1040))) == terrain.Ground.WATER, "Điểm thử đúng là nước")
	var frame: Control = minimap.get_node("MinimapFrame")
	_check(minimap.get("_map_rect").texture != null and frame.visible, "Bản đồ nhỏ hiện trên màn hình")
	_check(minimap.world_to_minimap(Vector2.ZERO) == Vector2.ZERO and minimap.world_to_minimap(Vector2(2560, 1440)) == minimap.DISPLAY_SIZE, "Góc bản đồ khớp góc khung bản đồ nhỏ")
	player.global_position = Vector2(1280, 720)
	await process_frame
	var dot: ColorRect = minimap.get("_player_dot")
	_check(dot.position.distance_to(minimap.DISPLAY_SIZE * 0.5 - Vector2.ONE * 2.0) < 1.0, "Chấm người chơi đi theo vị trí")
	var frame_right: float = frame.position.x + frame.size.x
	_check(frame.position.y < 20.0 and frame_right > 600.0 and frame_right <= 640.0, "Bản đồ nhỏ nằm ở góc trên phải")

	# Bản đồ thế giới phím M.
	var world_layer: CanvasLayer = minimap.get_node("WorldMap")
	_check(not world_layer.visible, "Bản đồ thế giới mặc định đóng")
	paused = false
	minimap._unhandled_input(_key(KEY_M))
	_check(world_layer.visible and paused, "Ấn M mở bản đồ thế giới và tạm dừng")
	var labels: Control = minimap.get("_world_labels")
	var forest: Label = labels.get_node_or_null("Zone_ForestZone")
	var swamp: Label = labels.get_node_or_null("Zone_SwampZone")
	var world_state := root.get_node("/root/WorldState")
	var forest_known: bool = world_state.is_region_discovered(&"zone_forest")
	_check(forest != null and forest.text == ("KHU RỪNG" if forest_known else "???"), "Vùng rừng hiện tên hay ??? theo đã khám phá")
	_check(swamp != null and labels.get_child_count() >= 8, "Bản đồ thế giới ghi đủ các vùng")
	var world_dot: ColorRect = minimap.get("_world_dot")
	_check(world_dot.position.distance_to(minimap.WORLD_MAP_SIZE * 0.5 - Vector2.ONE * 3.0) < 1.0, "Chấm người chơi trên bản đồ thế giới đúng chỗ")
	minimap._input(_key(KEY_ESCAPE))
	_check(not world_layer.visible and not paused, "Esc đóng bản đồ và chạy tiếp")
	world_state.discover_region(&"zone_swamp")
	minimap._unhandled_input(_key(KEY_M))
	_check((labels.get_node("Zone_SwampZone") as Label).text == "ĐẦM LẦY", "Vùng vừa khám phá hiện tên")
	minimap._input(_key(KEY_M))
	_check(not world_layer.visible and not paused, "Ấn M lần nữa thì đóng")
	paused = true
	minimap._unhandled_input(_key(KEY_M))
	_check(not world_layer.visible, "Đang tạm dừng (menu, túi đồ) thì M không mở")
	paused = false
	_finish()

func _key(keycode: Key) -> InputEventKey:
	var event := InputEventKey.new()
	event.physical_keycode = keycode
	event.pressed = true
	return event

func _wheel(button: MouseButton, ctrl: bool) -> InputEventMouseButton:
	var event := InputEventMouseButton.new()
	event.button_index = button
	event.pressed = true
	event.ctrl_pressed = ctrl
	return event

func _check(ok: bool, description: String) -> void:
	_total += 1
	if ok:
		_passed += 1
		print("PASS: " + description)
	else:
		printerr("FAIL: " + description)

func _finish() -> void:
	print("View checks: %d/%d passed" % [_passed, _total])
	quit(0 if _passed == _total else 1)
