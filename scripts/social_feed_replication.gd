extends RefCounted
## Reliable post deltas. Texture objects never enter RPC payloads.
var sent: Dictionary = {}
var decoded: Dictionary = {}
var sent_photos: Dictionary = {}

func signature(post: Dictionary) -> Array:
	var pic = post.get("pic")
	return [post.get("stars", 0.0), post.get("who", ""), post.get("text", ""), post.get("reply", ""), post.get("reply_kind", ""), post.get("argue", ""), post.get("breakdown", {}).duplicate(true), pic.get_instance_id() if pic is Texture2D else 0]

func prepare_photo(post: Dictionary) -> void:
	var pic = post.get("pic")
	if not pic is Texture2D or not (post.get("pic_png", PackedByteArray()) as PackedByteArray).is_empty():
		return
	var image: Image = pic.get_image()
	if image == null:
		return
	if image.is_compressed():
		image.decompress()
	if image.get_width() > 96 or image.get_height() > 96:
		var factor := 96.0 / maxf(image.get_width(), image.get_height())
		image.resize(maxi(1, int(image.get_width() * factor)), maxi(1, int(image.get_height() * factor)), Image.INTERPOLATE_BILINEAR)
	post["pic_png"] = image.save_png_to_buffer()

func encode(post: Dictionary) -> Dictionary:
	var row := post.duplicate()
	row.erase("pic")
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
			var row := encode(post)
			var bytes: PackedByteArray = row.get("pic_png", PackedByteArray())
			if sent_photos.get(id, null) == bytes:
				row.erase("pic_png")
			else:
				sent_photos[id] = bytes
			upserts.append(row)
	for id in sent:
		if not current.has(id):
			removed.append(id)
			sent_photos.erase(id)
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
		if bytes.is_empty() and decoded.has(id):
			post["pic"] = decoded[id]["texture"]
		elif not bytes.is_empty():
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
