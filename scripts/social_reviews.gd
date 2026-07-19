## Modular BizPhone review writer — huge phrase banks + combo assembly for thousands of unique posts.
extends RefCounted
class_name SocialReviews

const CAT_ASIDE_CHANCE := 0.22
const ROBBER_ASIDE_CHANCE := 0.05
const ROBBER_FULL_CHANCE := 0.03
const HUGE_POST_CHANCE := 0.10
const ONE_WORD_CHANCE := 0.16
const ULTRA_SHORT_CHANCE := 0.28
const MODULAR_CHANCE := 0.70
const RECENT_MAX := 64

static var _recent: Array[String] = []


static func generate(stars: float, kind: String, tip: int = 0) -> String:
	var s := clampf(stars, 0.0, 5.0)
	if kind == "cat_burnt":
		return _remember(_cat_burnt())
	if kind != "spray" and randf() < ROBBER_FULL_CHANCE:
		return _remember(_pick(_ROBBER_FULL))
	if kind == "spray":
		return _remember(_spray(s))
	if kind == "burnt":
		return _remember(_burnt(s))
	## One-word / ultra-short — common on real feeds.
	if kind != "wrong" and randf() < ONE_WORD_CHANCE:
		return _remember(_one_word(s, kind))
	if randf() < ULTRA_SHORT_CHANCE:
		return _remember(_ultra_short(s, kind))
	if randf() < HUGE_POST_CHANCE:
		return _remember(_huge(s, kind, tip))
	if randf() < MODULAR_CHANCE:
		return _remember(_assemble_modular(s, kind, tip))
	if randf() < 0.55:
		return _remember(_combo_sentence(s, kind))
	return _remember(_short_classic(s, kind, tip))


static func argue_back(reply_kind: String, who: String = "Guest") -> String:
	## Clap-back under a Burger Pals "Not True!" / "Liar!" reply.
	var name := who if who.strip_edges() != "" else "Guest"
	if reply_kind == "liar":
		return _remember(_pick(_ARGUE_LIAR).replace("{who}", name))
	return _remember(_pick(_ARGUE_NOT_TRUE).replace("{who}", name))


const _ARGUE_NOT_TRUE: Array[String] = [
	"It IS true lol I was there",
	"Uhh yeah it is?? Receipts in my camera roll",
	"Not true? Bro I still taste it",
	"Cope. That burger was mid and you know it",
	"Sure Jan. My stomach says otherwise",
	"Deny it all you want — still happened",
	"Okay Burger Pals PR team 💀",
	"Funny how \"not true\" shows up faster than my food did",
	"Keep lying to the algorithm",
	"Nah I'm standing on business",
	"Tell that to the burnt edges",
	"Not true is crazy when I have the photo",
	"Y'all reply faster than you cook",
	"It's true and I'll say it again",
	"Gaslight the customers challenge (impossible)",
]

const _ARGUE_LIAR: Array[String] = [
	"I'm the liar?? YOU served that 💀",
	"Liar? Check the pic then talk",
	"Bold of the truck to call ME a liar",
	"Okay then post the security cam",
	"Calling customers liars is a choice",
	"LMAO the audacity",
	"I don't need to lie — your grill did the crime",
	"Name's not Liar, it's {who}, and I'm right",
	"If I'm lying why did you reply so fast",
	"Keep that energy when health inspects",
	"Projection much?",
	"Burger Pals calling foul like a ref with no whistle",
	"Say liar again. Say it to my cold fries",
	"You called me a liar over a 1★? Wild",
	"I'll be the liar AND the reviewer then",
]


static func _remember(text: String) -> String:
	var t := text.strip_edges()
	if t == "":
		return t
	_recent.append(t)
	while _recent.size() > RECENT_MAX:
		_recent.pop_front()
	return t


static func _pick(arr: Array) -> String:
	if arr.is_empty():
		return ""
	## Prefer lines we haven't used recently.
	for _i in 14:
		var s := str(arr[randi() % arr.size()])
		if not _recent.has(s):
			return s
	return str(arr[randi() % arr.size()])


static func _band(s: float, kind: String) -> String:
	if kind == "wrong":
		return "wrong"
	if kind == "angry" or s <= 1.5:
		return "bad"
	if kind == "meh" or s < 2.75:
		return "meh"
	if s >= 4.5:
		return "great"
	if s >= 3.5:
		return "good"
	return "ok"


static func _one_word(s: float, kind: String) -> String:
	var b := _band(s, kind)
	match b:
		"great":
			return _pick(_ONE_GREAT)
		"good":
			return _pick(_ONE_GOOD)
		"ok":
			return _pick(_ONE_OK)
		"meh":
			return _pick(_ONE_MEH)
		"wrong":
			return _pick(["Wrong", "Mixup", "Nope", "Different", "Mismatch", "Rewrite"])
		_:
			return _pick(_ONE_BAD)


static func _fill_short(templ: String, s: float, kind: String) -> String:
	var b := _band(s, kind)
	var adj := _pick(_ADJ_GREAT if b == "great" else _ADJ_GOOD if b == "good" else _ADJ_OK if b == "ok" else _ADJ_MEH if b == "meh" else _ADJ_BAD)
	var one := _one_word(s, kind)
	var noun := _pick(_NOUNS)
	var verb := _pick(_VERB_POS if b in ["great", "good"] else _VERB_NEG)
	return templ.replace("{a}", adj).replace("{n}", noun).replace("{one}", one).replace("{v}", verb)


static func _ultra_short(s: float, kind: String) -> String:
	var b := _band(s, kind)
	var templs: Array = _TEMPL_GREAT
	match b:
		"good":
			templs = _TEMPL_GOOD
		"ok":
			templs = _TEMPL_OK
		"meh":
			templs = _TEMPL_MEH
		"wrong":
			templs = ["Wrong {n}.", "{one}.", "Not my {n}.", "Mix-up.", "{a} mistake."]
		"bad":
			templs = _TEMPL_BAD
	return _fill_short(_pick(templs), s, kind)


static func _combo_sentence(s: float, kind: String) -> String:
	var b := _band(s, kind)
	var adj := _pick(_ADJ_GREAT if b == "great" else _ADJ_GOOD if b == "good" else _ADJ_OK if b == "ok" else _ADJ_MEH if b == "meh" else _ADJ_BAD)
	var noun := _pick(_NOUNS)
	var hook := _pick(_hooks_for(s, kind))
	var tail := _pick(_closers_for(s, kind))
	if randf() < 0.45:
		var tails_great: Array = ["slapped", "went crazy", "cleared", "won lunch"]
		var tails_other: Array = ["hit different", "did the job", "was whatever", "missed", "slapped", "was fine", "was mid", "was tragic"]
		var t := _pick(tails_great if b == "great" else tails_other)
		return "%s %s %s." % [adj.capitalize(), noun, t]
	if randf() < 0.5:
		return "%s %s" % [hook, _pick(_bodies_for(s, kind))]
	return "%s %s" % [_pick(_bodies_for(s, kind)), tail]


