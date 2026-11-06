extends Node

# PlayerAnimationController component
@export var anim_player: AnimationPlayer
@export var sprite: Sprite2D

var current_facing: String = "down" # "down", "up", "left", "right"
var is_locked: bool = false # Khóa animation khi đang né, chém hoặc gục

func _ready() -> void:
	if not anim_player:
		anim_player = get_parent().get_node_or_null("AnimationPlayer")
	if not sprite:
		sprite = get_parent().get_node_or_null("Sprite2D")

# Chuyển đổi vector 8 hướng thành 4 hướng chính (Down, Up, Left, Right)
func get_cardinal_direction(dir: Vector2) -> String:
	if dir == Vector2.ZERO:
		return current_facing
	if absf(dir.x) > absf(dir.y):
		return "right" if dir.x > 0.0 else "left"
	else:
		return "down" if dir.y > 0.0 else "up"

# Cập nhật hướng nhìn hiện tại
func set_facing(dir: Vector2) -> void:
	if dir != Vector2.ZERO:
		current_facing = get_cardinal_direction(dir)

# Cập nhật animation di chuyển / đứng yên hàng frame
func update_movement_animation(velocity: Vector2, is_sprinting: bool, move_dir: Vector2) -> void:
	if is_locked:
		return

	if move_dir != Vector2.ZERO:
		set_facing(move_dir)

	var speed := velocity.length()
	if speed > 10.0:
		if sprite:
			sprite.scale = Vector2(0.135, 0.135)
		if is_sprinting:
			_play_anim("run_" + current_facing)
		else:
			_play_anim("walk_" + current_facing)
	else:
		_play_anim("idle_" + current_facing)

# Phát animation né tránh
func play_dodge(dir: Vector2) -> void:
	set_facing(dir)
	is_locked = true
	_play_anim("dodge_" + current_facing)

# Kết thúc né tránh
func end_dodge() -> void:
	is_locked = false

# Phát animation vung kiếm theo hướng chuột
func play_attack(dir: Vector2) -> void:
	set_facing(dir)
	is_locked = true
	_play_anim("attack_" + current_facing)

# Kết thúc vung kiếm
func end_attack() -> void:
	is_locked = false

# Phát animation nhận sát thương
func play_hurt() -> void:
	if anim_player and anim_player.has_animation("hurt"):
		anim_player.play("hurt")

# Phát animation gục ngã
func play_die() -> void:
	is_locked = true
	if anim_player and anim_player.has_animation("die"):
		anim_player.play("die")

func _play_anim(anim_name: String) -> void:
	if anim_player and anim_player.has_animation(anim_name):
		if anim_player.current_animation != anim_name:
			anim_player.play(anim_name)
