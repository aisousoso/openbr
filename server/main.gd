extends Node3D

## Authoritative game server.
## Run headless:
##   godot --headless --path . res://server/main.tscn -- --port=7777 --dev-auth
##
## Responsibilities:
##  - load maps/verdant_reach.tscn (same colliders as the client)
##  - run the Battle Royale match lifecycle (WAITING -> COUNTDOWN -> LIVE -> ENDED -> RESET)
##  - simulate one CharacterBody3D per player with shared/movement.gd
##  - hitscan shooting, damage, one-life elimination and placement
##  - cell-based interest management for snapshots
##
## Match flags:
##   --min-players=N   players (humans + bots) needed to start (default 2)
##   --countdown=N     seconds of the deploy countdown (default 8)
##   --end-delay=N     seconds to show the result before returning to the lobby (default 10)
##   --auto-start      skip the READY requirement (dev/tests; still needs one human)
##   --dev-respawn     keep the old 3s respawn deathmatch loop (dev smoke tests only)

const Movement := preload("res://shared/movement.gd")
const Weapons := preload("res://shared/weapons.gd")
const Characters := preload("res://shared/characters.gd")
const Loot := preload("res://shared/loot.gd")
const Inventory := preload("res://shared/inventory.gd")
const MapData := preload("res://shared/map_data.gd")
const BattlePass := preload("res://shared/battle_pass.gd")
const Auth := preload("res://server/auth.gd")
const ARENA := preload("res://maps/verdant_reach.tscn")

const MAX_PLAYERS := 128
const SNAPSHOT_HZ := 15.0

const PHASE_WAITING := "WAITING"
const PHASE_COUNTDOWN := "COUNTDOWN"
const PHASE_LIVE := "LIVE"
const PHASE_ENDED := "ENDED"

const DEFAULT_WEAPON := 0
const WEAPON_SWITCH_TIME := 0.25
const RESPAWN_TIME := 3.0
const EYE_HEIGHT := 1.65
const BODY_CENTER := 0.9
const HIT_RADIUS := 0.6

const BOT_MAX := 32
const BOT_AIM_ERROR := 0.03

const CELL_SIZE := 20.0
const INTEREST_RADIUS := 35.0

# Storm phases: wait before the next shrink, shrink duration, target radius and
# damage per second for players outside the safe zone. The first wait is a
# grace period with no storm damage.
const STORM_CENTER := Vector2(0.0, 0.0)
const STORM_START_RADIUS := 85.0
const STORM_FINAL_DPS := 8.0
const STORM_PHASES := [
	{"wait": 30.0, "shrink": 30.0, "radius": 45.0, "dps": 2.0},
	{"wait": 15.0, "shrink": 20.0, "radius": 25.0, "dps": 4.0},
	{"wait": 10.0, "shrink": 15.0, "radius": 10.0, "dps": 6.0},
]

var players := {}
var cells := {}
var tick := 0
var snap_acc := 0.0
var _last_snapshots := {}  # viewer_id -> previous snapshot dict (delta compression)
var allow_dev := false

var _spawns: Array[Vector3] = []
var _pending_shots: Array = []
var _storm := {}
var _storm_damage_acc := 0.0
var _storm_time_scale := 1.0
var _run_seconds := 0.0
var _run_elapsed := 0.0
var _bot_count := 0
var _squad_size := 1
var _loot_taken := {}
var _dynamic_loot := {}  # id -> {type, pos, respawn_at}
var _next_dynamic_id := 10000
var _player_xp := {}  # player_id -> total xp
const LOOT_RESPAWN_DELAY := 30.0
var _test_loot := false

# Match lifecycle. Everything gameplay-related is gated on `_phase == PHASE_LIVE`.
var _phase := PHASE_WAITING
var _phase_timer := 0.0
var _min_players := 2
var _countdown_seconds := 8.0
var _end_delay := 10.0
var _auto_start := false
var _dev_respawn := false
var _winner_id := 0
var _placement := {}
var _match_number := 0
var _spawn_cursor := 0
var _analytics: Node

