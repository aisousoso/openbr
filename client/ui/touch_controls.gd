extends Control

## Full-screen touch layer:
##  - dynamic joystick anywhere in the lower-left half  -> move actions
##  - drag anywhere else                               -> camera look
##  - FIRE / JUMP buttons on the right                 -> fire / jump
##
## Enabled automatically on mobile, or on desktop with `--touch` for testing.
## Movement is fed through the normal input actions, so the shared movement
## code and the server stay untouched.

signal look(delta: Vector2)
signal fire
signal reload
signal weapon_cycle
signal loot
signal use_bandage
signal use_medkit

const JOY_RADIUS := 110.0
const JOY_MARGIN := 150.0
const FIRE_RADIUS := 58.0
const JUMP_RADIUS := 44.0
const RELOAD_RADIUS := 40.0
const SWAP_RADIUS := 40.0
const LOOT_RADIUS := 40.0
const BAND_RADIUS := 36.0
const MED_RADIUS := 36.0

var _enabled := false
var _force_touch := false
var _joy_index := -1
var _look_index := -1
var _fire_index := -1
var _jump_index := -1
var _reload_index := -1
var _swap_index := -1
var _loot_index := -1
var _band_index := -1
var _med_index := -1
var _joy_active := false
var _joy_center := Vector2.ZERO
var _joy_vec := Vector2.ZERO

func _ready() -> void:
	_force_touch = _has_arg("--touch")
	_enabled = OS.has_feature("mobile") or _force_touch
	mouse_filter = Control.MOUSE_FILTER_IGNORE
	visible = _enabled
	set_process(_enabled)
	set_process_input(_enabled)
	if _enabled:
		_joy_center = _default_joy_center()
		get_viewport().size_changed.connect(_on_viewport_resized)
	queue_redraw()

func is_enabled() -> bool:
	return _enabled

func set_active(value: bool) -> void:
	if not _enabled:
		visible = false
		return
	visible = value
	if not value:
		reset()
	queue_redraw()

func reset() -> void:
	_joy_index = -1
	_look_index = -1
	_fire_index = -1
	_jump_index = -1
	_reload_index = -1
	_swap_index = -1
	_loot_index = -1
	_band_index = -1
	_med_index = -1
	_joy_active = false
	_joy_vec = Vector2.ZERO
	_joy_center = _default_joy_center()
	if _enabled:
		_release_move()
		Input.action_release("jump")
	queue_redraw()

func _process(_delta: float) -> void:
	if not visible:
		return
	_set_action("move_right", maxf(_joy_vec.x, 0.0))
	_set_action("move_left", maxf(-_joy_vec.x, 0.0))
	_set_action("move_back", maxf(_joy_vec.y, 0.0))
	_set_action("move_forward", maxf(-_joy_vec.y, 0.0))

func _notification(what: int) -> void:
	if what == NOTIFICATION_APPLICATION_FOCUS_OUT:
		reset()

func _input(event: InputEvent) -> void:
	if not visible:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			_on_down(event.index, event.position)
		else:
			_on_up(event.index)
	elif event is InputEventScreenDrag:
		_on_drag(event.index, event.position, event.relative)
	elif _force_touch and not OS.has_feature("mobile"):
		# Allow testing the touch UI with a mouse on desktop (--touch).
		if event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
			if event.pressed:
				_on_down(0, event.position)
			else:
				_on_up(0)
		elif event is InputEventMouseMotion and (event.button_mask & MOUSE_BUTTON_MASK_LEFT) != 0:
			_on_drag(0, event.position, event.relative)

func _on_down(index: int, pos: Vector2) -> void:
	var screen := get_viewport_rect().size

	if _joy_index == -1 and pos.x < screen.x * 0.5 and pos.y > screen.y * 0.3:
		_joy_index = index
		_joy_active = true
		_joy_center = pos
		_joy_vec = Vector2.ZERO
		queue_redraw()
		return

	if pos.distance_to(_fire_center()) <= FIRE_RADIUS * 1.3:
		_fire_index = index
		fire.emit()
		queue_redraw()
		return

	if pos.distance_to(_jump_center()) <= JUMP_RADIUS * 1.3:
		_jump_index = index
		Input.action_press("jump")
		return

	if pos.distance_to(_reload_center()) <= RELOAD_RADIUS * 1.3:
		_reload_index = index
		reload.emit()
		queue_redraw()
		return

	if pos.distance_to(_swap_center()) <= SWAP_RADIUS * 1.3:
		_swap_index = index
		weapon_cycle.emit()
		queue_redraw()
		return

	if pos.distance_to(_loot_center()) <= LOOT_RADIUS * 1.3:
		_loot_index = index
		loot.emit()
		queue_redraw()
		return

	if pos.distance_to(_band_center()) <= BAND_RADIUS * 1.3:
		_band_index = index
		use_bandage.emit()
		queue_redraw()
		return

	if pos.distance_to(_med_center()) <= MED_RADIUS * 1.3:
		_med_index = index
		use_medkit.emit()
		queue_redraw()
		return

	if _look_index == -1:
		_look_index = index

func _on_drag(index: int, pos: Vector2, relative: Vector2) -> void:
	if index == _joy_index:
		var v := (pos - _joy_center) / JOY_RADIUS
		if v.length() > 1.0:
			v = v.normalized()
		_joy_vec = v
		queue_redraw()
	elif index == _look_index:
		look.emit(relative)

