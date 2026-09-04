class_name SpikeRow
extends Node2D

signal activation_finished

enum State { SAFE, WARNING, ACTIVE }

@export var warning_duration: float = 0.7
@export var active_duration: float = 0.8
@export var damage: int = 20

var state: State = State.SAFE
var _activation_serial: int = 0

@onready var warning_polygon: Polygon2D = $WarningPolygon
@onready var spike_polygon: Polygon2D = $SpikePolygon
@onready var damage_area: TrapDamageArea = $TrapDamageArea


func _ready() -> void:
	_set_safe_visuals()
	damage_area.body_entered.connect(_on_damage_body_entered)


func activate() -> void:
	if state != State.SAFE:
		return
	_activation_serial += 1
	var serial := _activation_serial
	state = State.WARNING
	warning_polygon.visible = true
	spike_polygon.visible = false
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
	warning_polygon.visible = false
	spike_polygon.visible = true
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
	if warning_polygon != null:
		warning_polygon.visible = false
	if spike_polygon != null:
		spike_polygon.visible = false
