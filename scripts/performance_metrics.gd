extends RefCounted
## Bounded debug sampling. Percentiles are computed only when a report is requested.
const CAPACITY := 1200
var frame_ms := PackedFloat64Array()
var script_ms := PackedFloat64Array()
var cursor := 0
var count := 0
func _init() -> void:
	frame_ms.resize(CAPACITY)
	script_ms.resize(CAPACITY)
func record(delta: float, usec: int) -> void:
	frame_ms[cursor] = delta * 1000.0
	script_ms[cursor] = float(usec) / 1000.0
	cursor = (cursor + 1) % CAPACITY
	count = mini(count + 1, CAPACITY)
func distribution(values: PackedFloat64Array) -> Dictionary:
	if count == 0:
		return {}
	var sorted := values.slice(0, count)
	sorted.sort()
	return {"p50_ms": sorted[int((count - 1) * 0.5)], "p95_ms": sorted[int((count - 1) * 0.95)], "p99_ms": sorted[int((count - 1) * 0.99)], "max_ms": sorted[count - 1]}
func report() -> Dictionary:
	return {"samples": count, "frame": distribution(frame_ms), "game_script": distribution(script_ms), "draw_calls": Performance.get_monitor(Performance.RENDER_TOTAL_DRAW_CALLS_IN_FRAME), "static_memory_bytes": Performance.get_monitor(Performance.MEMORY_STATIC), "video_memory_bytes": Performance.get_monitor(Performance.RENDER_VIDEO_MEM_USED)}
