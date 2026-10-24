extends Node3D

## Authoritative game server.
## Run headless:
##   godot --headless --path . res://server/main.tscn -- --port=7777 --dev-auth
##
## Responsibilities:
##  - load maps/verdant_reach.tscn (same colliders as the client)
##  - simulate one CharacterBody3D per player with shared/movement.gd
##  - hitscan shooting, damage, death and respawn
##  - cell-based interest management for snapshots

const Movement := preload("res://shared/movement.gd")
const Weapons := preload("res://shared/weapons.gd")
const Characters := preload("res://shared/characters.gd")
const Loot := preload("res://shared/loot.gd")
const Inventory := preload("res://shared/inventory.gd")
const MapData := preload("res://shared/map_data.gd")
const Auth := preload("res://server/auth.gd")
const ARENA := preload("res://maps/verdant_reach.tscn")

const MAX_PLAYERS := 64
const SNAPSHOT_HZ := 20.0

const DEFAULT_WEAPON := 0
const WEAPON_SWITCH_TIME := 0.25
const RESPAWN_TIME := 3.0
const EYE_HEIGHT := 1.65
const BODY_CENTER := 0.9
const HIT_RADIUS := 0.6

const BOT_MAX := 16
const BOT_AIM_ERROR := 0.03

const CELL_SIZE := 20.0
const INTEREST_RADIUS := 45.0

# Storm phases: wait before the next shrink, shrink duration, target radius and
# damage per second for players outside the safe zone. The first wait is a
# grace period with no storm damage.
const STORM_CENTER := Vector2(0.0, 0.0)
const STORM_START_RADIUS := 54.0
const STORM_FINAL_DPS := 8.0
const STORM_PHASES := [
	{"wait": 25.0, "shrink": 22.0, "radius": 38.0, "dps": 2.0},
	{"wait": 12.0, "shrink": 16.0, "radius": 22.0, "dps": 4.0},
	{"wait": 10.0, "shrink": 12.0, "radius": 10.0, "dps": 6.0},
]

var players := {}
var cells := {}
var tick := 0
var snap_acc := 0.0
var allow_dev := false

var _spawns: Array[Vector3] = []
var _pending_shots: Array = []
var _storm := {}
var _storm_damage_acc := 0.0
var _storm_time_scale := 1.0
var _run_seconds := 0.0
var _run_elapsed := 0.0
var _bot_count := 0
var _loot_taken := {}
var _test_loot := false

func _ready() -> void:
	allow_dev = "--dev-auth" in _all_args()
	# Debug aids for local testing: speed storm timers up 10x and optionally
	# quit after a fixed wall-clock duration so redirected logs flush cleanly.
	_storm_time_scale = 10.0 if "--storm-fast" in _all_args() else 1.0
	_run_seconds = float(_arg("--run-seconds", "0"))
	_bot_count = clampi(int(_arg("--bots", "0")), 0, BOT_MAX)
	_test_loot = "--test-loot" in _all_args()
	_storm = _new_storm()

	var arena := ARENA.instantiate()
	add_child(arena)
	_collect_spawns(arena)
	_spawn_bots()

	Net.auth_requested.connect(_on_auth_requested)
	Net.input_received.connect(_on_input_received)
	Net.fire_requested.connect(_on_fire_requested)
	Net.weapon_requested.connect(_on_weapon_requested)
	Net.reload_requested.connect(_on_reload_requested)
	Net.loot_requested.connect(_on_loot_requested)
	Net.use_item_requested.connect(_on_use_item_requested)
	Net.peer_disconnected.connect(_on_peer_disconnected)

	var port := int(_arg("--port", "7777"))
	var err := Net.host_game(port, MAX_PLAYERS)
	if err != OK:
		push_error("failed to host on udp/%d: %s" % [port, error_string(err)])
		get_tree().quit(1)
		return
	print("OpenBR server listening on udp/%d (map=%s, dev_auth=%s, spawns=%d, bots=%d, storm_scale=%.2f)" % [port, MapData.NAME, allow_dev, _spawns.size(), _bot_count, _storm_time_scale])

