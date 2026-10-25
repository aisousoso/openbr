extends Node3D

## Builds the original OpenBR map "Verdant Reach".
##
## The scene contains the spawn markers, lighting and environment. This script
## creates the ground, boundary, roads, regional landmarks and props from the
## shared map data. It runs on both the server and the client so collision and
## visuals always match.

const MapData := preload("res://shared/map_data.gd")

const WOOD := Color(0.30, 0.20, 0.12)
const DARK_WOOD := Color(0.18, 0.12, 0.08)
const CONCRETE := Color(0.42, 0.44, 0.46)
const DARK_METAL := Color(0.22, 0.25, 0.28)
const RUST := Color(0.56, 0.28, 0.16)
const TEAL_METAL := Color(0.16, 0.42, 0.46)
const STONE := Color(0.46, 0.42, 0.35)
const SAND := Color(0.62, 0.52, 0.34)
const GLASS := Color(0.45, 0.82, 0.88, 0.34)

var _props: Node3D
var _materials := {}

func _ready() -> void:
	_props = $Props
	_build_ground()
	_build_boundary()
	_build_region_grounds()
	_build_roads()
	_build_meridian_relay()
	_build_aurora_yards()
	_build_cinder_terrace()
	_build_tideglass_shore()
	_build_dune_chapel()
	_build_frostline_depot()
	_build_saltwind_docks()
	_build_hollow_grove()
	_build_sunken_gardens()
	_build_scatter()
	print("map: %s built (%d spawn markers)" % [MapData.NAME, $SpawnPoints.get_child_count()])

# ---------------------------------------------------------------- primitives

func _mat(color: Color, emission := Color(0, 0, 0)) -> StandardMaterial3D:
	var key := "%s|%s" % [color.to_html(), emission.to_html()]
	if _materials.has(key):
		return _materials[key]
	var material := StandardMaterial3D.new()
	material.albedo_color = color
	material.roughness = 0.86
	if color.a < 1.0:
		material.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		material.cull_mode = BaseMaterial3D.CULL_DISABLED
	if emission != Color(0, 0, 0):
		material.emission_enabled = true
		material.emission = emission
	_materials[key] = material
	return material

func _box(node_name: String, pos: Vector3, size: Vector3, color: Color, rot := Vector3.ZERO, collision := true, parent: Node3D = null, emission := Color(0, 0, 0)) -> Node3D:
	var target: Node3D = _props if parent == null else parent
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var box_mesh := BoxMesh.new()
	box_mesh.size = size
	mesh_instance.mesh = box_mesh
	mesh_instance.material_override = _mat(color, emission)
mesh_instance.visibility_range_begin = 0.0
mesh_instance.visibility_range_end = 80.0
mesh_instance.visibility_range_end_margin = 10.0

	if not collision:
		mesh_instance.position = pos
		mesh_instance.rotation_degrees = rot
		target.add_child(mesh_instance)
		return mesh_instance

	var body := StaticBody3D.new()
	body.name = node_name + "_body"
	body.position = pos
	body.rotation_degrees = rot
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_child(mesh_instance)
	var shape := CollisionShape3D.new()
	var box_shape := BoxShape3D.new()
	box_shape.size = size
	shape.shape = box_shape
	body.add_child(shape)
	target.add_child(body)
	return body

func _cylinder(node_name: String, pos: Vector3, radius: float, height: float, color: Color, rot := Vector3.ZERO, collision := true, parent: Node3D = null, emission := Color(0, 0, 0)) -> Node3D:
	var target: Node3D = _props if parent == null else parent
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var cylinder_mesh := CylinderMesh.new()
	cylinder_mesh.top_radius = radius
	cylinder_mesh.bottom_radius = radius
	cylinder_mesh.height = height
	cylinder_mesh.radial_segments = 12
	cylinder_mesh.rings = 1
	mesh_instance.mesh = cylinder_mesh
	mesh_instance.material_override = _mat(color, emission)
mesh_instance.visibility_range_begin = 0.0
mesh_instance.visibility_range_end = 80.0
mesh_instance.visibility_range_end_margin = 10.0

	if not collision:
		mesh_instance.position = pos
		mesh_instance.rotation_degrees = rot
		target.add_child(mesh_instance)
		return mesh_instance

	var body := StaticBody3D.new()
	body.name = node_name + "_body"
	body.position = pos
	body.rotation_degrees = rot
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_child(mesh_instance)
	var shape := CollisionShape3D.new()
	var cylinder_shape := CylinderShape3D.new()
	cylinder_shape.radius = radius
	cylinder_shape.height = height
	shape.shape = cylinder_shape
	body.add_child(shape)
	target.add_child(body)
	return body

