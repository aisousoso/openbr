extends CanvasLayer

## Battle Royale match panel.
##
## Built in code so it works on desktop and Android without extra theme files.
## It is presentation only: the server owns the phase, the countdown, the
## placement and the winner. Buttons emit signals that main.gd turns into RPCs.

signal ready_pressed(ready: bool)
signal leave_pressed
signal spectate_next_pressed

var _state: Dictionary = {}
## Buttons ignore presses for a moment after the panel appears. Without this,
## the click that focuses the window (cursor often sits mid-screen, right on
## READY) would instantly ready the player up.
var _ready_guard_until := 0

var _banner: Label
var _panel: PanelContainer
var _title: Label
var _details: Label
var _ready_btn: Button
var _leave_btn: Button
var _spectator_bar: HBoxContainer
var _spectator_label: Label

func _ready() -> void:
	layer = 6
	_build()
	visible = false

func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	root.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(root)

	_banner = Label.new()
	_banner.name = "Banner"
	_banner.set_anchors_preset(Control.PRESET_CENTER_TOP)
	_banner.offset_left = -420.0
	_banner.offset_top = 54.0
	_banner.offset_right = 420.0
	_banner.offset_bottom = 150.0
	_banner.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_banner.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_banner.add_theme_font_size_override("font_size", 34)
	_banner.add_theme_color_override("font_outline_color", Color(0.02, 0.03, 0.05, 0.95))
	_banner.add_theme_constant_override("outline_size", 10)
	_banner.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(_banner)

	var center := CenterContainer.new()
	center.name = "Center"
	center.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	center.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(center)

	_panel = PanelContainer.new()
	_panel.name = "Panel"
	_panel.custom_minimum_size = Vector2(440, 0)
	_panel.mouse_filter = Control.MOUSE_FILTER_STOP
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.04, 0.06, 0.08, 0.93)
	style.border_color = Color(0.32, 0.74, 0.86, 0.85)
	style.set_border_width_all(2)
	style.set_corner_radius_all(10)
	style.set_content_margin_all(22)
	_panel.add_theme_stylebox_override("panel", style)
	center.add_child(_panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	_panel.add_child(box)

	_title = Label.new()
	_title.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_title.add_theme_font_size_override("font_size", 34)
	box.add_child(_title)

	_details = Label.new()
	_details.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_details.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_details.add_theme_font_size_override("font_size", 18)
	_details.add_theme_color_override("font_color", Color(0.78, 0.86, 0.92, 1.0))
	box.add_child(_details)

	_ready_btn = _button("READY")
	_ready_btn.pressed.connect(func() -> void:
		if Time.get_ticks_msec() < _ready_guard_until:
			return
		ready_pressed.emit(not bool(_state.get("you_ready", false)))
	)
	box.add_child(_ready_btn)

	_leave_btn = _button("LEAVE MATCH")
	_leave_btn.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5, 1.0))
	_leave_btn.pressed.connect(func() -> void: leave_pressed.emit())
	box.add_child(_leave_btn)

	_spectator_bar = HBoxContainer.new()
	_spectator_bar.name = "SpectatorBar"
	_spectator_bar.set_anchors_preset(Control.PRESET_CENTER_BOTTOM)
	_spectator_bar.offset_left = -360.0
	_spectator_bar.offset_top = -104.0
	_spectator_bar.offset_right = 360.0
	_spectator_bar.offset_bottom = -48.0
	_spectator_bar.alignment = BoxContainer.ALIGNMENT_CENTER
	_spectator_bar.add_theme_constant_override("separation", 14)
	root.add_child(_spectator_bar)

	_spectator_label = Label.new()
	_spectator_label.add_theme_font_size_override("font_size", 20)
	_spectator_label.add_theme_color_override("font_color", Color(0.75, 0.9, 1.0, 1.0))
	_spectator_label.text = "SPECTATING"
	_spectator_bar.add_child(_spectator_label)

	var next_btn := _button("NEXT")
	next_btn.custom_minimum_size = Vector2(110, 46)
	next_btn.pressed.connect(func() -> void: spectate_next_pressed.emit())
	_spectator_bar.add_child(next_btn)

	var leave_btn := _button("LEAVE")
	leave_btn.custom_minimum_size = Vector2(110, 46)
	leave_btn.add_theme_color_override("font_color", Color(1.0, 0.55, 0.5, 1.0))
	leave_btn.pressed.connect(func() -> void: leave_pressed.emit())
	_spectator_bar.add_child(leave_btn)