func _physics_process(delta: float) -> void:
	if _run_seconds > 0.0:
		_run_elapsed += delta
		if _run_elapsed >= _run_seconds:
			print("server run limit reached (%.1fs)" % _run_seconds)
			get_tree().quit()
			return

	var now := Time.get_ticks_msec() / 1000.0
	_update_weapons(now)
	_update_healing(now)
	_update_bots(now)

	for id in players:
		var p: Dictionary = players[id]
		if not p["alive"]:
			var dead_body: CharacterBody3D = p["body"]
			if not dead_body.is_on_floor():
				dead_body.velocity.y -= Movement.GRAVITY * delta
				dead_body.move_and_slide()
				p["pos"] = dead_body.global_position
				_update_cell(id, p)
			if now >= float(p["respawn_at"]):
				_respawn(id, p)
			continue

		var body: CharacterBody3D = p["body"]
		Movement.step_body(body, p["input_dir"], p["yaw"], p["jump"], delta)
		p["jump"] = false
		p["pos"] = body.global_position
		_update_cell(id, p)

	# Resolve queued shots inside the physics tick so space-state queries are safe.
	for shot in _pending_shots:
		_resolve_shot(int(shot[0]), shot[1], int(shot[2]))
	_pending_shots.clear()

	_update_storm(delta)

	snap_acc += delta
	if snap_acc < 1.0 / SNAPSHOT_HZ:
		return
	snap_acc -= 1.0 / SNAPSHOT_HZ
	tick += 1
	_send_snapshots()

# ---------------------------------------------------------------- auth / peers

func _on_auth_requested(id: int, token: String, appearance: Dictionary) -> void:
	if players.has(id):
		return

	var ok := allow_dev and token == "dev"
	if not ok:
		var data := Auth.verify(token, OS.get_environment("BR_SECRET"))
		ok = not data.is_empty()

	if not ok:
		print("peer %d rejected (invalid token)" % id)
		Net.reject(id)
		return

	var p := _create_player(id, false, DEFAULT_WEAPON, appearance)
	if _test_loot:
		# Dev-only hook so the loot/heal smoke test can exercise a real heal.
		p["health"] = 60
	Net.spawn_for(id, p["pos"])
	Net.send_loot_state(id, _loot_taken.keys())
	print("peer %d authenticated (operator %s)" % [id, Characters.get_character(int(p["appearance"]["character"]))["name"]])

func _create_player(id: int, is_bot: bool, weapon_index := DEFAULT_WEAPON, appearance: Dictionary = {}) -> Dictionary:
	weapon_index = clampi(weapon_index, 0, Weapons.count() - 1)
	var spawn: Vector3 = _safe_spawn()
	var body := _make_body(spawn)
	var cell := _cell_of(spawn)
	var appearance_data := Characters.sanitize(appearance)
	if appearance.is_empty():
		appearance_data = Characters.default_appearance(0) if not is_bot else Characters.bot_appearance(id)

	var ammo := Weapons.fresh_ammo()
	if is_bot:
		# Bots are test dummies; keep their reserves topped up so a long test
		# session does not end with a map full of unarmed bots.
		for i in ammo:
			ammo[i]["reserve"] = 999

	var p := {
		"pos": spawn,
		"yaw": 0.0,
		"input_dir": Vector2.ZERO,
		"jump": false,
		"health": 100,
		"alive": true,
		"kills": 0,
		"last_shot": -999.0,
		"respawn_at": 0.0,
		"cell": cell,
		"body": body,
		"weapon": weapon_index,
		"preferred_weapon": weapon_index,
		"ammo": ammo,
		"reload_until": 0.0,
		"switch_until": 0.0,
		"bot": is_bot,
		"appearance": appearance_data,
	}
	p.merge(Inventory.new_state())
	players[id] = p

	if not cells.has(cell):
		cells[cell] = []
	cells[cell].append(id)
	return p

func _spawn_bots() -> void:
	for i in _bot_count:
		var id := -(i + 1)
		var weapon_index := i % Weapons.count()
		var p := _create_player(id, true, weapon_index)
		print("bot %d spawned (%s) at %s" % [id, Weapons.name_of(weapon_index), str(p["pos"])])

func _on_peer_disconnected(id: int) -> void:
	var p = players.get(id)
	if p == null:
		return
	_remove_from_cell(id, p["cell"])
	var body: CharacterBody3D = p["body"]
	if is_instance_valid(body):
		body.queue_free()
	players.erase(id)
	Net.announce_left(id)
	print("peer %d left" % id)

# ---------------------------------------------------------------- input / shooting

