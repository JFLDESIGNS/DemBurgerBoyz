## Modular BizPhone review writer — mix hooks/bodies/asides into intricate posts.
extends RefCounted
class_name SocialReviews

## Chance a modular post mentions the window cat.
const CAT_ASIDE_CHANCE := 0.28
## Rare "robber on the loose" beat — roughly 1–2 per busy shift.
const ROBBER_ASIDE_CHANCE := 0.055
const ROBBER_FULL_CHANCE := 0.035
## Essay sizes.
const HUGE_POST_CHANCE := 0.14
const LONG_POST_CHANCE := 0.38
const MODULAR_CHANCE := 0.62


static func generate(stars: float, kind: String, tip: int = 0) -> String:
	var s := clampf(stars, 0.0, 5.0)
	## Full robber story posts (rare, any star band except spray).
	if kind != "spray" and randf() < ROBBER_FULL_CHANCE:
		return _pick(_ROBBER_FULL)
	## Kind-specific dedicated banks still win for spray / extreme burnt hate-love.
	if kind == "spray":
		return _spray(s)
	if kind == "burnt":
		return _burnt(s)
	## Huge multi-paragraph essay.
	if randf() < HUGE_POST_CHANCE:
		return _huge(s, kind, tip)
	## Modular mix-and-match (most posts).
	if randf() < MODULAR_CHANCE:
		return _assemble_modular(s, kind, tip)
	## Classic short / medium fallback.
	if randf() < LONG_POST_CHANCE:
		return _long_classic(s, kind, tip)
	return _short_classic(s, kind, tip)


static func _assemble_modular(s: float, kind: String, tip: int) -> String:
	var parts: Array[String] = []
	parts.append(_pick(_hooks_for(s, kind)))
	if randf() < 0.82:
		parts.append(_pick(_bodies_for(s, kind)))
	if randf() < CAT_ASIDE_CHANCE:
		parts.append(_pick(_CAT_ASIDES))
	if randf() < ROBBER_ASIDE_CHANCE:
		parts.append(_pick(_ROBBER_ASIDES))
	if randf() < 0.55:
		parts.append(_pick(_vibes_for(s, kind)))
	if randf() < 0.7:
		parts.append(_pick(_closers_for(s, kind)))
	if tip > 0 and s >= 4.0 and randf() < 0.55:
		parts.append(_pick(_TIP_BITS))
	## Sometimes stitch with line breaks for "wrote a lot" energy.
	if parts.size() >= 4 and randf() < 0.35:
		var mid := mini(2, parts.size() - 1)
		var head: PackedStringArray = PackedStringArray()
		var tail: PackedStringArray = PackedStringArray()
		for i in parts.size():
			if i < mid:
				head.append(parts[i])
			else:
				tail.append(parts[i])
		return " ".join(head) + "\n\n" + " ".join(tail)
	return " ".join(PackedStringArray(parts))


static func _hooks_for(s: float, kind: String) -> Array:
	if kind == "wrong":
		return _HOOKS_WRONG
	if kind == "angry" or s <= 1.5:
		return _HOOKS_BAD
	if kind == "meh" or s < 2.75:
		return _HOOKS_MEH
	if s >= 4.5:
		return _HOOKS_GREAT
	if s >= 3.5:
		return _HOOKS_GOOD
	return _HOOKS_OK


static func _bodies_for(s: float, kind: String) -> Array:
	if kind == "wrong":
		return _BODY_WRONG
	if kind == "angry" or s <= 1.5:
		return _BODY_BAD
	if kind == "meh" or s < 2.75:
		return _BODY_MEH
	if s >= 4.5:
		return _BODY_GREAT
	if s >= 3.5:
		return _BODY_GOOD
	return _BODY_OK


static func _vibes_for(s: float, kind: String) -> Array:
	if kind == "angry" or s <= 1.5 or kind == "wrong":
		return _VIBE_BAD
	if s >= 4.0:
		return _VIBE_GREAT
	return _VIBE_MID


static func _closers_for(s: float, kind: String) -> Array:
	if kind == "angry" or s <= 1.5 or kind == "wrong":
		return _CLOSE_BAD
	if s >= 4.5:
		return _CLOSE_GREAT
	if s >= 3.5:
		return _CLOSE_GOOD
	return _CLOSE_OK


