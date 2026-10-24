extends CanvasLayer

const Weapons := preload("res://shared/weapons.gd")

@onready var map_label: Label = $Root/TopLeft/Map
@onready var health_label: Label = $Root/TopLeft/Health
@onready var armor_label: Label = $Root/TopLeft/Armor
@onready var kills_label: Label = $Root/TopLeft/Kills
@onready var alive_label: Label = $Root/TopLeft/Alive
@onready var storm_label: Label = $Root/TopLeft/Storm
@onready var weapon_label: Label = $Root/TopLeft/Weapon
@onready var inventory_label: Label = $Root/TopLeft/Inventory
@onready var heal_label: Label = $Root/TopLeft/Heal
@onready var crosshair: Label = $Root/Crosshair
@onready var message: Label = $Root/Message
@onready var loot_prompt: Label = $Root/LootPrompt
@onready var damage_flash: ColorRect = $Root/DamageFlash
@onready var kill_feed: VBoxContainer = $Root/KillFeed

var _message_left := 0.0

func _ready() -> void:
	# HUD must never eat mouse clicks meant for shooting.
	_ignore_mouse($Root)

func _ignore_mouse(node: Node) -> void:
	if node is Control:
		(node as Control).mouse_filter = Control.MOUSE_FILTER_IGNORE
	for child in node.get_children():
		_ignore_mouse(child)

func _process(delta: float) -> void:
	if _message_left > 0.0:
		_message_left -= delta
		if _message_left <= 0.0:
			message.text = ""

func set_map_name(map_name: String) -> void:
	map_label.text = map_name

func set_health(value: int) -> void:
	health_label.text = "HP %d" % value

func set_armor(value: int, max_value := 100) -> void:
	armor_label.text = "ARMOR %d / %d" % [value, max_value]
	if value > 0:
		armor_label.modulate = Color(1, 1, 1, 1)
	else:
		armor_label.modulate = Color(0.62, 0.68, 0.74, 1)

func set_inventory(bandages: int, medkits: int) -> void:
	inventory_label.text = "BANDAGE x%d   MEDKIT x%d" % [bandages, medkits]

func set_heal(kind: int, remaining: float) -> void:
	if kind == 0 or remaining <= 0.0:
		heal_label.text = ""
		return
	var item_name := "BANDAGE" if kind == 1 else "MEDKIT"
	heal_label.text = "USING %s  %.1fs" % [item_name, remaining]

func set_loot_prompt(text: String, visible := true) -> void:
	loot_prompt.text = text
	loot_prompt.visible = visible

func set_kills(value: int) -> void:
	kills_label.text = "Kills %d" % value

func set_alive(alive: int, total: int) -> void:
	alive_label.text = "ALIVE %d / %d" % [alive, total]

func push_kill_feed(text: String) -> void:
	if text.is_empty():
		return
	var label := Label.new()
	label.text = text
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
	label.add_theme_font_size_override("font_size", 17)
	label.add_theme_color_override("font_outline_color", Color(0.0, 0.0, 0.0, 0.9))
	label.add_theme_constant_override("outline_size", 5)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	if text.contains("WINS"):
		label.add_theme_color_override("font_color", Color(1.0, 0.84, 0.3, 1.0))
	elif text.contains("STORM"):
		label.add_theme_color_override("font_color", Color(0.55, 0.82, 1.0, 1.0))
	else:
		label.add_theme_color_override("font_color", Color(0.92, 0.95, 0.98, 1.0))
	kill_feed.add_child(label)

	while kill_feed.get_child_count() > 5:
		var oldest := kill_feed.get_child(0)
		kill_feed.remove_child(oldest)
		oldest.queue_free()

	var tween := create_tween()
	tween.tween_interval(4.5)
	tween.tween_property(label, "modulate:a", 0.0, 0.7)
	tween.tween_callback(func() -> void:
		if is_instance_valid(label):
			label.queue_free()
	)

func clear_kill_feed() -> void:
	for child in kill_feed.get_children():
		child.queue_free()

func set_weapon(index: int, mag: int, reserve: int, reloading := false) -> void:
	var weapon_name := Weapons.name_of(index)
	weapon_label.text = "%s  %d / %d" % [weapon_name, mag, reserve]
	if reloading:
		weapon_label.text += "  RELOADING..."
		weapon_label.modulate = Color(1.0, 0.75, 0.3, 1.0)
	else:
		weapon_label.modulate = Color(1.0, 1.0, 1.0, 1.0)

func set_storm_status(text: String, danger := false) -> void:
	storm_label.text = text
	if danger:
		storm_label.modulate = Color(1.0, 0.35, 0.35, 1.0)
	else:
		storm_label.modulate = Color(1.0, 1.0, 1.0, 1.0)

func show_message(text: String, seconds := 2.5) -> void:
	message.text = text
	_message_left = seconds

func flash_hit() -> void:
	crosshair.modulate = Color(1.0, 0.25, 0.25, 1.0)
	var t := create_tween()
	t.tween_property(crosshair, "modulate", Color(1, 1, 1, 1), 0.2)

func flash_damage() -> void:
	damage_flash.color = Color(0.8, 0.0, 0.0, 0.45)
	var t := create_tween()
	t.tween_property(damage_flash, "color:a", 0.0, 0.35)

func flash_armor() -> void:
	damage_flash.color = Color(0.2, 0.55, 1.0, 0.35)
	var t := create_tween()
	t.tween_property(damage_flash, "color:a", 0.0, 0.3)