func _on_input_received(id: int, dir: Vector2, yaw: float, jump: bool) -> void:
	var p = players.get(id)
	if p == null or not p["alive"]:
		return
	if not dir.is_finite() or not is_finite(yaw):
		return
	p["input_dir"] = dir.limit_length(1.0)
	p["yaw"] = yaw
	p["jump"] = jump

# ---------------------------------------------------------------- bots

func _update_bots(now: float) -> void:
	for id in players.keys():
		var p: Dictionary = players[id]
		if not p.get("bot", false) or not p["alive"]:
			continue

		var target_id := _pick_bot_target(id)
		if target_id == 0:
			p["input_dir"] = Vector2.ZERO
			p["jump"] = false
			continue

		var target: Dictionary = players[target_id]
		var delta: Vector3 = target["pos"] - p["pos"]
		var dist := Vector2(delta.x, delta.z).length()
		p["yaw"] = atan2(-delta.x, -delta.z)

		var input := Vector2.ZERO
		if dist > 16.0:
			input = Vector2(0.0, -1.0)
		elif dist < 7.0:
			input = Vector2(0.0, 1.0)
		else:
			input = Vector2(1.0, 0.0)
		p["input_dir"] = input
		p["jump"] = false

		var weapon := Weapons.get_weapon(int(p["weapon"]))
		if dist <= float(weapon["range"]) and _bot_has_line_of_sight(p, target):
			_bot_try_fire(id, p, target, now)

func _pick_bot_target(bot_id: int) -> int:
	var best_human := 0
	var best_human_dist := INF
	var best_any := 0
	var best_any_dist := INF
	var bot_pos: Vector3 = players[bot_id]["pos"]

	for id in players:
		if id == bot_id:
			continue
		var other: Dictionary = players[id]
		if not other["alive"]:
			continue
		var delta: Vector3 = other["pos"] - bot_pos
		var d := Vector2(delta.x, delta.z).length()
		if d < best_any_dist:
			best_any_dist = d
			best_any = id
		if not other.get("bot", false) and d < best_human_dist:
			best_human_dist = d
			best_human = id

	if best_human != 0:
		return best_human
	return best_any

func _bot_has_line_of_sight(p: Dictionary, target: Dictionary) -> bool:
	var space := get_world_3d().direct_space_state
	if space == null:
		return false
	var from: Vector3 = p["pos"] + Vector3(0, EYE_HEIGHT, 0)
	var to: Vector3 = target["pos"] + Vector3(0, BODY_CENTER, 0)
	var query := PhysicsRayQueryParameters3D.create(from, to, 1)
	query.collide_with_areas = false
	return space.intersect_ray(query).is_empty()

func _bot_try_fire(id: int, p: Dictionary, target: Dictionary, now: float) -> void:
	if float(p["reload_until"]) > now:
		return

	var index := int(p["weapon"])
	var weapon := Weapons.get_weapon(index)
	var ammo: Dictionary = p["ammo"][index]
	if int(ammo["mag"]) <= 0:
		_start_reload(id, p, now)
		return
	if now - float(p["last_shot"]) < float(weapon["cooldown"]):
		return

	var origin: Vector3 = p["pos"] + Vector3(0, EYE_HEIGHT, 0)
	var aim: Vector3 = target["pos"] + Vector3(0, BODY_CENTER, 0)
	var delta := aim - origin
	if delta.length_squared() < 0.01:
		return

	var dir := delta.normalized()
	dir = dir.rotated(Vector3.UP, randf_range(-BOT_AIM_ERROR, BOT_AIM_ERROR))
	dir.y += randf_range(-BOT_AIM_ERROR * 0.6, BOT_AIM_ERROR * 0.6)
	dir = dir.normalized()

	p["last_shot"] = now
	ammo["mag"] = int(ammo["mag"]) - 1
	_pending_shots.append([id, dir, index])

	if int(ammo["mag"]) <= 0:
		_start_reload(id, p, now)

func _on_fire_requested(id: int, dir: Vector3) -> void:
	var p = players.get(id)
	if p == null or not p["alive"]:
		return

	var now := Time.get_ticks_msec() / 1000.0
	if now < float(p["switch_until"]):
		return
	if float(p["reload_until"]) > now:
		return

	var index := int(p["weapon"])
	var weapon := Weapons.get_weapon(index)
	var ammo: Dictionary = p["ammo"][index]

	if int(ammo["mag"]) <= 0:
		_start_reload(id, p, now)
		return
	if now - float(p["last_shot"]) < float(weapon["cooldown"]):
		return
	if not dir.is_finite() or dir.length_squared() < 0.01:
		return

	if float(p.get("heal_until", 0.0)) > now:
		Inventory.cancel_heal(p)
	p["last_shot"] = now
	ammo["mag"] = int(ammo["mag"]) - 1
	_pending_shots.append([id, dir.normalized(), index])

	if int(ammo["mag"]) <= 0:
		_start_reload(id, p, now)

