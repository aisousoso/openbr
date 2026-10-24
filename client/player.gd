extends CharacterBody3D

const Movement := preload("res://shared/movement.gd")
const Weapons := preload("res://shared/weapons.gd")

@export var mouse_sensitivity := 0.0025

var spawn_id := 0
var is_alive := true
var touch_mode := false
var weapon_index := 0
var loot_field = null

var _fire_cd := 0.0

@onready var head: Node3D = $Head
@onready var camera: Camera3D = $Head/Camera3D
@onready var model: Node3D = $Model

func _ready() -> void:
	camera.current = true
	# The local camera sits inside the head, so hide the head/headgear while
	# keeping the torso, arms and legs visible in first person.
	if model.has_method("set_first_person"):
		model.set_first_person(true)
	# The on-screen touch controls drive look/fire on phones; do not grab the
	# mouse there (and never capture it while the connect screen is up).
	if not touch_mode and not OS.has_feature("mobile"):
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

func _process(delta: float) -> void:
	_fire_cd = maxf(0.0, _fire_cd - delta)

func _unhandled_input(event: InputEvent) -> void:
	# In touch mode the TouchControls node supplies look/fire instead.
	if touch_mode or OS.has_feature("mobile"):
		return

	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		apply_look(event.relative)
		return

	if event.is_action_pressed("fire"):
		if Input.mouse_mode != Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED
			return
		request_fire()
		return

	if event.is_action_pressed("reload"):
		request_reload()
		return
	if event.is_action_pressed("interact"):
		request_loot()
		return
	if event.is_action_pressed("use_bandage"):
		request_use_item("bandage")
		return
	if event.is_action_pressed("use_medkit"):
		request_use_item("medkit")
		return
	if event.is_action_pressed("weapon_1"):
		request_weapon(0)
		return
	if event.is_action_pressed("weapon_2"):
		request_weapon(1)
		return
	if event.is_action_pressed("weapon_3"):
		request_weapon(2)

## Rotate the body/head by a raw pointer delta (pixels). Shared by mouse and
## touch drag handling.
func apply_look(relative: Vector2) -> void:
	rotate_y(-relative.x * mouse_sensitivity)
	head.rotate_x(-relative.y * mouse_sensitivity)
	head.rotation.x = clampf(head.rotation.x, -1.4, 1.4)

## Fire request used by mouse click and the on-screen FIRE button.
func request_fire() -> void:
	if not is_alive or _fire_cd > 0.0:
		return
	_fire_cd = float(Weapons.get_weapon(weapon_index)["cooldown"])
	var dir := -camera.global_transform.basis.z
	Net.try_fire(dir.normalized())

func request_weapon(index: int) -> void:
	if not is_alive:
		return
	weapon_index = clampi(index, 0, Weapons.count() - 1)
	Net.request_weapon(weapon_index)

func cycle_weapon() -> void:
	request_weapon((weapon_index + 1) % Weapons.count())

func request_reload() -> void:
	if not is_alive:
		return
	Net.request_reload()

func request_loot() -> void:
	if not is_alive or loot_field == null:
		return
	loot_field.request_nearest()

func request_use_item(item_type: String) -> void:
	if not is_alive:
		return
	Net.request_use_item(item_type)

func _physics_process(delta: float) -> void:
	if not is_alive:
		return

	var input_dir := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
	var jumping := Input.is_action_pressed("jump")

	Movement.step_body(self, input_dir, rotation.y, jumping, delta)
	Net.queue_input(input_dir, rotation.y, jumping)

func apply_appearance(appearance: Dictionary) -> void:
	if model != null and model.has_method("apply_appearance"):
		model.apply_appearance(appearance)

func set_alive(value: bool) -> void:
	is_alive = value
	if model != null:
		model.visible = value
	if not value:
		velocity = Vector3.ZERO
