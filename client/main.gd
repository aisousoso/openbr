extends Node3D

## Client bootstrap: load the shared Verdant Reach map, show the operator lobby, connect,
## spawn the local player, render interest-managed snapshots, tracers and HUD.
##
## Run with no arguments for the lobby/character select, or connect directly:
##   godot --path . -- --host=127.0.0.1 --port=7777 --token=dev
## Add --touch to force the on-screen touch controls on desktop for testing.

const PlayerScene := preload("res://client/player.tscn")
const RemoteScene := preload("res://client/remote_player.tscn")
const ARENA := preload("res://maps/verdant_reach.tscn")
const Weapons := preload("res://shared/weapons.gd")
const Characters := preload("res://shared/characters.gd")
const MapData := preload("res://shared/map_data.gd")

const RECONCILE_DISTANCE := 1.0
const REMOTE_TIMEOUT_MS := 2000

var local_player
var remote_players := {}
var _seen := {}
var _connecting := false
var _reject_reason := ""
var _last_hp := 100
var _last_armor := 0
var _was_outside := false
var _last_storm_state := ""
var _run_seconds := 0.0
var _run_elapsed := 0.0
var _combat_test_started := false
var _loot_test_started := false
var _appearance: Dictionary = {}

@onready var hud = $HUD
@onready var touch = $Touch
@onready var connect_screen = $ConnectScreen
@onready var lobby = $Lobby
@onready var storm_visual = $Storm
@onready var loot_field = $LootField

func _ready() -> void:
	$World.add_child(ARENA.instantiate())

	Net.player_spawned.connect(_on_player_spawned)
	Net.snapshot_received.connect(_on_snapshot)
	Net.player_left.connect(_on_player_left)
	Net.connected.connect(_on_connected)
	Net.connection_failed.connect(_on_connection_failed)
	Net.disconnected.connect(_on_disconnected)
	Net.rejected.connect(_on_rejected)
	Net.shot_fired.connect(_on_shot_fired)
	Net.player_died.connect(_on_player_died)
	Net.player_respawned.connect(_on_player_respawned)
	Net.loot_result_received.connect(_on_loot_result)

	connect_screen.connect_requested.connect(_on_connect_requested)
	connect_screen.back_requested.connect(_on_connect_back)
	lobby.play_requested.connect(_on_lobby_play)
	loot_field.prompt_changed.connect(hud.set_loot_prompt)
	touch.loot.connect(_on_touch_loot)
	touch.use_bandage.connect(_on_touch_use_bandage)
	touch.use_medkit.connect(_on_touch_use_medkit)

	hud.set_map_name(MapData.NAME)
	hud.visible = false
	loot_field.visible = false
	touch.set_active(false)
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	_run_seconds = float(_arg("--run-seconds", "0"))
	_appearance = Characters.load_profile()

	if _has_connect_args():
		lobby.close_screen()
		connect_screen.close_screen()
		_start_connect(_arg("--host", "127.0.0.1"), int(_arg("--port", "7777")), _arg("--token", "dev"))
	else:
		lobby.open_screen()

func _process(_delta: float) -> void:
	if _run_seconds > 0.0:
		_run_elapsed += _delta
		if _run_elapsed >= _run_seconds:
			print("client run limit reached (%.1fs)" % _run_seconds)
			get_tree().quit()
			return

	# A remote player that leaves our interest area simply stops appearing in
	# snapshots; remove the proxy after a short grace period.
	var now := Time.get_ticks_msec()
	for id in _seen.keys():
		if now - int(_seen[id]) <= REMOTE_TIMEOUT_MS:
			continue
		_seen.erase(id)
		if remote_players.has(id):
			remote_players[id].queue_free()
			remote_players.erase(id)

func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"):
		# Do not steal the mouse while the connection or lobby UI is open, and
		# the touch UI needs a visible pointer on desktop (--touch).
		if lobby.visible or connect_screen.visible or local_player == null or touch.is_enabled():
			return
		if Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
			Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
		else:
			Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

# ---------------------------------------------------------------- connection

func _on_connect_requested(host: String, port: int, token: String) -> void:
	_start_connect(host, port, token)

func _on_connect_back() -> void:
	if _connecting:
		return
	connect_screen.close_screen()
	lobby.open_screen()

func _on_lobby_play() -> void:
	_appearance = lobby.get_appearance()
	Characters.save_profile(_appearance)
	lobby.close_screen()
	connect_screen.open_screen()