static func _assemble_modular(s: float, kind: String, tip: int) -> String:
	var parts: Array[String] = []
	parts.append(_pick(_hooks_for(s, kind)))
	if randf() < 0.85:
		parts.append(_pick(_bodies_for(s, kind)))
	if randf() < 0.4:
		parts.append(_combo_sentence(s, kind))
	if randf() < CAT_ASIDE_CHANCE:
		parts.append(_pick(_CAT_ASIDES))
	if randf() < ROBBER_ASIDE_CHANCE:
		parts.append(_pick(_ROBBER_ASIDES))
	if randf() < 0.55:
		parts.append(_pick(_vibes_for(s, kind)))
	if randf() < 0.72:
		parts.append(_pick(_closers_for(s, kind)))
	if tip > 0 and s >= 4.0 and randf() < 0.55:
		parts.append(_pick(_TIP_BITS))
	var cleaned: Array[String] = []
	for p in parts:
		var t := str(p).strip_edges()
		if t == "" or (not cleaned.is_empty() and cleaned[cleaned.size() - 1] == t):
			continue
		cleaned.append(t)
	if cleaned.size() >= 4 and randf() < 0.35:
		var mid := mini(2, cleaned.size() - 1)
		var head: PackedStringArray = PackedStringArray()
		var tail: PackedStringArray = PackedStringArray()
		for i in cleaned.size():
			if i < mid:
				head.append(cleaned[i])
			else:
				tail.append(cleaned[i])
		return " ".join(head) + "\n\n" + " ".join(tail)
	return " ".join(PackedStringArray(cleaned))


static func _hooks_for(s: float, kind: String) -> Array:
	if kind == "wrong":
		return _HOOKS_WRONG
	match _band(s, kind):
		"great":
			return _HOOKS_GREAT
		"good":
			return _HOOKS_GOOD
		"ok":
			return _HOOKS_OK
		"meh":
			return _HOOKS_MEH
		_:
			return _HOOKS_BAD


static func _bodies_for(s: float, kind: String) -> Array:
	if kind == "wrong":
		return _BODY_WRONG
	match _band(s, kind):
		"great":
			return _BODY_GREAT
		"good":
			return _BODY_GOOD
		"ok":
			return _BODY_OK
		"meh":
			return _BODY_MEH
		_:
			return _BODY_BAD


static func _vibes_for(s: float, kind: String) -> Array:
	match _band(s, kind):
		"great":
			return _VIBE_GREAT
		"good":
			return _VIBE_GOOD
		"ok":
			return _VIBE_OK
		"meh":
			return _VIBE_MEH
		"wrong":
			return _VIBE_BAD
		_:
			return _VIBE_BAD


static func _closers_for(s: float, kind: String) -> Array:
	match _band(s, kind):
		"great":
			return _CLOSE_GREAT
		"good":
			return _CLOSE_GOOD
		"ok":
			return _CLOSE_OK
		"meh":
			return _CLOSE_MEH
		"wrong":
			return _CLOSE_BAD
		_:
			return _CLOSE_BAD


static func _spray(_s: float) -> String:
	if randf() < 0.4:
		return _one_word(1.0, "angry")
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
		"Powdered. Traumatized. One star.",
		"Extinguisher to the face. Absolutely not.",
	])


static func _cat_burnt() -> String:
	## Mustache cat got charcoal — phone floods with furious meows.
	return _pick([
		"MEOW! MEOW! MEOW! MEOW! MEOW!",
		"MEOW MEOW MEOW MEOW MEOW MEOW!!!",
		"MEOW! MEOW! MEOW!\nMEOW! MEOW! MEOW!",
		"MEOW! MEOW! MEOW! MEOW! MEOW! MEOW! MEOW!",
		"MEOW MEOW MEOW!!!!\nMEOW MEOW MEOW!!!!",
		"MEOW! MEOW! MEOW! MEOW! MEOW! MEOW!",
		"MEOWMEOWMEOWMEOWMEOW\nMEOW! MEOW! MEOW!",
		"MEOW! MEOW!\nMEOW! MEOW!\nMEOW! MEOW!",
	])


static func _burnt(s: float) -> String:
	if s >= 3.5:
		if randf() < 0.35:
			return _one_word(s, "serve")
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
			"Ashy. Perfect. Fight me.",
			"Well-done freak reporting: yes.",
		])
	if randf() < 0.3:
		return _one_word(1.0, "angry")
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
		"Hockey puck. Hard pass.",
		"Ash tray lunch. One star.",
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
			(cat if cat != "" else _pick(_VIBE_GOOD)),
			_pick(_CLOSE_GOOD),
		]).strip_edges()
	if s >= 2.75:
		return "\n\n".join([
			"Trying to be fair here, not dramatic.",
			_pick(_BODY_OK),
			(cat if cat != "" else _pick(_VIBE_OK)),
			_pick(_CLOSE_OK),
		]).strip_edges()
	return "\n\n".join([
		"Trying to be fair here, not dramatic.",
		_pick(_BODY_MEH),
		(cat if cat != "" else _pick(_VIBE_MEH)),
		_pick(_CLOSE_MEH),
	]).strip_edges()


static func _short_classic(s: float, kind: String, tip: int) -> String:
	if tip > 0 and s >= 4.0 and randf() < 0.4:
		return _pick(_TIP_BITS)
	return _ultra_short(s, kind)



const _ONE_GREAT: Array = [
	"Slap",
	"Obsessed",
	"Insane",
	"Fire",
	"Perfect",
	"Goated",
	"Elite",
	"Legendary",
	"Heaven",
	"Crispy",
	"Juicy",
	"Addicted",
	"Returning",
	"W",
	"Iconic",
	"Delicious",
	"Phenomenal",
	"Unreal",
	"Nailed",
	"Chef",
	"Flawless",
	"Bussin",
	"Divine",
	"Amazing",
	"Stunned",
	"Speechless",
	"Wow",
	"Yesss",
	"Peak",
	"Mint",
	"Sublime",
	"Gorgeous",
	"Smacked",
	"Crushed",
	"Winner",
	"Favorite",
	"Blessed",
	"Ten",
	"Smashed",
	"Holy",
	"Gas",
	"Crazy",
	"Ridiculous",
	"Outstanding",
	"Superb",
	"Immaculate",
	"Pristine",
	"Art",
	"Magic",
	"Yes",
	"Slap.",
	"Slap!!",
	"SLAP",
	"Obsessed.",
	"Obsessed!!",
	"OBSESSED",
	"Insane.",
	"Insane!!",
	"INSANE",
	"Fire.",
	"Fire!!",
	"FIRE",
	"Perfect.",
	"Perfect!!",
	"PERFECT",
	"Goated.",
	"Goated!!",
	"GOATED",
	"Elite.",
	"Elite!!",
	"ELITE",
	"Legendary.",
	"Legendary!!",
	"LEGENDARY",
	"Heaven.",
	"Heaven!!",
	"HEAVEN",
	"Crispy.",
	"Crispy!!",
	"CRISPY",
	"Juicy.",
	"Juicy!!",
	"JUICY",
	"Addicted.",
	"Addicted!!",
	"ADDICTED",
	"Returning.",
	"Returning!!",
	"RETURNING",
	"W.",
	"W!!",
	"Iconic.",
	"Iconic!!",
	"ICONIC",
	"Delicious.",
	"Delicious!!",
	"DELICIOUS",
	"Phenomenal.",
	"Phenomenal!!",
	"PHENOMENAL",
	"Unreal.",
	"Unreal!!",
	"UNREAL",
	"Nailed.",
	"Nailed!!",
	"NAILED",
	"Chef.",
	"Chef!!",
	"CHEF",
	"Flawless.",
	"Flawless!!",
	"FLAWLESS",
	"Bussin.",
	"Bussin!!",
	"BUSSIN",
	"Divine.",
	"Divine!!",
	"DIVINE",
	"Amazing.",
	"Amazing!!",
	"AMAZING",
	"Stunned.",
	"Stunned!!",
	"STUNNED",
	"Speechless.",
	"Speechless!!",
	"SPEECHLESS",
	"Wow.",
	"Wow!!",
	"WOW",
	"Yesss.",
	"Yesss!!",
	"YESSS",
	"Peak.",
	"Peak!!",
	"PEAK",
	"Mint.",
	"Mint!!",
	"MINT",
]

