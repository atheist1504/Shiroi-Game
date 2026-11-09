extends Node

# WalletManager - Ví vàng và Tinh Vẫn, không chiếm ô túi đồ.

signal wallet_changed

const SCHEMA_VERSION: int = 1

var _gold: int = 0
var _tinh_van: int = 0

func get_gold() -> int:
	return _gold

func get_tinh_van() -> int:
	return _tinh_van

func add_gold(amount: int) -> bool:
	if amount <= 0:
		return false
	_gold += amount
	wallet_changed.emit()
	return true

func add_tinh_van(amount: int) -> bool:
	if amount <= 0:
		return false
	_tinh_van += amount
	wallet_changed.emit()
	return true

func spend_tinh_van(amount: int) -> bool:
	if amount <= 0 or _tinh_van < amount:
		return false
	_tinh_van -= amount
	wallet_changed.emit()
	return true

func to_dict() -> Dictionary:
	return {"schema_version": SCHEMA_VERSION, "gold": _gold, "tinh_van": _tinh_van}

static func is_valid_snapshot(data: Variant) -> bool:
	if not data is Dictionary or int(data.get("schema_version", 0)) > SCHEMA_VERSION:
		return false
	return int(data.get("gold", 0)) >= 0 and int(data.get("tinh_van", 0)) >= 0

# Save cũ không có ví sẽ bắt đầu với ví rỗng.
func load_from_dict(data: Dictionary) -> bool:
	if not is_valid_snapshot(data):
		return false
	_gold = int(data.get("gold", 0))
	_tinh_van = int(data.get("tinh_van", 0))
	wallet_changed.emit()
	return true
