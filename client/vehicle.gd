## Server-authoritative vehicle controller.
## The server owns position/rotation; the client sends input and interpolates.

extends VehicleBody3D

var driver_id := 0
var passenger_ids := []

func _physics_process(delta: float) -> void:
	if driver_id == 0:
		return
	# Vehicle movement is driven by server RPCs, not local input.
	# This is a placeholder for client-side interpolation.
	pass

func enter_vehicle(player_id: int) -> void:
	if driver_id == 0:
		driver_id = player_id
	else:
		passenger_ids.append(player_id)

func exit_vehicle(player_id: int) -> void:
	if driver_id == player_id:
		driver_id = 0
	else:
		passenger_ids.erase(player_id)