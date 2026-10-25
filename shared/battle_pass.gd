## Shared Battle Pass definitions and helpers.
## Cosmetic rewards only — no IAP. XP earned through gameplay.

const SEASON := 1
const MAX_TIER := 50
const XP_PER_TIER := 1000

## Tier rewards: tier -> {name, type, free}
const REWARDS := {
	1: {"name": "Rookie Skin", "type": "skin", "free": true},
	5: {"name": "Wave Emote", "type": "emote", "free": true},
	10: {"name": "Tactical Vest", "type": "outfit", "free": false},
	15: {"name": "Clap Emote", "type": "emote", "free": true},
	20: {"name": "Desert Camo", "type": "skin", "free": false},
	25: {"name": "Dance Emote", "type": "emote", "free": false},
	30: {"name": "Urban Outfit", "type": "outfit", "free": false},
	40: {"name": "Gold Skin", "type": "skin", "free": false},
	50: {"name": "Champion Title", "type": "title", "free": false},
}

## XP rewards for match performance.
static func xp_for_match(kills: int, placement: int, survived_seconds: float) -> int:
	var xp := 0
	xp += kills * 50
	xp += maxi(0, (51 - placement) * 20)  # 1st = 1000, 50th = 20
	xp += int(survived_seconds * 0.5)
	return xp

static func tier_for_xp(xp: int) -> int:
	return clampi(xp / XP_PER_TIER, 0, MAX_TIER)

static func reward_for_tier(tier: int) -> Dictionary:
	return REWARDS.get(tier, {})

static func is_unlocked(tier: int, unlocked_tiers: Array) -> bool:
	return tier in unlocked_tiers

static func next_reward_tier(current_tier: int) -> int:
	for t in REWARDS.keys():
		if t > current_tier:
			return t
	return -1