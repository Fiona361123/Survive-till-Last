class_name RockStrike
extends Node2D

signal strike_finished

enum State { SAFE, WARNING, IMPACT }

@export var warning_duration: float = 0.9
@export var impact_duration: float = 0.35
@export var damage: int = 20

var state: State = State.SAFE
var _strike_serial: int = 0

@onready var warning_circle: Polygon2D = $WarningCircle
@onready var rock_graphics: Node2D = $RockGraphics
@onready var impact_graphics: Polygon2D = $ImpactGraphics
@onready var damage_area: TrapDamageArea = $TrapDamageArea


func _ready() -> void:
	_set_safe_visuals()


func strike_at(target: Vector2) -> void:
	if state != State.SAFE:
		return
	_strike_serial += 1
	var serial := _strike_serial
	global_position = target
	state = State.WARNING
	warning_circle.visible = true
	rock_graphics.visible = false
	impact_graphics.visible = false
	await get_tree().create_timer(maxf(warning_duration, 0.0)).timeout
	if serial != _strike_serial or state != State.WARNING:
		return
	state = State.IMPACT
	warning_circle.visible = false
	rock_graphics.visible = true
	impact_graphics.visible = true
	damage_area.begin_activation(damage)
	# Monitoring updates its overlap list on the physics step after activation.
	await get_tree().physics_frame
	if serial != _strike_serial or state != State.IMPACT:
		return
	damage_area.damage_overlapping_bodies()
	await get_tree().create_timer(maxf(impact_duration, 0.0)).timeout
	if serial != _strike_serial or state != State.IMPACT:
		return
	damage_area.end_activation()
	state = State.SAFE
	_set_safe_visuals()
	strike_finished.emit()


func force_safe() -> void:
	_strike_serial += 1
	damage_area.end_activation()
	state = State.SAFE
	_set_safe_visuals()


func _set_safe_visuals() -> void:
	if warning_circle != null:
		warning_circle.visible = false
	if rock_graphics != null:
		rock_graphics.visible = false
	if impact_graphics != null:
		impact_graphics.visible = false
