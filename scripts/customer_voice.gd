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
	var identity := str(preset.get("name", ""))
	var index := absi(identity.hash()) if not identity.is_empty() else absi(fallback)
	return "female" if index % 2 else "male"
static func stream(voice: String, eating: bool) -> AudioStream:
	var key := ("female" if voice == "female" else "male") + ("_eat" if eating else "_talk")
	if not streams.has(key): streams[key] = load(PATHS[key]) as AudioStream
	return streams[key] as AudioStream