const _ONE_GOOD: Array = [
	"Solid",
	"Tasty",
	"Good",
	"Nice",
	"Fresh",
	"Hot",
	"Happy",
	"Recommend",
	"Satisfied",
	"Worthy",
	"Decent+",
	"Pretty",
	"Pleased",
	"Enjoyed",
	"Quality",
	"Crisp",
	"Melty",
	"Clean",
	"Fast",
	"Friendly",
	"Reliable",
	"Yum",
	"Hit",
	"Score",
	"Approved",
	"Respect",
	"Glad",
	"Back",
	"Again",
	"Positive",
	"Comfort",
	"Savory",
	"Balanced",
	"Proper",
	"Legit",
	"Strong",
	"Sharp",
	"Smooth",
	"Warm",
	"Greatish",
	"Liked",
	"Worked",
	"Wins",
	"Handy",
	"Snack",
	"Treat",
	"Fills",
	"Delivers",
	"Capable",
	"Fine+",
	"Solid.",
	"Solid!!",
	"SOLID",
	"Tasty.",
	"Tasty!!",
	"TASTY",
	"Good.",
	"Good!!",
	"GOOD",
	"Nice.",
	"Nice!!",
	"NICE",
	"Fresh.",
	"Fresh!!",
	"FRESH",
	"Hot.",
	"Hot!!",
	"HOT",
	"Happy.",
	"Happy!!",
	"HAPPY",
	"Recommend.",
	"Recommend!!",
	"RECOMMEND",
	"Satisfied.",
	"Satisfied!!",
	"SATISFIED",
	"Worthy.",
	"Worthy!!",
	"WORTHY",
	"Decent+.",
	"Decent+!!",
	"DECENT+",
	"Pretty.",
	"Pretty!!",
	"PRETTY",
	"Pleased.",
	"Pleased!!",
	"PLEASED",
	"Enjoyed.",
	"Enjoyed!!",
	"ENJOYED",
	"Quality.",
	"Quality!!",
	"QUALITY",
	"Crisp.",
	"Crisp!!",
	"CRISP",
	"Melty.",
	"Melty!!",
	"MELTY",
	"Clean.",
	"Clean!!",
	"CLEAN",
	"Fast.",
	"Fast!!",
	"FAST",
	"Friendly.",
	"Friendly!!",
	"FRIENDLY",
	"Reliable.",
	"Reliable!!",
	"RELIABLE",
	"Yum.",
	"Yum!!",
	"YUM",
	"Hit.",
	"Hit!!",
	"HIT",
	"Score.",
	"Score!!",
	"SCORE",
	"Approved.",
	"Approved!!",
	"APPROVED",
	"Respect.",
	"Respect!!",
	"RESPECT",
	"Glad.",
	"Glad!!",
	"GLAD",
	"Back.",
	"Back!!",
	"BACK",
	"Again.",
	"Again!!",
	"AGAIN",
	"Positive.",
	"Positive!!",
	"POSITIVE",
]

const _ONE_OK: Array = [
	"Okay",
	"Fine",
	"Average",
	"Meh+",
	"Alr",
	"Mid",
	"Passable",
	"Fair",
	"Neutral",
	"Whatever",
	"Edible",
	"Standard",
	"Basic",
	"Serviceable",
	"Adequate",
	"Ordinary",
	"Nothing",
	"Shrug",
	"Eh",
	"Three",
	"Acceptable",
	"Normal",
	"Plain",
	"Simple",
	"Workable",
	"Usual",
	"Typical",
	"So-so",
	"Mixed",
	"Alright",
	"Mediocre+",
	"Functional",
	"Fills",
	"Hunger",
	"Paid",
	"Got it",
	"Sure",
	"K",
	"Noted",
	"Blank",
	"Flat",
	"Mild",
	"Soft",
	"Quiet",
	"Calm",
	"Steady",
	"Even",
	"Middle",
	"Centrist",
	"Meh",
	"Okay.",
	"Okay!!",
	"OKAY",
	"Fine.",
	"Fine!!",
	"FINE",
	"Average.",
	"Average!!",
	"AVERAGE",
	"Meh+.",
	"Meh+!!",
	"MEH+",
	"Alr.",
	"Alr!!",
	"ALR",
	"Mid.",
	"Mid!!",
	"MID",
	"Passable.",
	"Passable!!",
	"PASSABLE",
	"Fair.",
	"Fair!!",
	"FAIR",
	"Neutral.",
	"Neutral!!",
	"NEUTRAL",
	"Whatever.",
	"Whatever!!",
	"WHATEVER",
	"Edible.",
	"Edible!!",
	"EDIBLE",
	"Standard.",
	"Standard!!",
	"STANDARD",
	"Basic.",
	"Basic!!",
	"BASIC",
	"Serviceable.",
	"Serviceable!!",
	"SERVICEABLE",
	"Adequate.",
	"Adequate!!",
	"ADEQUATE",
	"Ordinary.",
	"Ordinary!!",
	"ORDINARY",
	"Nothing.",
	"Nothing!!",
	"NOTHING",
	"Shrug.",
	"Shrug!!",
	"SHRUG",
	"Eh.",
	"Eh!!",
	"EH",
	"Three.",
	"Three!!",
	"THREE",
	"Acceptable.",
	"Acceptable!!",
	"ACCEPTABLE",
	"Normal.",
	"Normal!!",
	"NORMAL",
	"Plain.",
	"Plain!!",
	"PLAIN",
	"Simple.",
	"Simple!!",
	"SIMPLE",
	"Workable.",
	"Workable!!",
	"WORKABLE",
	"Usual.",
	"Usual!!",
	"USUAL",
	"Typical.",
	"Typical!!",
	"TYPICAL",
	"So-so.",
	"So-so!!",
	"SO-SO",
	"Mixed.",
	"Mixed!!",
	"MIXED",
	"Alright.",
	"Alright!!",
	"ALRIGHT",
]

