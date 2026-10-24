extends Node

## Networking facade shared by client and server.
## Every RPC lives here, so both sides agree on node paths (/root/Net).
##
## Client -> server : authenticate(token, appearance), send_input, request_fire,
##                    request_loot, request_use_item
## Server -> client : spawn_player, apply_snapshot, apply_shot,
##                    apply_death, apply_respawn, player_gone, kicked,
##                    loot_state, loot_taken, loot_result

signal connected
signal connection_failed
signal disconnected
signal rejected(reason: String)

signal auth_requested(id: int, token: String, appearance: Dictionary)
signal input_received(id: int, dir: Vector2, yaw: float, jump: bool)
signal fire_requested(id: int, dir: Vector3)
signal weapon_requested(id: int, index: int)
signal reload_requested(id: int)
signal loot_requested(id: int, loot_id: int)
signal use_item_requested(id: int, item_type: String)
signal peer_disconnected(id: int)

signal player_spawned(id: int, pos: Vector3)
signal snapshot_received(snap: Dictionary, tick: int, storm: Dictionary)
signal player_left(id: int)
signal shot_fired(shooter: int, from: Vector3, to: Vector3, hit: int, weapon: int)
signal player_died(victim: int, killer: int)
signal player_respawned(pos: Vector3)
signal loot_state(taken: Array)
signal loot_taken(loot_id: int, by: int)
signal loot_result_received(message: String)

const SEND_HZ := 30.0

var _peer: ENetMultiplayerPeer
var _acc := 0.0
var _dir := Vector2.ZERO
var _yaw := 0.0
var _jump := false
var _join_gen := 0
var _appearance: Dictionary = {}

func _ready() -> void:
	multiplayer.connected_to_server.connect(func() -> void: connected.emit())
	multiplayer.connection_failed.connect(func() -> void:
		connection_failed.emit()
		_shutdown.call_deferred()
	)
	multiplayer.server_disconnected.connect(func() -> void:
		disconnected.emit()
		_shutdown.call_deferred()
	)
	multiplayer.peer_disconnected.connect(func(id: int) -> void: peer_disconnected.emit(id))

func _shutdown() -> void:
	_join_gen += 1
	if multiplayer.multiplayer_peer != null:
		multiplayer.multiplayer_peer.close()
	multiplayer.multiplayer_peer = null

func is_server() -> bool:
	return multiplayer.has_multiplayer_peer() and multiplayer.is_server()

func is_client_connected() -> bool:
	return multiplayer.has_multiplayer_peer() \
		and multiplayer.multiplayer_peer.get_connection_status() == MultiplayerPeer.CONNECTION_CONNECTED

func host_game(port: int, max_clients: int) -> Error:
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_server(port, max_clients)
	if err == OK:
		multiplayer.multiplayer_peer = _peer
	return err

func join_game(host: String, port: int, token: String, appearance: Dictionary = {}) -> void:
	_join_gen += 1
	var gen := _join_gen
	_appearance = appearance.duplicate(true)
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(host, port)
	if err != OK:
		push_error("connect failed: %s" % error_string(err))
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = _peer
	await multiplayer.connected_to_server
	# A failed attempt can leave this await pending; ignore it if a newer
	# connect/shutdown happened in the meantime.
	if gen != _join_gen or not is_client_connected():
		return
	rpc_id(1, "authenticate", token, _appearance)

func queue_input(dir: Vector2, yaw: float, jump: bool) -> void:
	_dir = dir
	_yaw = yaw
	_jump = jump

func try_fire(dir: Vector3) -> void:
	if is_server() or not is_client_connected():
		return
	rpc_id(1, "request_fire", dir)

func request_weapon(index: int) -> void:
	if is_server() or not is_client_connected():
		return
	rpc_id(1, "select_weapon", index)

func request_reload() -> void:
	if is_server() or not is_client_connected():
		return
	rpc_id(1, "request_reload_rpc")

func request_loot(loot_id: int) -> void:
	if is_server() or not is_client_connected():
		return
	rpc_id(1, "request_loot_rpc", loot_id)

func request_use_item(item_type: String) -> void:
	if is_server() or not is_client_connected():
		return
	rpc_id(1, "request_use_item_rpc", item_type)

func _physics_process(delta: float) -> void:
	if is_server() or not is_client_connected():
		return
	_acc += delta
	if _acc < 1.0 / SEND_HZ:
		return
	_acc = 0.0
	rpc_id(1, "send_input", _dir, _yaw, _jump)

# ---------------------------------------------------------------- client -> server