func _sphere(node_name: String, pos: Vector3, radius: float, color: Color, collision := true, parent: Node3D = null, emission := Color(0, 0, 0)) -> Node3D:
	var target: Node3D = _props if parent == null else parent
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var sphere_mesh := SphereMesh.new()
	sphere_mesh.radius = radius
	sphere_mesh.height = radius * 2.0
	sphere_mesh.radial_segments = 8
	sphere_mesh.rings = 4
	mesh_instance.mesh = sphere_mesh
	mesh_instance.material_override = _mat(color, emission)
mesh_instance.visibility_range_begin = 0.0
mesh_instance.visibility_range_end = 80.0
mesh_instance.visibility_range_end_margin = 10.0

	if not collision:
		mesh_instance.position = pos
		target.add_child(mesh_instance)
		return mesh_instance

	var body := StaticBody3D.new()
	body.name = node_name + "_body"
	body.position = pos
	body.collision_layer = 1
	body.collision_mask = 0
	body.add_child(mesh_instance)
	var shape := CollisionShape3D.new()
	var sphere_shape := SphereShape3D.new()
	sphere_shape.radius = radius
	shape.shape = sphere_shape
	body.add_child(shape)
	target.add_child(body)
	return body

func _cone(node_name: String, pos: Vector3, radius: float, height: float, color: Color) -> void:
	var mesh_instance := MeshInstance3D.new()
	mesh_instance.name = node_name
	var cone_mesh := CylinderMesh.new()
	cone_mesh.top_radius = 0.0
	cone_mesh.bottom_radius = radius
	cone_mesh.height = height
	cone_mesh.radial_segments = 9
	cone_mesh.rings = 1
	mesh_instance.mesh = cone_mesh
	mesh_instance.material_override = _mat(color)
	mesh_instance.visibility_range_begin = 0.0
	mesh_instance.visibility_range_end = 80.0
	mesh_instance.visibility_range_end_margin = 10.0
	mesh_instance.position = pos
	_props.add_child(mesh_instance)

func _label(text: String, center: Vector2, color: Color, height := 7.5, size := 46) -> void:
	var label := Label3D.new()
	label.name = "Label_" + text.replace(" ", "_")
	label.text = text
	label.position = Vector3(center.x, height, center.y)
	label.font_size = size
	label.pixel_size = 0.018
	label.modulate = color
	label.outline_size = 12
	label.outline_modulate = Color(0.02, 0.02, 0.03, 0.9)
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.no_depth_test = true
	label.render_priority = 1
	_props.add_child(label)

# ---------------------------------------------------------------- ground / roads

func _build_ground() -> void:
	var ground_color := Color(0.20, 0.26, 0.21)
	_box("Ground", Vector3(0, -0.5, 0), Vector3(MapData.HALF_SIZE * 2.0, 1.0, MapData.HALF_SIZE * 2.0), ground_color, Vector3.ZERO, true, self)

func _build_boundary() -> void:
	var wall_height := 9.0
	var wall_color := Color(0.10, 0.12, 0.15)
	var edge := MapData.HALF_SIZE + 0.5
	_box("Boundary_N", Vector3(0, wall_height * 0.5, edge), Vector3(MapData.HALF_SIZE * 2.0 + 1.0, wall_height, 1.0), wall_color, Vector3.ZERO, true, self)
	_box("Boundary_S", Vector3(0, wall_height * 0.5, -edge), Vector3(MapData.HALF_SIZE * 2.0 + 1.0, wall_height, 1.0), wall_color, Vector3.ZERO, true, self)
	_box("Boundary_E", Vector3(edge, wall_height * 0.5, 0), Vector3(1.0, wall_height, MapData.HALF_SIZE * 2.0 + 1.0), wall_color, Vector3.ZERO, true, self)
	_box("Boundary_W", Vector3(-edge, wall_height * 0.5, 0), Vector3(1.0, wall_height, MapData.HALF_SIZE * 2.0 + 1.0), wall_color, Vector3.ZERO, true, self)

	for corner in [Vector2(edge, edge), Vector2(edge, -edge), Vector2(-edge, edge), Vector2(-edge, -edge)]:
		_box("Boundary_Pillar", Vector3(corner.x, wall_height * 0.5, corner.y), Vector3(2.0, wall_height + 1.0, 2.0), Color(0.16, 0.18, 0.21), Vector3.ZERO, true, self)

