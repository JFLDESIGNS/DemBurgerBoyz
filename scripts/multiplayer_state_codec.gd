extends RefCounted
## Sparse array patches with ordered revisions and periodic complete recovery.
var sent: Dictionary = {}
var received: Dictionary = {}
var revisions: Dictionary = {}
var received_revisions: Dictionary = {}
var last_full: Dictionary = {}

func reset() -> void:
	sent.clear()
	received.clear()
	revisions.clear()
	received_revisions.clear()
	last_full.clear()

func quantized(value: Variant) -> Variant:
	if value is float:
		return snappedf(value, 0.01)
	if value is Array:
		var result: Array = []
		for item in value:
			result.append(quantized(item))
		return result
	if value is Dictionary:
		var result := {}
		for key in value:
			result[key] = quantized(value[key])
		return result
	return value

func patch(before: Variant, after: Variant) -> Dictionary:
	if before == after:
		return {}
	if before is Array and after is Array and before.size() == after.size():
		var changes := {}
		for i in after.size():
			var change := patch(before[i], after[i])
			if not change.is_empty():
				changes[i] = change
		return {"a": changes}
	return {"v": after}

func apply_patch_value(before: Variant, changes: Dictionary) -> Variant:
	if changes.has("v"):
		return changes["v"]
	var result: Array = before.duplicate()
	for index in changes.get("a", {}):
		if int(index) < 0 or int(index) >= result.size():
			return null
		result[int(index)] = apply_patch_value(result[int(index)], changes["a"][index])
	return result

func encode(topic: String, values: Array, force_full: bool = false) -> Dictionary:
	var now := Time.get_ticks_msec()
	var data: Array = quantized(values)
	var full := force_full or not sent.has(topic) or now - int(last_full.get(topic, 0)) >= 5000
	var changes := {"v": data} if full else patch(sent[topic], data)
	if changes.is_empty():
		return {}
	var previous := int(revisions.get(topic, 0))
	revisions[topic] = previous + 1
	sent[topic] = data
	if full:
		last_full[topic] = now
	return {"rev": previous + 1, "base": previous, "full": full, "patch": changes}

func decode(topic: String, packet: Dictionary) -> Array:
	var revision := int(packet.get("rev", -1))
	if revision < int(received_revisions.get(topic, -1)) or (revision == int(received_revisions.get(topic, -1)) and not bool(packet.get("repair", false))):
		return []
	if not bool(packet.get("full", false)) and (not received.has(topic) or int(packet.get("base", -2)) != int(received_revisions.get(topic, -1))):
		return []
	var value: Variant = apply_patch_value(received.get(topic, []), packet.get("patch", {}))
	if not value is Array:
		return []
	received[topic] = value
	received_revisions[topic] = revision
	return value