func _ready() -> void:
	allow_dev = "--dev-auth" in _all_args()
	# Debug aids for local testing: speed storm timers up 10x and optionally
	# quit after a fixed wall-clock duration so redirected logs flush cleanly.
	var _storm_scale_arg := _arg("--storm-scale", "")
	if not _storm_scale_arg.is_empty():
		_storm_time_scale = maxf(0.01, float(_storm_scale_arg))
	elif "--storm-fast" in _all_args():
		_storm_time_scale = 10.0
	else:
		_storm_time_scale = 1.0
	_run_seconds = float(_arg("--run-seconds", "0"))
	_bot_count = clampi(int(_arg("--bots", "0")), 0, BOT_MAX)
	_squad_size = clampi(int(_arg("--squad-size", "1")), 1, 4)
	_test_loot = "--test-loot" in _all_args()
	_min_players = maxi(1, int(_arg("--min-players", "2")))
	_countdown_seconds = maxf(0.0, float(_arg("--countdown", "8")))
	_end_delay = maxf(0.0, float(_arg("--end-delay", "10")))
	_auto_start = "--auto-start" in _all_args()
	_dev_respawn = "--dev-respawn" in _all_args()
	_storm = _new_storm()

	var arena := ARENA.instantiate()
	add_child(arena)
	_collect_spawns(arena)
	_spawn_bots()

	_analytics = get_node_or_null("Analytics")
	if _analytics == null:
		_analytics = get_node_or_null("/root/Server/Analytics")

	Net.auth_requested.connect(_on_auth_requested)
	Net.input_received.connect(_on_input_received)
	Net.fire_requested.connect(_on_fire_requested)
	Net.weapon_requested.connect(_on_weapon_requested)
	Net.reload_requested.connect(_on_reload_requested)
	Net.loot_requested.connect(_on_loot_requested)
	Net.use_item_requested.connect(_on_use_item_requested)
	Net.peer_disconnected.connect(_on_peer_disconnected)
	Net.ready_requested.connect(_on_ready_requested)
	Net.emote_requested.connect(_on_emote_requested)
	Net.ping_requested.connect(_on_ping_requested)
	Net.vehicle_enter_requested.connect(_on_vehicle_enter_requested)
	Net.vehicle_exit_requested.connect(_on_vehicle_exit_requested)

	var port := int(_arg("--port", "7777"))
	var err := Net.host_game(port, MAX_PLAYERS)
	if err != OK:
		push_error("failed to host on udp/%d: %s" % [port, error_string(err)])
		get_tree().quit(1)
		return
	print("OpenBR server listening on udp/%d (map=%s, dev_auth=%s, spawns=%d, bots=%d, storm_scale=%.2f, min_players=%d, countdown=%.0fs, auto_start=%s, dev_respawn=%s)" % [port, MapData.NAME, allow_dev, _spawns.size(), _bot_count, _storm_time_scale, _min_players, _countdown_seconds, _auto_start, _dev_respawn])

func _physics_process(delta: float) -> void:
	if _run_seconds > 0.0:
		_run_elapsed += delta
		if _run_elapsed >= _run_seconds:
			print("server run limit reached (%.1fs)" % _run_seconds)
			get_tree().quit()
			return

	var now := Time.get_ticks_msec() / 1000.0
	_update_match(delta)

	if _phase == PHASE_LIVE:
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
				if _dev_respawn and now >= float(p["respawn_at"]):
					_respawn(id, p)
				continue

			var body: CharacterBody3D = p["body"]
			var old_pos: Vector3 = p["pos"]
			Movement.step_body(body, p["input_dir"], p["yaw"], p["jump"], delta)
			p["jump"] = false
			p["pos"] = body.global_position
			# Anti-cheat: clamp excessive movement speed.
			var moved := old_pos.distance_to(p["pos"])
			var max_move := 15.0 * delta  # 15 m/s max
			if moved > max_move and not p.get("bot", false):
				var dir: Vector3 = (p["pos"] - old_pos).normalized()
				p["pos"] = old_pos + dir * max_move
				body.global_position = p["pos"]
			_update_cell(id, p)

		# Resolve queued shots inside the physics tick so space-state queries are safe.
		for shot in _pending_shots:
			_resolve_shot(int(shot[0]), shot[1], int(shot[2]))
		_pending_shots.clear()

		_update_storm(delta)
	else:
		_pending_shots.clear()

	snap_acc += delta
	if snap_acc < 1.0 / SNAPSHOT_HZ:
		return
	snap_acc -= 1.0 / SNAPSHOT_HZ
	tick += 1

	# Dynamic loot respawn check.
	var now2 := Time.get_ticks_msec() / 1000.0
	var to_spawn := []
	for dl_id in _dynamic_loot.keys():
		var dl: Dictionary = _dynamic_loot[dl_id]
		if dl.has("taken"):
			continue
		if not dl.has("respawn_at"):
			continue
		if now2 >= float(dl["respawn_at"]):
			to_spawn.append(dl_id)
	for dl_id in to_spawn:
		var dl: Dictionary = _dynamic_loot[dl_id]
		Net.announce_loot_spawned(dl_id, String(dl["type"]), dl["pos"])
		_dynamic_loot[dl_id]["respawn_at"] = -1.0  # Mark as spawned.

	_send_snapshots()

