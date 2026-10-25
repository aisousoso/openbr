## Adaptive quality settings for mobile performance.
## Adjusts shadows, particles, and rendering based on device capability.

extends Node

enum QualityLevel { LOW, MEDIUM, HIGH }

var current_level: QualityLevel = QualityLevel.MEDIUM

func _ready() -> void:
	# Auto-detect based on OS.
	if OS.has_feature("mobile"):
		# Default to medium on mobile, can be overridden by settings.
		current_level = QualityLevel.MEDIUM
	else:
		current_level = QualityLevel.HIGH
	apply_settings()

func set_quality(level: QualityLevel) -> void:
	current_level = level
	apply_settings()

func apply_settings() -> void:
	var world_env := get_node_or_null("/root/Main/WorldEnvironment")
	if world_env == null or world_env.environment == null:
		return
	var env: Environment = world_env.environment

	match current_level:
		QualityLevel.LOW:
			env.glow_enabled = false
			env.fog_enabled = false
			env.ssao_enabled = false
			env.ssr_enabled = false
			env.sdfgi_enabled = false
			# Disable shadows on sun.
			var sun := get_node_or_null("/root/Main/Sun")
			if sun is DirectionalLight3D:
				sun.shadow_enabled = false
		QualityLevel.MEDIUM:
			env.glow_enabled = true
			env.glow_intensity = 0.2
			env.fog_enabled = true
			env.fog_density = 0.003
			env.ssao_enabled = false
			env.ssr_enabled = false
			env.sdfgi_enabled = false
			var sun := get_node_or_null("/root/Main/Sun")
			if sun is DirectionalLight3D:
				sun.shadow_enabled = true
		QualityLevel.HIGH:
			env.glow_enabled = true
			env.glow_intensity = 0.3
			env.fog_enabled = true
			env.fog_density = 0.003
			env.ssao_enabled = false
			env.ssr_enabled = false
			env.sdfgi_enabled = false
			var sun := get_node_or_null("/root/Main/Sun")
			if sun is DirectionalLight3D:
				sun.shadow_enabled = true