func _on_weapon_requested(id: int, index: int) -> void:
	var p = players.get(id)
	if p == null or not p["alive"]:
		return

	index = clampi(index, 0, Weapons.count() - 1)
	if index == int(p["weapon"]):
		return

	p["weapon"] = index
	p["preferred_weapon"] = index
	p["reload_until"] = 0.0
	p["switch_until"] = Time.get_ticks_msec() / 1000.0 + WEAPON_SWITCH_TIME

func _on_reload_requested(id: int) -> void:
	var p = players.get(id)
	if p == null or not p["alive"]:
		return
	_start_reload(id, p, Time.get_ticks_msec() / 1000.0)

func _on_loot_requested(id: int, loot_id: int) -> void:
	var p = players.get(id)
	if p == null or not p["alive"]:
		return

	var spawn := Loot.get_spawn(loot_id)
	if spawn.is_empty():
		Net.send_loot_result(id, "Unknown loot")
		return
	if _loot_taken.has(loot_id):
		Net.send_loot_result(id, "Already taken")
		return

	var loot_pos: Vector3 = spawn["pos"]
	var player_pos: Vector3 = p["pos"]
	# Small tolerance covers interpolation and the loot's floating height.
	if player_pos.distance_to(loot_pos) > Loot.PICKUP_RADIUS + 0.6:
		Net.send_loot_result(id, "Move closer to loot")
		return

	var result := Inventory.pickup(p, String(spawn["type"]))
	if not bool(result["ok"]):
		Net.send_loot_result(id, String(result["message"]))
		return

	_loot_taken[loot_id] = true
	Net.announce_loot_taken(loot_id, id)
	Net.send_loot_result(id, String(result["message"]))

func _on_use_item_requested(id: int, item_type: String) -> void:
	var p = players.get(id)
	if p == null or not p["alive"]:
		return

	var now := Time.get_ticks_msec() / 1000.0
	var result := Inventory.start_heal(p, item_type, now)
	Net.send_loot_result(id, String(result["message"]))

func _update_healing(now: float) -> void:
	for id in players.keys():
		var p: Dictionary = players[id]
		if float(p.get("heal_until", 0.0)) <= 0.0:
			continue
		if not p["alive"]:
			Inventory.cancel_heal(p)
			continue

		var healed := Inventory.tick_heal(p, now)
		if healed > 0 and not p.get("bot", false):
			Net.send_loot_result(id, "Healed +%d HP" % healed)

func _start_reload(id: int, p: Dictionary, now: float) -> void:
	if float(p["reload_until"]) > now:
		return

	var index := int(p["weapon"])
	var weapon := Weapons.get_weapon(index)
	var ammo: Dictionary = p["ammo"][index]
	if int(ammo["mag"]) >= int(weapon["mag"]) or int(ammo["reserve"]) <= 0:
		return

	p["reload_until"] = now + float(weapon["reload"])

func _update_weapons(now: float) -> void:
	for id in players.keys():
		var p: Dictionary = players[id]
		if not p["alive"]:
			continue

		var until := float(p["reload_until"])
		if until <= 0.0 or now < until:
			continue

		var index := int(p["weapon"])
		var weapon := Weapons.get_weapon(index)
		var ammo: Dictionary = p["ammo"][index]
		var need := int(weapon["mag"]) - int(ammo["mag"])
		var take := mini(need, int(ammo["reserve"]))
		ammo["mag"] = int(ammo["mag"]) + take
		ammo["reserve"] = int(ammo["reserve"]) - take
		p["reload_until"] = 0.0