# ---------------------------------------------------------------- match lifecycle

func _update_match(delta: float) -> void:
	match _phase:
		PHASE_WAITING:
			if _can_start():
				_begin_countdown()
		PHASE_COUNTDOWN:
			if not _can_still_start():
				_cancel_countdown()
				return
			_phase_timer = maxf(0.0, _phase_timer - delta)
			if _phase_timer <= 0.0:
				_start_match()
		PHASE_ENDED:
			_phase_timer = maxf(0.0, _phase_timer - delta)
			if _phase_timer <= 0.0:
				_reset_match()

func _can_start() -> bool:
	if players.is_empty() or players.size() < _min_players:
		return false
	if _auto_start:
		# Bots alone must never start a match; at least one human has to be in.
		return _human_count() > 0
	var human_ready := false
	for id in players:
		var p: Dictionary = players[id]
		if p.get("bot", false):
			continue
		if bool(p.get("ready", false)):
			human_ready = true
			break
	return human_ready and _ready_count() >= _min_players

func _can_still_start() -> bool:
	if players.size() < _min_players:
		return false
	return _auto_start or _human_count() > 0

func _begin_countdown() -> void:
	_phase = PHASE_COUNTDOWN
	_phase_timer = _countdown_seconds
	_winner_id = 0
	_placement.clear()
	print("match countdown started (%.0fs, %d/%d players)" % [_countdown_seconds, players.size(), _min_players])
	Net.announce_kill_feed("MATCH STARTING")
	if _countdown_seconds <= 0.0:
		_start_match()
	else:
		_broadcast_match_state()

func _cancel_countdown() -> void:
	_phase = PHASE_WAITING
	_phase_timer = 0.0
	print("match countdown cancelled (not enough players)")
	Net.announce_kill_feed("COUNTDOWN CANCELLED")
	_broadcast_match_state()

func _start_match() -> void:
	_match_number += 1
	_phase = PHASE_LIVE
	_phase_timer = 0.0
	_winner_id = 0
	_placement.clear()
	_loot_taken.clear()
	_dynamic_loot.clear()
	_next_dynamic_id = 10000
	_last_snapshots.clear()
	_storm = _new_storm()
	_storm_damage_acc = 0.0
	_spawn_cursor = 0

	for id in players.keys():
		_reset_player_for_match(id, players[id])
		if _test_loot and not players[id].get("bot", false):
			# Keep the loot/heal smoke test meaningful: the player starts hurt.
			players[id]["health"] = 60

	for id in players:
		if not players[id].get("bot", false):
			Net.send_loot_reset(id)

	_broadcast_match_state()
	Net.announce_kill_feed("MATCH %d STARTED" % _match_number)
	print("match %d LIVE (%d players, %d humans)" % [_match_number, players.size(), _human_count()])
	if _analytics != null:
		_analytics.match_started(players.size(), _bot_count, _squad_size)