func _button(text: String) -> Button:
	var btn := Button.new()
	btn.text = text
	btn.custom_minimum_size = Vector2(0, 48)
	btn.focus_mode = Control.FOCUS_NONE
	btn.add_theme_font_size_override("font_size", 20)
	return btn

func apply_state(state: Dictionary) -> void:
	var was_visible := visible
	_state = state
	visible = true
	if not was_visible:
		_ready_guard_until = Time.get_ticks_msec() + 700
	_spectator_bar.visible = false
	_panel.visible = false
	_banner.visible = true

	var phase := String(state.get("phase", "WAITING"))
	var timer := int(ceil(maxf(0.0, float(state.get("timer", 0.0)))))
	var alive := int(state.get("alive", 0))
	var total := int(state.get("total", 0))
	var ready := int(state.get("ready", 0))
	var min_players := int(state.get("min_players", 2))
	var placement := int(state.get("placement", 0))
	var you_alive := bool(state.get("you_alive", false))

	match phase:
		"WAITING":
			_banner.text = "WAITING FOR PLAYERS"
			_banner.add_theme_font_size_override("font_size", 30)
			_banner.add_theme_color_override("font_color", Color(0.78, 0.9, 1.0, 1.0))
			_panel.visible = true
			_title.text = "BATTLE ROYALE"
			_title.add_theme_color_override("font_color", Color(0.95, 0.98, 1.0, 1.0))
			_details.text = "Players %d  ·  Ready %d\nNeed %d to deploy. Last one standing wins." % [
				total, ready, min_players,
			]
			_ready_btn.visible = true
			_ready_btn.text = "CANCEL READY" if bool(state.get("you_ready", false)) else "READY"
			_leave_btn.text = "LEAVE MATCH"
		"COUNTDOWN":
			_banner.text = "DEPLOYING IN %d" % timer
			_banner.add_theme_font_size_override("font_size", 46)
			_banner.add_theme_color_override("font_color", Color(1.0, 0.86, 0.35, 1.0))
		"LIVE":
			_banner.text = "ALIVE  %d / %d" % [alive, total]
			_banner.add_theme_font_size_override("font_size", 26)
			_banner.add_theme_color_override("font_color", Color(0.9, 0.96, 1.0, 1.0))
			if not you_alive:
				_spectator_bar.visible = true
				_banner.visible = false
		"ENDED":
			_banner.text = "MATCH OVER"
			_banner.add_theme_font_size_override("font_size", 30)
			_banner.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95, 1.0))
			_panel.visible = true
			_ready_btn.visible = false
			_leave_btn.text = "LEAVE MATCH"
			if placement == 1:
				_title.text = "VICTORY"
				_title.add_theme_color_override("font_color", Color(1.0, 0.84, 0.3, 1.0))
				_details.text = "Last operator standing.\nReturning to lobby in %ds." % timer
			elif placement > 1:
				_title.text = "ELIMINATED"
				_title.add_theme_color_override("font_color", Color(1.0, 0.5, 0.45, 1.0))
				_details.text = "Placement  #%d / %d\nReturning to lobby in %ds." % [placement, total, timer]
			else:
				_title.text = "MATCH OVER"
				_title.add_theme_color_override("font_color", Color(0.9, 0.92, 0.95, 1.0))
				_details.text = "Returning to lobby in %ds." % timer
			var winner_name := String(state.get("winner_name", ""))
			if not winner_name.is_empty():
				_details.text += "\nWinner: %s" % winner_name

func set_spectator_target(display_name: String) -> void:
	_spectator_label.text = "SPECTATING  %s" % display_name

func hide_panel() -> void:
	visible = false
	_state = {}
	_spectator_bar.visible = false
	_panel.visible = false