func _resolve_shot(id: int, dir: Vector3, weapon_index: int) -> void:
	var shooter = players.get(id)
	if shooter == null or not shooter["alive"]:
		return

	var weapon := Weapons.get_weapon(weapon_index)
	var origin: Vector3 = shooter["pos"] + Vector3(0, EYE_HEIGHT, 0)
	var now := Time.get_ticks_msec() / 1000.0
	var max_range := float(weapon["range"])
	var pellets := maxi(1, int(weapon["pellets"]))
	var spread := float(weapon["spread"])

	for pellet in pellets:
		var pellet_dir := dir
		if spread > 0.0:
			pellet_dir = dir.rotated(Vector3.UP, randf_range(-spread, spread))
			pellet_dir.y += randf_range(-spread, spread)
			pellet_dir = pellet_dir.normalized()

		var limit := max_range
		var space := get_world_3d().direct_space_state
		if space != null:
			var query := PhysicsRayQueryParameters3D.create(origin, origin + pellet_dir * max_range, 1)
			query.collide_with_areas = false
			var wall := space.intersect_ray(query)
			if not wall.is_empty():
				var wall_pos: Vector3 = wall["position"]
				limit = origin.distance_to(wall_pos)

		var hit_id := 0
		var hit_t := limit

		for other_id in players:
			if other_id == id:
				continue
			var target: Dictionary = players[other_id]
			if not target["alive"]:
				continue
			var center: Vector3 = target["pos"] + Vector3(0, BODY_CENTER, 0)
			var t := _ray_sphere(origin, pellet_dir, center, HIT_RADIUS)
			if t >= 0.0 and t < hit_t:
				hit_t = t
				hit_id = other_id

		var end := origin + pellet_dir * hit_t
		if hit_id != 0:
			_apply_damage(hit_id, id, now, int(weapon["damage"]))
		_send_shot_events(id, origin, end, hit_id, weapon_index)

func _send_shot_events(shooter_id: int, from: Vector3, to: Vector3, hit: int, weapon_index: int) -> void:
	for id in players:
		var p: Dictionary = players[id]
		if p.get("bot", false):
			continue
		var pos: Vector3 = p["pos"]
		if id == shooter_id or id == hit or pos.distance_to(from) <= INTEREST_RADIUS:
			Net.send_shot(id, shooter_id, from, to, hit, weapon_index)

func _send_death_events(victim_id: int, killer_id: int) -> void:
	var victim_pos: Vector3 = players[victim_id]["pos"]
	for id in players:
		var p: Dictionary = players[id]
		if p.get("bot", false):
			continue
		var pos: Vector3 = p["pos"]
		if id == victim_id or id == killer_id or pos.distance_to(victim_pos) <= INTEREST_RADIUS:
			Net.send_death(id, victim_id, killer_id)

func _apply_damage(victim_id: int, killer_id: int, now: float, amount := 25, ignore_armor := false) -> void:
	var victim: Dictionary = players[victim_id]

	var result := Inventory.apply_damage(victim, amount, ignore_armor)
	if not bool(result["dead"]):
		return

	victim["alive"] = false
	victim["respawn_at"] = now + RESPAWN_TIME
	var body: CharacterBody3D = victim["body"]
	body.velocity = Vector3.ZERO

	if killer_id != 0 and players.has(killer_id):
		var killer: Dictionary = players[killer_id]
		killer["kills"] = int(killer["kills"]) + 1
	_send_death_events(victim_id, killer_id)
	if killer_id == 0:
		print("storm eliminated peer %d" % victim_id)
	else:
		print("peer %d eliminated peer %d" % [killer_id, victim_id])

func _respawn(id: int, p: Dictionary) -> void:
	var spawn: Vector3 = _safe_spawn()
	var body: CharacterBody3D = p["body"]
	body.global_position = spawn
	body.velocity = Vector3.ZERO

	p["pos"] = spawn
	p["health"] = 100
	Inventory.reset(p)
	p["alive"] = true
	p["input_dir"] = Vector2.ZERO
	p["jump"] = false
	var preferred := clampi(int(p.get("preferred_weapon", DEFAULT_WEAPON)), 0, Weapons.count() - 1)
	p["weapon"] = preferred
	p["ammo"] = Weapons.fresh_ammo()
	if p.get("bot", false):
		for i in p["ammo"]:
			p["ammo"][i]["reserve"] = 999
	p["reload_until"] = 0.0
	p["switch_until"] = 0.0
	_update_cell(id, p)

	if not p.get("bot", false):
		Net.send_respawn(id, spawn)

static func _ray_sphere(origin: Vector3, dir: Vector3, center: Vector3, radius: float) -> float:
	var oc := origin - center
	var b := oc.dot(dir)
	var c := oc.length_squared() - radius * radius
	var disc := b * b - c
	if disc < 0.0:
		return -1.0

	var sq := sqrt(disc)
	var t := -b - sq
	if t >= 0.0:
		return t
	t = -b + sq
	if t >= 0.0:
		return t
	return -1.0

