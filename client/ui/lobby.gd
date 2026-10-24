extends CanvasLayer

## Original operator lobby and character select.
##
## The roster, palettes and outfit styles live in shared/characters.gd. This
## screen is purely cosmetic; the selected appearance is saved to
## user://profile.cfg and sent to the server after authentication.

signal play_requested

const Characters := preload("res://shared/characters.gd")
const CharacterModel := preload("res://shared/character_model.gd")

const PRESETS := [
	{
		"name": "Ember",
		"primary": Color(0.72, 0.28, 0.18),
		"secondary": Color(0.20, 0.12, 0.10),
		"accent": Color(1.00, 0.72, 0.25),
	},
	{
		"name": "Frost",
		"primary": Color(0.42, 0.70, 0.82),
		"secondary": Color(0.12, 0.23, 0.32),
		"accent": Color(0.86, 0.96, 1.00),
	},
	{
		"name": "Forest",
		"primary": Color(0.30, 0.48, 0.27),
		"secondary": Color(0.12, 0.20, 0.12),
		"accent": Color(0.86, 0.72, 0.30),
	},
	{
		"name": "Neon",
		"primary": Color(0.18, 0.12, 0.34),
		"secondary": Color(0.08, 0.05, 0.15),
		"accent": Color(0.30, 0.95, 0.78),
	},
	{
		"name": "Signal",
		"primary": Color(0.82, 0.78, 0.66),
		"secondary": Color(0.18, 0.23, 0.28),
		"accent": Color(0.20, 0.72, 0.92),
	},
]

var _appearance: Dictionary = {}
var _roster_buttons: Array[Button] = []
var _pickers: Dictionary = {}
var _outfit_option: OptionButton
var _name_label: Label
var _role_label: Label
var _bio_label: Label
var _status_label: Label
var _preview: Node3D
var _preview_pivot: Node3D
var _preview_spin := true

func _ready() -> void:
	layer = 20
	_appearance = Characters.load_profile()
	_build()
	visible = false

func _process(delta: float) -> void:
	if not visible or _preview_pivot == null or not _preview_spin:
		return
	_preview_pivot.rotation.y += delta * 0.35

func open_screen(message := "") -> void:
	visible = true
	_refresh_all()
	if _status_label != null:
		_status_label.text = message if not message.is_empty() else "Select an operator, customize the look, then deploy."
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE

func close_screen() -> void:
	visible = false
	for picker in _pickers.values():
		if picker is ColorPickerButton:
			picker.get_popup().hide()
	DisplayServer.virtual_keyboard_hide()

func get_appearance() -> Dictionary:
	return Characters.sanitize(_appearance)

func set_status(message: String) -> void:
	if _status_label != null:
		_status_label.text = message

# ---------------------------------------------------------------- build

func _build() -> void:
	var root := Control.new()
	root.name = "Root"
	root.mouse_filter = Control.MOUSE_FILTER_STOP
	add_child(root)
	root.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var bg := ColorRect.new()
	bg.color = Color(0.025, 0.035, 0.050, 1.0)
	bg.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(bg)
	bg.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var top_glow := ColorRect.new()
	top_glow.color = Color(0.10, 0.18, 0.22, 0.20)
	top_glow.mouse_filter = Control.MOUSE_FILTER_IGNORE
	root.add_child(top_glow)
	top_glow.set_anchors_and_offsets_preset(Control.PRESET_TOP_WIDE)
	top_glow.custom_minimum_size = Vector2(0, 84)

	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", 24)
	margin.add_theme_constant_override("margin_right", 24)
	margin.add_theme_constant_override("margin_top", 18)
	margin.add_theme_constant_override("margin_bottom", 18)
	root.add_child(margin)
	margin.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)

	var outer := VBoxContainer.new()
	outer.add_theme_constant_override("separation", 12)
	margin.add_child(outer)

	outer.add_child(_build_header())

	var main := HBoxContainer.new()
	main.size_flags_vertical = Control.SIZE_EXPAND_FILL
	main.add_theme_constant_override("separation", 12)
	outer.add_child(main)

	main.add_child(_build_roster_panel())
	main.add_child(_build_preview_panel())
	main.add_child(_build_customize_panel())

	var footer := HBoxContainer.new()
	footer.add_theme_constant_override("separation", 10)
	outer.add_child(footer)
	var hint := _small("Original characters and cosmetics. No paid unlocks. Appearance is synced by the server for other players.")
	hint.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	footer.add_child(hint)
	var quit_btn := Button.new()
	quit_btn.text = "QUIT"
	quit_btn.custom_minimum_size = Vector2(90, 34)
	quit_btn.pressed.connect(func() -> void: get_tree().quit())
	footer.add_child(quit_btn)

