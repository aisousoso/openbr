extends Node

const BattlePass := preload("res://shared/battle_pass.gd")

## Networking facade shared by client and server.
## Every RPC lives here, so both sides agree on node paths (/root/Net).
##
## Client -> server : authenticate(token, appearance), request_ready, send_input,
##                    request_fire, request_loot, request_use_item
## Server -> client : match_state, spawn_player, apply_snapshot, apply_shot,
##                    apply_death, apply_respawn, player_gone, kicked,
##                    loot_state, loot_taken, loot_result, kill_feed

signal connected
signal connection_failed
signal disconnected
signal rejected(reason: String)

signal auth_requested(id: int, token: String, appearance: Dictionary)
signal ready_requested(id: int, ready: bool)
signal input_received(id: int, dir: Vector2, yaw: float, jump: bool)
signal fire_requested(id: int, dir: Vector3)
signal weapon_requested(id: int, index: int)
signal reload_requested(id: int)
signal loot_requested(id: int, loot_id: int)
signal use_item_requested(id: int, item_type: String)
signal vehicle_enter_requested(id: int, vehicle_id: int)
signal vehicle_exit_requested(id: int, vehicle_id: int)
signal emote_requested(id: int, emote_index: int)
signal ping_requested(id: int, pos: Vector3)
signal emote_received(player_id: int, emote_index: int)
signal ping_received(player_id: int, pos: Vector3)
signal peer_disconnected(id: int)

signal match_state_received(state: Dictionary)
signal player_spawned(id: int, pos: Vector3)
signal snapshot_received(snap: Dictionary, tick: int, storm: Dictionary)
signal player_left(id: int)
signal shot_fired(shooter: int, from: Vector3, to: Vector3, hit: int, weapon: int)
signal player_died(victim: int, killer: int)
signal player_respawned(pos: Vector3)
signal loot_state(taken: Array)
signal loot_taken(loot_id: int, by: int)
signal loot_spawned(loot_id: int, item_type: String, pos: Vector3)
signal loot_spawned_bulk(spawns: Array)
signal loot_result_received(message: String)
signal loot_reset
signal battle_pass_updated(xp: int, tier: int)
signal kill_feed_received(text: String)

const SEND_HZ := 30.0
## ENet only reports a dead connection after ~32s, which feels like a hang.
## Fail fast so the connect screen can show a useful message.
const CONNECT_TIMEOUT := 8.0

var _peer: ENetMultiplayerPeer
var _acc := 0.0
var _dir := Vector2.ZERO
var _yaw := 0.0
var _jump := false
var _appearance: Dictionary = {}
var _join_token := ""
var _connect_deadline := 0.0
## Human-readable reason for the last connection_failed, so the UI can tell a
## DNS/address mistake apart from a silent (firewall) timeout.
var last_connect_error := ""

func _ready() -> void:
	multiplayer.connected_to_server.connect(func() -> void:
		_connect_deadline = 0.0
		last_connect_error = ""
		connected.emit()
		if not _join_token.is_empty() and is_client_connected():
			rpc_id(1, "authenticate", _join_token, _appearance)
	)
	multiplayer.connection_failed.connect(func() -> void:
		_connect_deadline = 0.0
		if last_connect_error.is_empty():
			last_connect_error = "server refused the connection"
		connection_failed.emit()
		_shutdown.call_deferred()
	)
	multiplayer.server_disconnected.connect(func() -> void:
		disconnected.emit()
		_shutdown.call_deferred()
	)
	multiplayer.peer_disconnected.connect(func(id: int) -> void: peer_disconnected.emit(id))

func _process(_delta: float) -> void:
	if _connect_deadline <= 0.0:
		return
	if is_client_connected():
		_connect_deadline = 0.0
		return
	if Time.get_ticks_msec() < _connect_deadline:
		return
	_connect_deadline = 0.0
	push_warning("connect timed out after %.0fs" % CONNECT_TIMEOUT)
	last_connect_error = "no response after %.0fs (host, port or firewall)" % CONNECT_TIMEOUT
	connection_failed.emit()
	_shutdown.call_deferred()

func _shutdown() -> void:
	_connect_deadline = 0.0
	_join_token = ""
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
	_appearance = appearance.duplicate(true)
	_join_token = token
	_peer = ENetMultiplayerPeer.new()
	var err := _peer.create_client(host, port)
	if err != OK:
		push_error("connect failed: %s" % error_string(err))
		_join_token = ""
		_connect_deadline = 0.0
		last_connect_error = "could not reach %s:%d (check the address)" % [host, port]
		connection_failed.emit()
		return
	multiplayer.multiplayer_peer = _peer
	# Authentication is sent from the connected_to_server handler in _ready().
	_connect_deadline = Time.get_ticks_msec() + int(CONNECT_TIMEOUT * 1000.0)

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

func request_vehicle_enter(vehicle_id: int) -> void:
	if is_server() or not is_client_connected():
		return
	rpc_id(1, "request_vehicle_enter_rpc", vehicle_id)

func request_vehicle_exit(vehicle_id: int) -> void:
	if is_server() or not is_client_connected():
		return
	rpc_id(1, "request_vehicle_exit_rpc", vehicle_id)

func request_emote(emote_index: int) -> void:
	if is_server() or not is_client_connected():
		return
	rpc_id(1, "request_emote_rpc", emote_index)