func _reset_player_for_match(id: int, p: Dictionary) -> void:
	var spawn := _next_match_spawn()
	var body: CharacterBody3D = p["body"]
	if is_instance_valid(body):
		body.global_position = spawn
		body.velocity = Vector3.ZERO

	p["pos"] = spawn
	p["yaw"] = randf_range(-PI, PI)
	p["input_dir"] = Vector2.ZERO
	p["jump"] = false
	p["health"] = 100
	p["alive"] = true
	p["kills"] = 0
	p["respawn_at"] = 0.0
	Inventory.reset(p)
	p["weapon"] = clampi(int(p.get("preferred_weapon", DEFAULT_WEAPON)), 0, Weapons.count() - 1)
	p["ammo"] = Weapons.fresh_ammo()
	if p.get("bot", false):
		for i in p["ammo"]:
			p["ammo"][i]["reserve"] = 999
	p["reload_until"] = 0.0
	p["switch_until"] = 0.0
	p["ready"] = false
	_update_cell(id, p)

	if not p.get("bot", false):
		Net.send_respawn(id, spawn)

func _next_match_spawn() -> Vector3:
	if _spawns.is_empty():
		return Vector3(0.0, 0.7, 0.0)
	var spawn := _spawns[_spawn_cursor % _spawns.size()]
	_spawn_cursor += 1
	return spawn

func _assign_team(id: int) -> int:
	# Assign players to teams of squad_size.
	var team_count := ceili(players.size() / float(_squad_size))
	# Find the team with fewest members.
	var team_sizes := {}
	for pid in players:
		var tid := int(players[pid].get("team_id", 0))
		team_sizes[tid] = team_sizes.get(tid, 0) + 1
	var best_team := 1
	var best_size := 999
	for t in range(1, team_count + 2):
		var sz := int(team_sizes.get(t, 0))
		if sz < _squad_size and sz < best_size:
			best_size = sz
			best_team = t
	return best_team

func _random_loot_pos() -> Vector3:
	var half := MapData.HALF_SIZE - 5.0
	var x := randf_range(-half, half)
	var z := randf_range(-half, half)
	var y := 0.25
	if randf() < 0.3:
		y = 0.65
	return Vector3(x, y, z)

func _reset_match() -> void:
	_phase = PHASE_WAITING
	_phase_timer = 0.0
	_winner_id = 0
	_placement.clear()
	_loot_taken.clear()
	_dynamic_loot.clear()
	_next_dynamic_id = 10000
	_last_snapshots.clear()
	_storm = _new_storm()
	_storm_damage_acc = 0.0
	_spawn_cursor = 0

	for id in players.keys():
		_reset_player_for_match(id, players[id])
		players[id]["ready"] = _auto_start

	for id in players:
		if not players[id].get("bot", false):
			Net.send_loot_reset(id)

	_broadcast_match_state()
	Net.announce_kill_feed("RETURNED TO LOBBY")
	print("match reset -> WAITING (%d players)" % players.size())

func _check_match_end() -> void:
	if _phase != PHASE_LIVE:
		return

	if _squad_size > 1:
		# Squad mode: last team standing wins.
		var alive_teams := {}
		for id in players:
			if players[id]["alive"]:
				var tid := int(players[id].get("team_id", 0))
				alive_teams[tid] = true
		if alive_teams.size() > 1:
			return
		# Find a winner from the surviving team.
		var winner_team := int(alive_teams.keys()[0]) if alive_teams.size() == 1 else 0
		_winner_id = 0
		if winner_team > 0:
			for id in players:
				if players[id]["alive"] and int(players[id].get("team_id", 0)) == winner_team:
					_winner_id = id
					break
	else:
		var alive_ids: Array = []
		for id in players:
			if players[id]["alive"]:
				alive_ids.append(id)
		if alive_ids.size() > 1:
			return
		_winner_id = int(alive_ids[0]) if alive_ids.size() == 1 else 0
	if _winner_id != 0:
		_placement[_winner_id] = 1
		Net.announce_kill_feed("%s WINS THE MATCH" % _display_name(_winner_id))
		print("match %d winner: %s (%d)" % [_match_number, _display_name(_winner_id), _winner_id])
	else:
		Net.announce_kill_feed("NO SURVIVORS")
		print("match %d ended with no survivors" % _match_number)

	_phase = PHASE_ENDED
	_phase_timer = _end_delay

	# Analytics.
	if _analytics != null:
		var survivors := 0
		for id in players:
			if players[id]["alive"]:
				survivors += 1
		_analytics.match_ended(_winner_id, _end_delay, survivors)

	# Award Battle Pass XP.
	_award_battle_pass_xp()

	_broadcast_match_state()
	if _end_delay <= 0.0:
		_reset_match()