func _build_header() -> Control:
	var header := HBoxContainer.new()
	header.add_theme_constant_override("separation", 14)

	var brand := VBoxContainer.new()
	brand.add_theme_constant_override("separation", 0)
	var title := Label.new()
	title.text = "OPENBR // OPERATOR LOBBY"
	title.add_theme_font_size_override("font_size", 26)
	title.add_theme_color_override("font_color", Color(0.92, 0.96, 1.0))
	brand.add_child(title)
	var sub := _small("SERVER-AUTHORITATIVE BATTLE ROYALE  ·  COSMETIC LOADOUT")
	brand.add_child(sub)
	header.add_child(brand)

	var spacer := Control.new()
	spacer.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	header.add_child(spacer)

	var profile := _small("LOCAL PROFILE  ·  %d OPERATORS" % Characters.count())
	profile.autowrap_mode = TextServer.AUTOWRAP_OFF
	profile.add_theme_color_override("font_color", Color(0.55, 0.82, 0.78))
	header.add_child(profile)
	return header

func _build_roster_panel() -> PanelContainer:
	var panel := _panel(Vector2(252, 0))
	var margin := _panel_margin(panel, 12)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 8)
	margin.add_child(box)

	box.add_child(_heading("ROSTER"))
	box.add_child(_small("Choose an original operator. Selecting one restores its default palette and outfit."))

	var scroll := ScrollContainer.new()
	scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	box.add_child(scroll)

	var grid := GridContainer.new()
	grid.columns = 2
	grid.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	grid.add_theme_constant_override("h_separation", 6)
	grid.add_theme_constant_override("v_separation", 6)
	scroll.add_child(grid)

	var group := ButtonGroup.new()
	group.allow_unpress = false
	for i in Characters.count():
		var character: Dictionary = Characters.get_character(i)
		var button := Button.new()
		button.text = "%02d  %s" % [i + 1, String(character["name"])]
		button.tooltip_text = String(character["role"])
		button.toggle_mode = true
		button.button_group = group
		button.custom_minimum_size = Vector2(0, 42)
		button.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		button.add_theme_font_size_override("font_size", 13)
		button.pressed.connect(_on_character_selected.bind(i))
		grid.add_child(button)
		_roster_buttons.append(button)
	return panel

func _build_preview_panel() -> PanelContainer:
	var panel := _panel(Vector2(360, 0))
	panel.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	panel.size_flags_stretch_ratio = 1.25
	var margin := _panel_margin(panel, 12)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	margin.add_child(box)

	box.add_child(_heading("OPERATOR PREVIEW"))

	var view_container := SubViewportContainer.new()
	view_container.stretch = true
	view_container.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	view_container.size_flags_vertical = Control.SIZE_EXPAND_FILL
	view_container.custom_minimum_size = Vector2(320, 330)
	view_container.mouse_filter = Control.MOUSE_FILTER_IGNORE
	box.add_child(view_container)

	var viewport := SubViewport.new()
	viewport.name = "PreviewViewport"
	viewport.size = Vector2i(480, 520)
	viewport.render_target_update_mode = SubViewport.UPDATE_ALWAYS
	viewport.own_world_3d = true
	viewport.handle_input_locally = false
	view_container.add_child(viewport)
	_build_preview_world(viewport)

	_name_label = Label.new()
	_name_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_name_label.add_theme_font_size_override("font_size", 25)
	_name_label.add_theme_color_override("font_color", Color(0.94, 0.97, 1.0))
	box.add_child(_name_label)

	_role_label = Label.new()
	_role_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_role_label.add_theme_font_size_override("font_size", 13)
	_role_label.add_theme_color_override("font_color", Color(0.55, 0.82, 0.78))
	box.add_child(_role_label)

	_bio_label = Label.new()
	_bio_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_bio_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_bio_label.add_theme_font_size_override("font_size", 12)
	_bio_label.modulate = Color(1, 1, 1, 0.65)
	_bio_label.custom_minimum_size = Vector2(0, 34)
	box.add_child(_bio_label)
	return panel

