extends Camera3D
## @brief Orbital camera controller for the 3D chess board.
## @details Allows rotation around the board with right-click drag, and zoom with scroll wheel.

## Rotation speed in radians per pixel of mouse movement.
@export var rotation_speed: float = 0.005
## Zoom speed multiplier per scroll step.
@export var zoom_speed: float = 0.5
## Minimum distance from pivot.
@export var min_distance: float = 5.0
## Maximum distance from pivot.
@export var max_distance: float = 25.0

var _dragging: bool = false
var _distance: float = 12.0
var _yaw: float = 0.0
var _pitch: float = -1.05  # ~60 degrees down

func _ready() -> void:
	_update_transform()

func _input(event: InputEvent) -> void:
	if event is InputEventMouseButton:
		if event.button_index == MOUSE_BUTTON_RIGHT:
			_dragging = event.pressed
		elif event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_distance = max(min_distance, _distance - zoom_speed)
			_update_transform()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_distance = min(max_distance, _distance + zoom_speed)
			_update_transform()

	if event is InputEventMouseMotion and _dragging:
		_yaw -= event.relative.x * rotation_speed
		_pitch -= event.relative.y * rotation_speed
		_pitch = clamp(_pitch, -PI / 2.0 + 0.1, -0.2)
		_update_transform()

func _update_transform() -> void:
	var offset = Vector3(
		_distance * cos(_pitch) * sin(_yaw),
		-_distance * sin(_pitch),
		_distance * cos(_pitch) * cos(_yaw)
	)
	position = offset
	look_at(get_parent().global_position, Vector3.UP)