func _award_battle_pass_xp() -> void:
	for id in players:
		var p: Dictionary = players[id]
		if p.get("bot", false):
			continue
		var kills := int(p.get("kills", 0))
		var placement := int(_placement.get(id, players.size()))
		var survived := _phase_timer  # approximate
		var xp := BattlePass.xp_for_match(kills, placement, survived)
		var current := int(_player_xp.get(id, 0))
		_player_xp[id] = current + xp
		print("Battle Pass: peer %d earned %d XP (total %d, tier %d)" % [id, xp, _player_xp[id], BattlePass.tier_for_xp(_player_xp[id])])
		Net.send_battle_pass_update(id, _player_xp[id])

func _on_ready_requested(id: int, ready: bool) -> void:
	var p = players.get(id)
	if p == null or p.get("bot", false):
		return
	if _phase != PHASE_WAITING:
		return
	p["ready"] = ready
	print("peer %d ready=%s (%d/%d)" % [id, ready, _ready_count(), _min_players])
	_broadcast_match_state()

func _on_emote_requested(id: int, emote_index: int) -> void:
	if _phase != PHASE_LIVE:
		return
	var p = players.get(id)
	if p == null or not p["alive"]:
		return
	Net.announce_emote(id, emote_index)

func _on_ping_requested(id: int, pos: Vector3) -> void:
	if _phase != PHASE_LIVE:
		return
	var p = players.get(id)
	if p == null or not p["alive"]:
		return
	Net.announce_ping(id, pos)

func _on_vehicle_enter_requested(id: int, vehicle_id: int) -> void:
	if _phase != PHASE_LIVE:
		return
	var p = players.get(id)
	if p == null or not p["alive"]:
		return
	# Mark player as in vehicle (disable movement).
	p["in_vehicle"] = vehicle_id
	p["input_dir"] = Vector2.ZERO

func _on_vehicle_exit_requested(id: int, vehicle_id: int) -> void:
	if _phase != PHASE_LIVE:
		return
	var p = players.get(id)
	if p == null or not p["alive"]:
		return
	p["in_vehicle"] = 0

func _match_state_for(id: int) -> Dictionary:
	var p: Dictionary = players.get(id, {})
	return {
		"phase": _phase,
		"timer": maxf(0.0, _phase_timer),
		"alive": _alive_count(),
		"total": players.size(),
		"ready": _ready_count(),
		"min_players": _min_players,
		"you": id,
		"you_ready": bool(p.get("ready", false)),
		"you_alive": bool(p.get("alive", false)),
		"placement": int(_placement.get(id, 0)),
		"winner": _winner_id,
		"winner_name": _display_name(_winner_id) if _winner_id != 0 else "",
		"match": _match_number,
		"team_id": int(p.get("team_id", 0)),
		"squad_size": _squad_size,
		"roster": _roster(),
	}

func _broadcast_match_state() -> void:
	for id in players:
		if players[id].get("bot", false):
			continue
		Net.send_match_state(id, _match_state_for(id))

func _roster() -> Array:
	var out: Array = []
	for id in players:
		var p: Dictionary = players[id]
		out.append({
			"id": id,
			"name": _display_name(id),
			"alive": bool(p["alive"]),
			"bot": bool(p.get("bot", false)),
			"team_id": int(p.get("team_id", 0)),
		})
	return out

func _display_name(id: int) -> String:
	if id == 0:
		return "the storm"
	var p = players.get(id)
	if p == null:
		return "player %d" % id
	var look: Dictionary = p.get("appearance", {})
	return String(Characters.get_character(int(look.get("character", 0)))["name"])

