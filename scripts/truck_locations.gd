## The five-stop food-truck route. Location, not day number, owns difficulty.
extends RefCounted

const TIER_EASY := "easy"
const TIER_MEDIUM := "medium"
const TIER_HARD := "hard"
const TIER_EXTREME := "extreme"

const DEFAULT_ID := "riverside_park"

const TIER_COLORS := {
	TIER_EASY: Color(0.42, 0.82, 0.48),
	TIER_MEDIUM: Color(1.0, 0.78, 0.28),
	TIER_HARD: Color(1.0, 0.48, 0.22),
	TIER_EXTREME: Color(0.95, 0.28, 0.42),
}

const TIER_LABELS := {
	TIER_EASY: "EASY",
	TIER_MEDIUM: "MEDIUM",
	TIER_HARD: "HARD",
	TIER_EXTREME: "VERY HARD",
}

## Defaults keep older callers safe. Every stop below supplies exact tuning.
const TIER_STATS := {
	TIER_EASY: {"spawn_rate": 0.85, "patience": 1.20, "customer_cap_bonus": 0},
	TIER_MEDIUM: {"spawn_rate": 1.15, "patience": 0.95, "customer_cap_bonus": 0},
	TIER_HARD: {"spawn_rate": 1.55, "patience": 0.70, "customer_cap_bonus": 1},
	TIER_EXTREME: {"spawn_rate": 2.10, "patience": 0.50, "customer_cap_bonus": 2},
}

## order_base + order_ramp drive recipe complexity over one shift; there is no day boost.
const LOCATIONS: Array[Dictionary] = [
	{
		"id": "riverside_park", "name": "Riverside Park",
		"blurb": "A relaxed first stop with patient walkers and a one-ticket line.",
		"tier": TIER_EASY, "rank": 1, "map": Vector2(0.14, 0.76),
		"bg": "res://assets/bg/street_window.png",
		"first_delay": 18.0, "spawn_start": 25.0, "spawn_end": 15.0, "spawn_jitter": 4.0,
		"customer_cap": 1, "patience_base": 92.0, "patience_jitter": 6.0,
		"order_base": 0.00, "order_ramp": 0.25,
	},
	{
		"id": "market_street", "name": "Market Street",
		"blurb": "A steady shopping crowd. Two orders can stack during the lunch wave.",
		"tier": TIER_MEDIUM, "rank": 2, "map": Vector2(0.22, 0.48),
		"bg": "res://IMAGES/location1.png",
		"first_delay": 14.0, "spawn_start": 18.0, "spawn_end": 10.0, "spawn_jitter": 3.0,
		"customer_cap": 2, "patience_base": 78.0, "patience_jitter": 5.0,
		"order_base": 0.18, "order_ramp": 0.28,
	},
	{
		"id": "old_town_shops", "name": "Old Town Shops",
		"blurb": "Tourists arrive in groups and ask for more complicated burgers.",
		"tier": TIER_MEDIUM, "rank": 3, "map": Vector2(0.80, 0.46),
		"bg": "res://assets/bg/street_preview_storefront.png",
		"first_delay": 11.0, "spawn_start": 14.0, "spawn_end": 7.5, "spawn_jitter": 2.5,
		"customer_cap": 3, "patience_base": 66.0, "patience_jitter": 5.0,
		"order_base": 0.34, "order_ramp": 0.31,
	},
	{
		"id": "downtown_row", "name": "Downtown Row",
		"blurb": "Office rush: a full line, shorter patience, and demanding tickets.",
		"tier": TIER_HARD, "rank": 4, "map": Vector2(0.53, 0.44),
		"bg": "res://assets/backgrounds/pixel_palace_street.png",
		"first_delay": 8.0, "spawn_start": 10.0, "spawn_end": 5.0, "spawn_jitter": 1.8,
		"customer_cap": 4, "patience_base": 54.0, "patience_jitter": 4.0,
		"order_base": 0.53, "order_ramp": 0.32,
	},
	{
		"id": "city_center_peak", "name": "City Center Peak",
		"blurb": "The final stop. Peak crowds, complex orders, and almost no breathing room.",
		"tier": TIER_EXTREME, "rank": 5, "map": Vector2(0.64, 0.12),
		"bg": "res://assets/backgrounds/pixel_palace_festival.png",
		"first_delay": 5.0, "spawn_start": 7.0, "spawn_end": 3.2, "spawn_jitter": 1.2,
		"customer_cap": 4, "patience_base": 43.0, "patience_jitter": 3.0,
		"order_base": 0.70, "order_ramp": 0.30,
	},
]


static func all() -> Array[Dictionary]:
	return LOCATIONS


static func get_by_id(id: String) -> Dictionary:
	for loc in LOCATIONS:
		if str(loc.get("id", "")) == id:
			return loc
	return LOCATIONS[0] if not LOCATIONS.is_empty() else {}


static func tier_of(id: String) -> String:
	return str(get_by_id(id).get("tier", TIER_EASY))


static func tier_color(tier: String) -> Color:
	return TIER_COLORS.get(tier, TIER_COLORS[TIER_EASY]) as Color


static func tier_label(tier: String) -> String:
	return str(TIER_LABELS.get(tier, tier.to_upper()))


static func stats_for(id: String) -> Dictionary:
	var loc := get_by_id(id)
	var tier := str(loc.get("tier", TIER_EASY))
	var stats := (TIER_STATS.get(tier, TIER_STATS[TIER_EASY]) as Dictionary).duplicate()
	for key in [
		"rank", "first_delay", "spawn_start", "spawn_end", "spawn_jitter",
		"customer_cap", "patience_base", "patience_jitter", "order_base", "order_ramp"
	]:
		if loc.has(key):
			stats[key] = loc[key]
	return stats


static func display_name(id: String) -> String:
	return str(get_by_id(id).get("name", "Unknown Spot"))


static func rank_of(id: String) -> int:
	return int(get_by_id(id).get("rank", 1))


static func background_path(id: String) -> String:
	return str(get_by_id(id).get("bg", ""))