const _ONE_MEH: Array = [
	"Meh",
	"Bland",
	"Dull",
	"Weak",
	"Dry",
	"Slow",
	"Miss",
	"Underwhelming",
	"Forgettable",
	"Shrug-",
	"Tired",
	"Soggy",
	"Coldish",
	"Late",
	"Saltless",
	"Boring",
	"Mid-",
	"Phoned",
	"Lazy",
	"Thin",
	"Chewy",
	"Greasy",
	"Sad",
	"Flat-",
	"Basic-",
	"Nope-ish",
	"Disappointed",
	"Whatever-",
	"Skip",
	"Two",
	"Eh-",
	"Kinda",
	"Almost",
	"Nearly",
	"NotReally",
	"Lacking",
	"Empty",
	"Hollow",
	"Muted",
	"Softfail",
	"Meh.",
	"Meh!!",
	"MEH",
	"Bland.",
	"Bland!!",
	"BLAND",
	"Dull.",
	"Dull!!",
	"DULL",
	"Weak.",
	"Weak!!",
	"WEAK",
	"Dry.",
	"Dry!!",
	"DRY",
	"Slow.",
	"Slow!!",
	"SLOW",
	"Miss.",
	"Miss!!",
	"MISS",
	"Underwhelming.",
	"Underwhelming!!",
	"Forgettable.",
	"Forgettable!!",
	"FORGETTABLE",
	"Shrug-.",
	"Shrug-!!",
	"SHRUG-",
	"Tired.",
	"Tired!!",
	"TIRED",
	"Soggy.",
	"Soggy!!",
	"SOGGY",
	"Coldish.",
	"Coldish!!",
	"COLDISH",
	"Late.",
	"Late!!",
	"LATE",
	"Saltless.",
	"Saltless!!",
	"SALTLESS",
	"Boring.",
	"Boring!!",
	"BORING",
	"Mid-.",
	"Mid-!!",
	"MID-",
	"Phoned.",
	"Phoned!!",
	"PHONED",
	"Lazy.",
	"Lazy!!",
	"LAZY",
	"Thin.",
	"Thin!!",
	"THIN",
	"Chewy.",
	"Chewy!!",
	"CHEWY",
	"Greasy.",
	"Greasy!!",
	"GREASY",
	"Sad.",
	"Sad!!",
	"SAD",
	"Flat-.",
	"Flat-!!",
	"FLAT-",
	"Basic-.",
	"Basic-!!",
	"BASIC-",
	"Nope-ish.",
	"Nope-ish!!",
	"NOPE-ISH",
	"Disappointed.",
	"Disappointed!!",
	"DISAPPOINTED",
	"Whatever-.",
	"Whatever-!!",
	"WHATEVER-",
	"Skip.",
	"Skip!!",
	"SKIP",
	"Two.",
	"Two!!",
	"TWO",
]

const _ONE_BAD: Array = [
	"Trash",
	"Awful",
	"Never",
	"Blocked",
	"Rage",
	"Hungry",
	"Joke",
	"Disgusting",
	"Horrible",
	"Worst",
	"Burnt",
	"Cold",
	"Rude",
	"Chaos",
	"Scam",
	"No",
	"Leave",
	"Quit",
	"Fail",
	"One",
	"Gross",
	"Nasty",
	"Ew",
	"Yikes",
	"Hardpass",
	"Dogwater",
	"Midless",
	"Cringe",
	"Pain",
	"Suffering",
	"Zero",
	"Nope",
	"Gone",
	"Done",
	"Blocked+",
	"Report",
	"Refund",
	"Walked",
	"Left",
	"Mad",
	"Trash.",
	"Trash!!",
	"TRASH",
	"Awful.",
	"Awful!!",
	"AWFUL",
	"Never.",
	"Never!!",
	"NEVER",
	"Blocked.",
	"Blocked!!",
	"BLOCKED",
	"Rage.",
	"Rage!!",
	"RAGE",
	"Hungry.",
	"Hungry!!",
	"HUNGRY",
	"Joke.",
	"Joke!!",
	"JOKE",
	"Disgusting.",
	"Disgusting!!",
	"DISGUSTING",
	"Horrible.",
	"Horrible!!",
	"HORRIBLE",
	"Worst.",
	"Worst!!",
	"WORST",
	"Burnt.",
	"Burnt!!",
	"BURNT",
	"Cold.",
	"Cold!!",
	"COLD",
	"Rude.",
	"Rude!!",
	"RUDE",
	"Chaos.",
	"Chaos!!",
	"CHAOS",
	"Scam.",
	"Scam!!",
	"SCAM",
	"No.",
	"No!!",
	"NO",
	"Leave.",
	"Leave!!",
	"LEAVE",
	"Quit.",
	"Quit!!",
	"QUIT",
	"Fail.",
	"Fail!!",
	"FAIL",
	"One.",
	"One!!",
	"ONE",
	"Gross.",
	"Gross!!",
	"GROSS",
	"Nasty.",
	"Nasty!!",
	"NASTY",
	"Ew.",
	"Ew!!",
	"EW",
	"Yikes.",
	"Yikes!!",
	"YIKES",
	"Hardpass.",
	"Hardpass!!",
	"HARDPASS",
	"Dogwater.",
	"Dogwater!!",
	"DOGWATER",
	"Midless.",
	"Midless!!",
	"MIDLESS",
	"Cringe.",
	"Cringe!!",
	"CRINGE",
	"Pain.",
	"Pain!!",
	"PAIN",
	"Suffering.",
	"Suffering!!",
	"SUFFERING",
]

const _ADJ_GREAT: Array = [
	"perfect",
	"insane",
	"ridiculous",
	"elite",
	"juicy",
	"crispy",
	"goated",
	"legendary",
	"flawless",
	"divine",
	"hot",
	"loud",
	"smoky",
	"melty",
	"gorgeous",
	"pristine",
	"immaculate",
	"unreal",
	"phenomenal",
	"addictive",
]

const _ADJ_GOOD: Array = [
	"solid",
	"tasty",
	"fresh",
	"clean",
	"crisp",
	"proper",
	"reliable",
	"friendly",
	"savory",
	"balanced",
	"legit",
	"strong",
	"warm",
	"handy",
	"satisfying",
	"quality",
	"neat",
	"sharp",
	"smooth",
	"good",
]

const _ADJ_OK: Array = [
	"okay",
	"fine",
	"average",
	"basic",
	"plain",
	"mild",
	"standard",
	"serviceable",
	"ordinary",
	"adequate",
	"alright",
	"passable",
	"simple",
	"usual",
	"typical",
	"even",
	"middle",
	"quiet",
	"soft",
	"flat",
]

const _ADJ_MEH: Array = [
	"bland",
	"dull",
	"weak",
	"dry",
	"slow",
	"soggy",
	"late",
	"thin",
	"chewy",
	"greasy",
	"tired",
	"forgettable",
	"underwhelming",
	"muted",
	"hollow",
	"lazy",
	"coldish",
	"phoned-in",
	"mid",
	"sad",
]

const _ADJ_BAD: Array = [
	"awful",
	"burnt",
	"cold",
	"rude",
	"chaotic",
	"disgusting",
	"horrible",
	"nasty",
	"gross",
	"scammy",
	"tragic",
	"painful",
	"embarrassing",
	"insulting",
	"inedible",
	"charred",
	"hostile",
	"broken",
	"hopeless",
	"cursed",
]

const _NOUNS: Array = [
	"smash",
	"burger",
	"patty",
	"stack",
	"window service",
	"truck stop",
	"lunch",
	"bite",
	"build",
	"crust",
	"cheese pull",
	"ticket match",
	"grill smell",
	"first bite",
	"hand-off",
	"line wait",
	"soda side",
	"bun",
	"toppings",
	"cook",
]

const _VERB_POS: Array = [
	"slapped",
	"hit",
	"delivered",
	"nailed",
	"crushed",
	"cleared",
	"won",
	"fed",
	"saved",
	"ruined other trucks for me",
]

const _VERB_NEG: Array = [
	"missed",
	"failed",
	"flopped",
	"dragged",
	"stalled",
	"disappointed",
	"insulted",
	"burned",
	"ignored",
	"wasted my break",
]

const _TEMPL_GREAT: Array = [
	"{a} {n}.",
	"{a} smash.",
	"{one}.",
	"That {n} was {a}.",
	"{one} burger.",
	"I'm {one}.",
	"{v}.",
	"Hot and {a}.",
	"{one}!!!",
	"Yes. {one}.",
]

const _TEMPL_GOOD: Array = [
	"{a} {n}.",
	"Pretty {a}.",
	"{one}.",
	"Good {n}.",
	"{a} enough.",
	"Would reorder.",
	"Nice {n}.",
	"{one} lunch.",
	"Solid {n}.",
	"Happy.",
]