func _build_region_grounds() -> void:
	for region in MapData.REGIONS:
		var center: Vector2 = region["center"]
		var radius := float(region["radius"])
		_box("RegionGround_" + String(region["id"]), Vector3(center.x, 0.02, center.y), Vector3(radius * 2.15, 0.04, radius * 2.15), region["ground"], Vector3.ZERO, false)
		_box("RegionAccent_" + String(region["id"]), Vector3(center.x, 0.035, center.y), Vector3(radius * 1.35, 0.03, radius * 1.35), region["accent"], Vector3(0, 18, 0), false)
		_label(String(region["name"]), center, region["label"])

	_label(MapData.NAME, Vector2(0, 0), Color(0.92, 0.96, 1.0), 18.0, 64)

func _build_roads() -> void:
	var road_color := Color(0.18, 0.20, 0.22)
	var ring: Array[Vector2] = []
	for region in MapData.REGIONS:
		if String(region["id"]) == "relay":
			continue
		var center: Vector2 = region["center"]
		ring.append(center)
		_road(Vector2(0, 0), center, 3.2, road_color)

	for i in range(ring.size()):
		_road(ring[i], ring[(i + 1) % ring.size()], 2.2, Color(0.22, 0.23, 0.25))

	# A small central roundabout gives the relay a readable approach.
	_cylinder("Roundabout", Vector3(0, 0.04, 0), 7.0, 0.05, Color(0.30, 0.32, 0.34), Vector3.ZERO, false)

func _road(a: Vector2, b: Vector2, width: float, color: Color) -> void:
	var mid := (a + b) * 0.5
	var length := a.distance_to(b)
	var angle := rad_to_deg(atan2(b.x - a.x, b.y - a.y))
	_box("Road", Vector3(mid.x, 0.03, mid.y), Vector3(width, 0.02, length), color, Vector3(0, angle, 0), false)

func _house(node_name: String, center: Vector2, size: Vector2, height: float, wall_color: Color, roof_color: Color, door_width := 3.0, door_side := -1) -> void:
	var half_x := size.x * 0.5
	var half_z := size.y * 0.5
	var thickness := 0.5
	var wall_y := height * 0.5
	var front_z := center.y + half_z * float(door_side)
	var back_z := center.y - half_z * float(door_side)

	_box(node_name + "_Back", Vector3(center.x, wall_y, back_z), Vector3(size.x, height, thickness), wall_color)
	_box(node_name + "_SideW", Vector3(center.x - half_x, wall_y, center.y), Vector3(thickness, height, size.y), wall_color)
	_box(node_name + "_SideE", Vector3(center.x + half_x, wall_y, center.y), Vector3(thickness, height, size.y), wall_color)

	var segment := (size.x - door_width) * 0.5
	if segment > 0.25:
		_box(node_name + "_FrontW", Vector3(center.x - (door_width + segment) * 0.5, wall_y, front_z), Vector3(segment, height, thickness), wall_color)
		_box(node_name + "_FrontE", Vector3(center.x + (door_width + segment) * 0.5, wall_y, front_z), Vector3(segment, height, thickness), wall_color)

	_box(node_name + "_Roof", Vector3(center.x, height + 0.2, center.y), Vector3(size.x + 0.7, 0.4, size.y + 0.7), roof_color)

# ---------------------------------------------------------------- regions

