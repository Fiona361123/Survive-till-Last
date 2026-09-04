class_name FireSweep
extends Node2D

signal sweep_finished

enum State { SAFE, WARNING, ACTIVE }

@export var warning_duration: float = 0.7
@export var travel_duration: float = 0.8
@export var damage: int = 20

var state: State = State.SAFE
var _sweep_serial: int = 0
var _travel_tween: Tween

@onready var warning_strip: Polygon2D = $WarningStrip
@onready var fire_graphics: Polygon2D = $FireGraphics
@onready var damage_area: TrapDamageArea = $TrapDamageArea


func _ready() -> void:
	_set_safe_visuals()


func sweep(from: Vector2, to: Vector2) -> void:
	if state != State.SAFE:
		return
	_sweep_serial += 1
	var serial := _sweep_serial
	position = from
	var direction := to - from
	var length := direction.length()
	if length > 0.001:
		rotation = direction.angle()
		warning_strip.scale.x = length / 96.0
		fire_graphics.scale.x = length / 96.0
	state = State.WARNING
	warning_strip.visible = true
	fire_graphics.visible = false
	await get_tree().create_timer(maxf(warning_duration, 0.0)).timeout
	if serial != _sweep_serial or state != State.WARNING:
		return
	state = State.ACTIVE
	warning_strip.visible = false
	fire_graphics.visible = true
	damage_area.begin_activation(damage)
	damage_area.damage_overlapping_bodies()
	_travel_tween = create_tween().set_trans(Tween.TRANS_LINEAR)
	_travel_tween.tween_property(self, "position", to, maxf(travel_duration, 0.0))
	while _travel_tween.is_running():
		await get_tree().physics_frame
		if serial != _sweep_serial or state != State.ACTIVE:
			return
		damage_area.damage_overlapping_bodies()
	if serial != _sweep_serial or state != State.ACTIVE:
		return
	position = to
	damage_area.end_activation()
	state = State.SAFE
	_set_safe_visuals()
	sweep_finished.emit()


func force_safe() -> void:
	_sweep_serial += 1
	if _travel_tween != null and _travel_tween.is_running():
		_travel_tween.kill()
	damage_area.end_activation()
	state = State.SAFE
	_set_safe_visuals()


func _set_safe_visuals() -> void:
	if warning_strip != null:
		warning_strip.visible = false
	if fire_graphics != null:
		fire_graphics.visible = false
