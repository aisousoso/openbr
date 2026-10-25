## Shared weapon definitions.
## The server owns damage, ammo, fire rate and reload timing; the client only
## uses names/indices for the HUD and tracer colors.

const LIST := [
	{
		"name": "Rifle",
		"damage": 25,
		"cooldown": 0.15,
		"range": 40.0,
		"mag": 30,
		"reserve": 90,
		"reload": 1.8,
		"pellets": 1,
		"spread": 0.0,
	},
	{
		"name": "SMG",
		"damage": 16,
		"cooldown": 0.08,
		"range": 28.0,
		"mag": 35,
		"reserve": 105,
		"reload": 1.5,
		"pellets": 1,
		"spread": 0.012,
	},
	{
		"name": "Shotgun",
		"damage": 12,
		"cooldown": 0.8,
		"range": 20.0,
		"mag": 6,
		"reserve": 24,
		"reload": 2.2,
		"pellets": 6,
		"spread": 0.06,
	},
	{
		"name": "Sniper",
		"damage": 80,
		"cooldown": 1.5,
		"range": 100.0,
		"mag": 5,
		"reserve": 15,
		"reload": 3.0,
		"pellets": 1,
		"spread": 0.0,
	},
	{
		"name": "Grenade",
		"damage": 60,
		"cooldown": 2.0,
		"range": 25.0,
		"mag": 3,
		"reserve": 6,
		"reload": 2.5,
		"pellets": 1,
		"spread": 0.0,
		"explosive": true,
		"blast_radius": 5.0,
	},
	{
		"name": "Rocket",
		"damage": 100,
		"cooldown": 3.0,
		"range": 60.0,
		"mag": 1,
		"reserve": 3,
		"reload": 4.0,
		"pellets": 1,
		"spread": 0.0,
		"explosive": true,
		"blast_radius": 8.0,
	},
	{
		"name": "Melee",
		"damage": 35,
		"cooldown": 0.6,
		"range": 2.5,
		"mag": 1,
		"reserve": 0,
		"reload": 0.0,
		"pellets": 1,
		"spread": 0.0,
		"melee": true,
	},
]

static func count() -> int:
	return LIST.size()

static func get_weapon(index: int) -> Dictionary:
	return LIST[clampi(index, 0, LIST.size() - 1)]

static func name_of(index: int) -> String:
	return String(get_weapon(index)["name"])

static func fresh_ammo() -> Dictionary:
	var out := {}
	for i in LIST.size():
		out[i] = {
			"mag": int(LIST[i]["mag"]),
			"reserve": int(LIST[i]["reserve"]),
		}
	return out