func _build_meridian_relay() -> void:
	var plaza := Color(0.44, 0.46, 0.48)
	_cylinder("Relay_Platform", Vector3(0, 0.3, 0), 6.5, 0.6, plaza, Vector3.ZERO, true)
	_cylinder("Relay_Base", Vector3(0, 0.7, 0), 3.8, 1.4, Color(0.32, 0.34, 0.37), Vector3.ZERO, true)
	_cylinder("Relay_Column", Vector3(0, 6.0, 0), 2.0, 10.0, Color(0.30, 0.32, 0.35), Vector3.ZERO, true)
	_box("Relay_Deck", Vector3(0, 5.0, 0), Vector3(10.0, 0.4, 10.0), Color(0.38, 0.40, 0.43), Vector3.ZERO, true)
	_box("Relay_Roof", Vector3(0, 11.2, 0), Vector3(6.0, 0.4, 6.0), DARK_METAL, Vector3.ZERO, true)
	_cylinder("Relay_Antenna", Vector3(0, 15.0, 0), 0.16, 8.0, Color(0.65, 0.70, 0.75), Vector3.ZERO, false)
	_cylinder("Relay_Beacon", Vector3(0, 19.2, 0), 0.32, 0.35, Color(1.0, 0.25, 0.18), Vector3.ZERO, false, null, Color(1.0, 0.08, 0.02))

	for x in [-1.0, 1.0]:
		for z in [-1.0, 1.0]:
			_box("Relay_Leg", Vector3(x * 3.0, 3.0, z * 3.0), Vector3(0.45, 6.0, 0.45), DARK_METAL)

	# Two broad ramps lead to the relay deck; both are walkable.
	_box("Relay_RampS", Vector3(0, 2.8, 10.5), Vector3(4.0, 0.35, 12.0), Color(0.36, 0.38, 0.40), Vector3(24, 0, 0), true)
	_box("Relay_RampN", Vector3(0, 2.8, -10.5), Vector3(4.0, 0.35, 12.0), Color(0.36, 0.38, 0.40), Vector3(-24, 0, 0), true)

	for edge in [Vector3(0, 5.7, 4.85), Vector3(0, 5.7, -4.85), Vector3(4.85, 5.7, 0), Vector3(-4.85, 5.7, 0)]:
		_box("Relay_Rail", edge, Vector3(0.18, 1.1, 0.18), Color(0.22, 0.24, 0.27))

	# Solar panels and service crates around the plaza.
	for i in range(4):
		var angle := float(i) * PI * 0.5 + 0.4
		var panel_pos := Vector3(cos(angle) * 11.0, 1.25, sin(angle) * 11.0)
		_box("Relay_Panel", panel_pos, Vector3(4.2, 0.16, 2.4), Color(0.08, 0.18, 0.28), Vector3(0, rad_to_deg(angle), 0))
		_box("Relay_PanelLeg", panel_pos - Vector3(0, 1.0, 0), Vector3(0.2, 2.0, 0.2), DARK_METAL)
	_box("Relay_Crate", Vector3(-8, 1.0, 8), Vector3(2.0, 2.0, 2.0), RUST)
	_box("Relay_Barrier", Vector3(8, 0.7, 8), Vector3(4.0, 1.4, 0.4), Color(0.55, 0.48, 0.25))

func _build_aurora_yards() -> void:
	var wall := Color(0.34, 0.27, 0.22)
	var roof := Color(0.18, 0.16, 0.15)
	_house("Aurora_Warehouse", Vector2(24, 24), Vector2(14, 12), 5.0, wall, roof, 4.0, 1)
	_box("Aurora_Catwalk", Vector3(35, 3.4, 26), Vector3(12, 0.3, 2.0), Color(0.32, 0.34, 0.36))
	_box("Aurora_CatwalkPostW", Vector3(30, 1.7, 26), Vector3(0.35, 3.4, 0.35), DARK_METAL)
	_box("Aurora_CatwalkPostE", Vector3(40, 1.7, 26), Vector3(0.35, 3.4, 0.35), DARK_METAL)

	_box("Aurora_ContainerA", Vector3(38, 1.4, 26), Vector3(5.0, 2.8, 2.6), TEAL_METAL)
	_box("Aurora_ContainerB", Vector3(40, 1.4, 34), Vector3(5.0, 2.8, 2.6), RUST)
	_box("Aurora_ContainerC", Vector3(28, 1.4, 40), Vector3(5.0, 2.8, 2.6), Color(0.22, 0.34, 0.52))
	_box("Aurora_ContainerD", Vector3(37, 1.4, 42), Vector3(5.0, 2.8, 2.6), Color(0.52, 0.44, 0.18))
	_cylinder("Aurora_SiloA", Vector3(45, 4.0, 44), 2.6, 8.0, Color(0.52, 0.56, 0.60))
	_cylinder("Aurora_SiloB", Vector3(47, 3.0, 36), 2.2, 6.0, Color(0.45, 0.50, 0.54))
	_cylinder("Aurora_Pipe", Vector3(36, 2.5, 30), 0.32, 8.0, Color(0.55, 0.34, 0.18), Vector3(0, 0, 90), true)
	_box("Aurora_FenceW", Vector3(17, 0.8, 36), Vector3(0.18, 1.6, 14), DARK_METAL)
	_box("Aurora_FenceS", Vector3(25, 0.8, 17), Vector3(16, 1.6, 0.18), DARK_METAL)
	_box("Aurora_CrateA", Vector3(20, 0.8, 20), Vector3(1.6, 1.6, 1.6), RUST)
	_box("Aurora_CrateB", Vector3(22, 0.8, 21), Vector3(1.6, 1.6, 1.6), Color(0.38, 0.32, 0.22))

