## Stylized hit spark effect — spawned when a shot hits a player.
## Visual only, no gameplay impact.

extends Node3D

func _ready() -> void:
	# Create a few spark particles.
	for i in 6:
		var mesh := MeshInstance3D.new()
		var box := BoxMesh.new()
		box.size = Vector3(0.08, 0.08, 0.2)
		mesh.mesh = box
		var mat := StandardMaterial3D.new()
		mat.albedo_color = Color(1.0, 0.85, 0.3, 0.9)
		mat.emission_enabled = true
		mat.emission = Color(1.0, 0.7, 0.2)
		mat.emission_energy_multiplier = 4.0
		mat.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
		mat.transparency = BaseMaterial3D.TRANSPARENCY_ALPHA
		mesh.material_override = mat
		var dir := Vector3(randf_range(-1, 1), randf_range(0, 1), randf_range(-1, 1)).normalized()
		mesh.position = dir * 0.1
		mesh.look_at(mesh.position + dir, Vector3.UP)
		add_child(mesh)
		# Animate outward.
		var tween := create_tween()
		tween.tween_property(mesh, "position", dir * 0.6, 0.3)
		tween.parallel().tween_property(mat, "albedo_color:a", 0.0, 0.3)
	# Auto-remove.
	var timer := get_tree().create_timer(0.35)
	timer.timeout.connect(queue_free)