static func _pick(arr: Array) -> String:
	if arr.is_empty():
		return ""
	return str(arr[randi() % arr.size()])


static func _spray(_s: float) -> String:
	if randf() < 0.45:
		return _pick([
			"I am still shaking. Ordered a simple burger, leaned toward the window, and they blasted me with a fire extinguisher like I was a grease fire. White powder in my hair, on my jacket, in my mouth. Called my cousin. Called corporate. One star forever.",
			"Excuse me??? Your cook emptied an extinguisher THROUGH THE WINDOW onto a paying customer. I looked like a powdered donut walking back to my car. This is a health hazard and honestly traumatic. Never. Coming. Back.",
			"Long review because short ones don't cover this: arrived hungry, left covered in extinguisher dust, coughing, and embarrassed in front of the whole line. If this is the vibe at Burger Pals, close the truck. ☆",
			"Okay so there was ALSO a cat under the window watching this happen like it was theater. Cool. Extinguisher face + street-cat audience. One star, zero dignity.",
		])
	return _pick([
		"ONE STAR. They sprayed me with a fire extinguisher??",
		"Covered in white powder. Calling corporate. Never again.",
		"Got blasted by the extinguisher through the window. Disgusting.",
		"Why did they spray me?! Hair full of powder. 1 star.",
		"Health hazard. Extinguisher to the face. I'm done.",
		"Came for a burger, left looking like a powdered donut. ☆",
	])


static func _burnt(s: float) -> String:
	if s >= 3.5:
		if randf() < 0.4:
			return _assemble_modular(s, "burnt_love", 0)
		return _pick([
			"Okay hear me out — I KNOW it was burnt and I loved it. Black crust, bitter edges, smoky as hell. Leave it on the grill longer next time please. Four stars from a well-done freak.",
			"Most people will hate this but that charcoal patty slapped. Crunchy, dark, tastes like a campfire. Keep burning them. Five stars (yes I'm serious).",
			"Burnt on purpose? Don't care. I asked for well-done and this truck delivered ash in the best way. Mentioning it so the cooks know SOME of us want the puck.",
			"Burnt AF and I loved it. More please.",
			"Charcoal crust = elite. Well-done gang.",
			"Black patty slap. Don't listen to the haters.",
			"I like them burnt. Five stars honestly.",
		])
	if randf() < 0.35:
		return _assemble_modular(s, "burnt", 0)
	return _pick([
		"I asked for a burger and got a charcoal briquette with toppings. Crunchy in the worst way. One star — learn when to scoop.",
		"Burnt. Like, properly burnt. The outside was black and bitter and I still paid for it because I was starving. Never again until y'all watch the grill.",
		"Long review for a short meal: perfect ticket build, absolute ash patty. Matching the order doesn't fix serving hockey pucks. One star.",
		"Burnt hockey puck. One star.",
		"Charcoal with cheese. Gross.",
		"That patty was BLACK. No thanks.",
		"Burnt meat. Fix your grill timing.",
		"Tasted like ash. Never again.",
	])


static func _huge(s: float, kind: String, tip: int) -> String:
	var cat := _pick(_CAT_ASIDES) if randf() < 0.55 else ""
	var robber := _pick(_ROBBER_ASIDES) if randf() < 0.25 else ""
	var tip_bit := _pick(_TIP_BITS) if tip > 0 and s >= 4.0 else ""
	if kind == "wrong" or s <= 1.5:
		return "\n\n".join([
			"I need to write this down while I'm still mad so I don't soften it later.",
			_pick(_BODY_BAD) + " " + _pick(_BODY_WRONG if kind == "wrong" else _VIBE_BAD),
			(cat + " " if cat != "" else "") + (robber if robber != "" else "The whole window vibe felt chaotic in a bad way."),
			_pick(_CLOSE_BAD),
		]).strip_edges()
	if s >= 4.5:
		return "\n\n".join([
			"Okay I sat in my car for five minutes because I had to process that burger properly.",
			_pick(_BODY_GREAT) + " " + _pick(_VIBE_GREAT),
			(cat if cat != "" else "There was this little street energy under the window that somehow made it feel like a neighborhood spot, not a chain."),
			(robber + "\n\n" if robber != "" else "") + _pick(_CLOSE_GREAT) + (" " + tip_bit if tip_bit != "" else ""),
		]).strip_edges()
	if s >= 3.5:
		return "\n\n".join([
			"Not a short review person — here's the honest version.",
			_pick(_BODY_GOOD),
			(cat if cat != "" else _pick(_VIBE_MID)),
			_pick(_CLOSE_GOOD),
		]).strip_edges()
	return "\n\n".join([
		"Trying to be fair here, not dramatic.",
		_pick(_BODY_OK if s >= 2.75 else _BODY_MEH),
		(cat if cat != "" else _pick(_VIBE_MID)),
		_pick(_CLOSE_OK),
	]).strip_edges()


