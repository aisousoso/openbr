extends Node3D

## Client-side visualization of the authoritative shrinking storm.
## The server sends center/radius in every snapshot; this node smooths the
## 20 Hz updates so the wall and ground ring move continuously.

@onready var wall: MeshInstance3D = $Wall
@onready var ring: MeshInstance3D = $Ring

var _center := Vector2.ZERO
var _target_center := Vector2.ZERO
var _radius := 54.0
var _target_radius := 54.0
var _has_state := false

func _ready() -> void:
	visible = false
	_apply()

func set_state(cx: float, cz: float, radius: float) -> void:
	_target_center = Vector2(cx, cz)
	_target_radius = maxf(radius, 0.5)
	if not _has_state:
		_center = _target_center
		_radius = _target_radius
		_has_state = true
	visible = true
	_apply()

func reset() -> void:
	_has_state = false
	visible = false

func _process(delta: float) -> void:
	if not _has_state:
		return

	var t := clampf(delta * 8.0, 0.0, 1.0)
	_radius = lerpf(_radius, _target_radius, t)
	_center = _center.lerp(_target_center, t)
	_apply()

func _apply() -> void:
	global_position = Vector3(_center.x, 0.0, _center.y)
	# The wall and ring meshes are unit-sized, so scaling avoids rebuilding
	# mesh arrays every frame while the storm shrinks.
	wall.scale = Vector3(_radius, 30.0, _radius)
	wall.position = Vector3(0.0, 15.0, 0.0)
	ring.scale = Vector3(_radius, 1.0, _radius)
