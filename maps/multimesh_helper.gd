## MultiMesh helper — creates a MultiMeshInstance3D from a list of transforms.
## Reduces draw calls for repeated props (rocks, bushes, lamps).

extends RefCounted

static func create_sphere_multimesh(parent: Node3D, name: String, radius: float, color: Color, positions: Array[Vector3], collision: bool = false) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	mm.mesh = SphereMesh.new()
	mm.mesh.radius = radius
	mm.mesh.height = radius * 2.0
	mm.instance_count = positions.size()

	var mmi := MultiMeshInstance3D.new()
	mmi.name = name
	mmi.multimesh = mm

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.86
	mmi.material_override = mat

	for i in positions.size():
		var t := Transform3D()
		t.origin = positions[i]
		mm.set_instance_transform(i, t)

	parent.add_child(mmi)
	return mmi

static func create_box_multimesh(parent: Node3D, name: String, size: Vector3, color: Color, positions: Array[Vector3]) -> MultiMeshInstance3D:
	var mm := MultiMesh.new()
	mm.transform_format = MultiMesh.TRANSFORM_3D
	var box := BoxMesh.new()
	box.size = size
	mm.mesh = box
	mm.instance_count = positions.size()

	var mmi := MultiMeshInstance3D.new()
	mmi.name = name
	mmi.multimesh = mm

	var mat := StandardMaterial3D.new()
	mat.albedo_color = color
	mat.roughness = 0.86
	mmi.material_override = mat

	for i in positions.size():
		var t := Transform3D()
		t.origin = positions[i]
		mm.set_instance_transform(i, t)

	parent.add_child(mmi)
	return mmi