func _on_up(index: int) -> void:
	if index == _joy_index:
		_joy_index = -1
		_joy_active = false
		_joy_vec = Vector2.ZERO
		_joy_center = _default_joy_center()
		_release_move()
		queue_redraw()
	elif index == _look_index:
		_look_index = -1
	elif index == _fire_index:
		_fire_index = -1
		queue_redraw()
	elif index == _jump_index:
		_jump_index = -1
		Input.action_release("jump")
	elif index == _reload_index:
		_reload_index = -1
		queue_redraw()
	elif index == _swap_index:
		_swap_index = -1
		queue_redraw()
	elif index == _loot_index:
		_loot_index = -1
		queue_redraw()
	elif index == _band_index:
		_band_index = -1
		queue_redraw()
	elif index == _med_index:
		_med_index = -1
		queue_redraw()

func _release_move() -> void:
	for action in ["move_forward", "move_back", "move_left", "move_right"]:
		Input.action_release(action)

func _set_action(action: String, strength: float) -> void:
	if strength > 0.01:
		Input.action_press(action, minf(strength, 1.0))
	else:
		Input.action_release(action)

func _on_viewport_resized() -> void:
	if _joy_index == -1:
		_joy_center = _default_joy_center()
	queue_redraw()

func _default_joy_center() -> Vector2:
	var screen := get_viewport_rect().size
	return Vector2(JOY_MARGIN, screen.y - JOY_MARGIN)

func _fire_center() -> Vector2:
	var screen := get_viewport_rect().size
	return Vector2(screen.x - 120.0, screen.y - 160.0)

func _jump_center() -> Vector2:
	var screen := get_viewport_rect().size
	return Vector2(screen.x - 250.0, screen.y - 100.0)

func _reload_center() -> Vector2:
	var screen := get_viewport_rect().size
	return Vector2(screen.x - 120.0, screen.y - 280.0)

func _swap_center() -> Vector2:
	var screen := get_viewport_rect().size
	return Vector2(screen.x - 250.0, screen.y - 220.0)

func _loot_center() -> Vector2:
	var screen := get_viewport_rect().size
	return Vector2(screen.x - 120.0, screen.y - 400.0)

func _band_center() -> Vector2:
	var screen := get_viewport_rect().size
	return Vector2(screen.x - 250.0, screen.y - 340.0)

func _med_center() -> Vector2:
	var screen := get_viewport_rect().size
	return Vector2(screen.x - 250.0, screen.y - 430.0)

func _has_arg(prefix: String) -> bool:
	for a in OS.get_cmdline_args():
		if a == prefix:
			return true
	for a in OS.get_cmdline_user_args():
		if a == prefix:
			return true
	return false

func _draw() -> void:
	if not _enabled:
		return

	var base: Vector2 = _joy_center if _joy_active else _default_joy_center()
	draw_circle(base, JOY_RADIUS, Color(1, 1, 1, 0.12))
	draw_arc(base, JOY_RADIUS, 0.0, TAU, 48, Color(1, 1, 1, 0.35), 2.0, true)
	if _joy_active:
		var knob := base + _joy_vec * JOY_RADIUS
		draw_circle(knob, 42.0, Color(1, 1, 1, 0.35))

	var fc := _fire_center()
	draw_circle(fc, FIRE_RADIUS, Color(0.9, 0.25, 0.2, 0.45))
	draw_arc(fc, FIRE_RADIUS, 0.0, TAU, 32, Color(1, 1, 1, 0.4), 2.0, true)
	_draw_label(fc, "FIRE")

	var jc := _jump_center()
	draw_circle(jc, JUMP_RADIUS, Color(0.3, 0.65, 1.0, 0.4))
	draw_arc(jc, JUMP_RADIUS, 0.0, TAU, 32, Color(1, 1, 1, 0.4), 2.0, true)
	_draw_label(jc, "JUMP")

	var rc := _reload_center()
	draw_circle(rc, RELOAD_RADIUS, Color(0.95, 0.75, 0.2, 0.42))
	draw_arc(rc, RELOAD_RADIUS, 0.0, TAU, 32, Color(1, 1, 1, 0.4), 2.0, true)
	_draw_label(rc, "RELOAD")

	var sc := _swap_center()
	draw_circle(sc, SWAP_RADIUS, Color(0.55, 0.85, 0.45, 0.4))
	draw_arc(sc, SWAP_RADIUS, 0.0, TAU, 32, Color(1, 1, 1, 0.4), 2.0, true)
	_draw_label(sc, "SWAP")

	var lc := _loot_center()
	draw_circle(lc, LOOT_RADIUS, Color(1.0, 0.82, 0.25, 0.42))
	draw_arc(lc, LOOT_RADIUS, 0.0, TAU, 32, Color(1, 1, 1, 0.4), 2.0, true)
	_draw_label(lc, "LOOT")

	var bc := _band_center()
	draw_circle(bc, BAND_RADIUS, Color(0.88, 0.82, 0.58, 0.42))
	draw_arc(bc, BAND_RADIUS, 0.0, TAU, 32, Color(1, 1, 1, 0.4), 2.0, true)
	_draw_label(bc, "BAND")

	var mc := _med_center()
	draw_circle(mc, MED_RADIUS, Color(0.95, 0.3, 0.3, 0.42))
	draw_arc(mc, MED_RADIUS, 0.0, TAU, 32, Color(1, 1, 1, 0.4), 2.0, true)
	_draw_label(mc, "MED")

func _draw_label(center: Vector2, text: String) -> void:
	var font := ThemeDB.fallback_font
	var font_size := 16
	var text_size := font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size)
	var pos := center - Vector2(text_size.x * 0.5, -text_size.y * 0.35)
	draw_string(font, pos, text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, Color(1, 1, 1, 0.9))
