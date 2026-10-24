extends CanvasLayer

## Server connection screen. Builds its UI in code so it works on desktop and
## Android without extra theme/scene dependencies. Settings persist in
## user://client.cfg (never include server secrets in the APK).

signal connect_requested(host: String, port: int, token: String)
signal back_requested

const SETTINGS_PATH := "user://client.cfg"

var _host_edit: LineEdit
var _port_edit: LineEdit
var _token_edit: LineEdit
var _status: Label
var _connect_btn: Button
var _back_btn: Button

func _ready() -> void:
	layer = 10
	_build()
	_load_settings()
	visible = false

func open_screen(message := "") -> void:
	visible = true
	_connect_btn.disabled = false
	if _back_btn != null:
		_back_btn.disabled = false
	if not message.is_empty():
		_status.text = message
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_screen() -> void:
	visible = false
	for edit in [_host_edit, _port_edit, _token_edit]:
		if edit != null:
			edit.release_focus()
	DisplayServer.virtual_keyboard_hide()

func set_status(message: String) -> void:
	if _status != null:
		_status.text = message

func set_connecting(value: bool) -> void:
	if _connect_btn != null:
		_connect_btn.disabled = value
	if _back_btn != null:
		_back_btn.disabled = value

func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var dim := ColorRect.new()
	dim.color = Color(0.05, 0.07, 0.10, 0.94)
	dim.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(dim)
	dim.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var center := CenterContainer.new()
	root.add_child(center)
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(470, 0)
	center.add_child(panel)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 26)
	margin.add_theme_constant_override("margin_right", 26)
	margin.add_theme_constant_override("margin_top", 22)
	margin.add_theme_constant_override("margin_bottom", 22)
	panel.add_child(margin)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	var title := Label.new()
	title.text = "OpenBR"
	title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	title.add_theme_font_size_override("font_size", 34)
	box.add_child(title)

	var sub := Label.new()
	sub.text = "Server-authoritative Battle Royale prototype"
	sub.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	sub.add_theme_font_size_override("font_size", 14)
	sub.modulate = Color(1, 1, 1, 0.65)
	box.add_child(sub)

	box.add_child(_label("Server host"))
	_host_edit = LineEdit.new()
	_host_edit.text = "127.0.0.1"
	_host_edit.custom_minimum_size = Vector2(0, 38)
	_host_edit.text_submitted.connect(func(_t: String) -> void: _port_edit.grab_focus())
	box.add_child(_host_edit)

	box.add_child(_label("Port"))
	_port_edit = LineEdit.new()
	_port_edit.text = "7777"
	_port_edit.custom_minimum_size = Vector2(0, 38)
	_port_edit.text_submitted.connect(func(_t: String) -> void: _token_edit.grab_focus())
	box.add_child(_port_edit)

	box.add_child(_label("Join token"))
	_token_edit = LineEdit.new()
	_token_edit.text = "dev"
	_token_edit.custom_minimum_size = Vector2(0, 38)
	_token_edit.text_submitted.connect(func(_t: String) -> void: _on_connect_pressed())
	box.add_child(_token_edit)

	_connect_btn = Button.new()
	_connect_btn.text = "Connect"
	_connect_btn.custom_minimum_size = Vector2(0, 44)
	_connect_btn.pressed.connect(_on_connect_pressed)
	box.add_child(_connect_btn)

	_back_btn = Button.new()
	_back_btn.text = "Change operator"
	_back_btn.custom_minimum_size = Vector2(0, 36)
	_back_btn.pressed.connect(func() -> void: back_requested.emit())
	box.add_child(_back_btn)

	var quit_btn := Button.new()
	quit_btn.text = "Quit"
	quit_btn.custom_minimum_size = Vector2(0, 36)
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	box.add_child(quit_btn)

	_status = Label.new()
	_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status.modulate = Color(1.0, 0.85, 0.55, 1.0)
	_status.custom_minimum_size = Vector2(0, 42)
	box.add_child(_status)

	var hint := Label.new()
	hint.text = "On a phone use your PC's LAN IP, e.g. 192.168.1.10. Token 'dev' works only when the server runs with --dev-auth."
	hint.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	hint.add_theme_font_size_override("font_size", 12)
	hint.modulate = Color(1, 1, 1, 0.55)
	box.add_child(hint)

func _label(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	return l

func _on_connect_pressed() -> void:
	if _connect_btn.disabled:
		return
	var host := _host_edit.text.strip_edges()
	var port := int(_port_edit.text.strip_edges())
	var token := _token_edit.text.strip_edges()

	if host.is_empty():
		_status.text = "Enter the server host."
		return
	if port <= 0 or port > 65535:
		_status.text = "Enter a valid port (1-65535)."
		return

	_save_settings(host, port, token)
	_connect_btn.disabled = true
	_status.text = "Connecting to %s:%d ..." % [host, port]
	connect_requested.emit(host, port, token)

func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) != OK:
		return
	_host_edit.text = str(cfg.get_value("client", "host", "127.0.0.1"))
	_port_edit.text = str(cfg.get_value("client", "port", 7777))
	_token_edit.text = str(cfg.get_value("client", "token", "dev"))

func _save_settings(host: String, port: int, token: String) -> void:
	var cfg := ConfigFile.new()
	cfg.set_value("client", "host", host)
	cfg.set_value("client", "port", port)
	cfg.set_value("client", "token", token)
	cfg.save(SETTINGS_PATH)