func _build_cinder_terrace() -> void:
	var terra := Color(0.55, 0.32, 0.22)
	var cream := Color(0.68, 0.57, 0.42)
	var roof := Color(0.22, 0.15, 0.12)
	_house("Cinder_HouseA", Vector2(-38, 36), Vector2(10, 8), 4.5, terra, roof, 3.0, -1)
	_house("Cinder_HouseB", Vector2(-24, 36), Vector2(8, 8), 6.0, cream, roof, 3.0, -1)
	_house("Cinder_HouseC", Vector2(-32, 25), Vector2(12, 6), 3.2, Color(0.50, 0.36, 0.26), roof, 3.0, 1)

	# Courtyard market stalls.
	for stall in [Vector2(-36, 30), Vector2(-27, 33)]:
		for dx in [-1.5, 1.5]:
			for dz in [-1.5, 1.5]:
				_box("Cinder_StallPost", Vector3(stall.x + dx, 1.2, stall.y + dz), Vector3(0.18, 2.4, 0.18), DARK_WOOD)
		_box("Cinder_StallRoof", Vector3(stall.x, 2.5, stall.y), Vector3(4.0, 0.25, 4.0), Color(0.58, 0.36, 0.18))

	_cylinder("Cinder_WaterTank", Vector3(-46, 6.0, 28), 2.5, 4.0, Color(0.44, 0.34, 0.24))
	for leg in [Vector3(-48, 2.0, 28), Vector3(-44, 2.0, 28), Vector3(-46, 2.0, 26), Vector3(-46, 2.0, 30)]:
		_box("Cinder_TankLeg", leg, Vector3(0.3, 4.0, 0.3), DARK_WOOD)
	_box("Cinder_PlanterA", Vector3(-28, 0.45, 38), Vector3(3.0, 0.9, 1.2), Color(0.30, 0.24, 0.18))
	_box("Cinder_PlanterB", Vector3(-36, 0.45, 28), Vector3(3.0, 0.9, 1.2), Color(0.30, 0.24, 0.18))
	_box("Cinder_PlanterTopA", Vector3(-28, 0.95, 38), Vector3(2.7, 0.15, 0.9), Color(0.26, 0.48, 0.20))
	_box("Cinder_PlanterTopB", Vector3(-36, 0.95, 28), Vector3(2.7, 0.15, 0.9), Color(0.26, 0.48, 0.20))
	_box("Cinder_Wall", Vector3(-32, 0.8, 42), Vector3(18, 1.6, 0.25), Color(0.38, 0.27, 0.20))

func _build_tideglass_shore() -> void:
	var water := Color(0.10, 0.38, 0.46, 0.52)
	_box("Tideglass_Water", Vector3(32, 0.045, -32), Vector3(30, 0.02, 30), water, Vector3.ZERO, false, null, Color(0.02, 0.08, 0.12))
	_box("Tideglass_SpawnPad", Vector3(32, 0.2, -32), Vector3(5.0, 0.3, 5.0), Color(0.32, 0.27, 0.19))
	_box("Tideglass_BoardwalkS", Vector3(32, 0.25, -27), Vector3(22, 0.3, 3.0), WOOD)
	_box("Tideglass_BoardwalkN", Vector3(32, 0.25, -37), Vector3(18, 0.3, 3.0), WOOD)
	_box("Tideglass_BoardwalkC", Vector3(28, 0.25, -32), Vector3(3.0, 0.3, 12.0), WOOD)
	_box("Tideglass_BoardwalkE", Vector3(38, 0.25, -32), Vector3(3.0, 0.3, 10.0), WOOD)
	_house("Tideglass_Warehouse", Vector2(24, -24), Vector2(12, 8), 4.0, Color(0.28, 0.36, 0.40), Color(0.16, 0.20, 0.22), 3.0, -1)
	_box("Tideglass_ContainerA", Vector3(42, 1.4, -26), Vector3(5.0, 2.8, 2.6), TEAL_METAL)
	_box("Tideglass_ContainerB", Vector3(44, 1.4, -38), Vector3(5.0, 2.8, 2.6), RUST)
	_box("Tideglass_ContainerC", Vector3(30, 1.4, -42), Vector3(5.0, 2.8, 2.6), Color(0.22, 0.34, 0.52))
	_box("Tideglass_CraneBase", Vector3(48, 0.8, -46), Vector3(4.0, 1.6, 4.0), DARK_METAL)
	_box("Tideglass_CraneMast", Vector3(48, 5.8, -46), Vector3(1.2, 10.0, 1.2), Color(0.55, 0.42, 0.20))
	_box("Tideglass_CraneArm", Vector3(44, 10.5, -46), Vector3(10.0, 0.5, 0.7), Color(0.55, 0.42, 0.20))
	_sphere("Tideglass_BuoyA", Vector3(44, 0.55, -30), 0.45, Color(0.90, 0.45, 0.20), false)
	_sphere("Tideglass_BuoyB", Vector3(20, 0.55, -36), 0.45, Color(0.90, 0.45, 0.20), false)
	_sphere("Tideglass_RockA", Vector3(46, 0.8, -20), 1.8, STONE, true)
	_sphere("Tideglass_RockB", Vector3(20, 0.6, -42), 1.2, STONE, true)

