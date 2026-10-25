## Reusable low-poly operator model.
##
## The same procedural model is used by the lobby preview, the local player and
## remote players. It is deliberately built from simple primitives so the whole
## roster stays original, lightweight and easy to customize at runtime.

extends Node3D

const Characters := preload("res://shared/characters.gd")

var appearance: Dictionary = {}
var first_person := false

var _root: Node3D
var _head_group: Node3D
var _materials := {}

func _ready() -> void:
	if appearance.is_empty():
		appearance = Characters.default_appearance(0)
	_rebuild()

func apply_appearance(value: Dictionary) -> void:
	var safe := Characters.sanitize(value)
	if appearance == safe:
		return
	appearance = safe
	if is_inside_tree():
		_rebuild()

func set_first_person(value: bool) -> void:
	if first_person == value:
		return
	first_person = value
	if is_inside_tree():
		_rebuild()

func get_appearance() -> Dictionary:
	return appearance.duplicate(true)

func _rebuild() -> void:
	if _root != null and is_instance_valid(_root):
		remove_child(_root)
		_root.free()
	_root = null
	_head_group = null

	var safe := Characters.sanitize(appearance)
	appearance = safe
	var index := int(safe["character"])
	var character: Dictionary = Characters.get_character(index)
	var primary: Color = safe["primary"]
	var secondary: Color = safe["secondary"]
	var accent: Color = safe["accent"]
	var skin: Color = character["skin"]
	var hair: Color = character["hair"]
	var outfit := int(safe["outfit"])
	var headgear := int(character["headgear"])

	_root = Node3D.new()
	_root.name = "Rig"
	add_child(_root)

	# Legs and boots.
	for side in [-1.0, 1.0]:
		_add_box(_root, "Thigh", Vector3(0.19, 0.34, 0.21), Vector3(0.13 * side, 0.55, 0.0), primary)
		_add_box(_root, "Shin", Vector3(0.17, 0.32, 0.19), Vector3(0.13 * side, 0.26, 0.0), secondary)
		_add_box(_root, "Boot", Vector3(0.20, 0.16, 0.27), Vector3(0.13 * side, 0.08, -0.03), accent)

	# Hips and torso.
	_add_box(_root, "Hips", Vector3(0.44, 0.24, 0.28), Vector3(0.0, 0.82, 0.0), secondary)
	_add_box(_root, "Torso", Vector3(0.52, 0.62, 0.30), Vector3(0.0, 1.18, 0.0), primary)

	# Arms. The hands use skin tone; sleeves use the outfit colors.
	for side in [-1.0, 1.0]:
		_add_box(_root, "UpperArm", Vector3(0.15, 0.30, 0.17), Vector3(0.35 * side, 1.25, 0.0), primary)
		_add_box(_root, "Forearm", Vector3(0.13, 0.30, 0.15), Vector3(0.35 * side, 0.98, 0.0), secondary)
		_add_sphere(_root, "Hand", 0.085, Vector3(0.35 * side, 0.81, 0.0), skin)

	_add_cylinder(_root, "Neck", 0.08, 0.08, 0.12, Vector3(0.0, 1.53, 0.0), skin)

	_head_group = Node3D.new()
	_head_group.name = "HeadGroup"
	_root.add_child(_head_group)

	_add_sphere(_head_group, "Head", 0.17, Vector3(0.0, 1.66, 0.0), skin, 0.34)
	_add_hemisphere(_head_group, "Hair", 0.185, Vector3(0.0, 1.75, 0.01), hair, 0.16)
	_add_box(_head_group, "EyeL", Vector3(0.035, 0.025, 0.02), Vector3(-0.065, 1.69, -0.158), Color(0.03, 0.03, 0.04))
	_add_box(_head_group, "EyeR", Vector3(0.035, 0.025, 0.02), Vector3(0.065, 1.69, -0.158), Color(0.03, 0.03, 0.04))

	_build_outfit(outfit, secondary, accent)
	_build_headgear(headgear, secondary, accent)

	if first_person:
		_head_group.visible = false

