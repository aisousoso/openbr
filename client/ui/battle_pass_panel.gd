## Battle Pass panel — shows tier, XP progress, and next reward.

extends Control

const BattlePass := preload("res://shared/battle_pass.gd")

var _xp := 0
var _tier := 0
var _xp_label: Label
var _tier_label: Label
var _progress: ProgressBar
var _reward_label: Label

func _ready() -> void:
	_build()
	visible = false

func _build() -> void:
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(280, 120)
	add_child(panel)

	var box := VBoxContainer.new()
	box.add_theme_constant_override("separation", 6)
	panel.add_child(box)

	_tier_label = Label.new()
	_tier_label.text = "Battle Pass — Tier 0"
	_tier_label.add_theme_font_size_override("font_size", 16)
	box.add_child(_tier_label)

	_xp_label = Label.new()
	_xp_label.text = "XP: 0 / 1000"
	_xp_label.add_theme_font_size_override("font_size", 12)
	box.add_child(_xp_label)

	_progress = ProgressBar.new()
	_progress.custom_minimum_size = Vector2(0, 16)
	_progress.max_value = 1000
	_progress.value = 0
	box.add_child(_progress)

	_reward_label = Label.new()
	_reward_label.text = "Next: (none)"
	_reward_label.add_theme_font_size_override("font_size", 12)
	_reward_label.modulate = Color(1, 0.85, 0.4)
	box.add_child(_reward_label)

func update(xp: int) -> void:
	_xp = xp
	_tier = BattlePass.tier_for_xp(xp)
	_tier_label.text = "Battle Pass — Tier %d / %d" % [_tier, BattlePass.MAX_TIER]
	var tier_xp := (_tier + 1) * BattlePass.XP_PER_TIER
	_xp_label.text = "XP: %d / %d" % [xp, tier_xp]
	_progress.max_value = BattlePass.XP_PER_TIER
	_progress.value = xp % BattlePass.XP_PER_TIER
	var next_tier := BattlePass.next_reward_tier(_tier)
	if next_tier > 0:
		var reward := BattlePass.reward_for_tier(next_tier)
		_reward_label.text = "Next reward (Tier %d): %s" % [next_tier, reward.get("name", "???")]
	else:
		_reward_label.text = "Max tier reached!"