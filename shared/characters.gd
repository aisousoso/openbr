## Original OpenBR operator roster and cosmetic appearance helpers.
##
## Everything here is original clean-room content: names, roles, palettes and
## outfit styles are not copied from any commercial game. Appearances are
## cosmetic only; the server stores them so other clients can render the same
## operator, but they never affect movement, hitboxes or damage.

const PROFILE_PATH := "user://profile.cfg"
const DEFAULT_INDEX := 0

const OUTFITS := ["Tactical", "Hoodie", "Armored", "Runner"]

## Headgear values: 0 = none, 1 = cap, 2 = helmet, 3 = hood.
const ROSTER := [
	{
		"name": "Aster",
		"role": "Skyline Scout",
		"bio": "A calm pathfinder who reads rooftops and ridge lines before the first shot.",
		"skin": Color(0.78, 0.53, 0.35),
		"hair": Color(0.17, 0.13, 0.09),
		"primary": Color(0.18, 0.55, 0.55),
		"secondary": Color(0.11, 0.23, 0.29),
		"accent": Color(0.95, 0.72, 0.29),
		"outfit": 0,
		"headgear": 1,
	},
	{
		"name": "Bram",
		"role": "Breach Engineer",
		"bio": "A patient heavy who prefers a reinforced doorway to an open field.",
		"skin": Color(0.55, 0.35, 0.23),
		"hair": Color(0.12, 0.09, 0.07),
		"primary": Color(0.65, 0.33, 0.20),
		"secondary": Color(0.23, 0.16, 0.14),
		"accent": Color(0.91, 0.76, 0.35),
		"outfit": 2,
		"headgear": 2,
	},
	{
		"name": "Cyra",
		"role": "Night Runner",
		"bio": "A courier built for silent rotations and quick exits through narrow alleys.",
		"skin": Color(0.85, 0.65, 0.49),
		"hair": Color(0.06, 0.07, 0.12),
		"primary": Color(0.29, 0.31, 0.62),
		"secondary": Color(0.11, 0.12, 0.20),
		"accent": Color(0.38, 0.84, 0.77),
		"outfit": 3,
		"headgear": 3,
	},
	{
		"name": "Dax",
		"role": "Dune Raider",
		"bio": "A salvage hunter who turns broken ground and dust clouds into cover.",
		"skin": Color(0.66, 0.42, 0.27),
		"hair": Color(0.16, 0.11, 0.07),
		"primary": Color(0.73, 0.54, 0.32),
		"secondary": Color(0.29, 0.21, 0.14),
		"accent": Color(0.95, 0.42, 0.31),
		"outfit": 0,
		"headgear": 0,
	},
	{
		"name": "Eira",
		"role": "Frost Medic",
		"bio": "A field medic whose bright kit marks the calmest pair of hands in the squad.",
		"skin": Color(0.88, 0.73, 0.61),
		"hair": Color(0.85, 0.82, 0.76),
		"primary": Color(0.50, 0.72, 0.79),
		"secondary": Color(0.17, 0.29, 0.35),
		"accent": Color(0.96, 0.91, 0.76),
		"outfit": 1,
		"headgear": 3,
	},
	{
		"name": "Fenn",
		"role": "Marsh Tracker",
		"bio": "A quiet tracker who knows when to wait, when to move and when to vanish.",
		"skin": Color(0.71, 0.48, 0.32),
		"hair": Color(0.16, 0.14, 0.10),
		"primary": Color(0.36, 0.48, 0.29),
		"secondary": Color(0.16, 0.21, 0.12),
		"accent": Color(0.85, 0.64, 0.25),
		"outfit": 0,
		"headgear": 1,
	},
	{
		"name": "Gale",
		"role": "Storm Courier",
		"bio": "A fast mover who treats every storm edge like a starting line.",
		"skin": Color(0.79, 0.55, 0.39),
		"hair": Color(0.23, 0.16, 0.11),
		"primary": Color(0.30, 0.61, 0.79),
		"secondary": Color(0.13, 0.23, 0.33),
		"accent": Color(0.95, 0.82, 0.36),
		"outfit": 3,
		"headgear": 0,
	},
	{
		"name": "Iris",
		"role": "Signal Analyst",
		"bio": "A patient listener who maps a fight from fragments of radio noise.",
		"skin": Color(0.89, 0.71, 0.58),
		"hair": Color(0.14, 0.10, 0.18),
		"primary": Color(0.49, 0.35, 0.65),
		"secondary": Color(0.18, 0.12, 0.26),
		"accent": Color(0.37, 0.88, 0.71),
		"outfit": 1,
		"headgear": 0,
	},
	{
		"name": "Jax",
		"role": "Iron Volunteer",
		"bio": "A steady volunteer who carries the heaviest plate and never complains.",
		"skin": Color(0.54, 0.35, 0.24),
		"hair": Color(0.10, 0.10, 0.10),
		"primary": Color(0.42, 0.48, 0.52),
		"secondary": Color(0.17, 0.20, 0.22),
		"accent": Color(0.88, 0.55, 0.24),
		"outfit": 2,
		"headgear": 2,
	},
	{
		"name": "Kira",
		"role": "Sunset Duelist",
		"bio": "A bold skirmisher who makes the last ten metres feel like a stage.",
		"skin": Color(0.83, 0.61, 0.45),
		"hair": Color(0.12, 0.08, 0.09),
		"primary": Color(0.79, 0.36, 0.36),
		"secondary": Color(0.29, 0.12, 0.17),
		"accent": Color(0.96, 0.76, 0.35),
		"outfit": 0,
		"headgear": 0,
	},
	{
		"name": "Lumen",
		"role": "Lab Courier",
		"bio": "A precise courier who keeps experiments, supplies and secrets moving.",
		"skin": Color(0.73, 0.49, 0.35),
		"hair": Color(0.16, 0.14, 0.13),
		"primary": Color(0.85, 0.83, 0.77),
		"secondary": Color(0.23, 0.28, 0.33),
		"accent": Color(0.30, 0.79, 0.94),
		"outfit": 1,
		"headgear": 3,
	},
	{
		"name": "Mako",
		"role": "Coastal Breacher",
		"bio": "A tide-line specialist who enters loud and leaves before the water settles.",
		"skin": Color(0.65, 0.42, 0.27),
		"hair": Color(0.09, 0.09, 0.09),
		"primary": Color(0.18, 0.36, 0.49),
		"secondary": Color(0.10, 0.17, 0.23),
		"accent": Color(0.95, 0.56, 0.23),
		"outfit": 2,
		"headgear": 1,
	},
]

