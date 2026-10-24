extends Node3D

## Remote players are visual proxies: the server owns their position and
## their alive state. Snapshots arrive at 20 Hz, so interpolate.

@export var interpolation_speed := 15.0

var is_alive := true

var _target_pos := Vector3.ZERO
var _target_yaw := 0.0
var _has_target := false

@onready var model: Node3D = $Model

func set_target(pos: Vector3, yaw: float) -> void:
	_target_pos = pos
	_target_yaw = yaw
	if not _has_target:
		global_position = pos
		rotation.y = yaw
	_has_target = true

func apply_appearance(appearance: Dictionary) -> void:
	if model != null and model.has_method("apply_appearance"):
		model.apply_appearance(appearance)

func set_alive(value: bool) -> void:
	is_alive = value
	if model != null:
		model.visible = value

func _process(delta: float) -> void:
	if not _has_target:
		return
	var t := clampf(delta * interpolation_speed, 0.0, 1.0)
	global_position = global_position.lerp(_target_pos, t)
	rotation.y = lerp_angle(rotation.y, _target_yaw, t)