static func _long_classic(s: float, kind: String, tip: int) -> String:
	if kind == "wrong":
		return _pick(_LONG_WRONG)
	if kind == "angry" or s <= 1.5:
		return _pick(_LONG_BAD)
	if kind == "meh" or s < 2.75:
		return _pick(_LONG_MEH)
	if s >= 4.5:
		var essays: Array = _LONG_GREAT.duplicate()
		if tip > 0:
			essays.append(
				"Tipped hard on purpose. Service was sharp, burger was perfect, and I want this truck to stay parked in my neighborhood forever. Best smash I've had in ages — thank you cooks."
			)
		return _pick(essays)
	if s >= 3.5:
		return _pick(_LONG_GOOD)
	return _pick(_LONG_OK)


static func _short_classic(s: float, kind: String, tip: int) -> String:
	if kind == "wrong":
		return _pick(_SHORT_WRONG)
	if kind == "angry" or s <= 1.5:
		return _pick(_SHORT_BAD)
	if kind == "meh" or s < 2.75:
		return _pick(_SHORT_MEH)
	if s >= 4.5:
		var lines: Array = _SHORT_GREAT.duplicate()
		if tip > 0:
			lines.append("Tipped hard. They earned it.")
		return _pick(lines)
	if s >= 3.5:
		return _pick(_SHORT_GOOD)
	return _pick(_SHORT_OK)


## --- Modular piece banks -------------------------------------------------------

const _HOOKS_GREAT: Array = [
	"Okay I need to write a real review.",
	"Stop scrolling — this truck slapped.",
	"Rare food-truck W.",
	"I wasn't going to post but that first bite forced my hand.",
	"Burger Pals just ruined other smash burgers for me.",
	"Came skeptical, left evangelical.",
]
const _HOOKS_GOOD: Array = [
	"Solid lunch, honest take:",
	"Pretty good truck night.",
	"Would order again without drama.",
	"Not life-changing, still glad I stopped.",
	"Quick review because it earned one.",
]
const _HOOKS_OK: Array = [
	"Three-star energy:",
	"Mixed bag, keeping it real.",
	"Fine. Not mad. Not obsessed.",
	"Alright burger with caveats.",
]
const _HOOKS_MEH: Array = [
	"Came in hopeful, left shrugging.",
	"Edible is the nicest word I've got.",
	"Expected more from the cute logo.",
	"Seasoning optional, apparently.",
]
const _HOOKS_BAD: Array = [
	"Worst window experience this month.",
	"Writing this so nobody else wastes a lunch break.",
	"Still mad in the parking lot.",
	"One star and I'm telling the neighborhood chat.",
]
const _HOOKS_WRONG: Array = [
	"Wrong burger. Like, fully wrong.",
	"Ticket said one thing. Window handed me another.",
	"Order mix-up with confidence, somehow.",
]

const _BODY_GREAT: Array = [
	"Patty had that loud crust, cheese melted properly, stack stayed hot through the window.",
	"Juicy smash, clean build, no soggy bun disaster.",
	"They matched my ticket and still somehow made it feel special.",
	"Grill smell alone sold me, then the burger backed it up.",
	"Fast without feeling rushed — cook knew what they were doing.",
]
const _BODY_GOOD: Array = [
	"Fresh toppings, hot patty, didn't mess up the order.",
	"Wait was fine, burger hit the spot, crew kept the line moving.",
	"Good crust, decent melt, nothing weird in the stack.",
	"Tasted like a real smash truck, not a microwave impersonation.",
]
const _BODY_OK: Array = [
	"Got my food, it was fine, service was fine, nothing wild.",
	"Room to grow on seasoning and speed, but I wasn't robbed.",
	"Decent for a truck stop — just not a destination yet.",
]
const _BODY_MEH: Array = [
	"Bun was fine, meat was okay, flavor took a nap.",
	"Needed salt, love, and maybe a manager tasting the line.",
	"Wouldn't drive across town for it again unless they tighten the cook.",
]
const _BODY_BAD: Array = [
	"Stood there forever watching the same patty flip while my stomach filed a complaint.",
	"Slow service, cold attitude, walked away hungrier than I arrived.",
	"Felt like they forgot customers exist until I was already leaving.",
]
const _BODY_WRONG: Array = [
	"Had to explain the ticket twice like it was a courtroom exhibit.",
	"Wrong toppings, wrong vibe, shrugged at me through the glass.",
	"If you can't match an order, the whole truck falls apart.",
]