func _start_connect(host: String, port: int, token: String) -> void:
	if _connecting:
		return
	_connecting = true
	if _appearance.is_empty():
		_appearance = Characters.load_profile()
	connect_screen.set_connecting(true)
	connect_screen.set_status("Connecting to %s:%d ..." % [host, port])
	print("Connecting to %s:%d ..." % [host, port])
	Net.join_game(host, port, token, _appearance)

func _on_connected() -> void:
	connect_screen.set_status("Connected. Authenticating...")

func _on_connection_failed() -> void:
	_connecting = false
	connect_screen.open_screen("Could not connect. Check host, port and firewall.")

func _on_rejected(reason: String) -> void:
	_reject_reason = reason

func _on_disconnected() -> void:
	print("Disconnected from server.")
	if is_instance_valid(local_player):
		local_player.queue_free()
	local_player = null
	for id in remote_players:
		remote_players[id].queue_free()
	remote_players.clear()
	_seen.clear()

	touch.set_active(false)
	touch.reset()
	hud.visible = false
	loot_field.visible = false
	storm_visual.reset()
	loot_field.set_local_player(null)
	loot_field.reset()
	_last_hp = 100
	_last_armor = 0
	_was_outside = false
	_last_storm_state = ""
	_connecting = false
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

	var msg := "Disconnected."
	if not _reject_reason.is_empty():
		msg = "Rejected: %s" % _reject_reason
	_reject_reason = ""
	if _has_connect_args():
		connect_screen.open_screen(msg)
	else:
		lobby.open_screen(msg)

# ---------------------------------------------------------------- players

func _on_player_spawned(id: int, pos: Vector3) -> void:
	if local_player != null:
		return
	local_player = PlayerScene.instantiate()
	local_player.name = "LocalPlayer"
	local_player.position = pos
	local_player.spawn_id = id
	local_player.touch_mode = touch.is_enabled()
	$Players.add_child(local_player)
	local_player.apply_appearance(_appearance)
	local_player.loot_field = loot_field
	loot_field.set_local_player(local_player)

	if touch.is_enabled():
		touch.look.connect(local_player.apply_look)
		touch.fire.connect(local_player.request_fire)
		touch.reload.connect(local_player.request_reload)
		touch.weapon_cycle.connect(local_player.cycle_weapon)
		touch.set_active(true)
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	else:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED

	hud.visible = true
	loot_field.visible = true
	var start_weapon := Weapons.get_weapon(0)
	hud.set_weapon(0, int(start_weapon["mag"]), int(start_weapon["reserve"]), false)
	hud.set_armor(0)
	hud.set_inventory(0, 0)
	hud.set_heal(0, 0.0)
	lobby.close_screen()
	connect_screen.close_screen()
	_connecting = false
	_reject_reason = ""
	_last_hp = 100
	_last_armor = 0
	_was_outside = false
	_last_storm_state = ""

	if _has_arg("--test-combat") and not _combat_test_started:
		_combat_test_started = true
		_run_combat_test()
	if _has_arg("--test-loot") and not _loot_test_started:
		_loot_test_started = true
		_run_loot_test()

func _run_loot_test() -> void:
	# Dev-only smoke test: walk up to the spawn-adjacent loot in spirit (the
	# server validates distance), pick it up, then use the bandage.
	await get_tree().create_timer(0.8).timeout
	if local_player == null:
		return
	print("loot test prompt: visible=%s text='%s'" % [hud.loot_prompt.visible, hud.loot_prompt.text])
	loot_field.request_nearest()
	await get_tree().create_timer(0.8).timeout
	if local_player == null:
		return
	print("loot test pickup: inventory='%s' armor='%s' message='%s'" % [
		hud.inventory_label.text, hud.armor_label.text, hud.message.text,
	])
	local_player.request_use_item("bandage")
	await get_tree().create_timer(0.8).timeout
	if local_player == null:
		return
	print("loot test heal start: hp='%s' inventory='%s' heal='%s' message='%s'" % [
		hud.health_label.text, hud.inventory_label.text, hud.heal_label.text, hud.message.text,
	])
	await get_tree().create_timer(2.2).timeout
	if local_player == null:
		return
	print("loot test healed: hp='%s' inventory='%s' heal='%s' message='%s'" % [
		hud.health_label.text, hud.inventory_label.text, hud.heal_label.text, hud.message.text,
	])

