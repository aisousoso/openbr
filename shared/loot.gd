## Shared loot definitions and deterministic spawn points.
##
## The server owns pickup validation and inventory state. The client uses the
## same definitions to render loot and to show the correct pickup prompt.
## All item names and visuals are original OpenBR content.

const PICKUP_RADIUS := 2.6

const ITEM_DEFS := {
	"armor": {
		"label": "ARMOR",
		"amount": 50,
		"color": Color(0.28, 0.68, 1.0),
	},
	"medkit": {
		"label": "MEDKIT",
		"amount": 1,
		"max_stack": 3,
		"heal": 60,
		"use_time": 4.0,
		"color": Color(0.95, 0.28, 0.28),
	},
	"bandage": {
		"label": "BANDAGE",
		"amount": 2,
		"max_stack": 5,
		"heal": 25,
		"use_time": 2.0,
		"color": Color(0.88, 0.82, 0.58),
	},
	"ammo": {
		"label": "AMMO",
		"amount": 30,
		"color": Color(0.78, 0.86, 0.28),
	},
}

## Fixed positions keep the server and client in sync without shipping a loot
## snapshot every tick. IDs are the array indices.
##
## The first nine entries are spawn-adjacent bandages, one for each of the nine
## Verdant Reach spawn points. Boardwalk and pier loot sits at y=0.65 so it is
## visible above the wooden surface instead of under it.
const SPAWNS := [
	# Spawn-adjacent supplies.
	{"id": 0, "type": "bandage", "pos": Vector3(1.5, 0.25, 18.0)},
	{"id": 1, "type": "bandage", "pos": Vector3(35.5, 0.25, 34.0)},
	{"id": 2, "type": "bandage", "pos": Vector3(-30.5, 0.25, 32.0)},
	{"id": 3, "type": "bandage", "pos": Vector3(33.5, 0.65, -32.0)},
	{"id": 4, "type": "bandage", "pos": Vector3(-31.5, 0.25, -30.5)},
	{"id": 5, "type": "bandage", "pos": Vector3(1.5, 0.25, 45.0)},
	{"id": 6, "type": "bandage", "pos": Vector3(45.0, 0.65, 1.5)},
	{"id": 7, "type": "bandage", "pos": Vector3(-45.0, 0.25, 1.5)},
	{"id": 8, "type": "bandage", "pos": Vector3(0.0, 0.65, -43.5)},

	# Meridian Relay.
	{"id": 9, "type": "medkit", "pos": Vector3(5.0, 0.25, 9.0)},
	{"id": 10, "type": "armor", "pos": Vector3(-8.0, 0.25, 3.0)},
	{"id": 11, "type": "ammo", "pos": Vector3(8.0, 0.25, 0.0)},
	{"id": 12, "type": "bandage", "pos": Vector3(7.0, 0.25, -7.0)},
	{"id": 13, "type": "ammo", "pos": Vector3(-5.0, 0.25, -9.0)},
	{"id": 14, "type": "medkit", "pos": Vector3(11.0, 0.25, 11.0)},

	# Aurora Yards.
	{"id": 15, "type": "armor", "pos": Vector3(24.0, 0.25, 24.0)},
	{"id": 16, "type": "ammo", "pos": Vector3(37.0, 0.25, 32.0)},
	{"id": 17, "type": "bandage", "pos": Vector3(32.0, 0.25, 38.0)},
	{"id": 18, "type": "medkit", "pos": Vector3(37.0, 0.25, 40.0)},
	{"id": 19, "type": "armor", "pos": Vector3(20.0, 0.25, 34.0)},
	{"id": 20, "type": "ammo", "pos": Vector3(35.0, 0.25, 22.0)},

	# Cinder Terrace.
	{"id": 21, "type": "medkit", "pos": Vector3(-24.0, 0.25, 28.0)},
	{"id": 22, "type": "armor", "pos": Vector3(-41.0, 0.25, 28.0)},
	{"id": 23, "type": "bandage", "pos": Vector3(-23.0, 0.25, 38.0)},
	{"id": 24, "type": "ammo", "pos": Vector3(-40.0, 0.25, 38.0)},
	{"id": 25, "type": "bandage", "pos": Vector3(-35.0, 0.25, 20.0)},
	{"id": 26, "type": "armor", "pos": Vector3(-19.0, 0.25, 32.0)},

	# Tideglass Shore.
	{"id": 27, "type": "armor", "pos": Vector3(33.0, 0.65, -28.0)},
	{"id": 28, "type": "medkit", "pos": Vector3(37.0, 0.65, -28.0)},
	{"id": 29, "type": "bandage", "pos": Vector3(28.0, 0.65, -38.0)},
	{"id": 30, "type": "ammo", "pos": Vector3(38.0, 0.65, -38.0)},
	{"id": 31, "type": "bandage", "pos": Vector3(32.0, 0.25, -22.0)},
	{"id": 32, "type": "armor", "pos": Vector3(42.0, 0.25, -30.0)},

	# Dune Chapel.
	{"id": 33, "type": "medkit", "pos": Vector3(-27.0, 0.25, -28.0)},
	{"id": 34, "type": "armor", "pos": Vector3(-38.0, 0.25, -28.0)},
	{"id": 35, "type": "bandage", "pos": Vector3(-25.0, 0.25, -38.0)},
	{"id": 36, "type": "ammo", "pos": Vector3(-40.0, 0.25, -38.0)},
	{"id": 37, "type": "bandage", "pos": Vector3(-32.0, 0.25, -22.0)},
	{"id": 38, "type": "armor", "pos": Vector3(-22.0, 0.25, -32.0)},

	# Frostline Depot.
	{"id": 39, "type": "armor", "pos": Vector3(-8.0, 0.25, 40.0)},
	{"id": 40, "type": "medkit", "pos": Vector3(8.0, 0.25, 40.0)},
	{"id": 41, "type": "bandage", "pos": Vector3(-8.0, 0.25, 50.0)},
	{"id": 42, "type": "ammo", "pos": Vector3(8.0, 0.25, 50.0)},
	{"id": 43, "type": "bandage", "pos": Vector3(0.0, 0.25, 36.0)},
	{"id": 44, "type": "medkit", "pos": Vector3(16.0, 0.25, 48.0)},

	# Saltwind Docks.
	{"id": 45, "type": "armor", "pos": Vector3(40.0, 0.65, -8.0)},
	{"id": 46, "type": "medkit", "pos": Vector3(50.0, 0.25, -4.0)},
	{"id": 47, "type": "bandage", "pos": Vector3(40.0, 0.25, 8.0)},
	{"id": 48, "type": "ammo", "pos": Vector3(50.0, 0.25, 8.0)},
	{"id": 49, "type": "bandage", "pos": Vector3(36.0, 0.25, 0.0)},
	{"id": 50, "type": "armor", "pos": Vector3(52.0, 0.25, -18.0)},

	# Hollow Grove.
	{"id": 51, "type": "armor", "pos": Vector3(-40.0, 0.25, -8.0)},
	{"id": 52, "type": "medkit", "pos": Vector3(-50.0, 0.25, -8.0)},
	{"id": 53, "type": "bandage", "pos": Vector3(-40.0, 0.25, 8.0)},
	{"id": 54, "type": "ammo", "pos": Vector3(-46.0, 0.25, 8.0)},
	{"id": 55, "type": "bandage", "pos": Vector3(-36.0, 0.25, 0.0)},
	{"id": 56, "type": "armor", "pos": Vector3(-52.0, 0.25, 14.0)},

	# Sunken Gardens.
	{"id": 57, "type": "armor", "pos": Vector3(-8.0, 0.25, -40.0)},
	{"id": 58, "type": "medkit", "pos": Vector3(8.0, 0.25, -40.0)},
	{"id": 59, "type": "bandage", "pos": Vector3(-8.0, 0.25, -50.0)},
	{"id": 60, "type": "ammo", "pos": Vector3(8.0, 0.25, -50.0)},
	{"id": 61, "type": "bandage", "pos": Vector3(0.0, 0.65, -36.0)},
	{"id": 62, "type": "armor", "pos": Vector3(16.0, 0.25, -46.0)},

	# Roads and mid-map cover.
	{"id": 63, "type": "armor", "pos": Vector3(16.0, 0.25, 18.0)},
	{"id": 64, "type": "medkit", "pos": Vector3(-18.0, 0.25, 18.0)},
	{"id": 65, "type": "bandage", "pos": Vector3(18.0, 0.25, -18.0)},
	{"id": 66, "type": "ammo", "pos": Vector3(-18.0, 0.25, -18.0)},
	{"id": 67, "type": "medkit", "pos": Vector3(0.0, 0.25, 20.0)},
	{"id": 68, "type": "armor", "pos": Vector3(20.0, 0.25, 0.0)},
	{"id": 69, "type": "armor", "pos": Vector3(-74.0, 0.25, -67.0)},
	{"id": 70, "type": "bandage", "pos": Vector3(-44.0, 0.65, -68.0)},
	{"id": 71, "type": "ammo", "pos": Vector3(-17.0, 0.25, -73.0)},
	{"id": 72, "type": "bandage", "pos": Vector3(6.0, 0.25, -68.0)},
	{"id": 73, "type": "ammo", "pos": Vector3(29.0, 0.25, -66.0)},
	{"id": 74, "type": "medkit", "pos": Vector3(58.0, 0.25, -73.0)},
	{"id": 75, "type": "armor", "pos": Vector3(-69.0, 0.25, -45.0)},
	{"id": 76, "type": "bandage", "pos": Vector3(-45.0, 0.25, -46.0)},
	{"id": 77, "type": "ammo", "pos": Vector3(-19.0, 0.25, -45.0)},
	{"id": 78, "type": "bandage", "pos": Vector3(9.0, 0.25, -45.0)},
	{"id": 79, "type": "ammo", "pos": Vector3(33.0, 0.25, -41.0)},
	{"id": 80, "type": "medkit", "pos": Vector3(56.0, 0.25, -48.0)},
	{"id": 81, "type": "armor", "pos": Vector3(-72.0, 0.25, -20.0)},
	{"id": 82, "type": "bandage", "pos": Vector3(-46.0, 0.25, -16.0)},
	{"id": 83, "type": "ammo", "pos": Vector3(-22.0, 0.25, -16.0)},
	{"id": 84, "type": "bandage", "pos": Vector3(1.0, 0.65, -24.0)},
	{"id": 85, "type": "ammo", "pos": Vector3(33.0, 0.25, -19.0)},
	{"id": 86, "type": "medkit", "pos": Vector3(58.0, 0.25, -20.0)},
	{"id": 87, "type": "armor", "pos": Vector3(-66.0, 0.25, 9.0)},
	{"id": 88, "type": "bandage", "pos": Vector3(-44.0, 0.25, 0.0)},
	{"id": 89, "type": "ammo", "pos": Vector3(-17.0, 0.25, 2.0)},
	{"id": 90, "type": "bandage", "pos": Vector3(1.0, 0.25, 4.0)},
	{"id": 91, "type": "ammo", "pos": Vector3(31.0, 0.25, 9.0)},
	{"id": 92, "type": "medkit", "pos": Vector3(56.0, 0.25, 4.0)},
	{"id": 93, "type": "armor", "pos": Vector3(-69.0, 0.25, 33.0)},
	{"id": 94, "type": "bandage", "pos": Vector3(-43.0, 0.25, 26.0)},
	{"id": 95, "type": "ammo", "pos": Vector3(-25.0, 0.25, 33.0)},
	{"id": 96, "type": "bandage", "pos": Vector3(3.0, 0.25, 27.0)},
	{"id": 97, "type": "ammo", "pos": Vector3(31.0, 0.25, 26.0)},
	{"id": 98, "type": "medkit", "pos": Vector3(50.0, 0.25, 30.0)},
	{"id": 99, "type": "armor", "pos": Vector3(-69.0, 0.25, 50.0)},

]

static func all() -> Array:
	return SPAWNS

static func count() -> int:
	return SPAWNS.size()

static func valid_id(id: int) -> bool:
	return id >= 0 and id < SPAWNS.size()

static func get_spawn(id: int) -> Dictionary:
	if not valid_id(id):
		return {}
	return SPAWNS[id]

static func def(item_type: String) -> Dictionary:
	return ITEM_DEFS.get(item_type, {})

static func label(item_type: String) -> String:
	var data := def(item_type)
	return String(data.get("label", "ITEM"))

static func color(item_type: String) -> Color:
	var data := def(item_type)
	return data.get("color", Color(1, 1, 1))
