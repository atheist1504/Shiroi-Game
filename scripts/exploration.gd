extends RefCounted

# % khám phá của từng khu và cả vùng, dùng trên bản đồ M.
# Mỗi khu đếm: đã đặt chân tới khu, cột mốc đã kích hoạt, điểm tài nguyên đã tự tay
# thu thập ít nhất một lần (cờ "touched_<node_id>"), điểm khám phá đã khám phá.
# Thêm loại nội dung mới (rương, quái tinh anh...) thì cộng vào _items().

# Trả về Vector2i(đã xong, tổng) cho các thứ nằm trong rect; rect rỗng = cả vùng.
static func count(tree: SceneTree, rect: Rect2 = Rect2()) -> Vector2i:
	var done := 0
	var total := 0
	for item in _items(tree):
		var position: Vector2 = item[0]
		if rect.has_area() and not rect.has_point(position):
			continue
		total += 1
		if item[1]:
			done += 1
	return Vector2i(done, total)

static func percent(progress: Vector2i) -> int:
	return 0 if progress.y <= 0 else int(floor(100.0 * progress.x / progress.y))

# Tiến độ của một khu (node map_zone): cộng thêm 1 mục "đã đặt chân tới khu".
static func zone_progress(tree: SceneTree, zone: Node2D) -> Vector2i:
	var progress := count(tree, Rect2(zone.global_position, zone.get("zone_size")))
	var region_id: StringName = zone.get("region_id")
	if region_id != StringName():
		progress += Vector2i(1 if _world(tree).is_region_discovered(region_id) else 0, 1)
	return progress

# Tiến độ cả vùng: mọi mục trên bản đồ cộng các khu đã đặt chân tới.
static func region_progress(tree: SceneTree, zones: Array) -> Vector2i:
	var progress := count(tree)
	for zone in zones:
		var region_id: StringName = zone.get("region_id")
		if region_id != StringName():
			progress += Vector2i(1 if _world(tree).is_region_discovered(region_id) else 0, 1)
	return progress

static func _world(tree: SceneTree) -> Node:
	return tree.root.get_node("WorldState")

# Danh sách [vị trí, đã xong] của mọi mục được tính.
static func _items(tree: SceneTree) -> Array:
	var world := _world(tree)
	var items: Array = []
	for beacon in tree.get_nodes_in_group("beacons"):
		items.append([beacon.global_position, bool(beacon.call("is_active"))])
	for node in tree.get_nodes_in_group("resource_nodes"):
		items.append([node.global_position, world.get_flag(StringName("touched_" + str(node.get("node_id"))), false) == true])
	for point in tree.get_nodes_in_group("discovery_points"):
		items.append([point.global_position, world.is_region_discovered(point.get("region_id"))])
	return items
