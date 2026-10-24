extends Node3D

## Renders the shared loot spawns and reports the nearest pickup to the HUD.
## The server still validates every pickup; this node is presentation plus the
## local "press E / tap LOOT" prompt.

signal prompt_changed(text: String, visible: bool)

const Loot := preload("res://shared/loot.gd")

var local_player = null

var _nodes := {}
var _taken := {}
var _nearest_id := -1
var _time := 0.0

func _ready() -> void:
	Net.loot_state.connect(_on_loot_state)
	Net.loot_taken.connect(_on_loot_taken)
	Net.loot_spawned.connect(_on_loot_spawned)
	Net.loot_spawned_bulk.connect(_on_loot_spawned_bulk)
	Net.loot_reset.connect(reset)
	_build_all()

func _on_loot_spawned_bulk(spawns: Array) -> void:
	for s in spawns:
		var loot_id := int(s["id"])
		var item_type := String(s["type"])
		var pos: Vector3 = s["pos"]
		if _nodes.has(loot_id):
			continue
		var root := Node3D.new()
		root.name = "Loot_%d" % loot_id
		root.position = pos
		add_child(root)
		_build_visual(root, item_type)
		_nodes[loot_id] = root

func _build_all() -> void:
	for spawn in Loot.all():
		var loot_id := int(spawn["id"])
		var root := Node3D.new()
		root.name = "Loot_%d" % loot_id
		root.position = spawn["pos"]
		add_child(root)
		_build_visual(root, String(spawn["type"]))
		_nodes[loot_id] = root

func _on_loot_spawned(loot_id: int, item_type: String, pos: Vector3) -> void:
	if _nodes.has(loot_id):
		return
	var root := Node3D.new()
	root.name = "Loot_%d" % loot_id
	root.position = pos
	add_child(root)
	_build_visual(root, item_type)
	_nodes[loot_id] = root
	_taken.erase(loot_id)

func _build_visual(root: Node3D, item_type: String) -> void:
	var item_color := Loot.color(item_type)
	var mesh: Mesh
	match item_type:
		"armor":
			var vest := BoxMesh.new()
			vest.size = Vector3(0.55, 0.65, 0.28)
			mesh = vest
		"medkit":
			var kit := BoxMesh.new()
			kit.size = Vector3(0.45, 0.35, 0.45)
			mesh = kit
		"bandage":
			var roll := CylinderMesh.new()
			roll.top_radius = 0.18
			roll.bottom_radius = 0.18
			roll.height = 0.25
			mesh = roll
		_:
			var box := BoxMesh.new()
			box.size = Vector3(0.5, 0.3, 0.35)
			mesh = box

	var item := MeshInstance3D.new()
	item.name = "Item"
	item.mesh = mesh
	item.position = Vector3(0.0, 0.55, 0.0)
	var material := StandardMaterial3D.new()
	material.albedo_color = item_color
	material.emission_enabled = true
	material.emission = item_color * 0.35
	material.roughness = 0.4
	item.material_override = material
	root.add_child(item)

	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.35
	torus.outer_radius = 0.45
	torus.rings = 16
	torus.ring_segments = 6
	ring.mesh = torus
	ring.position = Vector3(0.0, 0.04, 0.0)
	var ring_material := StandardMaterial3D.new()
	ring_material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	ring_material.albedo_color = item_color
	ring_material.emission_enabled = true
	ring_material.emission = item_color * 0.5
	ring.material_override = ring_material
	root.add_child(ring)

	var label := Label3D.new()
	label.name = "Label"
	label.text = Loot.label(item_type)
	label.position = Vector3(0.0, 1.15, 0.0)
	label.font_size = 28
	label.pixel_size = 0.01
	label.modulate = item_color
	label.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	label.outline_size = 8
	label.outline_modulate = Color(0.0, 0.0, 0.0, 0.8)
	root.add_child(label)

func _process(delta: float) -> void:
	if not visible:
		# Outside a live match the whole field is hidden; make sure a stale
		# pickup prompt does not linger on the lobby screen.
		if _nearest_id != -1:
			_nearest_id = -1
			prompt_changed.emit("", false)
		return
	_time += delta
	for id in _nodes.keys():
		var node: Node3D = _nodes[id]
		if is_instance_valid(node) and node.visible:
			node.rotation.y = _time * 0.9
			# A Label3D at point-blank range fills the screen. Hide the world
			# label when the local player is right on top of the item; the HUD
			# prompt still shows the pickup hint.
			var label := node.get_node_or_null("Label")
			if label != null and local_player != null and is_instance_valid(local_player):
				var dist: float = local_player.global_position.distance_to(node.global_position)
				(label as Label3D).visible = dist > 2.2

	var nearest := -1
	var best := INF
	if local_player != null and is_instance_valid(local_player) and local_player.is_alive:
		for id in _nodes.keys():
			if _taken.has(id):
				continue
			var node: Node3D = _nodes[id]
			if not is_instance_valid(node) or not node.visible:
				continue
			var dist: float = local_player.global_position.distance_to(node.global_position)
			if dist <= Loot.PICKUP_RADIUS and dist < best:
				best = dist
				nearest = int(id)

	_update_prompt(nearest)

func _update_prompt(nearest: int) -> void:
	if nearest == _nearest_id:
		return
	_nearest_id = nearest
	if nearest < 0:
		prompt_changed.emit("", false)
		return
	var spawn := Loot.get_spawn(nearest)
	if spawn.is_empty():
		prompt_changed.emit("", false)
		return
	prompt_changed.emit("LOOT  %s   [E]" % Loot.label(String(spawn["type"])), true)

func request_nearest() -> void:
	if local_player == null or not is_instance_valid(local_player) or not local_player.is_alive:
		return
	if _nearest_id < 0:
		return
	Net.request_loot(_nearest_id)

func set_local_player(player) -> void:
	local_player = player
	if player == null:
		_update_prompt(-1)

func reset() -> void:
	_taken.clear()
	_nearest_id = -1
	var to_remove := []
	for id in _nodes.keys():
		var node: Node3D = _nodes[id]
		if is_instance_valid(node):
			if id >= 10000:
				node.queue_free()
				to_remove.append(id)
			else:
				node.visible = true
	for id in to_remove:
		_nodes.erase(id)
	prompt_changed.emit("", false)

func _on_loot_state(taken: Array) -> void:
	for raw_id in taken:
		var loot_id := int(raw_id)
		_taken[loot_id] = true
		if _nodes.has(loot_id):
			var node: Node3D = _nodes[loot_id]
			if is_instance_valid(node):
				node.visible = false
	if _nearest_id >= 0 and _taken.has(_nearest_id):
		_update_prompt(-1)

func _on_loot_taken(loot_id: int, _by: int) -> void:
	_taken[loot_id] = true
	if _nodes.has(loot_id):
		var node: Node3D = _nodes[loot_id]
		if is_instance_valid(node):
			node.visible = false
	if loot_id == _nearest_id:
		_update_prompt(-1)
