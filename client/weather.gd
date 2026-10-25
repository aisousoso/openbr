## Weather system — rain, fog, time of day.
## Attach to Main node. Visual only.

extends Node3D

@export var rain_enabled: bool = false
@export var time_of_day: float = 0.5  # 0=midnight, 0.5=noon, 1=midnight

var _rain_particles: GPUParticles3D
var _world_env: WorldEnvironment

func _ready() -> void:
	_world_env = get_node_or_null("../WorldEnvironment")
	if rain_enabled:
		_setup_rain()

func _setup_rain() -> void:
	_rain_particles = GPUParticles3D.new()
	_rain_particles.name = "Rain"
	_rain_particles.amount = 500
	_rain_particles.lifetime = 1.0
	_rain_particles.visibility_aabb = AABB(Vector3(-50, 0, -50), Vector3(100, 50, 100))
	var mat := ParticleProcessMaterial.new()
	mat.direction = Vector3(0, -1, 0)
	mat.initial_velocity_min = 8.0
	mat.initial_velocity_max = 12.0
	mat.gravity = Vector3(0, -20, 0)
	mat.scale_min = 0.02
	mat.scale_max = 0.05
	_rain_particles.process_material = mat
	var mesh := QuadMesh.new()
	mesh.size = Vector2(0.05, 0.3)
	_rain_particles.draw_pass_1 = mesh
	add_child(_rain_particles)

func set_time_of_day(t: float) -> void:
	time_of_day = clampf(t, 0.0, 1.0)
	if _world_env == null or _world_env.environment == null:
		return
	var env: Environment = _world_env.environment
	# Adjust ambient light and fog based on time.
	var day_factor := sin(time_of_day * PI)  # 0 at midnight, 1 at noon
	env.ambient_light_energy = 0.3 + day_factor * 0.7
	env.fog_density = 0.003 + (1.0 - day_factor) * 0.005
	if day_factor < 0.3:
		env.ambient_light_color = Color(0.3, 0.35, 0.5)
	else:
		env.ambient_light_color = Color(0.75, 0.80, 0.85)