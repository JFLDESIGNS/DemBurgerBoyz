extends RefCounted
const PATHS = {
	"male_eat": "res://sounds/malenumnum.wav",
	"female_eat": "res://sounds/femalenomnom.wav",
	"male_talk": "res://sounds/wawawa.ogg",
	"female_talk": "res://sounds/femalewawawa.wav",
}
static var streams: Dictionary = {}
static func resolve(preset: Dictionary, fallback: int = 0) -> String:
	var selected := str(preset.get("customer_voice", ""))
	if selected in ["male", "female"]: return selected
	# Older presets predate the voice selector; never assign voices by name hash.
	var identity := str(preset.get("name", "")).strip_edges().to_lower()
	if identity.begins_with("woman") or identity in ["rowan", "char1", "char2", "char33"]: return "female"
	if identity.begins_with("man") or int(preset.get("facial_hair_style", 0)) > 0: return "male"
	var gender := str(preset.get("gender", "")).to_lower()
	if gender in ["male", "female"]: return gender
	# Explicit Kenney skin slots: three female skins, all BTS skins male.
	return "female" if fallback in [1, 3, 5] else "male"
static func stream(voice: String, eating: bool) -> AudioStream:
	var key := ("female" if voice == "female" else "male") + ("_eat" if eating else "_talk")
	if not streams.has(key): streams[key] = load(PATHS[key]) as AudioStream
	return streams[key] as AudioStream
