## Shared deterministic movement.
## Both the client (prediction) and the server (authority) call step_body()
## on a CharacterBody3D with the same capsule, world and constants, so
## gravity, jumping and collision response stay in sync.

const SPEED := 6.0
const JUMP_VELOCITY := 5.5
const GRAVITY := 9.8

static func step_body(body: CharacterBody3D, input_dir: Vector2, yaw: float, jump: bool, delta: float) -> void:
	if not body.is_on_floor():
		body.velocity.y -= GRAVITY * delta

	if jump and body.is_on_floor():
		body.velocity.y = JUMP_VELOCITY

	var dir := Vector3(input_dir.x, 0.0, input_dir.y)
	if dir.length() > 1.0:
		dir = dir.normalized()
	dir = dir.rotated(Vector3.UP, yaw)

	body.velocity.x = dir.x * SPEED
	body.velocity.z = dir.z * SPEED

	body.move_and_slide()
