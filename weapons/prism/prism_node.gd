extends Node2D
class_name PrismNode

signal deployment_completed(prism: PrismNode)
signal collapse_completed(prism: PrismNode)

var deployed: bool = false
var collapsing: bool = false
var _visual_time: float = 0.0


func _process(delta: float) -> void:
	_visual_time += delta
	rotation += delta * (2.6 if not collapsing else 7.0)
	queue_redraw()


func deploy(start_position: Vector2, target_position: Vector2, duration: float) -> void:
	global_position = start_position
	scale = Vector2.ONE * 0.12
	modulate = Color(0.45, 0.75, 1.0, 0.0)
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "global_position", target_position, maxf(duration, 0.01)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "scale", Vector2.ONE, maxf(duration, 0.01)).set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)
	tween.tween_property(self, "modulate", Color.WHITE, maxf(duration * 0.65, 0.01))
	await tween.finished
	if not is_instance_valid(self) or collapsing:
		return
	deployed = true
	deployment_completed.emit(self)


func collapse_to(target_position: Vector2, duration: float) -> void:
	if collapsing:
		return
	collapsing = true
	deployed = false
	var tween := create_tween().set_parallel(true)
	tween.tween_property(self, "global_position", target_position, maxf(duration, 0.01)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "scale", Vector2.ONE * 0.08, maxf(duration, 0.01)).set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	tween.tween_property(self, "modulate", Color(1.5, 1.5, 2.0, 0.25), maxf(duration, 0.01))
	await tween.finished
	if is_instance_valid(self):
		collapse_completed.emit(self)


func flash() -> void:
	var tween := create_tween()
	tween.tween_property(self, "scale", Vector2.ONE * 1.35, 0.08)
	tween.tween_property(self, "scale", Vector2.ONE, 0.14)


func _draw() -> void:
	var breathe := 1.0 + sin(_visual_time * 5.0) * 0.12
	draw_circle(Vector2.ZERO, 21.0 * breathe, Color(0.18, 0.35, 1.0, 0.13))
	draw_circle(Vector2.ZERO, 14.0 * breathe, Color(0.28, 0.05, 0.75, 0.22))
	var diamond := PackedVector2Array([
		Vector2(0.0, -16.0),
		Vector2(11.0, 0.0),
		Vector2(0.0, 16.0),
		Vector2(-11.0, 0.0),
	])
	draw_colored_polygon(diamond, Color(0.34, 0.12, 0.95, 0.92))
	var outline := PackedVector2Array([
		diamond[0], diamond[1], diamond[2], diamond[3], diamond[0]
	])
	draw_polyline(outline, Color(0.88, 0.96, 1.0, 1.0), 2.5, true)
	draw_line(Vector2(0.0, -12.0), Vector2(0.0, 12.0), Color(0.45, 0.95, 1.0), 2.0, true)
	draw_arc(Vector2.ZERO, 25.0 * breathe, 0.0, TAU, 28, Color(0.35, 0.75, 1.0, 0.68), 1.5, true)
