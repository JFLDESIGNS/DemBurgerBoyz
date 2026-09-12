extends RefCounted
## Reliable post deltas. Texture objects never enter RPC payloads.
var sent: Dictionary = {}
var decoded: Dictionary = {}

func signature(post: Dictionary) -> Array:
	var pic = post.get("pic")
	return [post.get("stars", 0.0), post.get("who", ""), post.get("text", ""), post.get("reply", ""), post.get("reply_kind", ""), post.get("argue", ""), post.get("breakdown", {}).duplicate(true), pic.get_instance_id() if pic is Texture2D else 0]

func encode(post: Dictionary) -> Dictionary:
	var row := post.duplicate()
	var pic = row.get("pic")
	row.erase("pic")
	if pic is Texture2D and (post.get("pic_png", PackedByteArray()) as PackedByteArray).is_empty():
		var image: Image = pic.get_image()
		if image != null:
			if image.is_compressed():
				image.decompress()
			post["pic_png"] = image.save_png_to_buffer()
	row["pic_png"] = post.get("pic_png", PackedByteArray())
	return row

func build_delta(posts: Array) -> Dictionary:
	var current := {}
	var upserts: Array = []
	var removed: Array = []
	for post in posts:
		var id := int(post.get("id", 0))
		var state := signature(post)
		current[id] = state
		if not sent.has(id) or sent[id] != state:
			upserts.append(encode(post))
	for id in sent:
		if not current.has(id):
			removed.append(id)
	sent = current
	return {"upserts": upserts, "removed": removed}

func apply_delta(posts: Array, upserts: Array, removed: Array, reset: bool = false) -> Array:
	var by_id := {}
	if not reset:
		for post in posts:
			by_id[int(post.get("id", 0))] = post
	for id in removed:
		by_id.erase(int(id))
		decoded.erase(int(id))
	for row in upserts:
		var post: Dictionary = row.duplicate()
		var id := int(post.get("id", 0))
		var bytes: PackedByteArray = post.get("pic_png", PackedByteArray())
		if not bytes.is_empty():
			var cached: Dictionary = decoded.get(id, {})
			if cached.get("bytes", PackedByteArray()) == bytes and cached.has("texture"):
				post["pic"] = cached["texture"]
			else:
				var image := Image.new()
				if image.load_png_from_buffer(bytes) == OK:
					post["pic"] = ImageTexture.create_from_image(image)
					decoded[id] = {"bytes": bytes, "texture": post["pic"]}
		by_id[id] = post
	var ids: Array = by_id.keys()
	ids.sort()
	ids.reverse()
	var result: Array = []
	var retained := {}
	for id in ids.slice(0, 200):
		result.append(by_id[id])
		retained[id] = true
	for id in decoded.keys():
		if not retained.has(id):
			decoded.erase(id)
	return result