func request_ping(pos: Vector3) -> void:
	if is_server() or not is_client_connected():
		return
	rpc_id(1, "request_ping_rpc", pos.x, pos.y, pos.z)

func send_ready(ready: bool) -> void:
	if is_server() or not is_client_connected():
		return
	rpc_id(1, "request_ready_rpc", ready)

## Leave the current server without waiting for a socket timeout. The client
## treats this exactly like a server disconnect and returns to the lobby.
func leave_game() -> void:
	_shutdown()
	disconnected.emit()

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

@rpc("any_peer", "reliable")
func request_vehicle_enter_rpc(vehicle_id: int) -> void:
	if not multiplayer.is_server():
		return
	vehicle_enter_requested.emit(multiplayer.get_remote_sender_id(), vehicle_id)

@rpc("any_peer", "reliable")
func request_vehicle_exit_rpc(vehicle_id: int) -> void:
	if not multiplayer.is_server():
		return
	vehicle_exit_requested.emit(multiplayer.get_remote_sender_id(), vehicle_id)

@rpc("any_peer", "reliable")
func request_emote_rpc(emote_index: int) -> void:
	if not multiplayer.is_server():
		return
	emote_requested.emit(multiplayer.get_remote_sender_id(), emote_index)

@rpc("any_peer", "reliable")
func request_ping_rpc(px: float, py: float, pz: float) -> void:
	if not multiplayer.is_server():
		return
	var pos := Vector3(px, py, pz)
	ping_requested.emit(multiplayer.get_remote_sender_id(), pos)

@rpc("any_peer", "reliable")
func request_ready_rpc(ready: bool) -> void:
	if not multiplayer.is_server():
		return
	ready_requested.emit(multiplayer.get_remote_sender_id(), ready)

# ---------------------------------------------------------------- server -> client

func send_match_state(id: int, state: Dictionary) -> void:
	rpc_id(id, "apply_match_state", state)

func broadcast_match_state(state: Dictionary) -> void:
	rpc("apply_match_state", state)

@rpc("authority", "reliable")
func apply_match_state(state: Dictionary) -> void:
	match_state_received.emit(state)

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

func send_dynamic_loot(id: int, spawns: Array) -> void:
	rpc_id(id, "apply_dynamic_loot", spawns)

@rpc("authority", "reliable")
func apply_dynamic_loot(spawns: Array) -> void:
	loot_spawned_bulk.emit(spawns)

func announce_loot_taken(loot_id: int, by: int) -> void:
	rpc("apply_loot_taken", loot_id, by)

@rpc("authority", "reliable")
func apply_loot_taken(loot_id: int, by: int) -> void:
	loot_taken.emit(loot_id, by)

func announce_emote(player_id: int, emote_index: int) -> void:
	rpc("apply_emote", player_id, emote_index)

@rpc("authority", "reliable")
func apply_emote(player_id: int, emote_index: int) -> void:
	emote_received.emit(player_id, emote_index)

func announce_ping(player_id: int, pos: Vector3) -> void:
	rpc("apply_ping", player_id, pos.x, pos.y, pos.z)

@rpc("authority", "reliable")
func apply_ping(player_id: int, px: float, py: float, pz: float) -> void:
	var pos := Vector3(px, py, pz)
	ping_received.emit(player_id, pos)

func announce_loot_spawned(loot_id: int, item_type: String, pos: Vector3) -> void:
	rpc("apply_loot_spawned", loot_id, item_type, pos)

@rpc("authority", "reliable")
func apply_loot_spawned(loot_id: int, item_type: String, pos: Vector3) -> void:
	loot_spawned.emit(loot_id, item_type, pos)

func send_loot_result(id: int, message: String) -> void:
	rpc_id(id, "apply_loot_result", message)

@rpc("authority", "reliable")
func apply_loot_result(message: String) -> void:
	loot_result_received.emit(message)

func send_loot_reset(id: int) -> void:
	rpc_id(id, "apply_loot_reset")

@rpc("authority", "reliable")
func apply_loot_reset() -> void:
	loot_reset.emit()

func send_battle_pass_update(id: int, xp: int) -> void:
	rpc_id(id, "apply_battle_pass_update", xp)

@rpc("authority", "reliable")
func apply_battle_pass_update(xp: int) -> void:
	battle_pass_updated.emit(xp, BattlePass.tier_for_xp(xp))

func announce_kill_feed(text: String) -> void:
	rpc("apply_kill_feed", text)

@rpc("authority", "reliable")
func apply_kill_feed(text: String) -> void:
	kill_feed_received.emit(text)

func reject(id: int, reason := "authentication failed") -> void:
	rpc_id(id, "kicked", reason)
	await get_tree().create_timer(0.5).timeout
	if not multiplayer.has_multiplayer_peer() or not (multiplayer.multiplayer_peer is ENetMultiplayerPeer):
		return
	var peer := multiplayer.multiplayer_peer as ENetMultiplayerPeer
	# The client usually closes the connection itself as soon as it receives
	# "kicked", so the peer may already be gone by the time we get here.
	# get_peer() pushes an engine error for unknown ids, so check the peer list
	# from the MultiplayerAPI first.
	if multiplayer.get_peers().has(id):
		peer.disconnect_peer(id)

@rpc("authority", "reliable")
func kicked(reason: String) -> void:
	push_warning("Disconnected by server: %s" % reason)
	rejected.emit(reason)
	disconnected.emit()
	_shutdown.call_deferred()