# ---------------------------------------------------------------- storm

func _new_storm() -> Dictionary:
	return {
		"center": STORM_CENTER,
		"radius": STORM_START_RADIUS,
		"from_radius": STORM_START_RADIUS,
		"to_radius": STORM_START_RADIUS,
		"state": "waiting",
		"phase": 0,
		"timer": float(STORM_PHASES[0]["wait"]),
	}

func _update_storm(delta: float) -> void:
	if _storm.is_empty():
		return

	var dt := delta * _storm_time_scale
	var state := String(_storm["state"])

	if state == "waiting":
		_storm["timer"] = float(_storm["timer"]) - dt
		if float(_storm["timer"]) <= 0.0:
			_begin_storm_shrink()
	elif state == "shrinking":
		_storm["timer"] = float(_storm["timer"]) - dt
		var phase := int(_storm["phase"])
		var shrink := float(STORM_PHASES[phase]["shrink"])
		var t := 1.0 - clampf(float(_storm["timer"]) / maxf(shrink, 0.001), 0.0, 1.0)
		_storm["radius"] = lerpf(float(_storm["from_radius"]), float(_storm["to_radius"]), t)
		if float(_storm["timer"]) <= 0.0:
			_finish_storm_shrink()

	var dps := _storm_dps()
	if dps <= 0.0:
		_storm_damage_acc = 0.0
		return

	_storm_damage_acc += dt
	if _storm_damage_acc < 1.0:
		return

	var amount := maxi(1, int(round(dps * _storm_damage_acc)))
	_storm_damage_acc = 0.0
	var now := Time.get_ticks_msec() / 1000.0
	var center: Vector2 = _storm["center"]
	var radius := float(_storm["radius"])

	for id in players.keys():
		var p: Dictionary = players[id]
		if not p["alive"]:
			continue
		var pos: Vector3 = p["pos"]
		var offset := Vector2(pos.x - center.x, pos.z - center.y)
		if offset.length() > radius:
			_apply_damage(id, 0, now, amount, true)

func _begin_storm_shrink() -> void:
	var phase := int(_storm["phase"])
	if phase >= STORM_PHASES.size():
		_storm["state"] = "final"
		_storm["timer"] = 0.0
		return

	var data: Dictionary = STORM_PHASES[phase]
	var shrink := float(data["shrink"])
	_storm["from_radius"] = float(_storm["radius"])
	_storm["to_radius"] = float(data["radius"])

	if shrink <= 0.0:
		_storm["radius"] = float(data["radius"])
		_finish_storm_shrink()
		return

	_storm["state"] = "shrinking"
	_storm["timer"] = shrink
	print("storm phase %d shrinking to %.0fm over %.0fs" % [phase + 1, float(data["radius"]), shrink])

func _finish_storm_shrink() -> void:
	var phase := int(_storm["phase"])
	_storm["radius"] = float(_storm["to_radius"])
	_storm["phase"] = phase + 1

	if phase + 1 >= STORM_PHASES.size():
		_storm["state"] = "final"
		_storm["timer"] = 0.0
		print("storm final radius %.0fm" % float(_storm["radius"]))
		return

	_storm["state"] = "waiting"
	_storm["timer"] = float(STORM_PHASES[phase + 1]["wait"])
	print("storm phase %d waiting %.0fs" % [phase + 2, float(_storm["timer"])])

func _storm_dps() -> float:
	var state := String(_storm["state"])
	if state == "final":
		return STORM_FINAL_DPS

	var phase := int(_storm["phase"])
	if phase < 0 or phase >= STORM_PHASES.size():
		return 0.0
	if state == "waiting" and phase == 0:
		return 0.0
	return float(STORM_PHASES[phase]["dps"])

func _storm_public() -> Dictionary:
	var center: Vector2 = _storm["center"]
	return {
		"cx": center.x,
		"cz": center.y,
		"radius": float(_storm["radius"]),
		"state": String(_storm["state"]),
		"timer": float(_storm["timer"]),
		"phase": int(_storm["phase"]),
		"dps": _storm_dps(),
	}