func _alive_count() -> int:
	var count := 0
	for id in players:
		if players[id]["alive"]:
			count += 1
	return count

func _ready_count() -> int:
	var count := 0
	for id in players:
		var p: Dictionary = players[id]
		if p.get("bot", false) or bool(p.get("ready", false)):
			count += 1
	return count

func _human_count() -> int:
	var count := 0
	for id in players:
		if not players[id].get("bot", false):
			count += 1
	return count

# ---------------------------------------------------------------- auth / peers

func _on_auth_requested(id: int, token: String, appearance: Dictionary) -> void:
	if players.has(id):
		return
	if _phase != PHASE_WAITING:
		print("peer %d rejected (match in progress, phase=%s)" % [id, _phase])
		Net.reject(id, "match in progress")
		return
	if players.size() >= MAX_PLAYERS:
		print("peer %d rejected (server full)" % id)
		Net.reject(id, "server full")
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
	p["ready"] = _auto_start
	if _test_loot:
		# Dev-only hook so the loot/heal smoke test can exercise a real heal.
		p["health"] = 60
	Net.spawn_for(id, p["pos"])
	Net.send_loot_state(id, _loot_taken.keys())
	# Send dynamic loot spawns.
	var dyn_spawns := []
	for dl_id in _dynamic_loot:
		var dl: Dictionary = _dynamic_loot[dl_id]
		if dl.has("taken"):
			continue
		dyn_spawns.append({"id": dl_id, "type": dl["type"], "pos": dl["pos"]})
	if not dyn_spawns.is_empty():
		Net.send_dynamic_loot(id, dyn_spawns)
	Net.send_match_state(id, _match_state_for(id))
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
		"ready": is_bot,
		"team_id": 0,
		"in_vehicle": 0,
		"appearance": appearance_data,
	}
	p.merge(Inventory.new_state())
	players[id] = p

	if _analytics != null:
		_analytics.player_joined(id, is_bot)

	# Assign team for squad mode.
	if _squad_size > 1:
		p["team_id"] = _assign_team(id)

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

	if _phase == PHASE_LIVE and bool(p["alive"]) and not p.get("bot", false):
		# A disconnect is an elimination so the remaining players can still win.
		_placement[id] = _alive_count()
		Net.announce_kill_feed("%s LEFT THE MATCH" % _display_name(id))
		print("peer %d left during LIVE (placement %d)" % [id, int(_placement[id])])

	_remove_from_cell(id, p["cell"])
	var body: CharacterBody3D = p["body"]
	if is_instance_valid(body):
		body.queue_free()
	players.erase(id)
	Net.announce_left(id)

	if _phase == PHASE_LIVE:
		_broadcast_match_state()
		_check_match_end()
	elif _phase == PHASE_WAITING or _phase == PHASE_COUNTDOWN:
		_broadcast_match_state()
	print("peer %d left" % id)

# ---------------------------------------------------------------- input / shooting

func _on_input_received(id: int, dir: Vector2, yaw: float, jump: bool) -> void:
	if _phase != PHASE_LIVE:
		return
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
	if _phase != PHASE_LIVE:
		return
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
	if _phase != PHASE_LIVE:
		return
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
	if _phase != PHASE_LIVE:
		return
	var p = players.get(id)
	if p == null or not p["alive"]:
		return
	_start_reload(id, p, Time.get_ticks_msec() / 1000.0)

func _on_loot_requested(id: int, loot_id: int) -> void:
	if _phase != PHASE_LIVE:
		return
	var p = players.get(id)
	if p == null or not p["alive"]:
		return

	var spawn := Loot.get_spawn(loot_id)
	var is_dynamic := false
	if spawn.is_empty() and _dynamic_loot.has(loot_id):
		var dl: Dictionary = _dynamic_loot[loot_id]
		spawn = {"id": loot_id, "type": dl["type"], "pos": dl["pos"]}
		is_dynamic = true
	if spawn.is_empty():
		Net.send_loot_result(id, "Unknown loot")
		return
	if _loot_taken.has(loot_id):
		Net.send_loot_result(id, "Already taken")
		return
	if is_dynamic and _dynamic_loot.has(loot_id) and bool(_dynamic_loot[loot_id].get("taken", false)):
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

	if is_dynamic:
		_dynamic_loot.erase(loot_id)
	else:
		# Schedule dynamic respawn for static loot.
		_dynamic_loot[_next_dynamic_id] = {
			"type": String(spawn["type"]),
			"pos": _random_loot_pos(),
			"respawn_at": Time.get_ticks_msec() / 1000.0 + LOOT_RESPAWN_DELAY,
		}
		_next_dynamic_id += 1