const _TEMPL_OK: Array = [
	"{a}.",
	"{one}.",
	"Three stars.",
	"It was {a}.",
	"{n} was {a}.",
	"Mid {n}.",
	"Eh, {a}.",
	"{one} I guess.",
	"Average {n}.",
	"Fine.",
]

const _TEMPL_MEH: Array = [
	"{a}.",
	"{one}.",
	"Two stars.",
	"{n} was {a}.",
	"Kinda {a}.",
	"{v}.",
	"Soft miss.",
	"{one} burger.",
	"Not great.",
	"Bland {n}.",
]

const _TEMPL_BAD: Array = [
	"{one}.",
	"{a}.",
	"One star.",
	"{v}.",
	"{n} was {a}.",
	"Never.",
	"Hard {one}.",
	"{one}!!!",
	"Walked.",
	"Nope.",
]

const _HOOKS_GREAT: Array = [
	"Okay I need to write a real review.",
	"Stop scrolling — this truck slapped.",
	"Rare food-truck W.",
	"I wasn't going to post but that first bite forced my hand.",
	"Burger Pals just ruined other smash burgers for me.",
	"Came skeptical, left evangelical.",
	"Not kidding.",
	"Posting from the car.",
	"Still thinking about it.",
	"Calling it now.",
	"Told my group chat already.",
	"Had to sit down.",
	"This is the one.",
	"Bookmarked the truck.",
	"I'm the problem now.",
	"Fan behavior unlocked.",
	"Respectfully obsessed.",
	"Short version first.",
	"Long story short.",
	"Real talk.",
]

const _HOOKS_GOOD: Array = [
	"Solid lunch, honest take:",
	"Pretty good truck night.",
	"Would order again without drama.",
	"Not life-changing, still glad I stopped.",
	"Quick review because it earned one.",
	"Four-star energy.",
	"Happy customer report.",
	"Came, ate, smiled.",
	"Recommendable.",
	"Good smash day.",
	"Window did its job.",
	"No complaints worth typing long.",
	"Positive note.",
	"Leaving this up.",
	"Worth the stop.",
	"Lunch win.",
	"Satisfied.",
	"Fresh and hot.",
	"Kept it moving.",
	"Nice work.",
]

const _HOOKS_OK: Array = [
	"Three-star energy:",
	"Mixed bag, keeping it real.",
	"Fine. Not mad. Not obsessed.",
	"Alright burger with caveats.",
	"Middle of the road.",
	"Neither a W nor an L.",
	"Honest middle.",
	"Average smash night.",
	"Got what I paid for.",
	"Centrist review.",
	"Neutral take.",
	"Could go either way.",
	"Not writing a novel.",
	"Shrug with fries.",
	"Serviceable lunch.",
	"It existed.",
	"Checked the box.",
	"No fireworks.",
	"Steady Eddie burger.",
	"Room-temperature feelings.",
]

const _HOOKS_MEH: Array = [
	"Came in hopeful, left shrugging.",
	"Edible is the nicest word I've got.",
	"Expected more from the cute logo.",
	"Seasoning optional, apparently.",
	"Two-star shrug.",
	"Underwhelmed.",
	"Almost good.",
	"Missed the mark.",
	"Needed more love.",
	"Bland wave.",
	"Forgot it already.",
	"Wouldn't cross town.",
	"Phone-it-in vibes.",
	"Soft L.",
	"Meh with receipts.",
	"Hunger fixed, soul unmoved.",
	"Dry take.",
	"Slow and soft.",
	"Not angry, just bored.",
	"Could've been something.",
]

const _HOOKS_BAD: Array = [
	"Worst window experience this month.",
	"Writing this so nobody else wastes a lunch break.",
	"Still mad in the parking lot.",
	"One star and I'm telling the neighborhood chat.",
	"Hard pass forever.",
	"Never again energy.",
	"Rage typing.",
	"Left hungry.",
	"Embarrassing.",
	"Do better.",
	"Blocked.",
	"Report filed in my brain.",
	"Absolute joke.",
	"Trash run.",
	"Walked out.",
	"Zero redeeming bites.",
	"Health? Vibes? No.",
	"Chaos only.",
	"Paid for pain.",
	"Done with this truck.",
]

const _HOOKS_WRONG: Array = [
	"Wrong burger. Like, fully wrong.",
	"Ticket said one thing. Window handed me another.",
	"Order mix-up with confidence, somehow.",
	"Build board vs reality: mismatch.",
	"That wasn't my stack.",
	"Wrong toppings, loud shrug.",
	"Mix-up city.",
	"Held up the ticket like evidence.",
	"Different burger entirely.",
	"Not what I ordered.",
]

const _BODY_GREAT: Array = [
	"Patty had that loud crust, cheese melted properly, stack stayed hot through the window.",
	"Juicy smash, clean build, no soggy bun disaster.",
	"They matched my ticket and still somehow made it feel special.",
	"Grill smell alone sold me, then the burger backed it up.",
	"Fast without feeling rushed — cook knew what they were doing.",
	"Every layer earned its place.",
	"Crisp edges, juicy middle, no sad wilt.",
	"Hand-off was clean and hot.",
	"Soda + smash combo slapped.",
	"Seasoning actually showed up.",
	"Bun held, cheese draped, onions sang.",
	"Watching the grill made me hungrier then the bite paid rent.",
	"No cold spots, no weird sauce floods.",
	"Ticket-perfect and still exciting.",
	"That crust bark is illegal.",
	"Cook timed it like a pro.",
	"Toppings fresh, not fridge-tired.",
	"Window energy matched the food.",
	"I ate half before I remembered to take a pic.",
	"Line moved and quality didn't drop.",
	"This is what smash is supposed to taste like.",
	"The smash was perfect.",
	"Really perfect burger.",
	"Honestly perfect on the patty.",
	"That stack? perfect.",
	"Got a perfect window service today.",
	"perfect truck stop, no notes.",
	"Calling the lunch perfect.",
	"My bite came out perfect.",
	"Unexpectedly perfect build.",
	"Lowkey perfect crust.",
	"The cheese pull was perfect.",
	"Really perfect ticket match.",
	"Honestly perfect on the grill smell.",
	"That first bite? perfect.",
	"Got a perfect hand-off today.",
	"perfect line wait, no notes.",
	"Calling the soda side perfect.",
	"My bun came out perfect.",
	"Unexpectedly perfect toppings.",
	"Lowkey perfect cook.",
	"The smash was insane.",
	"Really insane burger.",
	"Honestly insane on the patty.",
	"That stack? insane.",
	"Got a insane window service today.",
	"insane truck stop, no notes.",
	"Calling the lunch insane.",
	"My bite came out insane.",
	"Unexpectedly insane build.",
	"Lowkey insane crust.",
	"The cheese pull was insane.",
	"Really insane ticket match.",
	"Honestly insane on the grill smell.",
	"That first bite? insane.",
	"Got a insane hand-off today.",
	"insane line wait, no notes.",
	"Calling the soda side insane.",
	"My bun came out insane.",
	"Unexpectedly insane toppings.",
	"Lowkey insane cook.",
	"The smash was ridiculous.",
	"Really ridiculous burger.",
	"Honestly ridiculous on the patty.",
	"That stack? ridiculous.",
	"Got a ridiculous window service today.",
	"ridiculous truck stop, no notes.",
	"Calling the lunch ridiculous.",
	"My bite came out ridiculous.",
	"Unexpectedly ridiculous build.",
	"Lowkey ridiculous crust.",
	"The cheese pull was ridiculous.",
	"Really ridiculous ticket match.",
	"Honestly ridiculous on the grill smell.",
	"That first bite? ridiculous.",
	"Got a ridiculous hand-off today.",
	"ridiculous line wait, no notes.",
	"Calling the soda side ridiculous.",
	"My bun came out ridiculous.",
	"Unexpectedly ridiculous toppings.",
	"Lowkey ridiculous cook.",
	"The smash was elite.",
	"Really elite burger.",
	"Honestly elite on the patty.",
	"That stack? elite.",
	"Got a elite window service today.",
	"elite truck stop, no notes.",
	"Calling the lunch elite.",
	"My bite came out elite.",
	"Unexpectedly elite build.",
	"Lowkey elite crust.",
	"The cheese pull was elite.",
	"Really elite ticket match.",
	"Honestly elite on the grill smell.",
	"That first bite? elite.",
	"Got a elite hand-off today.",
	"elite line wait, no notes.",
	"Calling the soda side elite.",
	"My bun came out elite.",
	"Unexpectedly elite toppings.",
	"Lowkey elite cook.",
	"The smash was juicy.",
	"Really juicy burger.",
	"Honestly juicy on the patty.",
	"That stack? juicy.",
	"Got a juicy window service today.",
	"juicy truck stop, no notes.",
	"Calling the lunch juicy.",
	"My bite came out juicy.",
	"Unexpectedly juicy build.",
	"Lowkey juicy crust.",
]