func _build_outfit(outfit: int, secondary: Color, accent: Color) -> void:
	match outfit:
		1:
			# Hoodie: soft hood behind the head, front pocket and drawstrings.
			_add_box(_root, "HoodBack", Vector3(0.30, 0.30, 0.13), Vector3(0.0, 1.68, 0.15), secondary)
			_add_torus(_root, "HoodCollar", 0.12, 0.22, 0.14, Vector3(0.0, 1.52, 0.02), secondary)
			_add_box(_root, "Pocket", Vector3(0.30, 0.16, 0.05), Vector3(0.0, 1.00, -0.17), secondary)
			_add_box(_root, "StringL", Vector3(0.025, 0.22, 0.025), Vector3(-0.06, 1.36, -0.17), accent)
			_add_box(_root, "StringR", Vector3(0.025, 0.22, 0.025), Vector3(0.06, 1.36, -0.17), accent)
		2:
			# Armored: chest plate, shoulder guards, collar and knee pads.
			_add_box(_root, "ChestPlate", Vector3(0.60, 0.50, 0.38), Vector3(0.0, 1.18, 0.0), secondary)
			_add_box(_root, "Collar", Vector3(0.40, 0.10, 0.34), Vector3(0.0, 1.48, 0.0), accent)
			for side in [-1.0, 1.0]:
				_add_box(_root, "Shoulder", Vector3(0.22, 0.16, 0.26), Vector3(0.38 * side, 1.42, 0.0), accent)
				_add_box(_root, "Knee", Vector3(0.21, 0.14, 0.23), Vector3(0.13 * side, 0.32, -0.02), secondary)
			_add_box(_root, "Backpack", Vector3(0.36, 0.38, 0.16), Vector3(0.0, 1.20, 0.22), secondary)
			_add_box(_root, "Belt", Vector3(0.46, 0.08, 0.32), Vector3(0.0, 0.95, 0.0), accent)
		3:
			# Runner: cropped vest, side stripes and light arm bands.
			_add_box(_root, "Vest", Vector3(0.56, 0.24, 0.33), Vector3(0.0, 1.34, 0.0), secondary)
			_add_box(_root, "Belt", Vector3(0.46, 0.07, 0.31), Vector3(0.0, 0.96, 0.0), accent)
			for side in [-1.0, 1.0]:
				_add_box(_root, "LegStripe", Vector3(0.035, 0.50, 0.02), Vector3(0.225 * side, 0.48, -0.105), accent)
				_add_box(_root, "ArmBand", Vector3(0.17, 0.05, 0.18), Vector3(0.35 * side, 1.09, 0.0), accent)
		_:
			# Tactical: vest, pouches, shoulder pads and a utility belt.
			_add_box(_root, "Vest", Vector3(0.56, 0.40, 0.34), Vector3(0.0, 1.20, 0.0), secondary)
			_add_box(_root, "Belt", Vector3(0.46, 0.08, 0.30), Vector3(0.0, 0.95, 0.0), accent)
			for side in [-1.0, 1.0]:
				_add_box(_root, "Shoulder", Vector3(0.18, 0.12, 0.22), Vector3(0.36 * side, 1.42, 0.0), secondary)
				_add_box(_root, "Pouch", Vector3(0.12, 0.12, 0.05), Vector3(0.17 * side, 1.07, -0.18), accent)
			_add_box(_root, "Backpack", Vector3(0.34, 0.34, 0.14), Vector3(0.0, 1.20, 0.21), secondary)

