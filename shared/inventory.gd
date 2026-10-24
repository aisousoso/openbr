## Shared inventory, armor and healing rules.
##
## The server calls these helpers on its authoritative player dictionaries. The
## client only displays the values that arrive in snapshots, so this file is a
## good place for deterministic, testable gameplay rules.

const Loot := preload("res://shared/loot.gd")

const MAX_ARMOR := 100
const ARMOR_ABSORB := 0.55
const MAX_HEALTH := 100

## Creates the inventory-related fields for a fresh player dictionary.
static func new_state() -> Dictionary:
	return {
		"health": MAX_HEALTH,
		"armor": 0,
		"armor_max": MAX_ARMOR,
		"inventory": {"bandage": 0, "medkit": 0},
		"heal_until": 0.0,
		"heal_type": 0,
		"heal_amount": 0,
	}

## Resets armor, consumables and any active heal. Health is reset by the caller
## so respawn logic stays in one place.
static func reset(state: Dictionary) -> void:
	state["armor"] = 0
	state["armor_max"] = MAX_ARMOR
	state["inventory"] = {"bandage": 0, "medkit": 0}
	cancel_heal(state)

## Applies one loot pickup. Returns {"ok": bool, "message": String}.
static func pickup(state: Dictionary, item_type: String) -> Dictionary:
	var data := Loot.def(item_type)
	if data.is_empty():
		return {"ok": false, "message": "Unknown item"}

	var added := 0
	match item_type:
		"armor":
			var armor := int(state.get("armor", 0))
			var max_armor := int(state.get("armor_max", MAX_ARMOR))
			if armor >= max_armor:
				return {"ok": false, "message": "Armor already full"}
			added = mini(int(data["amount"]), max_armor - armor)
			state["armor"] = armor + added
			return {"ok": true, "message": "Armor +%d" % added}

		"bandage", "medkit":
			var inv: Dictionary = state.get("inventory", {})
			if inv.is_empty():
				inv = {"bandage": 0, "medkit": 0}
				state["inventory"] = inv
			var current := int(inv.get(item_type, 0))
			var cap := int(data.get("max_stack", 5))
			if current >= cap:
				return {"ok": false, "message": "%s full" % String(data["label"])}
			added = mini(int(data["amount"]), cap - current)
			inv[item_type] = current + added
			return {"ok": true, "message": "%s +%d" % [String(data["label"]), added]}

		"ammo":
			var ammo: Dictionary = state.get("ammo", {})
			if ammo.is_empty():
				return {"ok": false, "message": "No weapon"}
			var current_weapon := int(state.get("weapon", 0))
			var total := 0
			for weapon_index in ammo.keys():
				var add := int(data["amount"])
				if int(weapon_index) != current_weapon:
					add = maxi(1, int(add / 2))
				ammo[weapon_index]["reserve"] = int(ammo[weapon_index]["reserve"]) + add
				total += add
			if total <= 0:
				return {"ok": false, "message": "Ammo full"}
			return {"ok": true, "message": "Ammo +%d" % total}

	return {"ok": false, "message": "Unknown item"}

## Starts a timed heal. Consumables are spent immediately; damage or firing
## cancels the heal and the item stays spent.
static func start_heal(state: Dictionary, item_type: String, now: float) -> Dictionary:
	if item_type != "bandage" and item_type != "medkit":
		return {"ok": false, "message": "Unknown item"}
	if float(state.get("heal_until", 0.0)) > now:
		return {"ok": false, "message": "Already using an item"}
	if int(state.get("health", 0)) >= MAX_HEALTH:
		return {"ok": false, "message": "Health is full"}

	var data := Loot.def(item_type)
	var inv: Dictionary = state.get("inventory", {})
	var current := int(inv.get(item_type, 0))
	if current <= 0:
		return {"ok": false, "message": "No %s" % String(data["label"])}

	inv[item_type] = current - 1
	state["heal_type"] = 1 if item_type == "bandage" else 2
	state["heal_until"] = now + float(data["use_time"])
	state["heal_amount"] = int(data["heal"])
	return {"ok": true, "message": "Using %s..." % String(data["label"])}

## Advances a heal. Returns the amount healed this tick.
static func tick_heal(state: Dictionary, now: float) -> int:
	var until := float(state.get("heal_until", 0.0))
	if until <= 0.0 or now < until:
		return 0

	var amount := int(state.get("heal_amount", 0))
	var health := int(state.get("health", 0))
	var healed := mini(amount, maxi(0, MAX_HEALTH - health))
	state["health"] = health + healed
	state["heal_until"] = 0.0
	state["heal_type"] = 0
	state["heal_amount"] = 0
	return healed

static func cancel_heal(state: Dictionary) -> void:
	state["heal_until"] = 0.0
	state["heal_type"] = 0
	state["heal_amount"] = 0

## Applies weapon or storm damage. Armor absorbs a percentage of weapon damage
## until it is depleted; storm damage passes ignore_armor = true.
static func apply_damage(state: Dictionary, amount: int, ignore_armor := false) -> Dictionary:
	var remaining := maxi(0, amount)
	var absorbed := 0
	if not ignore_armor:
		var armor := int(state.get("armor", 0))
		if armor > 0 and remaining > 0:
			absorbed = mini(armor, int(ceil(remaining * ARMOR_ABSORB)))
			state["armor"] = armor - absorbed
			remaining -= absorbed

	var health := maxi(0, int(state.get("health", 0)) - remaining)
	state["health"] = health
	cancel_heal(state)
	return {
		"health_damage": remaining,
		"armor_damage": absorbed,
		"dead": health <= 0,
	}

static func heal_remaining(state: Dictionary, now: float) -> float:
	return maxf(0.0, float(state.get("heal_until", 0.0)) - now)
