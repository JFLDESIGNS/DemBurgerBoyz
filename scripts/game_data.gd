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
	"soda_cola": "Cola",
	"soda_lemon_lime": "Lime Soda",
	"soda_orange": "Orange Soda",
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
	"soda_cola": Color("5D2A1A"),
	"soda_lemon_lime": Color("7CB342"),
	"soda_orange": Color("F57C00"),
}

const EXTRA_TOPPINGS := ["cheese", "tomato", "lettuce", "onion", "pickle", "bacon", "ketchup", "mustard"]
const SODA_ORDER_IDS: Array[String] = ["soda_cola", "soda_lemon_lime", "soda_orange"]
const SODA_ONLY_CHANCE := 0.08
const SODA_WITH_BURGER_CHANCE := 0.30

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


static func is_soda_item(id: String) -> bool:
	return str(id).begins_with("soda_")


static func soda_flavor_from_order_id(id: String) -> String:
	## "soda_cola" → "cola", "soda_lemon_lime" → "lemon_lime"
	var s := str(id)
	if s.begins_with("soda_"):
		return s.substr(5)
	return ""


static func order_soda_ids(order: Array) -> Array:
	var out: Array = []
	for item in order:
		if is_soda_item(str(item)):
			out.append(str(item))
	return out


static func order_burger_items(order: Array) -> Array:
	var out: Array = []
	for item in order:
		if not is_soda_item(str(item)):
			out.append(item)
	return out


static func is_soda_only_order(order: Array) -> bool:
	if order.is_empty():
		return false
	for item in order:
		if not is_soda_item(str(item)):
			return false
	return true


static func random_soda_order_id() -> String:
	return SODA_ORDER_IDS[randi() % SODA_ORDER_IDS.size()]


static func generate_order(difficulty: float = 0.0) -> Array[String]:
	## Occasional drink-only ticket.
	if randf() < SODA_ONLY_CHANCE:
		return [random_soda_order_id()] as Array[String]
	var order: Array[String] = ["bun_bottom", "patty"]
	## Once in a while: plain patty or ketchup only — no other toppings.
	const MINIMAL_CHANCE := 0.12
	if randf() < MINIMAL_CHANCE:
		if randf() < 0.5:
			order.append("bun_top")
		else:
			order.append("ketchup")
			order.append("bun_top")
	else:
		## Some orders ask for a double patty.
		if difficulty >= 0.15 and randf() < 0.2 + difficulty * 0.35:
			order.append("patty")
		var picked: Array = []
		## Some tickets just say EVERYTHING — every topping on the strip.
		var everything_chance := 0.10 + difficulty * 0.18
		if randf() < everything_chance:
			picked = EXTRA_TOPPINGS.duplicate()
		else:
			var pool := EXTRA_TOPPINGS.duplicate()
			pool.shuffle()
			var count := clampi(2 + int(difficulty * 2.5) + randi_range(0, 2), 2, 6)
			for i in count:
				if pool.is_empty():
					break
				picked.append(pool.pop_front())
		## Tickets always list toppings in the same kitchen order.
		order.append_array(sort_toppings(picked))
		order.append("bun_top")
	## Chance the burger comes with a fountain drink.
	var soda_chance := SODA_WITH_BURGER_CHANCE + difficulty * 0.12
	if randf() < soda_chance:
		order.append(random_soda_order_id())
	return order


static func is_everything_order(order: Array) -> bool:
	var burger := order_burger_items(order)
	for t in EXTRA_TOPPINGS:
		if not burger.has(t):
			return false
	return true


static func is_plain_patty_order(order: Array) -> bool:
	## Bottom bun + one patty + top bun — nothing else (soda side ok).
	var burger := order_burger_items(order)
	return burger.size() == 3 \
		and burger[0] == "bun_bottom" \
		and burger[1] == "patty" \
		and burger[2] == "bun_top"


## Strip hotkey digits for toppings on the ticket (1 tomato … 7 mustard).
## Cheese is grabbed from the board wheel — shown as "C" when ordered.
## Everything → "C1234567"; ketchup only → "6"; plain → "".
static func order_number_code(order: Array) -> String:
	const STRIP := ["tomato", "lettuce", "onion", "pickle", "bacon", "ketchup", "mustard"]
	const DIGITS := ["1", "2", "3", "4", "5", "6", "7"]
	var burger := order_burger_items(order)
	var code := ""
	if burger.has("cheese"):
		code += "C"
	for i in STRIP.size():
		if burger.has(STRIP[i]):
			code += DIGITS[i]
	return code


static func order_value(order: Array) -> int:
	var burger := order_burger_items(order)
	var sodas := order_soda_ids(order)
	var base := 0
	if not burger.is_empty():
		base += 4 + burger.size()
		if is_everything_order(order):
			base += 3
	base += sodas.size() * 3
	return maxi(base, 3)


static func compare_orders(built: Array, requested: Array) -> Dictionary:
	## Burger layers only — soda is checked separately against the cup.
	var req_burger := order_burger_items(requested)
	var built_burger := order_burger_items(built)
	if req_burger.is_empty():
		## Drink-only ticket — burger side is vacuously perfect.
		return {"quality": 1.0, "perfect": true, "missing": [], "extra": []}
	if built_burger.is_empty():
		return {"quality": 0.0, "perfect": false, "missing": req_burger.duplicate(), "extra": []}

	var req_counts := {}
	var built_counts := {}
	for item in req_burger:
		req_counts[item] = req_counts.get(item, 0) + 1
	for item in built_burger:
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
	if built_burger.size() >= 2 and built_burger[0] == "bun_bottom" and built_burger[built_burger.size() - 1] == "bun_top":
		quality = minf(1.0, quality + 0.05)
	var perfect := missing.is_empty() and extra.is_empty() and built_burger.size() == req_burger.size()
	if perfect:
		perfect = built_burger == req_burger or _soft_order_match(built_burger, req_burger)
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