func _build_dune_chapel() -> void:
	_house("Dune_Chapel", Vector2(-36, -36), Vector2(12, 10), 5.0, STONE, Color(0.25, 0.20, 0.16), 3.0, 1)
	_box("Dune_Tower", Vector3(-43, 4.0, -43), Vector3(4.0, 8.0, 4.0), Color(0.52, 0.46, 0.36))
	_box("Dune_TowerTop", Vector3(-43, 8.2, -43), Vector3(5.0, 0.4, 5.0), Color(0.36, 0.31, 0.24))
	_box("Dune_ArchL", Vector3(-38, 2.0, -30.5), Vector3(1.0, 4.0, 1.0), SAND)
	_box("Dune_ArchR", Vector3(-34, 2.0, -30.5), Vector3(1.0, 4.0, 1.0), SAND)
	_box("Dune_ArchTop", Vector3(-36, 4.2, -30.5), Vector3(5.0, 0.8, 1.0), SAND)
	_box("Dune_BrokenWallA", Vector3(-28, 1.0, -36), Vector3(2.0, 2.0, 8.0), Color(0.50, 0.44, 0.34))
	_box("Dune_BrokenWallB", Vector3(-32, 0.8, -42), Vector3(8.0, 1.6, 1.5), Color(0.50, 0.44, 0.34))
	_cylinder("Dune_Fountain", Vector3(-40, 0.3, -24), 2.2, 0.6, Color(0.46, 0.40, 0.30))
	_sphere("Dune_RockA", Vector3(-46, 1.0, -28), 2.0, Color(0.56, 0.46, 0.32), true)
	_sphere("Dune_RockB", Vector3(-24, 1.4, -42), 2.8, Color(0.56, 0.46, 0.32), true)
	_sphere("Dune_RockC", Vector3(-38, 1.0, -20), 1.8, Color(0.56, 0.46, 0.32), true)
	_cylinder("Dune_DeadTreeA", Vector3(-44, 2.0, -34), 0.25, 4.0, Color(0.30, 0.24, 0.18))
	_cylinder("Dune_DeadTreeB", Vector3(-26, 2.0, -30), 0.25, 4.0, Color(0.30, 0.24, 0.18))

func _build_frostline_depot() -> void:
	_house("Frostline_Depot", Vector2(0, 53), Vector2(18, 8), 5.0, Color(0.46, 0.52, 0.58), Color(0.28, 0.34, 0.40), 4.0, -1)
	_cylinder("Frostline_SiloA", Vector3(-12, 4.0, 52), 3.0, 8.0, Color(0.62, 0.70, 0.76))
	_cylinder("Frostline_SiloB", Vector3(12, 4.0, 52), 3.0, 8.0, Color(0.62, 0.70, 0.76))
	_box("Frostline_CrateA", Vector3(-8, 0.8, 42), Vector3(2.0, 1.6, 2.0), Color(0.42, 0.50, 0.58))
	_box("Frostline_CrateB", Vector3(8, 0.8, 42), Vector3(2.0, 1.6, 2.0), Color(0.42, 0.50, 0.58))
	_box("Frostline_CrateC", Vector3(-15, 0.8, 46), Vector3(2.0, 1.6, 2.0), RUST)
	_box("Frostline_CrateD", Vector3(15, 0.8, 46), Vector3(2.0, 1.6, 2.0), TEAL_METAL)
	_box("Frostline_Fence", Vector3(0, 0.8, 38), Vector3(26, 1.6, 0.2), DARK_METAL)
	_sphere("Frostline_SnowA", Vector3(-20, 0.4, 44), 2.2, Color(0.82, 0.88, 0.92), false)
	_sphere("Frostline_SnowB", Vector3(20, 0.4, 48), 2.4, Color(0.82, 0.88, 0.92), false)
	_sphere("Frostline_SnowC", Vector3(-18, 0.3, 54), 1.8, Color(0.82, 0.88, 0.92), false)