func _build_customize_panel() -> PanelContainer:
	var panel := _panel(Vector2(318, 0))
	var margin := _panel_margin(panel, 12)
	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 7)
	margin.add_child(box)

	box.add_child(_heading("CUSTOMIZE"))
	box.add_child(_small("Colors and clothing are cosmetic. Outfit changes the silhouette."))

	box.add_child(_label("Outfit"))
	_outfit_option = OptionButton.new()
	for outfit in Characters.OUTFITS:
		_outfit_option.add_item(String(outfit))
	_outfit_option.item_selected.connect(_on_outfit_selected)
	box.add_child(_outfit_option)

	_add_color_row(box, "Primary", "primary")
	_add_color_row(box, "Secondary", "secondary")
	_add_color_row(box, "Accent", "accent")

	box.add_child(_label("Palette preset"))
	var presets := OptionButton.new()
	presets.add_item("Roster default")
	for preset in PRESETS:
		presets.add_item(String(preset["name"]))
	presets.item_selected.connect(_on_preset_selected)
	box.add_child(presets)

	var actions := HBoxContainer.new()
	actions.add_theme_constant_override("separation", 6)
	var reset_btn := Button.new()
	reset_btn.text = "Reset"
	reset_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	reset_btn.pressed.connect(_on_reset_pressed)
	actions.add_child(reset_btn)
	var random_btn := Button.new()
	random_btn.text = "Randomize"
	random_btn.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	random_btn.pressed.connect(_on_randomize_pressed)
	actions.add_child(random_btn)
	box.add_child(actions)

	var spacer := Control.new()
	spacer.size_flags_vertical = Control.SIZE_EXPAND_FILL
	box.add_child(spacer)

	_status_label = Label.new()
	_status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_status_label.add_theme_font_size_override("font_size", 12)
	_status_label.add_theme_color_override("font_color", Color(0.95, 0.78, 0.42))
	_status_label.custom_minimum_size = Vector2(0, 42)
	box.add_child(_status_label)

	var play_btn := Button.new()
	play_btn.text = "DEPLOY"
	play_btn.custom_minimum_size = Vector2(0, 54)
	play_btn.add_theme_font_size_override("font_size", 20)
	play_btn.pressed.connect(_on_play_pressed)
	box.add_child(play_btn)

	box.add_child(_small("Profile saved locally to user://profile.cfg"))
	return panel

func _build_preview_world(viewport: SubViewport) -> void:
	var world := Node3D.new()
	world.name = "PreviewWorld"
	viewport.add_child(world)

	var environment_node := WorldEnvironment.new()
	var environment := Environment.new()
	environment.background_mode = Environment.BG_COLOR
	environment.background_color = Color(0.035, 0.050, 0.070)
	environment.ambient_light_source = Environment.AMBIENT_SOURCE_COLOR
	environment.ambient_light_color = Color(0.50, 0.62, 0.72)
	environment.ambient_light_energy = 0.85
	environment_node.environment = environment
	world.add_child(environment_node)

	var camera := Camera3D.new()
	camera.fov = 32.0
	camera.position = Vector3(0.0, 1.20, 3.65)
	camera.look_at_from_position(Vector3(0.0, 1.20, 3.65), Vector3(0.0, 1.02, 0.0), Vector3.UP)
	world.add_child(camera)

	var key_light := DirectionalLight3D.new()
	key_light.rotation_degrees = Vector3(-42.0, -32.0, 0.0)
	key_light.light_energy = 1.35
	key_light.shadow_enabled = true
	world.add_child(key_light)

	var fill_light := OmniLight3D.new()
	fill_light.position = Vector3(-2.0, 2.2, 2.0)
	fill_light.light_color = Color(0.55, 0.78, 1.0)
	fill_light.light_energy = 2.5
	fill_light.omni_range = 6.0
	world.add_child(fill_light)

	var rim_light := OmniLight3D.new()
	rim_light.position = Vector3(2.0, 1.6, -2.0)
	rim_light.light_color = Color(1.0, 0.58, 0.30)
	rim_light.light_energy = 2.0
	rim_light.omni_range = 5.0
	world.add_child(rim_light)

	var platform := MeshInstance3D.new()
	var platform_mesh := CylinderMesh.new()
	platform_mesh.top_radius = 1.05
	platform_mesh.bottom_radius = 1.05
	platform_mesh.height = 0.12
	platform_mesh.radial_segments = 32
	platform.mesh = platform_mesh
	platform.position = Vector3(0.0, -0.06, 0.0)
	var platform_material := StandardMaterial3D.new()
	platform_material.albedo_color = Color(0.09, 0.13, 0.17)
	platform_material.roughness = 0.88
	platform_material.metallic = 0.15
	platform.material_override = platform_material
	world.add_child(platform)

	var ring := MeshInstance3D.new()
	var ring_mesh := TorusMesh.new()
	ring_mesh.inner_radius = 1.02
	ring_mesh.outer_radius = 1.12
	ring_mesh.rings = 32
	ring_mesh.ring_segments = 6
	ring.mesh = ring_mesh
	ring.position = Vector3(0.0, 0.015, 0.0)
	var ring_material := StandardMaterial3D.new()
	ring_material.albedo_color = Color(0.28, 0.72, 0.68)
	ring_material.roughness = 0.45
	ring_material.emission_enabled = true
	ring_material.emission = Color(0.10, 0.35, 0.32)
	ring.material_override = ring_material
	world.add_child(ring)

	_preview_pivot = Node3D.new()
	_preview_pivot.position = Vector3(0.0, 0.02, 0.0)
	world.add_child(_preview_pivot)

	_preview = CharacterModel.new()
	_preview_pivot.add_child(_preview)
	_preview.apply_appearance(_appearance)