static func count() -> int:
	return ROSTER.size()

static func get_character(index: int) -> Dictionary:
	return ROSTER[clampi(index, 0, ROSTER.size() - 1)]

static func outfit_name(index: int) -> String:
	return OUTFITS[clampi(index, 0, OUTFITS.size() - 1)]

static func default_appearance(index: int) -> Dictionary:
	var safe_index := clampi(index, 0, ROSTER.size() - 1)
	var character: Dictionary = ROSTER[safe_index]
	return {
		"character": safe_index,
		"primary": character["primary"],
		"secondary": character["secondary"],
		"accent": character["accent"],
		"outfit": int(character["outfit"]),
	}

## Accepts untrusted data (network/profile) and returns a complete, safe
## appearance dictionary. Colors may arrive as Color values or HTML strings.
static func sanitize(value: Dictionary) -> Dictionary:
	var safe_index := clampi(int(value.get("character", DEFAULT_INDEX)), 0, ROSTER.size() - 1)
	var character: Dictionary = ROSTER[safe_index]
	var out := default_appearance(safe_index)

	for key in ["primary", "secondary", "accent"]:
		if not value.has(key):
			continue
		var raw = value[key]
		if raw is Color:
			out[key] = _safe_color(raw)
		elif raw is String:
			var html := String(raw)
			if Color.html_is_valid(html):
				out[key] = _safe_color(Color.html(html))

	out["outfit"] = clampi(int(value.get("outfit", int(character["outfit"]))), 0, OUTFITS.size() - 1)
	return out

static func _safe_color(color: Color) -> Color:
	return Color(
		clampf(color.r, 0.0, 1.0),
		clampf(color.g, 0.0, 1.0),
		clampf(color.b, 0.0, 1.0),
		1.0
	)

## Bots use a deterministic but varied palette so a test match does not look
## like a row of identical operators.
static func bot_appearance(seed_index: int) -> Dictionary:
	var index := posmod(seed_index, ROSTER.size())
	var out := default_appearance(index)
	var hue := fmod(0.11 + float(index) * 0.173, 1.0)
	out["primary"] = Color.from_hsv(hue, 0.55, 0.78)
	out["secondary"] = Color.from_hsv(fmod(hue + 0.50, 1.0), 0.38, 0.28)
	out["accent"] = Color.from_hsv(fmod(hue + 0.12, 1.0), 0.75, 0.95)
	out["outfit"] = posmod(seed_index, OUTFITS.size())
	return out

static func load_profile() -> Dictionary:
	var cfg := ConfigFile.new()
	if cfg.load(PROFILE_PATH) != OK:
		return default_appearance(DEFAULT_INDEX)

	var index := clampi(int(cfg.get_value("operator", "character", DEFAULT_INDEX)), 0, ROSTER.size() - 1)
	var out := default_appearance(index)
	for key in ["primary", "secondary", "accent"]:
		var html := String(cfg.get_value("operator", key, ""))
		if Color.html_is_valid(html):
			out[key] = Color.html(html)
	out["outfit"] = int(cfg.get_value("operator", "outfit", out["outfit"]))
	return sanitize(out)

static func save_profile(value: Dictionary) -> void:
	var out := sanitize(value)
	var cfg := ConfigFile.new()
	cfg.set_value("operator", "character", int(out["character"]))
	cfg.set_value("operator", "primary", (out["primary"] as Color).to_html(false))
	cfg.set_value("operator", "secondary", (out["secondary"] as Color).to_html(false))
	cfg.set_value("operator", "accent", (out["accent"] as Color).to_html(false))
	cfg.set_value("operator", "outfit", int(out["outfit"]))
	cfg.save(PROFILE_PATH)