func _on_use_item_requested(id: int, item_type: String) -> void:
	if _phase != PHASE_LIVE:
		return
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
		# Explosive: area damage.
		if bool(weapon.get("explosive", false)):
			var blast := float(weapon.get("blast_radius", 5.0))
			for other_id in players:
				if other_id == id:
					continue
				var target: Dictionary = players[other_id]
				if not target["alive"]:
					continue
				var center: Vector3 = target["pos"] + Vector3(0, BODY_CENTER, 0)
				var dist := center.distance_to(end)
				if dist <= blast:
					var falloff := 1.0 - (dist / blast)
					_apply_damage(other_id, id, now, int(float(weapon["damage"]) * falloff * 0.5))
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
	var victim = players.get(victim_id)
	if victim == null or not victim["alive"]:
		return
	# Friendly fire prevention in squad mode.
	if _squad_size > 1 and killer_id != 0:
		var killer = players.get(killer_id)
		if killer != null and int(killer.get("team_id", 0)) == int(victim.get("team_id", 0)):
			return

	var result := Inventory.apply_damage(victim, amount, ignore_armor)
	if not bool(result["dead"]):
		return

	victim["alive"] = false
	var body: CharacterBody3D = victim["body"]
	body.velocity = Vector3.ZERO

	if killer_id != 0 and players.has(killer_id):
		var killer: Dictionary = players[killer_id]
		killer["kills"] = int(killer["kills"]) + 1
	_send_death_events(victim_id, killer_id)

	if killer_id == 0:
		Net.announce_kill_feed("%s WAS ELIMINATED BY THE STORM" % _display_name(victim_id))
		print("storm eliminated peer %d" % victim_id)
	else:
		Net.announce_kill_feed("%s ELIMINATED %s" % [_display_name(killer_id), _display_name(victim_id)])
		print("peer %d eliminated peer %d" % [killer_id, victim_id])

	if _phase == PHASE_LIVE and not _dev_respawn:
		# Placement is assigned at elimination: the first death in a 4-player
		# match is 4th, the winner is 1st.
		_placement[victim_id] = _alive_count() + 1
		_broadcast_match_state()
		_check_match_end()
	elif _dev_respawn:
		victim["respawn_at"] = now + RESPAWN_TIME
	else:
		victim["respawn_at"] = 0.0

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
		if _phase != PHASE_LIVE:
			break
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
	# The storm only exists during LIVE; the client hides its wall otherwise.
	var storm_state := _storm_public() if _phase == PHASE_LIVE else {}
	for id in players:
		var p: Dictionary = players[id]
		if p.get("bot", false):
			continue
		var snap := _snapshot_for(id, p)
		# Delta: skip if nothing changed since last snapshot.
		var last: Dictionary = _last_snapshots.get(id, {})
		# Send every 10 ticks (keyframe) or if data changed.
		var is_keyframe := (tick % 10 == 0)
		if not is_keyframe and not last.is_empty() and last.hash() == snap.hash():
			continue
		_last_snapshots[id] = snap.duplicate(true)
		Net.send_snapshot(id, snap, tick, storm_state)

func _snapshot_for(viewer_id: int, viewer: Dictionary) -> Dictionary:
	var out := {}
	out[viewer_id] = _pack(viewer)

	# Dead players are spectators: they need to see every survivor so the
	# client can follow one with the spectator camera, even across the map.
	if not viewer["alive"]:
		for id in players:
			if id != viewer_id:
				out[id] = _pack(players[id])
		return out

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
		int(p.get("team_id", 0)),
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
