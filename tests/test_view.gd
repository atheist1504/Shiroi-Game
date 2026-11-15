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
	_check(image.get_size() == Vector2i(320, 134), "Bản đồ nhỏ mỗi ô tile một điểm ảnh (cả bản đồ nối ra lục địa)")
	var origin: Vector2i = scene.get_node("Environment/Terrain").MAP_ORIGIN
	var water := image.get_pixelv(Vector2i(Vector2(260, 1040) / 16.0) - origin)
	var grass := image.get_pixelv(Vector2i(Vector2(640, 330) / 16.0) - origin)
	var dirt := image.get_pixelv(Vector2i(Vector2(900, 600) / 16.0) - origin)
	_check(water != grass and dirt != grass, "Nước, cỏ, đất trên bản đồ nhỏ khác màu nhau")
	_check(int(terrain.get_ground_at(Vector2(260, 1040))) == terrain.Ground.WATER, "Điểm thử đúng là nước")
	var frame: Control = minimap.get_node("MinimapFrame")
	_check(minimap.get("_map_rect").texture != null and frame.visible, "Bản đồ nhỏ hiện trên màn hình")
	player.global_position = Vector2(1280, 720)
	await process_frame
	var dot: ColorRect = minimap.get("_player_dot")
	var map_rect: TextureRect = minimap.get("_map_rect")
	_check(dot.position.distance_to(minimap.DISPLAY_SIZE * 0.5 - Vector2.ONE * 2.0) < 1.0, "Chấm người chơi luôn ở giữa bản đồ nhỏ")
	_check(map_rect.size.x > minimap.DISPLAY_SIZE.x * 2.0, "Bản đồ nhỏ phóng to, chỉ thấy vùng quanh người chơi")
	_check(minimap.world_to_minimap(player.global_position).distance_to(minimap.DISPLAY_SIZE * 0.5) < 0.01, "Vị trí người chơi ứng với giữa khung")
	var cell_px: float = minimap.MINIMAP_PIXELS_PER_CELL
	var visible_cells: Vector2 = minimap.DISPLAY_SIZE / cell_px
	_check(visible_cells.x * 16.0 > 640.0 and visible_cells.x * 16.0 < 1000.0, "Bản đồ nhỏ thấy rộng hơn màn hình một chút")
	var before := map_rect.position
	player.global_position += Vector2(160, 0)
	await process_frame
	_check(is_equal_approx(before.x - map_rect.position.x, 10.0 * cell_px), "Đi sang phải thì bản đồ trượt sang trái theo")
	player.global_position = Vector2(1280, 720)
	await process_frame
	var frame_right: float = frame.position.x + frame.size.x
	_check(frame.position.y < 20.0 and frame_right > 600.0 and frame_right <= 640.0, "Bản đồ nhỏ nằm ở góc trên phải")
	_check(is_equal_approx(minimap.DISPLAY_SIZE.x, minimap.DISPLAY_SIZE.y) and map_rect.material is ShaderMaterial, "Bản đồ nhỏ hình tròn (khung vuông, mặt nạ tròn)")
	_check(map_rect.texture == minimap.get("_world_rect").texture, "Bản đồ nhỏ dùng chung ảnh với bản đồ M (cả phần viền dưới mây)")
	await process_frame
	var shared_img: Image = map_rect.texture.get_image()
	var mini_uv: Vector2 = (minimap.DISPLAY_SIZE * 0.5 - map_rect.position) / map_rect.size
	var big_uv: Vector2 = minimap.world_to_world_map(player.global_position) / minimap.WORLD_MAP_SIZE
	_check(mini_uv.distance_to(big_uv) < 0.01, "Giữa bản đồ nhỏ và chấm trên bản đồ M chỉ cùng một chỗ")
	_check(shared_img.get_pixel(4, 4).get_luminance() < 0.2 and shared_img.get_pixel(4, 4).a > 0.9, "Ngoài rừng trên bản đồ nhỏ là lục địa dưới mây, không để trống")

	# Bản đồ thế giới phím M.
	var world_layer: CanvasLayer = minimap.get_node("WorldMap")
	_check(not world_layer.visible, "Bản đồ thế giới mặc định đóng")
	paused = false
	minimap._unhandled_input(_key(KEY_M))
	_check(world_layer.visible and paused, "Ấn M mở bản đồ thế giới và tạm dừng")
	var labels: Control = minimap.get("_world_labels")
	var forest: Label = labels.get_node_or_null("Zone_ForestZone")
	var swamp: Label = labels.get_node_or_null("Zone_IronMineZone")
	var world_state := root.get_node("/root/WorldState")
	var forest_known: bool = world_state.is_region_discovered(&"zone_forest")
	_check(forest != null and forest.text == ("KHU RỪNG" if forest_known else "???"), "Vùng rừng hiện tên hay ??? theo đã khám phá")
	_check(swamp != null and labels.get_child_count() >= 7, "Bản đồ thế giới ghi đủ các vùng")
	var world_dot: ColorRect = minimap.get("_world_dot")
	var expected_dot: Vector2 = minimap.world_to_world_map(player.global_position) - Vector2.ONE * 3.0
	var region_rect: Rect2 = minimap.get_region_rect_on_world_map()
	_check(world_dot.position.distance_to(expected_dot) < 1.0 and region_rect.has_point(world_dot.position), "Chấm người chơi nằm trong vùng đang chơi trên bản đồ thế giới")
	_check(region_rect.size.y < minimap.WORLD_MAP_SIZE.y * 0.8 and region_rect.position.y > 0.0, "Bản đồ M thấy cả lục địa, vùng chơi là phần phía nam")
	var world_img: Image = (minimap.get("_world_rect").texture as Texture2D).get_image()
	var inside_px: Color = world_img.get_pixelv(Vector2i(region_rect.get_center() / minimap.WORLD_MAP_SIZE * Vector2(world_img.get_size())))
	var fog_px: Color = world_img.get_pixel(30, 30)
	_check(fog_px.get_luminance() < 0.2 and inside_px.get_luminance() > fog_px.get_luminance() * 2.0, "Ngoài vùng đang chơi bị mây đen che")
	_check(labels.get_node_or_null("RegionName") != null and (labels.get_node("RegionName") as Label).text == "RỪNG NGUYỆT ẢNH", "Bản đồ M ghi tên Rừng Nguyệt Ảnh")
	minimap._input(_key(KEY_ESCAPE))
	_check(not world_layer.visible and not paused, "Esc đóng bản đồ và chạy tiếp")
	world_state.discover_region(&"zone_iron_mine")
	minimap._unhandled_input(_key(KEY_M))
	_check((labels.get_node("Zone_IronMineZone") as Label).text == "MỎ SẮT", "Vùng vừa khám phá hiện tên")
	# Mở bản đồ theo chỗ đã đi; nút ◆ ở Trại để dịch chuyển về.
	minimap.reveal_around(player.global_position)
	_check(minimap.is_revealed(player.global_position) and not minimap.is_revealed(Vector2(3300, 1100)), "Bản đồ M mở chỗ đã đi, chỗ chưa tới còn che")
	_check(world_state.get_flag(&"map_revealed", null) is Array, "Phần bản đồ đã mở lưu trong WorldState")
	_check(labels.get_node_or_null("CampTeleport") != null and labels.get_node_or_null("RevealFog") != null, "Bản đồ M có lớp che và nút dịch chuyển về Trại")
	minimap._input(_key(KEY_M))
	_check(not world_layer.visible and not paused, "Ấn M lần nữa thì đóng")
	var night_node := scene.get_node_or_null("FirstNight")
	if night_node:
		night_node.set_process(false)
	var player_spot := player.global_position
	player.global_position = Vector2(1500, 300)
	minimap.set_world_map_open(true)
	_check(minimap.teleport_to_camp() and player.global_position.distance_to(minimap.CAMP_TELEPORT_POSITION) < 4.0 and not world_layer.visible, "Bấm ◆ dịch chuyển về Trại rồi đóng bản đồ")
	player.global_position = player_spot
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
