extends Node

# WorldClock - Đồng hồ thế giới dùng chung (Bước 21.3).
# Thời gian chỉ trôi khi đang chơi: dừng khi game tạm dừng, không tính lúc tắt game,
# và được SaveManager lưu nên F9 quay về đúng thời điểm trong bản lưu.

const SCHEMA_VERSION: int = 1

var _elapsed: float = 0.0

func _process(delta: float) -> void:
	_elapsed += delta

func get_time() -> float:
	return _elapsed

func advance(seconds: float) -> void:
	if seconds > 0.0:
		_elapsed += seconds

func to_dict() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "elapsed": _elapsed}

static func is_valid_snapshot(data: Variant) -> bool:
	if not data is Dictionary or int(data.get("schema_version", 0)) > SCHEMA_VERSION:
		return false
	var elapsed := float(data.get("elapsed", 0.0))
	return is_finite(elapsed) and elapsed >= 0.0

# Save cũ không có đồng hồ sẽ bắt đầu lại từ 0; mốc hồi sinh của chúng được tạo mới khi tải.
func load_from_dict(data: Dictionary) -> bool:
	if not is_valid_snapshot(data):
		return false
	_elapsed = float(data.get("elapsed", 0.0))
	return true