func _build_saltwind_docks() -> void:
	var water := Color(0.10, 0.36, 0.42, 0.50)
	_box("Saltwind_Water", Vector3(45, 0.045, 0), Vector3(30, 0.02, 30), water, Vector3.ZERO, false, null, Color(0.02, 0.07, 0.10))
	_box("Saltwind_Boardwalk", Vector3(45, 0.25, 0), Vector3(3.0, 0.3, 26.0), WOOD)
	_box("Saltwind_Cross", Vector3(45, 0.25, -8), Vector3(14.0, 0.3, 3.0), WOOD)
	_house("Saltwind_Warehouse", Vector2(52, -12), Vector2(8, 8), 4.0, Color(0.30, 0.38, 0.42), Color(0.18, 0.22, 0.24), 3.0, 1)
	_box("Saltwind_ContainerA", Vector3(54, 1.4, 8), Vector3(5.0, 2.8, 2.6), TEAL_METAL)
	_box("Saltwind_ContainerB", Vector3(54, 1.4, 14), Vector3(5.0, 2.8, 2.6), RUST)
	_box("Saltwind_ContainerC", Vector3(40, 1.4, 12), Vector3(5.0, 2.8, 2.6), Color(0.22, 0.34, 0.52))
	_box("Saltwind_CraneBase", Vector3(55, 0.8, 6), Vector3(4.0, 1.6, 4.0), DARK_METAL)
	_box("Saltwind_CraneMast", Vector3(55, 5.8, 6), Vector3(1.2, 10.0, 1.2), Color(0.52, 0.42, 0.20))
	_box("Saltwind_CraneArm", Vector3(50, 10.5, 6), Vector3(10.0, 0.5, 0.7), Color(0.52, 0.42, 0.20))
	_sphere("Saltwind_RockA", Vector3(54, 0.7, -24), 1.6, STONE, true)
	_sphere("Saltwind_RockB", Vector3(38, 0.5, -18), 1.1, STONE, true)
	_sphere("Saltwind_Buoy", Vector3(38, 0.5, 6), 0.45, Color(0.90, 0.45, 0.20), false)

func _build_hollow_grove() -> void:
	_house("Hollow_Cabin", Vector2(-52, 8), Vector2(8, 6), 3.5, WOOD, DARK_WOOD, 2.5, -1)
	for tree in [
		Vector3(-52, 0, -6), Vector3(-40, 0, -10), Vector3(-38, 0, 6),
		Vector3(-50, 0, -16), Vector3(-56, 0, 16), Vector3(-42, 0, 16),
		Vector3(-34, 0, -4), Vector3(-48, 0, 20), Vector3(-56, 0, -20),
		Vector3(-36, 0, -18), Vector3(-28, 0, 8), Vector3(-58, 0, 0),
		Vector3(-30, 0, -12), Vector3(-54, 0, 24),
	]:
		_tree(tree, 1.0 + float(int(abs(tree.x)) % 3) * 0.12)
	_sphere("Hollow_RockA", Vector3(-44, 0.8, 4), 1.6, Color(0.34, 0.38, 0.30), true)
	_sphere("Hollow_RockB", Vector3(-46, 0.7, -4), 1.4, Color(0.34, 0.38, 0.30), true)
	_sphere("Hollow_RockC", Vector3(-32, 0.6, -8), 1.1, Color(0.34, 0.38, 0.30), true)
	_cylinder("Hollow_LogA", Vector3(-48, 0.5, 12), 0.45, 4.0, DARK_WOOD, Vector3(0, 0, 90), true)
	_cylinder("Hollow_LogB", Vector3(-34, 0.5, 4), 0.45, 3.0, DARK_WOOD, Vector3(0, 0, 90), true)
	_box("Hollow_Woodpile", Vector3(-52, 0.6, 2), Vector3(2.4, 1.2, 2.4), DARK_WOOD)

func _tree(pos: Vector3, scale := 1.0) -> void:
	_cylinder("Tree_Trunk", Vector3(pos.x, 2.0 * scale, pos.z), 0.42 * scale, 4.0 * scale, Color(0.28, 0.19, 0.12))
	_cone("Tree_CanopyA", Vector3(pos.x, 5.3 * scale, pos.z), 2.6 * scale, 4.0 * scale, Color(0.16, 0.36, 0.18))
	_cone("Tree_CanopyB", Vector3(pos.x, 7.1 * scale, pos.z), 1.8 * scale, 3.0 * scale, Color(0.20, 0.44, 0.22))