const _VIBE_GREAT: Array = [
	"Window energy was friendly without being fake.",
	"Felt like a neighborhood spot that accidentally went viral.",
	"The kind of truck you text a photo of before you take a bite.",
]
const _VIBE_MID: Array = [
	"Vibe was chill, not chaotic.",
	"Nothing weird happened, which is rarer than it should be.",
	"Line moved okay for a lunch rush.",
]
const _VIBE_BAD: Array = [
	"Whole interaction felt dismissive.",
	"Chaotic in the annoying way, not the fun way.",
	"Left with main-character rage and zero fries of comfort.",
]

const _CLOSE_GREAT: Array = [
	"Instant favorite. Bringing my whole group next shift.",
	"Five stars isn't enough. Tell them a loud person on the internet sent you.",
	"Burger Pals forever. Already plotting the next order.",
	"If you're on the fence — just go.",
]
const _CLOSE_GOOD: Array = [
	"I'd happily come back on a lunch break.",
	"Recommend to a friend who likes smash burgers.",
	"Leaving stars because short reviews never capture 'yeah I'd reorder.'",
]
const _CLOSE_OK: Array = [
	"If they tighten the cook, they'll earn a fourth star from me.",
	"Decent. Room to grow.",
	"Not a disaster, not a revelation.",
]
const _CLOSE_BAD: Array = [
	"Blocking this place and moving on.",
	"Fix the window or don't open it.",
	"One star. Do better.",
	"Never again until something changes.",
]

const _TIP_BITS: Array = [
	"Tipped hard on purpose — keep the truck alive.",
	"Left extra because that cook earned it.",
	"Tip was a thank-you, not pity.",
]

const _CAT_ASIDES: Array = [
	"Also there's a street cat living under the window who absolutely runs that sidewalk like a manager.",
	"Side note: the window cat locked eyes with me the whole time I ate. Felt judged. Felt correct.",
	"Fed the black cat under the sill a scrap (don't @ me) and it did a little happy dance. Ten out of ten mascot.",
	"The cat under the truck is the real VIP. Burger was good; cat lore is elite.",
	"Watched a chunky street cat peek up like it was inspecting health code. Iconic.",
	"Someone needs to put that window cat on the logo. It already has better branding than half the city trucks.",
	"Between bites I pet the cat under the window — soft, dramatic, slightly sticky from street life. Wholesome chaos.",
	"The cat stole focus. I came for smash, stayed for the tiny fur security guard.",
	"Pro tip: if the cat under the window looks smug, the burger is about to slap.",
	"Lowkey think the cooks feed that cat on purpose. Unionized mascot energy.",
]

const _ROBBER_ASIDES: Array = [
	"Wild aside — someone in line kept whispering there's a robber on the loose near the strip? Cool lunch atmosphere.",
	"Heard two people arguing about a robber on the loose while I waited. Great. Love that for my nervous system.",
	"Not the burger's fault, but the 'robber on the loose' chatter from the sidewalk did NOT help my appetite.",
]

const _ROBBER_FULL: Array = [
	"Okay this is only half about the burger. While I was in line somebody said there's a robber on the loose around here and half the sidewalk went quiet. I still got my food (it was fine), but I ate it in the car with the doors locked like a sitcom. Stars for the smash. Zero stars for the crime-podcast ambiance.",
	"Review of the truck AND the neighborhood: burger arrived hot, toppings matched, cooks were hustling — AND two strangers were comparing notes about a robber on the loose like it was weather. I tipped anyway. Please hire that window cat as security.",
]