func _run_combat_test() -> void:
	# Dev-only smoke test: exercise weapon switch, fire and reload RPCs.
	await get_tree().create_timer(0.8).timeout
	if local_player == null:
		return
	for index in [1, 2, 0]:
		local_player.request_weapon(index)
		await get_tree().create_timer(0.4).timeout
		for shot in 4:
			local_player.request_fire()
			await get_tree().create_timer(0.22).timeout
	local_player.request_reload()
	await get_tree().create_timer(0.5).timeout
	print("combat test done: hud='%s' remotes=%d" % [hud.weapon_label.text, remote_players.size()])

func _on_snapshot(snap: Dictionary, _tick: int, storm: Dictionary) -> void:
	var my_id := multiplayer.get_unique_id()
	var now := Time.get_ticks_msec()

	if not storm.is_empty():
		storm_visual.set_state(
			float(storm.get("cx", 0.0)),
			float(storm.get("cz", 0.0)),
			float(storm.get("radius", 48.0))
		)

	for id in snap:
		var d: Array = snap[id]
		if d.size() < 5:
			continue

		var pos := Vector3(d[0], d[1], d[2])
		var yaw := float(d[3])
		var hp := int(d[4])
		var alive := true
		if d.size() > 5:
			alive = bool(d[5])
		var kills := 0
		if d.size() > 6:
			kills = int(d[6])
		var weapon_index := 0
		var mag := 0
		var reserve := 0
		var reloading := false
		if d.size() > 7:
			weapon_index = int(d[7])
		if d.size() > 8:
			mag = int(d[8])
		if d.size() > 9:
			reserve = int(d[9])
		if d.size() > 10:
			reloading = bool(d[10])

		var appearance: Dictionary = {}
		if d.size() >= 16:
			appearance = {
				"character": int(d[11]),
				"primary": d[12],
				"secondary": d[13],
				"accent": d[14],
				"outfit": int(d[15]),
			}

		var armor := 0
		var bandages := 0
		var medkits := 0
		var heal_remaining := 0.0
		var heal_type := 0
		if d.size() >= 21:
			armor = int(d[16])
			bandages = int(d[17])
			medkits = int(d[18])
			heal_remaining = float(d[19])
			heal_type = int(d[20])

		if id == my_id:
			if not appearance.is_empty():
				_appearance = Characters.sanitize(appearance)
			var took_health_damage := hp < _last_hp
			if took_health_damage:
				hud.flash_damage()
			if armor < _last_armor and not took_health_damage:
				hud.flash_armor()
			_last_hp = hp
			_last_armor = armor
			hud.set_health(hp)
			hud.set_armor(armor)
			hud.set_inventory(bandages, medkits)
			hud.set_heal(heal_type, heal_remaining)
			hud.set_kills(kills)
			hud.set_weapon(weapon_index, mag, reserve, reloading)
			if local_player != null:
				local_player.weapon_index = weapon_index
			if local_player == null:
				_on_player_spawned(id, pos)
			else:
				if local_player.is_alive != alive:
					local_player.set_alive(alive)
				if alive and local_player.global_position.distance_to(pos) > RECONCILE_DISTANCE:
					local_player.global_position = pos
			if local_player != null and not appearance.is_empty():
				local_player.apply_appearance(_appearance)
			continue

		_seen[id] = now
		if not remote_players.has(id):
			var rp = RemoteScene.instantiate()
			rp.name = "Remote_%d" % id
			$Players.add_child(rp)
			remote_players[id] = rp
		remote_players[id].set_target(pos, yaw)
		remote_players[id].set_alive(alive)
		if not appearance.is_empty():
			remote_players[id].apply_appearance(appearance)

	_update_storm_hud(storm)

func _update_storm_hud(storm: Dictionary) -> void:
	if storm.is_empty():
		hud.set_storm_status("Storm: --", false)
		return

	var state := String(storm.get("state", "waiting"))
	var timer := int(ceil(maxf(0.0, float(storm.get("timer", 0.0)))))
	var radius := int(round(float(storm.get("radius", 0.0))))
	var dps := int(round(float(storm.get("dps", 0.0))))
	var storm_radius := float(storm.get("radius", 0.0))
	var center := Vector2(float(storm.get("cx", 0.0)), float(storm.get("cz", 0.0)))

	var outside := false
	if local_player != null and local_player.is_alive:
		var offset := Vector2(local_player.global_position.x - center.x, local_player.global_position.z - center.y)
		outside = offset.length() > storm_radius

	var text := ""
	if state == "shrinking":
		text = "STORM SHRINKING  %ds  |  Safe zone %dm" % [timer, radius]
	elif state == "final":
		text = "FINAL STORM  |  Safe zone %dm" % radius
	else:
		text = "Storm shrinks in %ds  |  Safe zone %dm" % [timer, radius]

	if outside:
		text = "OUTSIDE THE STORM!  %d HP/s" % dps
		if not _was_outside:
			hud.show_message("OUTSIDE THE STORM! Move to the safe zone.", 2.0)
	_was_outside = outside
	hud.set_storm_status(text, outside)

	if OS.is_debug_build() and state != _last_storm_state:
		_last_storm_state = state
		print("Storm: %s (radius %dm, timer %ds)" % [state, radius, timer])