func _build_sunken_gardens() -> void:
	var water := Color(0.10, 0.34, 0.30, 0.52)
	_box("Sunken_Water", Vector3(0, 0.045, -45), Vector3(30, 0.02, 30), water, Vector3.ZERO, false, null, Color(0.02, 0.08, 0.06))
	_box("Sunken_Boardwalk", Vector3(0, 0.25, -45), Vector3(3.0, 0.3, 26.0), WOOD)
	_box("Sunken_Cross", Vector3(0, 0.25, -45), Vector3(20.0, 0.3, 3.0), WOOD)
	_house("Sunken_Greenhouse", Vector2(0, -54), Vector2(14, 6), 4.0, GLASS, Color(0.24, 0.42, 0.36), 4.0, 1)
	for x in [-6.0, 6.0]:
		for z in [-56.0, -52.0]:
			_box("Sunken_GreenhouseBeam", Vector3(x, 2.0, z), Vector3(0.25, 4.0, 0.25), Color(0.22, 0.34, 0.28))
	_box("Sunken_PlanterA", Vector3(-12, 0.45, -40), Vector3(4.0, 0.9, 1.4), Color(0.26, 0.22, 0.16))
	_box("Sunken_PlanterB", Vector3(12, 0.45, -40), Vector3(4.0, 0.9, 1.4), Color(0.26, 0.22, 0.16))
	_box("Sunken_PlanterC", Vector3(-14, 0.45, -50), Vector3(4.0, 0.9, 1.4), Color(0.26, 0.22, 0.16))
	_box("Sunken_PlanterD", Vector3(18, 0.45, -50), Vector3(4.0, 0.9, 1.4), Color(0.26, 0.22, 0.16))
	_box("Sunken_PlantTopA", Vector3(-12, 0.95, -40), Vector3(3.6, 0.18, 1.0), Color(0.18, 0.50, 0.24))
	_box("Sunken_PlantTopB", Vector3(12, 0.95, -40), Vector3(3.6, 0.18, 1.0), Color(0.18, 0.50, 0.24))
	_box("Sunken_PlantTopC", Vector3(-14, 0.95, -50), Vector3(3.6, 0.18, 1.0), Color(0.18, 0.50, 0.24))
	_box("Sunken_PlantTopD", Vector3(18, 0.95, -50), Vector3(3.6, 0.18, 1.0), Color(0.18, 0.50, 0.24))
	for plant in [Vector3(-18, 0.4, -44), Vector3(18, 0.4, -44), Vector3(-6, 0.4, -58), Vector3(6, 0.4, -58)]:
		_cone("Sunken_Plant", plant, 0.7, 1.8, Color(0.18, 0.48, 0.28))

func _build_scatter() -> void:
	# Mid-map cover and waystations break up the open lanes.
	_sphere("Scatter_RockA", Vector3(16, 0.8, 22), 1.7, STONE, true)
	_sphere("Scatter_RockB", Vector3(-22, 0.8, 18), 1.8, STONE, true)
	_sphere("Scatter_RockC", Vector3(22, 0.7, -18), 1.6, STONE, true)
	_sphere("Scatter_RockD", Vector3(-18, 0.7, -22), 1.5, STONE, true)
	_sphere("Scatter_BushA", Vector3(10, 0.5, 14), 0.9, Color(0.18, 0.42, 0.20), false)
	_sphere("Scatter_BushB", Vector3(-12, 0.5, 14), 0.9, Color(0.18, 0.42, 0.20), false)
	_sphere("Scatter_BushC", Vector3(14, 0.5, -12), 0.9, Color(0.18, 0.42, 0.20), false)
	_sphere("Scatter_BushD", Vector3(-14, 0.5, -12), 0.9, Color(0.18, 0.42, 0.20), false)

	for lamp in [Vector3(0, 0, 24), Vector3(0, 0, -24), Vector3(24, 0, 0), Vector3(-24, 0, 0)]:
		_box("Scatter_LampPost", Vector3(lamp.x, 2.0, lamp.z), Vector3(0.18, 4.0, 0.18), DARK_METAL)
		_sphere("Scatter_Lamp", Vector3(lamp.x, 4.1, lamp.z), 0.28, Color(1.0, 0.82, 0.45), false, null, Color(1.0, 0.55, 0.15))
