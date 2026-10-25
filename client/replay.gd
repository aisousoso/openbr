## Replay recorder and player.
##
## Records match snapshots during a live match and can play them back
## in spectator mode. Files are saved to user://replays/.

extends Node

const REPLAY_DIR := "user://replays"

var recording := false
var playing := false
var replay_data := []
var play_index := 0
var play_timer := 0.0
var _record_timer := 0.0

signal replay_loaded(count: int)
signal replay_finished

func _ready() -> void:
	DirAccess.make_dir_recursive_absolute(REPLAY_DIR)

func start_recording() -> void:
	replay_data.clear()
	recording = true
	_record_timer = 0.0
	print("Replay: recording started")

func stop_recording() -> void:
	recording = false
	_save_replay()
	print("Replay: recording stopped (%d frames)" % replay_data.size())

func record_frame(snapshot: Dictionary, match_state: Dictionary, storm: Dictionary) -> void:
	if not recording:
		return
	replay_data.append({
		"t": _record_timer,
		"snapshot": snapshot.duplicate(true),
		"match_state": match_state.duplicate(true),
		"storm": storm.duplicate(true),
	})

func _process(delta: float) -> void:
	if recording:
		_record_timer += delta
	if playing:
		play_timer += delta
		# Advance to next frame if time exceeded.
		while play_index < replay_data.size() - 1 and play_timer >= replay_data[play_index + 1]["t"]:
			play_index += 1
		if play_index >= replay_data.size() - 1 and play_timer >= replay_data[-1]["t"] + 1.0:
			playing = false
			replay_finished.emit()

func _save_replay() -> void:
	if replay_data.is_empty():
		return
	var file := FileAccess.open(REPLAY_DIR + "/replay_%d.json" % Time.get_unix_time_from_system(), FileAccess.WRITE)
	if file == null:
		push_error("Replay: failed to save file")
		return
	file.store_string(JSON.stringify(replay_data))
	file.close()
	print("Replay: saved %d frames" % replay_data.size())

func load_replay(path: String) -> bool:
	var file := FileAccess.open(path, FileAccess.READ)
	if file == null:
		return false
	var json := JSON.new()
	var err := json.parse(file.get_as_text())
	file.close()
	if err != OK:
		return false
	replay_data = json.data
	play_index = 0
	play_timer = 0.0
	replay_loaded.emit(replay_data.size())
	return true

func start_playback() -> void:
	if replay_data.is_empty():
		return
	playing = true
	play_index = 0
	play_timer = 0.0
	print("Replay: playback started (%d frames)" % replay_data.size())

func stop_playback() -> void:
	playing = false
	print("Replay: playback stopped")

func get_current_frame() -> Dictionary:
	if replay_data.is_empty() or play_index >= replay_data.size():
		return {}
	return replay_data[play_index]

func list_replays() -> Array:
	var dir := DirAccess.open(REPLAY_DIR)
	if dir == null:
		return []
	var files := []
	dir.list_dir_begin()
	var name := dir.get_next()
	while name != "":
		if name.ends_with(".json"):
			files.append(REPLAY_DIR + "/" + name)
		name = dir.get_next()
	dir.list_dir_end()
	return files