const _BODY_GOOD: Array = [
	"Fresh toppings, hot patty, didn't mess up the order.",
	"Wait was fine, burger hit the spot, crew kept the line moving.",
	"Good crust, decent melt, nothing weird in the stack.",
	"Tasted like a real smash truck, not a microwave impersonation.",
	"Solid build, friendly hand-off.",
	"Hot enough, seasoned enough, fast enough.",
	"Cheese melted, bun behaved, pickles punched.",
	"No drama, good lunch.",
	"Would reorder the same ticket tomorrow.",
	"Crisp edges without charcoal bitterness.",
	"Soda was cold, burger was honest.",
	"Clean window service.",
	"Stack stayed together walking to the car.",
	"Flavor was there without overdoing sauce.",
	"Cook watched the grill — appreciated.",
	"Nice melt, decent smash.",
	"Happy with the value.",
	"Fresh lettuce actually crunched.",
	"No soggy bottom bun tragedy.",
	"Four stars feels right.",
	"The smash was solid.",
	"Really solid burger.",
	"Honestly solid on the patty.",
	"That stack? solid.",
	"Got a solid window service today.",
	"solid truck stop, no notes.",
	"Calling the lunch solid.",
	"My bite came out solid.",
	"Unexpectedly solid build.",
	"Lowkey solid crust.",
	"The cheese pull was solid.",
	"Really solid ticket match.",
	"Honestly solid on the grill smell.",
	"That first bite? solid.",
	"Got a solid hand-off today.",
	"solid line wait, no notes.",
	"Calling the soda side solid.",
	"My bun came out solid.",
	"Unexpectedly solid toppings.",
	"Lowkey solid cook.",
	"The smash was tasty.",
	"Really tasty burger.",
	"Honestly tasty on the patty.",
	"That stack? tasty.",
	"Got a tasty window service today.",
	"tasty truck stop, no notes.",
	"Calling the lunch tasty.",
	"My bite came out tasty.",
	"Unexpectedly tasty build.",
	"Lowkey tasty crust.",
	"The cheese pull was tasty.",
	"Really tasty ticket match.",
	"Honestly tasty on the grill smell.",
	"That first bite? tasty.",
	"Got a tasty hand-off today.",
	"tasty line wait, no notes.",
	"Calling the soda side tasty.",
	"My bun came out tasty.",
	"Unexpectedly tasty toppings.",
	"Lowkey tasty cook.",
	"The smash was fresh.",
	"Really fresh burger.",
	"Honestly fresh on the patty.",
	"That stack? fresh.",
	"Got a fresh window service today.",
	"fresh truck stop, no notes.",
	"Calling the lunch fresh.",
	"My bite came out fresh.",
	"Unexpectedly fresh build.",
	"Lowkey fresh crust.",
	"The cheese pull was fresh.",
	"Really fresh ticket match.",
	"Honestly fresh on the grill smell.",
	"That first bite? fresh.",
	"Got a fresh hand-off today.",
	"fresh line wait, no notes.",
	"Calling the soda side fresh.",
	"My bun came out fresh.",
	"Unexpectedly fresh toppings.",
	"Lowkey fresh cook.",
	"The smash was clean.",
	"Really clean burger.",
	"Honestly clean on the patty.",
	"That stack? clean.",
	"Got a clean window service today.",
	"clean truck stop, no notes.",
	"Calling the lunch clean.",
	"My bite came out clean.",
	"Unexpectedly clean build.",
	"Lowkey clean crust.",
	"The cheese pull was clean.",
	"Really clean ticket match.",
	"Honestly clean on the grill smell.",
	"That first bite? clean.",
	"Got a clean hand-off today.",
	"clean line wait, no notes.",
	"Calling the soda side clean.",
	"My bun came out clean.",
	"Unexpectedly clean toppings.",
	"Lowkey clean cook.",
	"The smash was crisp.",
	"Really crisp burger.",
	"Honestly crisp on the patty.",
	"That stack? crisp.",
	"Got a crisp window service today.",
	"crisp truck stop, no notes.",
	"Calling the lunch crisp.",
	"My bite came out crisp.",
	"Unexpectedly crisp build.",
	"Lowkey crisp crust.",
]

const _BODY_OK: Array = [
	"Got my food, it was fine, service was fine, nothing wild.",
	"Room to grow on seasoning and speed, but I wasn't robbed.",
	"Decent for a truck stop — just not a destination yet.",
	"Edible, warm, forgettable in a calm way.",
	"Matched the ticket, missed the magic.",
	"Average smash, average wait.",
	"Bun okay, patty okay, toppings okay.",
	"Three stars = accurate.",
	"Hunger gone, excitement absent.",
	"Nothing broken, nothing special.",
	"Could use more salt and more smile.",
	"Service was polite if quiet.",
	"Stack held, flavor coasted.",
	"I'd come back if I'm already nearby.",
	"Not a destination, a convenience.",
	"Middle-of-menu energy.",
	"Fine lunch break filler.",
	"No complaints big enough to type angry.",
	"Seasoning played it safe.",
	"It's a burger. It burgered.",
	"The smash was okay.",
	"Really okay burger.",
	"Honestly okay on the patty.",
	"That stack? okay.",
	"Got a okay window service today.",
	"okay truck stop, no notes.",
	"Calling the lunch okay.",
	"My bite came out okay.",
	"Unexpectedly okay build.",
	"Lowkey okay crust.",
	"The cheese pull was okay.",
	"Really okay ticket match.",
	"Honestly okay on the grill smell.",
	"That first bite? okay.",
	"Got a okay hand-off today.",
	"okay line wait, no notes.",
	"Calling the soda side okay.",
	"My bun came out okay.",
	"Unexpectedly okay toppings.",
	"Lowkey okay cook.",
	"The smash was fine.",
	"Really fine burger.",
	"Honestly fine on the patty.",
	"That stack? fine.",
	"Got a fine window service today.",
	"fine truck stop, no notes.",
	"Calling the lunch fine.",
	"My bite came out fine.",
	"Unexpectedly fine build.",
	"Lowkey fine crust.",
	"The cheese pull was fine.",
	"Really fine ticket match.",
	"Honestly fine on the grill smell.",
	"That first bite? fine.",
	"Got a fine hand-off today.",
	"fine line wait, no notes.",
	"Calling the soda side fine.",
	"My bun came out fine.",
	"Unexpectedly fine toppings.",
	"Lowkey fine cook.",
	"The smash was average.",
	"Really average burger.",
	"Honestly average on the patty.",
	"That stack? average.",
	"Got a average window service today.",
	"average truck stop, no notes.",
	"Calling the lunch average.",
	"My bite came out average.",
	"Unexpectedly average build.",
	"Lowkey average crust.",
	"The cheese pull was average.",
	"Really average ticket match.",
	"Honestly average on the grill smell.",
	"That first bite? average.",
	"Got a average hand-off today.",
	"average line wait, no notes.",
	"Calling the soda side average.",
	"My bun came out average.",
	"Unexpectedly average toppings.",
	"Lowkey average cook.",
	"The smash was basic.",
	"Really basic burger.",
	"Honestly basic on the patty.",
	"That stack? basic.",
	"Got a basic window service today.",
	"basic truck stop, no notes.",
	"Calling the lunch basic.",
	"My bite came out basic.",
	"Unexpectedly basic build.",
	"Lowkey basic crust.",
	"The cheese pull was basic.",
	"Really basic ticket match.",
	"Honestly basic on the grill smell.",
	"That first bite? basic.",
	"Got a basic hand-off today.",
	"basic line wait, no notes.",
	"Calling the soda side basic.",
	"My bun came out basic.",
	"Unexpectedly basic toppings.",
	"Lowkey basic cook.",
	"The smash was plain.",
	"Really plain burger.",
	"Honestly plain on the patty.",
	"That stack? plain.",
	"Got a plain window service today.",
	"plain truck stop, no notes.",
	"Calling the lunch plain.",
	"My bite came out plain.",
	"Unexpectedly plain build.",
	"Lowkey plain crust.",
]

