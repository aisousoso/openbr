## Server-side analytics — tracks match events, player counts, durations.
## Writes to user://analytics.jsonl (append-only).

extends Node

const ANALYTICS_FILE := "user://analytics.jsonl"

var _match_start_time := 0.0
var _match_players := 0

func log_event(event: String, data: Dictionary = {}) -> void:
	var entry := {
		"ts": Time.get_unix_time_from_system(),
		"event": event,
		"data": data,
	}
	var file := FileAccess.open(ANALYTICS_FILE, FileAccess.READ_WRITE)
	if file == null:
		file = FileAccess.open(ANALYTICS_FILE, FileAccess.WRITE)
	if file == null:
		return
	file.seek_end()
	file.store_line(JSON.stringify(entry))
	file.close()

func match_started(players: int, bots: int, squad_size: int) -> void:
	_match_start_time = Time.get_ticks_msec() / 1000.0
	_match_players = players
	log_event("match_started", {
		"players": players,
		"bots": bots,
		"squad_size": squad_size,
	})

func match_ended(winner_id: int, duration: float, survivors: int) -> void:
	log_event("match_ended", {
		"winner": winner_id,
		"duration": duration,
		"survivors": survivors,
		"total_players": _match_players,
	})

func player_joined(player_id: int, is_bot: bool) -> void:
	log_event("player_joined", {
		"player_id": player_id,
		"is_bot": is_bot,
	})

func player_died(victim_id: int, killer_id: int, cause: String) -> void:
	log_event("player_died", {
		"victim": victim_id,
		"killer": killer_id,
		"cause": cause,
	})