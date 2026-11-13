extends Camera2D

# Ctrl + lăn chuột: phóng to / thu nhỏ trong giới hạn.
# Zoom nhỏ hơn 1 là nhìn được rộng hơn, lớn hơn 1 là nhìn gần hơn.

const ZOOM_MIN: float = 0.75
const ZOOM_MAX: float = 1.5
const ZOOM_STEP: float = 0.125

func _unhandled_input(event: InputEvent) -> void:
	var wheel := event as InputEventMouseButton
	if not wheel or not wheel.pressed or not wheel.ctrl_pressed:
		return
	if wheel.button_index == MOUSE_BUTTON_WHEEL_UP:
		step_zoom(1)
	elif wheel.button_index == MOUSE_BUTTON_WHEEL_DOWN:
		step_zoom(-1)
	else:
		return
	get_viewport().set_input_as_handled()

# direction 1: phóng to, -1: thu nhỏ. Trả về mức zoom mới.
func step_zoom(direction: int) -> float:
	var level := clampf(zoom.x + ZOOM_STEP * direction, ZOOM_MIN, ZOOM_MAX)
	zoom = Vector2(level, level)
	return level