const _BODY_MEH: Array = [
	"Bun was fine, meat was okay, flavor took a nap.",
	"Needed salt, love, and maybe a manager tasting the line.",
	"Wouldn't drive across town for it again unless they tighten the cook.",
	"Bland patty, soft crust, meh melt.",
	"Wait felt longer than the flavor deserved.",
	"Undersalted and overthought.",
	"Toppings tired, energy tired.",
	"Almost good, then it wasn't.",
	"Cheese didn't melt right.",
	"Bun went limp fast.",
	"Seasoning ghosted me.",
	"Two stars with a polite nod.",
	"Edible but not exciting.",
	"Forgot the bite by the next block.",
	"Grill timing felt off.",
	"Service shrugged a little.",
	"Needed a better smash press.",
	"Soda carried harder than the burger.",
	"Soft L overall.",
	"Hunger fixed, standards unmet.",
	"The smash was bland.",
	"Really bland burger.",
	"Honestly bland on the patty.",
	"That stack? bland.",
	"Got a bland window service today.",
	"bland truck stop, no notes.",
	"Calling the lunch bland.",
	"My bite came out bland.",
	"Unexpectedly bland build.",
	"Lowkey bland crust.",
	"The cheese pull was bland.",
	"Really bland ticket match.",
	"Honestly bland on the grill smell.",
	"That first bite? bland.",
	"Got a bland hand-off today.",
	"bland line wait, no notes.",
	"Calling the soda side bland.",
	"My bun came out bland.",
	"Unexpectedly bland toppings.",
	"Lowkey bland cook.",
	"The smash was dull.",
	"Really dull burger.",
	"Honestly dull on the patty.",
	"That stack? dull.",
	"Got a dull window service today.",
	"dull truck stop, no notes.",
	"Calling the lunch dull.",
	"My bite came out dull.",
	"Unexpectedly dull build.",
	"Lowkey dull crust.",
	"The cheese pull was dull.",
	"Really dull ticket match.",
	"Honestly dull on the grill smell.",
	"That first bite? dull.",
	"Got a dull hand-off today.",
	"dull line wait, no notes.",
	"Calling the soda side dull.",
	"My bun came out dull.",
	"Unexpectedly dull toppings.",
	"Lowkey dull cook.",
	"The smash was weak.",
	"Really weak burger.",
	"Honestly weak on the patty.",
	"That stack? weak.",
	"Got a weak window service today.",
	"weak truck stop, no notes.",
	"Calling the lunch weak.",
	"My bite came out weak.",
	"Unexpectedly weak build.",
	"Lowkey weak crust.",
	"The cheese pull was weak.",
	"Really weak ticket match.",
	"Honestly weak on the grill smell.",
	"That first bite? weak.",
	"Got a weak hand-off today.",
	"weak line wait, no notes.",
	"Calling the soda side weak.",
	"My bun came out weak.",
	"Unexpectedly weak toppings.",
	"Lowkey weak cook.",
	"The smash was dry.",
	"Really dry burger.",
	"Honestly dry on the patty.",
	"That stack? dry.",
	"Got a dry window service today.",
	"dry truck stop, no notes.",
	"Calling the lunch dry.",
	"My bite came out dry.",
	"Unexpectedly dry build.",
	"Lowkey dry crust.",
	"The cheese pull was dry.",
	"Really dry ticket match.",
	"Honestly dry on the grill smell.",
	"That first bite? dry.",
	"Got a dry hand-off today.",
	"dry line wait, no notes.",
	"Calling the soda side dry.",
	"My bun came out dry.",
	"Unexpectedly dry toppings.",
	"Lowkey dry cook.",
	"The smash was slow.",
	"Really slow burger.",
	"Honestly slow on the patty.",
	"That stack? slow.",
	"Got a slow window service today.",
	"slow truck stop, no notes.",
	"Calling the lunch slow.",
	"My bite came out slow.",
	"Unexpectedly slow build.",
	"Lowkey slow crust.",
]

