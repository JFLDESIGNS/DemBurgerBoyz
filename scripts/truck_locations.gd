## Food-truck parking spots across the city.
## Difficulty changes customer rate + patience later — gameplay/kitchen stay the same.
extends RefCounted

const TIER_EASY := "easy"
const TIER_MEDIUM := "medium"
const TIER_HARD := "hard"
const TIER_EXTREME := "extreme"

const DEFAULT_ID := "night_market_peak"

## Tier → UI color for pins / badges.
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

## Multipliers applied when location logic is wired up.
## spawn_rate: higher = customers arrive more often (shorter delays).
## patience: lower = customers wait less before leaving.
## customer_cap_bonus: extra simultaneous customers on top of day caps.
const TIER_STATS := {
	TIER_EASY: {"spawn_rate": 0.85, "patience": 1.20, "customer_cap_bonus": 0},
	TIER_MEDIUM: {"spawn_rate": 1.15, "patience": 0.95, "customer_cap_bonus": 0},
	TIER_HARD: {"spawn_rate": 1.55, "patience": 0.70, "customer_cap_bonus": 1},
	TIER_EXTREME: {"spawn_rate": 2.10, "patience": 0.50, "customer_cap_bonus": 2},
}

## id, display name, blurb, tier, normalized map UV (0–1) on town_map.png building footprints.
## UVs aim at building centers / park fountain — not road asphalt.
const LOCATIONS: Array[Dictionary] = [
	## --- Easy (5) ---
	{
		"id": "quiet_park",
		"name": "Quiet Park",
		"blurb": "Shade, joggers, and the occasional picnic. Gentle starter spot.",
		"tier": TIER_EASY,
		"map": Vector2(0.14, 0.76), ## PARKS fountain
		"bg": "",
	},
	{
		"id": "suburb_lane",
		"name": "Suburb Lane",
		"blurb": "Cul-de-sac cookouts. Neighbors wander over when they smell the grill.",
		"tier": TIER_EASY,
		"map": Vector2(0.88, 0.80), ## Bottom-right red-roof house
		"bg": "",
	},
	{
		"id": "library_lot",
		"name": "Library Lot",
		"blurb": "Study-break snacks. Polite line, plenty of time to plate.",
		"tier": TIER_EASY,
		"map": Vector2(0.16, 0.44), ## Middle-left grey office
		"bg": "",
	},
	{
		"id": "community_garden",
		"name": "Community Garden",
		"blurb": "Gardeners and kids on bikes. Slow afternoon traffic.",
		"tier": TIER_EASY,
		"map": Vector2(0.20, 0.84), ## Park gazebo / benches
		"bg": "",
	},
	{
		"id": "residential_court",
		"name": "Residential Court",
		"blurb": "Apartment courtyard. Friendly regulars, low pressure.",
		"tier": TIER_EASY,
		"map": Vector2(0.18, 0.17), ## Top-left patio buildings
		"bg": "",
	},
	## --- Medium (5) ---
	{
		"id": "downtown_corner",
		"name": "Downtown Corner",
		"blurb": "Sidewalk hustle. Lunch rush keeps you honest.",
		"tier": TIER_MEDIUM,
		"map": Vector2(0.53, 0.44), ## DOWNTOWN building
		"bg": "",
	},
	{
		"id": "office_plaza",
		"name": "Office Plaza",
		"blurb": "Cubicle escapees on the clock. Tickets stack mid-day.",
		"tier": TIER_MEDIUM,
		"map": Vector2(0.38, 0.16), ## Top mid-left commercial
		"bg": "",
	},
	{
		"id": "shopping_strip",
		"name": "Shopping Strip",
		"blurb": "Bag bags and window shoppers. Steady flow all shift.",
		"tier": TIER_MEDIUM,
		"map": Vector2(0.33, 0.79), ## Bottom mid-left red-roof shop
		"bg": "",
	},
	{
		"id": "transit_stop",
		"name": "Transit Stop",
		"blurb": "Bus arrivals dump hungry riders. Pace picks up.",
		"tier": TIER_MEDIUM,
		"map": Vector2(0.80, 0.46), ## Middle-right shops
		"bg": "",
	},
	{
		"id": "market_edge",
		"name": "Market Edge",
		"blurb": "Farmers-market spillover. Crowds pulse in waves.",
		"tier": TIER_MEDIUM,
		"map": Vector2(0.22, 0.48), ## Pink cafe / bakery
		"bg": "",
	},
	## --- Hard (3) ---
	{
		"id": "stadium_tailgate",
		"name": "Stadium Tailgate",
		"blurb": "Pre-game frenzy. Long lines, short tempers.",
		"tier": TIER_HARD,
		"map": Vector2(0.64, 0.12), ## STADIUM roof
		"bg": "",
	},
	{
		"id": "festival_midway",
		"name": "Festival Midway",
		"blurb": "Lights, music, and hungry festival-goers nonstop.",
		"tier": TIER_HARD,
		"map": Vector2(0.88, 0.17), ## Far top-right brick shops
		"bg": "",
	},
	{
		"id": "mall_exterior",
		"name": "Mall Exterior",
		"blurb": "Food-court overflow. Everyone wants it yesterday.",
		"tier": TIER_HARD,
		"map": Vector2(0.68, 0.68), ## MALL building (above parking)
		"bg": "",
	},
	## --- Very hard (2) ---
	{
		"id": "city_center_rush",
		"name": "City Center Rush",
		"blurb": "Heart of downtown at peak hour. Wall of tickets.",
		"tier": TIER_EXTREME,
		"map": Vector2(0.55, 0.42), ## Downtown upper facade
		"bg": "",
	},
	{
		"id": "night_market_peak",
		"name": "Night Market Peak",
		"blurb": "Neon chaos. Packed aisle, zero patience.",
		"tier": TIER_EXTREME,
		"map": Vector2(0.85, 0.42), ## Colorful mid-right block
		"bg": "",
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
	var tier := tier_of(id)
	return (TIER_STATS.get(tier, TIER_STATS[TIER_EASY]) as Dictionary).duplicate()


static func display_name(id: String) -> String:
	return str(get_by_id(id).get("name", "Unknown Spot"))


static func background_path(id: String) -> String:
	## Empty until per-location mattes exist — callers fall back to the default street.
	return str(get_by_id(id).get("bg", ""))