func _build_headgear(headgear: int, secondary: Color, accent: Color) -> void:
	match headgear:
		1:
			_add_cylinder(_head_group, "Cap", 0.18, 0.18, 0.10, Vector3(0.0, 1.82, 0.0), secondary)
			_add_box(_head_group, "CapBrim", Vector3(0.34, 0.04, 0.22), Vector3(0.0, 1.78, -0.13), secondary)
			_add_box(_head_group, "CapBand", Vector3(0.36, 0.035, 0.20), Vector3(0.0, 1.77, -0.02), accent)
		2:
			_add_hemisphere(_head_group, "Helmet", 0.20, Vector3(0.0, 1.76, 0.0), secondary, 0.22)
			_add_box(_head_group, "Visor", Vector3(0.28, 0.08, 0.06), Vector3(0.0, 1.70, -0.17), accent)
			for side in [-1.0, 1.0]:
				_add_box(_head_group, "EarPad", Vector3(0.05, 0.13, 0.12), Vector3(0.19 * side, 1.68, 0.0), secondary)
		3:
			_add_box(_head_group, "HoodBack", Vector3(0.32, 0.34, 0.14), Vector3(0.0, 1.68, 0.15), secondary)
			_add_torus(_head_group, "HoodCollar", 0.12, 0.22, 0.12, Vector3(0.0, 1.54, 0.02), secondary)
			_add_box(_head_group, "HoodTrim", Vector3(0.30, 0.035, 0.05), Vector3(0.0, 1.84, -0.05), accent)

func _add_box(parent: Node3D, node_name: String, size: Vector3, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := BoxMesh.new()
	mesh.size = size
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = _material(color)
	# LOD: fade out distant parts.
	instance.visibility_range_begin = 0.0
	instance.visibility_range_end = 50.0
	instance.visibility_range_end_margin = 5.0
	parent.add_child(instance)
	return instance

func _add_sphere(parent: Node3D, node_name: String, radius: float, pos: Vector3, color: Color, height := -1.0) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0 if height < 0.0 else height
	mesh.radial_segments = 12
	mesh.rings = 6
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = _material(color)
	# LOD: fade out distant parts.
	instance.visibility_range_begin = 0.0
	instance.visibility_range_end = 50.0
	instance.visibility_range_end_margin = 5.0
	parent.add_child(instance)
	return instance

func _add_hemisphere(parent: Node3D, node_name: String, radius: float, pos: Vector3, color: Color, height: float) -> MeshInstance3D:
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = height
	mesh.is_hemisphere = true
	mesh.radial_segments = 12
	mesh.rings = 5
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = _material(color)
	# LOD: fade out distant parts.
	instance.visibility_range_begin = 0.0
	instance.visibility_range_end = 50.0
	instance.visibility_range_end_margin = 5.0
	parent.add_child(instance)
	return instance

func _add_cylinder(parent: Node3D, node_name: String, top_radius: float, bottom_radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := CylinderMesh.new()
	mesh.top_radius = top_radius
	mesh.bottom_radius = bottom_radius
	mesh.height = height
	mesh.radial_segments = 12
	mesh.rings = 1
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = pos
	instance.material_override = _material(color)
	# LOD: fade out distant parts.
	instance.visibility_range_begin = 0.0
	instance.visibility_range_end = 50.0
	instance.visibility_range_end_margin = 5.0
	parent.add_child(instance)
	return instance

func _add_torus(parent: Node3D, node_name: String, inner_radius: float, outer_radius: float, height: float, pos: Vector3, color: Color) -> MeshInstance3D:
	var mesh := TorusMesh.new()
	mesh.inner_radius = inner_radius
	mesh.outer_radius = outer_radius
	mesh.rings = 12
	mesh.ring_segments = 6
	var instance := MeshInstance3D.new()
	instance.name = node_name
	instance.mesh = mesh
	instance.position = pos
	instance.scale = Vector3(1.0, maxf(0.8, height * 6.0), 1.0)
	instance.material_override = _material(color)
	# LOD: fade out distant parts.
	instance.visibility_range_begin = 0.0
	instance.visibility_range_end = 50.0
	instance.visibility_range_end_margin = 5.0
	parent.add_child(instance)
	return instance

func _material(color: Color) -> StandardMaterial3D:
	var key := color.to_html(false)
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.82
	material.metallic = 0.08
	_materials[key] = material
	return material
