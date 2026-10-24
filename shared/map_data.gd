## Shared metadata for the original OpenBR map "Verdant Reach".
##
## The map scene builds its geometry from this data on both the client and the
## server. Keeping names, region centres and spawn points here avoids the two
## sides drifting apart.

const NAME := "VERDANT REACH"
const HALF_SIZE := 100.0

## Region centres and the colours used for ground patches and map labels.
const REGIONS := [
	{
		"id": "relay",
		"name": "MERIDIAN RELAY",
		"center": Vector2(0, 0),
		"radius": 14.0,
		"ground": Color(0.32, 0.34, 0.36),
		"accent": Color(0.50, 0.54, 0.58),
		"label": Color(0.85, 0.92, 1.0),
	},
	{
		"id": "aurora",
		"name": "AURORA YARDS",
		"center": Vector2(32, 32),
		"radius": 17.0,
		"ground": Color(0.34, 0.28, 0.22),
		"accent": Color(0.62, 0.34, 0.18),
		"label": Color(1.0, 0.72, 0.38),
	},
	{
		"id": "cinder",
		"name": "CINDER TERRACE",
		"center": Vector2(-32, 32),
		"radius": 16.0,
		"ground": Color(0.40, 0.29, 0.23),
		"accent": Color(0.70, 0.42, 0.26),
		"label": Color(1.0, 0.62, 0.42),
	},
	{
		"id": "tideglass",
		"name": "TIDEGLASS SHORE",
		"center": Vector2(32, -32),
		"radius": 17.0,
		"ground": Color(0.20, 0.32, 0.36),
		"accent": Color(0.16, 0.50, 0.54),
		"label": Color(0.42, 0.95, 1.0),
	},
	{
		"id": "dune",
		"name": "DUNE CHAPEL",
		"center": Vector2(-32, -32),
		"radius": 16.0,
		"ground": Color(0.50, 0.40, 0.24),
		"accent": Color(0.70, 0.56, 0.30),
		"label": Color(1.0, 0.88, 0.52),
	},
	{
		"id": "frostline",
		"name": "FROSTLINE DEPOT",
		"center": Vector2(0, 45),
		"radius": 14.0,
		"ground": Color(0.52, 0.59, 0.66),
		"accent": Color(0.72, 0.82, 0.90),
		"label": Color(0.72, 0.94, 1.0),
	},
	{
		"id": "saltwind",
		"name": "SALTWIND DOCKS",
		"center": Vector2(45, 0),
		"radius": 14.0,
		"ground": Color(0.26, 0.36, 0.40),
		"accent": Color(0.32, 0.58, 0.62),
		"label": Color(0.48, 1.0, 0.90),
	},
	{
		"id": "hollow",
		"name": "HOLLOW GROVE",
		"center": Vector2(-45, 0),
		"radius": 16.0,
		"ground": Color(0.14, 0.28, 0.16),
		"accent": Color(0.26, 0.50, 0.24),
		"label": Color(0.52, 1.0, 0.52),
	},
	{
		"id": "sunken",
		"name": "SUNKEN GARDENS",
		"center": Vector2(0, -45),
		"radius": 15.0,
		"ground": Color(0.16, 0.32, 0.28),
		"accent": Color(0.20, 0.52, 0.40),
		"label": Color(0.42, 1.0, 0.72),
	},
]

## Marker positions kept in sync with the SpawnPoints node in the map scene.
const SPAWN_POINTS := [
	Vector3(0.0, 0.5, 18.0),    # Meridian Relay
	Vector3(34.0, 0.5, 34.0),   # Aurora Yards
	Vector3(-32.0, 0.5, 32.0),  # Cinder Terrace
	Vector3(32.0, 0.5, -32.0),  # Tideglass Shore
	Vector3(-32.0, 0.5, -29.0), # Dune Chapel
	Vector3(0.0, 0.5, 45.0),    # Frostline Depot
	Vector3(45.0, 0.5, 0.0),    # Saltwind Docks
	Vector3(-45.0, 0.5, 0.0),   # Hollow Grove
	Vector3(0.0, 0.5, -45.0),   # Sunken Gardens
]

static func region_by_id(id: String) -> Dictionary:
	for region in REGIONS:
		if String(region["id"]) == id:
			return region
	return {}