func _on_player_left(id: int) -> void:
	_seen.erase(id)
	if remote_players.has(id):
		remote_players[id].queue_free()
		remote_players.erase(id)

# ---------------------------------------------------------------- events

func _on_shot_fired(shooter: int, from: Vector3, to: Vector3, hit: int, weapon: int) -> void:
	_spawn_tracer(from, to, weapon)
	var my_id := multiplayer.get_unique_id()
	if shooter == my_id and hit != 0:
		hud.flash_hit()
	if hit == my_id:
		hud.flash_damage()

func _on_player_died(victim: int, killer: int) -> void:
	var my_id := multiplayer.get_unique_id()
	if victim == my_id:
		if local_player != null:
			local_player.set_alive(false)
		var cause := "the storm"
		if killer < 0:
			cause = "a bot"
		elif killer != 0:
			cause = "player %d" % killer
		hud.show_message("Eliminated by %s — respawning..." % cause, 3.0)
	elif killer == my_id:
		if victim < 0:
			hud.show_message("Eliminated a bot", 2.0)
		else:
			hud.show_message("Eliminated player %d" % victim, 2.0)

func _on_player_respawned(pos: Vector3) -> void:
	if local_player == null:
		return
	local_player.global_position = pos
	local_player.velocity = Vector3.ZERO
	local_player.set_alive(true)
	hud.set_health(100)
	hud.set_armor(0)
	hud.set_inventory(0, 0)
	hud.set_heal(0, 0.0)
	var start_weapon := Weapons.get_weapon(0)
	hud.set_weapon(0, int(start_weapon["mag"]), int(start_weapon["reserve"]), false)
	_last_hp = 100
	_last_armor = 0
	_was_outside = false
	hud.show_message("Respawned", 1.5)

func _on_loot_result(message: String) -> void:
	if message.is_empty():
		return
	hud.show_message(message, 2.0)
	if OS.is_debug_build():
		print("loot: %s" % message)

func _on_touch_loot() -> void:
	if local_player != null and local_player.is_alive:
		loot_field.request_nearest()

func _on_touch_use_bandage() -> void:
	if local_player != null:
		local_player.request_use_item("bandage")

func _on_touch_use_medkit() -> void:
	if local_player != null:
		local_player.request_use_item("medkit")

func _spawn_tracer(from: Vector3, to: Vector3, weapon := 0) -> void:
	var mesh := ImmediateMesh.new()
	mesh.surface_begin(Mesh.PRIMITIVE_LINES)
	mesh.surface_add_vertex(from)
	mesh.surface_add_vertex(to)
	mesh.surface_end()

	var color := Color(1.0, 0.85, 0.35)
	var emission := Color(1.0, 0.7, 0.2)
	if weapon == 1:
		color = Color(0.45, 0.85, 1.0)
		emission = Color(0.2, 0.65, 1.0)
	elif weapon == 2:
		color = Color(1.0, 0.5, 0.2)
		emission = Color(1.0, 0.3, 0.1)

	var material := StandardMaterial3D.new()
	material.shading_mode = BaseMaterial3D.SHADING_MODE_UNSHADED
	material.albedo_color = color
	material.emission_enabled = true
	material.emission = emission

	var node := MeshInstance3D.new()
	node.mesh = mesh
	node.material_override = material
	node.top_level = true
	$Effects.add_child(node)
	get_tree().create_timer(0.07).timeout.connect(node.queue_free)

# ---------------------------------------------------------------- args

func _has_connect_args() -> bool:
	for a in _all_args():
		if a.begins_with("--host=") or a.begins_with("--port=") or a.begins_with("--token="):
			return true
	return false

func _has_arg(flag: String) -> bool:
	return flag in _all_args()

func _arg(key: String, fallback: String) -> String:
	for a in _all_args():
		if a.begins_with(key + "="):
			return a.substr(key.length() + 1)
	return fallback

func _all_args() -> Array:
	var out: Array = []
	for a in OS.get_cmdline_args():
		out.append(a)
	for a in OS.get_cmdline_user_args():
		out.append(a)
	return out
