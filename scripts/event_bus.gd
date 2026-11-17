extends Node

# EventBus - Hệ thống truyền thông tin hướng sự kiện toàn cục
# Không sử dụng làm nơi lưu trữ dữ liệu lâu dài.

# 1. Các tín hiệu chiến đấu & sinh vật
signal enemy_defeated(enemy_id: StringName, region_id: StringName)
signal building_placed(instance_id: StringName, building_type_id: StringName, base_id: StringName)

# 2. Các tín hiệu vật phẩm & thu thập
signal item_collected(item_id: StringName, amount: int)

# 3. Các tín hiệu khám phá & mở khóa thế giới
signal region_discovered(region_id: StringName)
signal region_unlocked(region_id: StringName)
signal world_flag_changed(flag_id: StringName, value: Variant)

# 4. Các tín hiệu nhiệm vụ
signal quest_completed(quest_id: StringName)

# 5. Các tín hiệu gacha & phòng thủ căn cứ
signal gacha_pulled(count: int)
signal raid_repelled(wave: int)

# Lịch sử sự kiện gần nhất phục vụ Debug Panel (tối đa 12 mục)
var recent_event_log: Array[Dictionary] = []
const MAX_LOG_ENTRIES := 12

func _ready() -> void:
	# Kết nối nội bộ để tự động ghi log sự kiện cho Debug Panel
	enemy_defeated.connect(func(e_id: StringName, r_id: StringName):
		_log_event("enemy_defeated", "Quái '%s' bị hạ gục tại vùng '%s'" % [e_id, r_id])
	)
	item_collected.connect(func(i_id: StringName, amt: int):
		_log_event("item_collected", "Thu thập %d x '%s'" % [amt, i_id])
	)
	region_discovered.connect(func(r_id: StringName):
		_log_event("region_discovered", "Phát hiện khu vực mới: '%s'" % r_id)
	)
	region_unlocked.connect(func(r_id: StringName):
		_log_event("region_unlocked", "Mở khóa khu vực: '%s'" % r_id)
	)
	world_flag_changed.connect(func(f_id: StringName, val: Variant):
		_log_event("world_flag_changed", "Flag '%s' = %s" % [f_id, str(val)])
	)
	quest_completed.connect(func(q_id: StringName):
		_log_event("quest_completed", "Hoàn thành nhiệm vụ: '%s'" % q_id)
	)

func _log_event(event_type: String, detail: String) -> void:
	var timestamp := Time.get_time_string_from_system()
	recent_event_log.push_front({
		"time": timestamp,
		"type": event_type,
		"detail": detail
	})
	if recent_event_log.size() > MAX_LOG_ENTRIES:
		recent_event_log.pop_back()

# Lấy bản sao danh sách log gần nhất
func get_recent_logs() -> Array[Dictionary]:
	return recent_event_log.duplicate()