@rpc("any_peer", "reliable")
func authenticate(token: String, appearance: Dictionary) -> void:
	if not multiplayer.is_server():
		return
	auth_requested.emit(multiplayer.get_remote_sender_id(), token, appearance)

@rpc("any_peer", "unreliable_ordered")
func send_input(dir: Vector2, yaw: float, jump: bool) -> void:
	if not multiplayer.is_server():
		return
	input_received.emit(multiplayer.get_remote_sender_id(), dir, yaw, jump)

@rpc("any_peer", "reliable")
func request_fire(dir: Vector3) -> void:
	if not multiplayer.is_server():
		return
	fire_requested.emit(multiplayer.get_remote_sender_id(), dir)

@rpc("any_peer", "reliable")
func select_weapon(index: int) -> void:
	if not multiplayer.is_server():
		return
	weapon_requested.emit(multiplayer.get_remote_sender_id(), index)

@rpc("any_peer", "reliable")
func request_reload_rpc() -> void:
	if not multiplayer.is_server():
		return
	reload_requested.emit(multiplayer.get_remote_sender_id())

@rpc("any_peer", "reliable")
func request_loot_rpc(loot_id: int) -> void:
	if not multiplayer.is_server():
		return
	loot_requested.emit(multiplayer.get_remote_sender_id(), loot_id)

@rpc("any_peer", "reliable")
func request_use_item_rpc(item_type: String) -> void:
	if not multiplayer.is_server():
		return
	use_item_requested.emit(multiplayer.get_remote_sender_id(), item_type)

# ---------------------------------------------------------------- server -> client

func spawn_for(id: int, pos: Vector3) -> void:
	rpc_id(id, "spawn_player", id, pos)

@rpc("authority", "reliable")
func spawn_player(id: int, pos: Vector3) -> void:
	player_spawned.emit(id, pos)

func send_snapshot(id: int, snap: Dictionary, tick: int, storm: Dictionary) -> void:
	rpc_id(id, "apply_snapshot", snap, tick, storm)

@rpc("authority", "unreliable")
func apply_snapshot(snap: Dictionary, tick: int, storm: Dictionary) -> void:
	snapshot_received.emit(snap, tick, storm)

func announce_left(id: int) -> void:
	rpc("player_gone", id)

@rpc("authority", "reliable")
func player_gone(id: int) -> void:
	player_left.emit(id)

func send_shot(target: int, shooter: int, from: Vector3, to: Vector3, hit: int, weapon: int) -> void:
	rpc_id(target, "apply_shot", shooter, from, to, hit, weapon)

@rpc("authority", "reliable")
func apply_shot(shooter: int, from: Vector3, to: Vector3, hit: int, weapon: int) -> void:
	shot_fired.emit(shooter, from, to, hit, weapon)

func send_death(target: int, victim: int, killer: int) -> void:
	rpc_id(target, "apply_death", victim, killer)

@rpc("authority", "reliable")
func apply_death(victim: int, killer: int) -> void:
	player_died.emit(victim, killer)

func send_respawn(id: int, pos: Vector3) -> void:
	rpc_id(id, "apply_respawn", pos)

@rpc("authority", "reliable")
func apply_respawn(pos: Vector3) -> void:
	player_respawned.emit(pos)

func send_loot_state(id: int, taken: Array) -> void:
	rpc_id(id, "apply_loot_state", taken)

@rpc("authority", "reliable")
func apply_loot_state(taken: Array) -> void:
	loot_state.emit(taken)

func announce_loot_taken(loot_id: int, by: int) -> void:
	rpc("apply_loot_taken", loot_id, by)

@rpc("authority", "reliable")
func apply_loot_taken(loot_id: int, by: int) -> void:
	loot_taken.emit(loot_id, by)

func send_loot_result(id: int, message: String) -> void:
	rpc_id(id, "apply_loot_result", message)

@rpc("authority", "reliable")
func apply_loot_result(message: String) -> void:
	loot_result_received.emit(message)

func reject(id: int) -> void:
	rpc_id(id, "kicked", "authentication failed")
	await get_tree().create_timer(0.5).timeout
	if multiplayer.has_multiplayer_peer() and multiplayer.multiplayer_peer is ENetMultiplayerPeer:
		(multiplayer.multiplayer_peer as ENetMultiplayerPeer).disconnect_peer(id)

@rpc("authority", "reliable")
func kicked(reason: String) -> void:
	push_warning("Disconnected by server: %s" % reason)
	rejected.emit(reason)
	disconnected.emit()
	_shutdown.call_deferred()