func _add_color_row(box: VBoxContainer, label_text: String, key: String) -> void:
	var row := HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	var label := _label(label_text)
	label.custom_minimum_size = Vector2(88, 0)
	row.add_child(label)
	var picker := ColorPickerButton.new()
	picker.color = _appearance[key]
	picker.custom_minimum_size = Vector2(0, 34)
	picker.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	picker.edit_alpha = false
	picker.color_changed.connect(func(color: Color) -> void: _on_color_changed(key, color))
	row.add_child(picker)
	_pickers[key] = picker
	box.add_child(row)

func _panel(minimum_size: Vector2) -> PanelContainer:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = minimum_size
	var style := StyleBoxFlat.new()
	style.bg_color = Color(0.055, 0.075, 0.100, 0.96)
	style.border_color = Color(0.16, 0.25, 0.30, 1.0)
	style.set_border_width_all(1)
	style.set_corner_radius_all(8)
	panel.add_theme_stylebox_override("panel", style)
	return panel

func _panel_margin(panel: PanelContainer, amount: int) -> MarginContainer:
	var margin := MarginContainer.new()
	margin.add_theme_constant_override("margin_left", amount)
	margin.add_theme_constant_override("margin_right", amount)
	margin.add_theme_constant_override("margin_top", amount)
	margin.add_theme_constant_override("margin_bottom", amount)
	panel.add_child(margin)
	return margin

func _heading(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 15)
	label.add_theme_color_override("font_color", Color(0.90, 0.95, 1.0))
	return label

func _label(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.add_theme_font_size_override("font_size", 13)
	return label

func _small(text: String) -> Label:
	var label := Label.new()
	label.text = text
	label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	label.add_theme_font_size_override("font_size", 11)
	label.modulate = Color(1, 1, 1, 0.58)
	return label

# ---------------------------------------------------------------- state

func _refresh_all() -> void:
	_appearance = Characters.sanitize(_appearance)
	var index := int(_appearance["character"])
	for i in _roster_buttons.size():
		_roster_buttons[i].set_pressed_no_signal(i == index)

	var character: Dictionary = Characters.get_character(index)
	_name_label.text = String(character["name"]).to_upper()
	_role_label.text = String(character["role"])
	_bio_label.text = String(character["bio"])

	for key in _pickers:
		_pickers[key].color = _appearance[key]
	_outfit_option.select(int(_appearance["outfit"]))

	if _preview != null:
		_preview.apply_appearance(_appearance)

func _on_character_selected(index: int) -> void:
	_appearance = Characters.default_appearance(index)
	_refresh_all()

func _on_color_changed(key: String, color: Color) -> void:
	_appearance[key] = color
	if _preview != null:
		_preview.apply_appearance(_appearance)

func _on_outfit_selected(index: int) -> void:
	_appearance["outfit"] = clampi(index, 0, Characters.OUTFITS.size() - 1)
	if _preview != null:
		_preview.apply_appearance(_appearance)

func _on_preset_selected(index: int) -> void:
	if index <= 0:
		_on_reset_pressed()
		return
	var preset: Dictionary = PRESETS[index - 1]
	_appearance["primary"] = preset["primary"]
	_appearance["secondary"] = preset["secondary"]
	_appearance["accent"] = preset["accent"]
	_refresh_all()

func _on_reset_pressed() -> void:
	_appearance = Characters.default_appearance(int(_appearance["character"]))
	_refresh_all()

func _on_randomize_pressed() -> void:
	var index := randi() % Characters.count()
	_appearance = Characters.default_appearance(index)
	var hue := randf()
	_appearance["primary"] = Color.from_hsv(hue, randf_range(0.42, 0.78), randf_range(0.58, 0.92))
	_appearance["secondary"] = Color.from_hsv(fmod(hue + 0.48, 1.0), randf_range(0.30, 0.58), randf_range(0.18, 0.35))
	_appearance["accent"] = Color.from_hsv(fmod(hue + 0.12, 1.0), randf_range(0.55, 0.95), randf_range(0.72, 1.0))
	_appearance["outfit"] = randi() % Characters.OUTFITS.size()
	_refresh_all()

func _on_play_pressed() -> void:
	_appearance = Characters.sanitize(_appearance)
	Characters.save_profile(_appearance)
	if _status_label != null:
		_status_label.text = "Profile saved. Opening connection screen..."
	play_requested.emit()
