## Shared game data: ingredients, order generation, scoring.
class_name GameData
extends RefCounted

const INGREDIENT_LABELS := {
	"bun_bottom": "Bottom Bun",
	"patty": "Patty",
	"cheese": "Cheese",
	"lettuce": "Lettuce",
	"tomato": "Tomato",
	"onion": "Onion",
	"bacon": "Bacon",
	"pickle": "Pickle",
	"ketchup": "Ketchup",
	"mustard": "Mustard",
	"bun_top": "Top Bun",
}

const INGREDIENT_COLORS := {
	"bun_bottom": Color("D4924A"),
	"patty": Color("6B3A2A"),
	"cheese": Color("F4C430"),
	"lettuce": Color("4CAF50"),
	"tomato": Color("E53935"),
	"onion": Color("CE93D8"),
	"bacon": Color("C62828"),
	"pickle": Color("7CB342"),
	"ketchup": Color("D32F2F"),
	"mustard": Color("F9A825"),
	"bun_top": Color("E8A85C"),
}

const EXTRA_TOPPINGS := ["cheese", "tomato", "lettuce", "onion", "pickle", "bacon", "ketchup", "mustard"]

## Always the same stack order on tickets (and when normalizing builds).
## Cheese first, then toppings right→left toward the buns.
const TOPPING_ORDER: Array[String] = [
	"cheese",
	"tomato",
	"lettuce",
	"onion",
	"pickle",
	"bacon",
	"ketchup",
	"mustard",
]

const CUSTOMER_COLORS := [
	Color("FF6B6B"),
	Color("4ECDC4"),
	Color("FFE66D"),
	Color("95E1D3"),
	Color("F38181"),
	Color("AA96DA"),
	Color("FCBAD3"),
	Color("A8D8EA"),
	Color("FF9F43"),
	Color("00D2D3"),
]


static func topping_sort_key(id: String) -> int:
	var i := TOPPING_ORDER.find(id)
	return i if i >= 0 else 100


static func sort_toppings(ids: Array) -> Array:
	var copy: Array = ids.duplicate()
	copy.sort_custom(func(a, b): return topping_sort_key(str(a)) < topping_sort_key(str(b)))
	return copy


static func generate_order(difficulty: float = 0.0) -> Array[String]:
	var order: Array[String] = ["bun_bottom", "patty"]
	## Some orders ask for a double patty.
	if difficulty >= 0.15 and randf() < 0.2 + difficulty * 0.35:
		order.append("patty")
	var pool := EXTRA_TOPPINGS.duplicate()
	pool.shuffle()
	var count := clampi(2 + int(difficulty * 2.5) + randi_range(0, 2), 2, 6)
	var picked: Array = []
	for i in count:
		if pool.is_empty():
			break
		picked.append(pool.pop_front())
	## Tickets always list toppings in the same kitchen order.
	order.append_array(sort_toppings(picked))
	order.append("bun_top")
	return order


static func order_value(order: Array) -> int:
	return 4 + order.size()


static func compare_orders(built: Array, requested: Array) -> Dictionary:
	if built.is_empty():
		return {"quality": 0.0, "perfect": false, "missing": requested.duplicate(), "extra": []}

	var req_counts := {}
	var built_counts := {}
	for item in requested:
		req_counts[item] = req_counts.get(item, 0) + 1
	for item in built:
		built_counts[item] = built_counts.get(item, 0) + 1

	var matched := 0
	var total := 0
	var missing: Array = []
	var extra: Array = []

	for item in req_counts:
		total += req_counts[item]
		var have: int = built_counts.get(item, 0)
		matched += mini(have, req_counts[item])
		if have < req_counts[item]:
			for _i in range(req_counts[item] - have):
				missing.append(item)

	for item in built_counts:
		var need: int = req_counts.get(item, 0)
		if built_counts[item] > need:
			for _i in range(built_counts[item] - need):
				extra.append(item)

	var quality := 0.0 if total == 0 else float(matched) / float(total)
	if not extra.is_empty():
		quality *= 0.85
	if built.size() >= 2 and built[0] == "bun_bottom" and built[built.size() - 1] == "bun_top":
		quality = minf(1.0, quality + 0.05)
	var perfect := missing.is_empty() and extra.is_empty() and built.size() == requested.size()
	if perfect:
		perfect = built == requested or _soft_order_match(built, requested)
	return {"quality": quality, "perfect": perfect, "missing": missing, "extra": extra}


static func _soft_order_match(built: Array, requested: Array) -> bool:
	## Same ingredients in canonical kitchen order counts as perfect.
	if built.size() != requested.size():
		return false
	return _canonical_items(built) == _canonical_items(requested)


static func _canonical_items(items: Array) -> Array:
	var bottoms: Array = []
	var patties: Array = []
	var middles: Array = []
	var tops: Array = []
	for item in items:
		match str(item):
			"bun_bottom":
				bottoms.append(item)
			"patty":
				patties.append(item)
			"bun_top":
				tops.append(item)
			_:
				middles.append(item)
	middles = sort_toppings(middles)
	var out: Array = []
	out.append_array(bottoms)
	out.append_array(patties)
	out.append_array(middles)
	out.append_array(tops)
	return out