const _LONG_GREAT: Array = [
	"Okay I need to write a real review because this smashed me (pun intended). Patty had the perfect crust, cheese melted like a dream, and they handed it over hot without making me wait forever. Instant favorite. I'm bringing my whole group next shift.",
	"Five stars isn't enough. I watched them cook it, smelled the grill, and the first bite actually made me stop talking mid-sentence. Fast, hot, ridiculous flavor. If you're on the fence — just go. Tell them a loud person on the internet sent you.",
	"Rare that a truck lives up to the hype but this one does. Clean window, solid stack, juicy meat, and they actually seemed happy to serve. Already plotting my next order. Burger Pals forever.",
	"Wrote this like a diary entry because short reviews feel dishonest. The smash had bark and juice, the stack didn't collapse, and the window crew treated me like a person not a ticket printer. Also the street cat under the sill winked at me (probably). Returning.",
]
const _LONG_GOOD: Array = [
	"Really solid overall — fresh toppings, hot patty, didn't mess up my order. Not quite life-changing but I'd happily come back on a lunch break and recommend it to a friend who likes smash burgers.",
	"Pretty good truck night. Wait wasn't bad, burger hit the spot, and the window crew kept it moving. Leaving a longer note because short reviews never capture that 'yeah I'd order this again' feeling.",
]
const _LONG_OK: Array = [
	"Three-star energy: got my food, it was fine, service was fine, nothing wild. Room to grow on seasoning and speed but I wasn't mad about spending the money. Decent for a truck stop.",
	"Alright burger with a side of 'could be better.' Not a disaster, not a revelation. If they tighten the cook and keep the line moving, they'll earn the fourth star from me next time.",
]
const _LONG_MEH: Array = [
	"It's edible, I'll give them that, but the patty was bland and the whole thing tasted like it needed salt, love, and maybe a manager. Not angry enough for one star — just… meh. Expected more from a smash-burger truck with a cute logo.",
	"Came in hopeful, left shrugging. Bun was fine, meat was okay, seasoning was optional apparently. Wouldn't drive across town for it again unless they tighten up the cook.",
]
const _LONG_BAD: Array = [
	"Stood there forever watching them flip the same patty while my stomach growled. Nobody acknowledged me, the line didn't move, and when I finally left I was hungrier and angrier than when I showed up. One star and I'm telling the neighborhood group chat.",
	"Worst food-truck experience I've had all year. Slow service, cold attitude, and I walked away with nothing. If you can't run a window, don't open the window. Blocking this place and moving on.",
	"I wanted to give them a chance but the wait was ridiculous and the whole vibe felt like they forgot customers exist. Left hungry, left mad, leaving this review so nobody else wastes their lunch break here.",
]
const _LONG_WRONG: Array = [
	"I ordered exactly what was on my ticket and somehow got a totally different stack. Had to explain it twice through the window while they looked confused. Not trying to be dramatic but if you can't match an order, the whole truck falls apart. Disappointed.",
	"Wrong burger, wrong toppings, wrong everything. I held up the ticket like a courtroom exhibit and still got shrugged at. Fix your build board before you take more customers. Two stars is generous.",
]

const _SHORT_GREAT: Array = [
	"Insane burger. Instant favorite.",
	"Five stars. That patty was perfect.",
	"I'm telling everyone about this truck.",
	"Best smash burger I've had in ages.",
	"Fast, hot, delicious. Obsessed.",
	"Window cat approved. So do I.",
]
const _SHORT_GOOD: Array = [
	"Solid burger, would order again.",
	"Pretty good! Fresh and hot.",
	"Nice job — tasty stack.",
	"Hit the spot. Happy customer.",
]
const _SHORT_OK: Array = [
	"Decent. Not bad for a truck.",
	"Alright burger. Room to grow.",
	"Three stars. Service was fine.",
	"Got my order. It was okay.",
]
const _SHORT_MEH: Array = [
	"Burger was… fine. Bland though.",
	"Edible. Seasoning optional apparently.",
	"Meh. Expected more from a food truck.",
	"Okay burger. Nothing to shout about.",
]
const _SHORT_BAD: Array = [
	"Walked out. Never coming back.",
	"Waited forever. Absolute joke.",
	"One star. Do better.",
	"Left hungry and mad. Fix your service.",
	"Trash experience. Blocking this place.",
]
const _SHORT_WRONG: Array = [
	"Wrong order?? Come on.",
	"That wasn't what I asked for.",
	"They served me something else entirely.",
	"Order mix-up. Not impressed.",
]
