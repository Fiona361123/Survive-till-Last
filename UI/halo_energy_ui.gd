extends Control
class_name HaloEnergyUI

@onready var frame: PanelContainer = $Frame
@onready var icon: Label = $Frame/Margin/Row/IconPanel/Icon
@onready var state_label: Label = $Frame/Margin/Row/Info/Header/StateLabel
@onready var energy_bar: ProgressBar = $Frame/Margin/Row/Info/EnergyBar
@onready var energy_label: Label = $Frame/Margin/Row/Info/Footer/EnergyLabel

var bound_halo: GuardHalo = null
var _base_frame_style: StyleBoxFlat
var _base_fill_style: StyleBoxFlat
var _displayed_state: GuardHalo.HaloState = GuardHalo.HaloState.ACTIVE
var _recharge_pulse_time: float = 0.0
var _rest_position: Vector2
var _feedback_tween: Tween = null

func _ready() -> void:
	_base_frame_style = frame.get_theme_stylebox("panel").duplicate() as StyleBoxFlat
	_base_fill_style = energy_bar.get_theme_stylebox("fill").duplicate() as StyleBoxFlat
	_rest_position = position
	visible = false

func _process(delta: float) -> void:
	if _displayed_state == GuardHalo.HaloState.RECHARGING:
		_recharge_pulse_time += delta * 4.0
		var pulse_alpha := 0.72 + sin(_recharge_pulse_time) * 0.18
		energy_bar.modulate = Color(1.0, 1.0, 1.0, pulse_alpha)
		icon.modulate = Color(1.0, 1.0, 1.0, pulse_alpha)
	else:
		_recharge_pulse_time = 0.0
		energy_bar.modulate = Color.WHITE
		icon.modulate = Color.WHITE

func bind_to_halo(halo: GuardHalo) -> void:
	if halo == null:
		return

	_unbind_current_halo()
	bound_halo = halo

	bound_halo.energy_changed.connect(_on_energy_changed)
	bound_halo.state_changed.connect(_on_state_changed)
	bound_halo.damage_blocked.connect(_on_damage_blocked)
	bound_halo.tree_exited.connect(_on_halo_removed)

	visible = true
	_on_energy_changed(bound_halo.current_energy, bound_halo.max_energy)
	_on_state_changed(bound_halo.state)

func _unbind_current_halo() -> void:
	if not is_instance_valid(bound_halo):
		bound_halo = null
		return

	if bound_halo.energy_changed.is_connected(_on_energy_changed):
		bound_halo.energy_changed.disconnect(_on_energy_changed)
	if bound_halo.state_changed.is_connected(_on_state_changed):
		bound_halo.state_changed.disconnect(_on_state_changed)
	if bound_halo.damage_blocked.is_connected(_on_damage_blocked):
		bound_halo.damage_blocked.disconnect(_on_damage_blocked)
	if bound_halo.tree_exited.is_connected(_on_halo_removed):
		bound_halo.tree_exited.disconnect(_on_halo_removed)

	bound_halo = null

func _on_energy_changed(current: float, maximum: float) -> void:
	var safe_maximum := maxf(maximum, 1.0)
	energy_bar.max_value = safe_maximum
	energy_bar.value = clampf(current, 0.0, safe_maximum)
	energy_label.text = "%d / %d" % [roundi(current), roundi(maximum)]

func _on_state_changed(new_state: GuardHalo.HaloState) -> void:
	_displayed_state = new_state
	match new_state:
		GuardHalo.HaloState.ACTIVE:
			state_label.text = "ACTIVE"
			icon.text = "✦"
			_apply_colors(
				Color(0.15, 0.85, 1.0),
				Color(0.02, 0.65, 0.95),
				Color(0.72, 0.95, 1.0)
			)
			_flash_frame(Color(0.55, 0.95, 1.0))
		GuardHalo.HaloState.BROKEN:
			state_label.text = "BROKEN"
			icon.text = "◆"
			_apply_colors(
				Color(0.95, 0.15, 0.48),
				Color(0.35, 0.03, 0.12),
				Color(1.0, 0.42, 0.62)
			)
			_play_impact_shake(8.0)
		GuardHalo.HaloState.RECHARGING:
			state_label.text = "RECHARGING"
			icon.text = "◇"
			_apply_colors(
				Color(0.48, 0.45, 1.0),
				Color(0.18, 0.32, 0.82),
				Color(0.72, 0.72, 1.0)
			)
			_flash_frame(Color(0.68, 0.62, 1.0))

func _apply_colors(accent: Color, fill: Color, text_color: Color) -> void:
	var frame_style := _base_frame_style.duplicate() as StyleBoxFlat
	frame_style.border_color = accent
	frame.add_theme_stylebox_override("panel", frame_style)

	var fill_style := _base_fill_style.duplicate() as StyleBoxFlat
	fill_style.bg_color = fill
	energy_bar.add_theme_stylebox_override("fill", fill_style)

	icon.add_theme_color_override("font_color", accent)
	icon.add_theme_color_override("font_shadow_color", Color(accent, 0.55))
	state_label.add_theme_color_override("font_color", text_color)

func _on_damage_blocked(amount: int) -> void:
	state_label.text = "BLOCKED %d" % amount
	_play_impact_shake(4.0)

	var state_restore_timer := get_tree().create_timer(0.55)
	state_restore_timer.timeout.connect(func() -> void:
		if is_instance_valid(bound_halo):
			_on_state_changed(bound_halo.state)
	)

func _play_impact_shake(strength: float) -> void:
	if is_instance_valid(_feedback_tween):
		_feedback_tween.kill()

	position = _rest_position
	_feedback_tween = create_tween()
	_feedback_tween.tween_property(self, "position", _rest_position + Vector2(strength, 0.0), 0.04)
	_feedback_tween.tween_property(self, "position", _rest_position + Vector2(-strength, 0.0), 0.05)
	_feedback_tween.tween_property(self, "position", _rest_position + Vector2(strength * 0.5, 0.0), 0.04)
	_feedback_tween.tween_property(self, "position", _rest_position, 0.05)

func _flash_frame(color: Color) -> void:
	frame.modulate = color
	var flash_tween := frame.create_tween()
	flash_tween.tween_property(frame, "modulate", Color.WHITE, 0.32)

func _on_halo_removed() -> void:
	if is_instance_valid(_feedback_tween):
		_feedback_tween.kill()
	position = _rest_position
	bound_halo = null
	visible = false
