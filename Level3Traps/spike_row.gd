@tool
class_name SpikeRow
extends Node2D

signal activation_finished

enum State { SAFE, WARNING, ACTIVE }

@export var warning_duration: float = 0.7
@export var active_duration: float = 0.8
@export var damage: int = 20
@export_range(1, 6, 1) var tile_count: int = 3
@export var tile_step: Vector2 = Vector2(128, -64)

var state: State = State.SAFE
var _activation_serial: int = 0

@onready var warning_tiles: Node2D = $WarningTiles
@onready var spike_tiles: Node2D = $SpikeTiles
@onready var damage_area: TrapDamageArea = $TrapDamageArea

const TILE_DIAMOND := PackedVector2Array([
	Vector2(-128, 0), Vector2(0, -64), Vector2(128, 0), Vector2(0, 64),
])
const WARNING_COLOR := Color(0.9, 0.26, 0.12, 0.48)
const SPIKE_BASE_COLOR := Color(0.34, 0.24, 0.16, 0.88)
const SPIKE_COLOR := Color(0.78, 0.72, 0.6, 1.0)
const SPIKE_SHADOW_COLOR := Color(0.38, 0.34, 0.29, 1.0)


func _ready() -> void:
	_build_isometric_tiles()
	if Engine.is_editor_hint():
		warning_tiles.visible = false
		spike_tiles.visible = true
		return
	_set_safe_visuals()
	damage_area.body_entered.connect(_on_damage_body_entered)


func activate() -> void:
	if state != State.SAFE:
		return
	_activation_serial += 1
	var serial := _activation_serial
	state = State.WARNING
	warning_tiles.visible = true
	spike_tiles.visible = false
	_run_activation(serial)


func force_safe() -> void:
	_activation_serial += 1
	damage_area.end_activation()
	state = State.SAFE
	_set_safe_visuals()


func _run_activation(serial: int) -> void:
	await get_tree().create_timer(maxf(warning_duration, 0.0)).timeout
	if serial != _activation_serial or state != State.WARNING:
		return
	state = State.ACTIVE
	warning_tiles.visible = false
	spike_tiles.visible = true
	damage_area.begin_activation(damage)
	damage_area.damage_overlapping_bodies()
	await get_tree().create_timer(maxf(active_duration, 0.0)).timeout
	if serial != _activation_serial or state != State.ACTIVE:
		return
	damage_area.end_activation()
	state = State.SAFE
	_set_safe_visuals()
	activation_finished.emit()


func _on_damage_body_entered(body: Node2D) -> void:
	if state == State.ACTIVE:
		damage_area.damage_overlapping_bodies()


func _set_safe_visuals() -> void:
	if warning_tiles != null:
		warning_tiles.visible = false
	if spike_tiles != null:
		spike_tiles.visible = false


func _build_isometric_tiles() -> void:
	_clear_generated_children(warning_tiles)
	_clear_generated_children(spike_tiles)
	_clear_generated_children(damage_area)
	for tile_index in tile_count:
		var tile_position := tile_step * tile_index
		warning_tiles.add_child(_make_polygon(
			"WarningTile%d" % tile_index, TILE_DIAMOND, WARNING_COLOR, tile_position
		))
		spike_tiles.add_child(_make_spike_cluster(tile_index, tile_position))
		var collision := CollisionPolygon2D.new()
		collision.name = "TileHitArea%d" % tile_index
		collision.position = tile_position
		collision.polygon = TILE_DIAMOND
		damage_area.add_child(collision)


func _make_spike_cluster(tile_index: int, tile_position: Vector2) -> Node2D:
	var cluster := Node2D.new()
	cluster.name = "SpikeTile%d" % tile_index
	cluster.position = tile_position
	cluster.add_child(_make_polygon("Base", TILE_DIAMOND, SPIKE_BASE_COLOR, Vector2.ZERO))
	var spike_positions := [
		Vector2(-58, 11), Vector2(0, -22), Vector2(58, 11),
		Vector2(-24, 29), Vector2(24, 29),
	]
	for spike_index in spike_positions.size():
		var spike := _make_polygon(
			"Spike%d" % spike_index,
			PackedVector2Array([Vector2(-18, 8), Vector2(0, -43), Vector2(18, 8)]),
			SPIKE_COLOR,
			spike_positions[spike_index]
		)
		cluster.add_child(spike)
		var shadow := _make_polygon(
			"SpikeShadow%d" % spike_index,
			PackedVector2Array([Vector2(0, -43), Vector2(18, 8), Vector2(4, 5)]),
			SPIKE_SHADOW_COLOR,
			spike_positions[spike_index]
		)
		cluster.add_child(shadow)
	return cluster


func _make_polygon(
	node_name: String, points: PackedVector2Array, color: Color, node_position: Vector2
) -> Polygon2D:
	var polygon := Polygon2D.new()
	polygon.name = node_name
	polygon.polygon = points
	polygon.color = color
	polygon.position = node_position
	return polygon


func _clear_generated_children(parent: Node) -> void:
	for child in parent.get_children():
		parent.remove_child(child)
		child.queue_free()