func _safe_spawn() -> Vector3:
	var center: Vector2 = _storm.get("center", STORM_CENTER)
	var radius := float(_storm.get("radius", STORM_START_RADIUS))
	var candidates: Array[Vector3] = []

	for spawn in _spawns:
		var offset := Vector2(spawn.x - center.x, spawn.z - center.y)
		if offset.length() <= maxf(2.0, radius - 1.5):
			candidates.append(spawn)

	if not candidates.is_empty():
		return candidates[randi() % candidates.size()]

	var angle := randf() * TAU
	var fallback_radius := maxf(0.0, radius * 0.5)
	return Vector3(center.x + cos(angle) * fallback_radius, 0.7, center.y + sin(angle) * fallback_radius)

# ---------------------------------------------------------------- cells / snapshots

func _cell_of(pos: Vector3) -> Vector2i:
	return Vector2i(floori(pos.x / CELL_SIZE), floori(pos.z / CELL_SIZE))

func _update_cell(id: int, p: Dictionary) -> void:
	var new_cell := _cell_of(p["pos"])
	var old_cell: Vector2i = p["cell"]
	if new_cell == old_cell:
		return

	_remove_from_cell(id, old_cell)
	if not cells.has(new_cell):
		cells[new_cell] = []
	cells[new_cell].append(id)
	p["cell"] = new_cell

func _remove_from_cell(id: int, cell: Vector2i) -> void:
	var list = cells.get(cell)
	if list == null:
		return
	list.erase(id)
	if list.is_empty():
		cells.erase(cell)

func _send_snapshots() -> void:
	var storm_state := _storm_public()
	for id in players:
		var p: Dictionary = players[id]
		if p.get("bot", false):
			continue
		Net.send_snapshot(id, _snapshot_for(id, p), tick, storm_state)

func _snapshot_for(viewer_id: int, viewer: Dictionary) -> Dictionary:
	var out := {}
	out[viewer_id] = _pack(viewer)

	var origin: Vector3 = viewer["pos"]
	var radius_sq := INTEREST_RADIUS * INTEREST_RADIUS
	var span := int(ceil(INTEREST_RADIUS / CELL_SIZE))
	var center := _cell_of(origin)

	for cx in range(center.x - span, center.x + span + 1):
		for cz in range(center.y - span, center.y + span + 1):
			var list = cells.get(Vector2i(cx, cz))
			if list == null:
				continue
			for id in list:
				if id == viewer_id or out.has(id):
					continue
				var other: Dictionary = players[id]
				var pos: Vector3 = other["pos"]
				if origin.distance_squared_to(pos) <= radius_sq:
					out[id] = _pack(other)

	return out

func _pack(p: Dictionary) -> Array:
	var pos: Vector3 = p["pos"]
	var index := int(p["weapon"])
	var ammo: Dictionary = p["ammo"][index]
	var now := Time.get_ticks_msec() / 1000.0
	var reloading := 0
	if float(p["reload_until"]) > now:
		reloading = 1
	var look: Dictionary = p["appearance"]
	var inv: Dictionary = p.get("inventory", {})
	return [
		pos.x, pos.y, pos.z, p["yaw"], p["health"], p["alive"], p["kills"],
		index, int(ammo["mag"]), int(ammo["reserve"]), reloading,
		int(look["character"]), look["primary"], look["secondary"], look["accent"], int(look["outfit"]),
		int(p.get("armor", 0)), int(inv.get("bandage", 0)), int(inv.get("medkit", 0)),
		Inventory.heal_remaining(p, now), int(p.get("heal_type", 0)),
	]

# ---------------------------------------------------------------- helpers

func _make_body(pos: Vector3) -> CharacterBody3D:
	var body := CharacterBody3D.new()
	body.collision_layer = 2
	body.collision_mask = 1
	body.position = pos

	var shape := CapsuleShape3D.new()
	shape.radius = 0.4
	shape.height = 1.8

	var col := CollisionShape3D.new()
	col.shape = shape
	col.position = Vector3(0, 0.9, 0)
	body.add_child(col)

	$Players.add_child(body)
	return body

func _collect_spawns(arena: Node) -> void:
	var markers := arena.get_node_or_null("SpawnPoints")
	if markers != null:
		for m in markers.get_children():
			if m is Node3D:
				_spawns.append((m as Node3D).global_position + Vector3(0, 0.2, 0))

	if _spawns.is_empty():
		for spawn in MapData.SPAWN_POINTS:
			_spawns.append(spawn + Vector3(0, 0.2, 0))

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