const _BODY_BAD: Array = [
	"Stood there forever watching the same patty flip while my stomach filed a complaint.",
	"Slow service, cold attitude, walked away hungrier than I arrived.",
	"Felt like they forgot customers exist until I was already leaving.",
	"Burnt edges, cold middle, zero apology.",
	"Chaos at the window, sadness on the plate.",
	"Wrong vibe, wrong cook, wrong day.",
	"Paid and regretted it.",
	"Line didn't move, patience did.",
	"One star is generous.",
	"Left mad in the lot.",
	"Food wasn't worth the wait or the mood.",
	"Grill looked abandoned.",
	"Hand-off felt hostile.",
	"I wanted a burger and got a story problem.",
	"Never matching ticket energy AND cold food.",
	"Embarrassing for a truck with a cute logo.",
	"Hunger + rage combo meal.",
	"Walked before it got worse.",
	"Service window of disappointment.",
	"Blocking after one visit.",
	"Do not recommend unless you enjoy suffering.",
	"The smash was awful.",
	"Really awful burger.",
	"Honestly awful on the patty.",
	"That stack? awful.",
	"Got a awful window service today.",
	"awful truck stop, no notes.",
	"Calling the lunch awful.",
	"My bite came out awful.",
	"Unexpectedly awful build.",
	"Lowkey awful crust.",
	"The cheese pull was awful.",
	"Really awful ticket match.",
	"Honestly awful on the grill smell.",
	"That first bite? awful.",
	"Got a awful hand-off today.",
	"awful line wait, no notes.",
	"Calling the soda side awful.",
	"My bun came out awful.",
	"Unexpectedly awful toppings.",
	"Lowkey awful cook.",
	"The smash was burnt.",
	"Really burnt burger.",
	"Honestly burnt on the patty.",
	"That stack? burnt.",
	"Got a burnt window service today.",
	"burnt truck stop, no notes.",
	"Calling the lunch burnt.",
	"My bite came out burnt.",
	"Unexpectedly burnt build.",
	"Lowkey burnt crust.",
	"The cheese pull was burnt.",
	"Really burnt ticket match.",
	"Honestly burnt on the grill smell.",
	"That first bite? burnt.",
	"Got a burnt hand-off today.",
	"burnt line wait, no notes.",
	"Calling the soda side burnt.",
	"My bun came out burnt.",
	"Unexpectedly burnt toppings.",
	"Lowkey burnt cook.",
	"The smash was cold.",
	"Really cold burger.",
	"Honestly cold on the patty.",
	"That stack? cold.",
	"Got a cold window service today.",
	"cold truck stop, no notes.",
	"Calling the lunch cold.",
	"My bite came out cold.",
	"Unexpectedly cold build.",
	"Lowkey cold crust.",
	"The cheese pull was cold.",
	"Really cold ticket match.",
	"Honestly cold on the grill smell.",
	"That first bite? cold.",
	"Got a cold hand-off today.",
	"cold line wait, no notes.",
	"Calling the soda side cold.",
	"My bun came out cold.",
	"Unexpectedly cold toppings.",
	"Lowkey cold cook.",
	"The smash was rude.",
	"Really rude burger.",
	"Honestly rude on the patty.",
	"That stack? rude.",
	"Got a rude window service today.",
	"rude truck stop, no notes.",
	"Calling the lunch rude.",
	"My bite came out rude.",
	"Unexpectedly rude build.",
	"Lowkey rude crust.",
	"The cheese pull was rude.",
	"Really rude ticket match.",
	"Honestly rude on the grill smell.",
	"That first bite? rude.",
	"Got a rude hand-off today.",
	"rude line wait, no notes.",
	"Calling the soda side rude.",
	"My bun came out rude.",
	"Unexpectedly rude toppings.",
	"Lowkey rude cook.",
	"The smash was chaotic.",
	"Really chaotic burger.",
	"Honestly chaotic on the patty.",
	"That stack? chaotic.",
	"Got a chaotic window service today.",
	"chaotic truck stop, no notes.",
	"Calling the lunch chaotic.",
	"My bite came out chaotic.",
	"Unexpectedly chaotic build.",
	"Lowkey chaotic crust.",
]

const _BODY_WRONG: Array = [
	"Had to explain the ticket twice like it was a courtroom exhibit.",
	"Wrong toppings, wrong vibe, shrugged at me through the glass.",
	"If you can't match an order, the whole truck falls apart.",
	"Build looked confident and completely incorrect.",
	"I pointed at the ticket. They pointed at vibes.",
	"Different stack, same price, worse mood.",
	"Mix-up with no fix.",
	"Wrong onion situation entirely.",
	"Cheese where pickles should be energy.",
	"Not my burger, not my stars.",
]

const _VIBE_GREAT: Array = [
	"Window energy was friendly without being fake.",
	"Felt like a neighborhood spot that accidentally went viral.",
	"The kind of truck you text a photo of before you take a bite.",
	"Crew hustled with good humor.",
	"Street vibe + hot smash = perfect lunch movie.",
	"I felt taken care of.",
]

const _VIBE_GOOD: Array = [
	"Vibe was chill, not chaotic.",
	"Nothing weird happened, which is rarer than it should be.",
	"Line moved okay for a lunch rush.",
	"Friendly enough, focused enough.",
	"Good neighborhood energy.",
	"Window felt professional.",
]

const _VIBE_OK: Array = [
	"Vibe was whatever.",
	"Neither warm nor cold service.",
	"Fine sidewalk energy.",
	"Cat watched. I ate. Life continued.",
	"No lore, just lunch.",
]

const _VIBE_MEH: Array = [
	"Vibe was sleepy.",
	"Interaction felt phoned in.",
	"Sidewalk chatter was more interesting than the food.",
	"Mood: shrugged.",
	"Energy dipped.",
]

const _VIBE_BAD: Array = [
	"Whole interaction felt dismissive.",
	"Chaotic in the annoying way, not the fun way.",
	"Left with main-character rage and zero fries of comfort.",
	"Hostile window weather.",
	"Bad vibes with a side of hunger.",
	"Never felt welcome.",
]

const _CLOSE_GREAT: Array = [
	"Instant favorite. Bringing my whole group next shift.",
	"Five stars isn't enough. Tell them a loud person on the internet sent you.",
	"Burger Pals forever. Already plotting the next order.",
	"If you're on the fence — just go.",
	"See you tomorrow.",
	"Bookmarking this truck.",
	"I'm ruined for other smash.",
	"Come hungry.",
]

const _CLOSE_GOOD: Array = [
	"I'd happily come back on a lunch break.",
	"Recommend to a friend who likes smash burgers.",
	"Leaving stars because short reviews never capture 'yeah I'd reorder.'",
	"Four stars, easy.",
	"Will return.",
	"Solid keep.",
	"Put it on your loop.",
	"Good stop.",
]

const _CLOSE_OK: Array = [
	"If they tighten the cook, they'll earn a fourth star from me.",
	"Decent. Room to grow.",
	"Not a disaster, not a revelation.",
	"Three feels honest.",
	"Maybe next time.",
	"Nearby? Sure. Destination? Not yet.",
	"Okay enough.",
	"Neutral forever.",
]

const _CLOSE_MEH: Array = [
	"Needs work.",
	"Come back when seasoning arrives.",
	"Two stars, moving on.",
	"Not rushing back.",
	"Fix the cook first.",
	"Meh stands.",
]

const _CLOSE_BAD: Array = [
	"Blocking this place and moving on.",
	"Fix the window or don't open it.",
	"One star. Do better.",
	"Never again until something changes.",
	"Hard pass.",
	"Stay away.",
	"Learn the grill.",
	"Gone.",
]

const _TIP_BITS: Array = [
	"Tipped hard on purpose — keep the truck alive.",
	"Left extra because that cook earned it.",
	"Tip was a thank-you, not pity.",
	"Threw cash because that slap deserved it.",
	"Tipped like I meant it.",
	"Extra tip for the crust alone.",
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
	"Cat tax: the window kitty approved with a slow blink.",
	"Street cat supervisor on duty.",
	"Mascot cat > half the reviews.",
	"Meow board of directors says hi.",
]

const _ROBBER_ASIDES: Array = [
	"Wild aside — someone in line kept whispering there's a robber on the loose near the strip? Cool lunch atmosphere.",
	"Heard two people arguing about a robber on the loose while I waited. Great. Love that for my nervous system.",
	"Not the burger's fault, but the 'robber on the loose' chatter from the sidewalk did NOT help my appetite.",
	"Sidewalk crime-podcast energy while I waited. Stars for smash, none for the lore.",
]

const _ROBBER_FULL: Array = [
	"Okay this is only half about the burger. While I was in line somebody said there's a robber on the loose around here and half the sidewalk went quiet. I still got my food (it was fine), but I ate it in the car with the doors locked like a sitcom. Stars for the smash. Zero stars for the crime-podcast ambiance.",
	"Review of the truck AND the neighborhood: burger arrived hot, toppings matched, cooks were hustling — AND two strangers were comparing notes about a robber on the loose like it was weather. I tipped anyway. Please hire that window cat as security.",
	"Got my smash, then overheard 'robber on the loose' like it was the special of the day. Ate in the car. Food was whatever the stars say — nerves were five-alarm.",
]
