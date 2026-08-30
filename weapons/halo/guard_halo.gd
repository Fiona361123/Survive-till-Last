# guard_halo.gd
extends Node2D
class_name GuardHalo

# --- HALO STATE ---
enum HaloState {
	ACTIVE,
	BROKEN,
	RECHARGING
}

# --- HALO EVENTS ---
signal energy_changed(current: float, maximum: float)
signal state_changed(new_state: HaloState)
signal damage_blocked(amount: int)
signal halo_broken
signal halo_restored

# --- SHIELD ENERGY SETTINGS ---
@export var max_energy: float = 100.0
@export var recharge_rate: float = 20.0
@export var broken_delay: float = 3.0
@export var energy_cost_multiplier: float = 1.0
@export_range(0.0, 1.0, 0.05) var absorption_ratio: float = 0.30

# These values are initialized when the equipped Halo enters the scene.
var current_energy: float = 0.0
var state: HaloState = HaloState.ACTIVE

# --- ORBIT SETTINGS ---
@export var orb_scene: PackedScene
@export var orb_count: int = 3
@export var radius: float = 80.0
@export var rotation_speed: float = 2.5   # radians per second

var orbs: Array[HaloOrb] = []
var angle: float = 0.0

@onready var player = get_tree().get_first_node_in_group("player")
@onready var broken_timer: Timer = $BrokenTimer

func _ready() -> void:
	current_energy = max_energy
	_spawn_orbs()
	set_orbs_enabled(state == HaloState.ACTIVE)
	broken_timer.timeout.connect(_on_broken_timer_timeout)
	energy_changed.emit(current_energy, max_energy)
	state_changed.emit(state)

# All runtime state changes pass through this function so each state always
# applies the same visuals, processing rules, and signals.
func change_state(new_state: HaloState) -> void:
	if state == new_state:
		return

	state = new_state

	match state:
		HaloState.ACTIVE:
			_enter_active_state()
		HaloState.BROKEN:
			_enter_broken_state()
		HaloState.RECHARGING:
			_enter_recharging_state()

	state_changed.emit(state)

func _enter_active_state() -> void:
	broken_timer.stop()
	visible = true
	set_physics_process(true)
	set_orbs_enabled(true)
	_animate_orb_restore()
	_spawn_halo_pulse(Color(0.15, 0.85, 1.0), 28.0, 82.0, 0.45)
	halo_restored.emit()

func _enter_broken_state() -> void:
	_spawn_halo_pulse(Color(1.0, 0.12, 0.45), 32.0, 115.0, 0.5)
	visible = false
	set_physics_process(false)
	set_orbs_enabled(false)
	broken_timer.start(maxf(broken_delay, 0.01))
	halo_broken.emit()

func _enter_recharging_state() -> void:
	visible = false
	set_physics_process(false)
	set_orbs_enabled(false)

func break_halo() -> void:
	if state != HaloState.ACTIVE:
		return

	# Some energy-cost values can leave a fraction that is too small to block
	# one complete damage point. Breaking consumes that unusable remainder.
	if current_energy > 0.0:
		current_energy = 0.0
		energy_changed.emit(current_energy, max_energy)

	change_state(HaloState.BROKEN)

func _on_broken_timer_timeout() -> void:
	if state == HaloState.BROKEN:
		change_state(HaloState.RECHARGING)

func _process(delta: float) -> void:
	if state != HaloState.RECHARGING:
		return

	var energy_limit := maxf(max_energy, 0.0)
	var energy_gained := maxf(recharge_rate, 0.0) * delta
	var next_energy := minf(current_energy + energy_gained, energy_limit)

	if next_energy >= energy_limit:
		restore_halo()
		return

	if not is_equal_approx(next_energy, current_energy):
		current_energy = next_energy
		energy_changed.emit(current_energy, max_energy)

func restore_halo() -> void:
	if state != HaloState.RECHARGING:
		return

	current_energy = maxf(max_energy, 0.0)
	energy_changed.emit(current_energy, max_energy)
	change_state(HaloState.ACTIVE)

# Consumes shield energy and returns the damage that still reaches the player.
# While the Halo is not ACTIVE, incoming damage passes through unchanged.
func absorb_damage(incoming_damage: int) -> int:
	if incoming_damage <= 0:
		return 0

	if state != HaloState.ACTIVE:
		return incoming_damage

	# Calculate the portion this Halo is allowed to block. Damage is integer-
	# based, so round to the closest whole damage point.
	var desired_blocked_damage := roundi(
		float(incoming_damage) * absorption_ratio
	)
	if desired_blocked_damage <= 0:
		return incoming_damage

	# Prevent an invalid Inspector value from causing division by zero.
	var cost_per_damage := maxf(energy_cost_multiplier, 0.001)
	var energy_capacity := floori(current_energy / cost_per_damage)
	var blocked_damage := mini(
		desired_blocked_damage,
		energy_capacity
	)

	# If the remaining energy cannot fund one complete damage point, consume it
	# and break instead of leaving the Halo permanently active with unusable energy.
	if blocked_damage <= 0:
		break_halo()
		return incoming_damage

	var consumed_energy := float(blocked_damage) * cost_per_damage
	current_energy = maxf(0.0, current_energy - consumed_energy)
	var remaining_damage := maxi(0, incoming_damage - blocked_damage)

	energy_changed.emit(current_energy, max_energy)
	if blocked_damage > 0:
		damage_blocked.emit(blocked_damage)
		_play_block_effect()

	if current_energy <= 0.0:
		break_halo()

	return remaining_damage

func _spawn_orbs() -> void:
	for i in range(orb_count):
		var orb := orb_scene.instantiate() as HaloOrb
		if orb == null:
			push_warning("Guard Halo orb scene must use HaloOrb as its root script.")
			continue
		add_child(orb)
		orbs.append(orb)

func set_orbs_enabled(value: bool) -> void:
	for orb in orbs:
		if is_instance_valid(orb):
			orb.set_damage_enabled(value)

func _play_block_effect() -> void:
	_spawn_halo_pulse(Color(0.35, 0.92, 1.0), 28.0, 58.0, 0.22)
	for orb in orbs:
		if not is_instance_valid(orb):
			continue
		orb.modulate = Color(1.4, 1.7, 2.0, 1.0)
		var flash_tween := orb.create_tween()
		flash_tween.tween_property(orb, "modulate", Color.WHITE, 0.2)

func _animate_orb_restore() -> void:
	for i in range(orbs.size()):
		var orb := orbs[i]
		if not is_instance_valid(orb):
			continue

		orb.modulate = Color(1.0, 1.0, 1.0, 0.0)
		orb.scale = Vector2(0.35, 0.35)

		var restore_tween := orb.create_tween()
		restore_tween.tween_interval(float(i) * 0.08)
		restore_tween.tween_property(orb, "modulate:a", 1.0, 0.24)
		restore_tween.parallel().tween_property(orb, "scale", Vector2.ONE, 0.24) \
			.set_trans(Tween.TRANS_BACK).set_ease(Tween.EASE_OUT)

func _spawn_halo_pulse(
		color: Color,
		start_radius: float,
		end_radius: float,
		duration: float
	) -> void:
	var pulse_parent := get_tree().current_scene
	if pulse_parent == null or start_radius <= 0.0:
		return

	var pulse := Line2D.new()
	pulse.name = "HaloPulse"
	pulse.width = 4.0
	pulse.default_color = color
	pulse.closed = true
	pulse.antialiased = true
	pulse.z_index = 100

	var segment_count := 36
	for segment in range(segment_count):
		var pulse_angle := TAU * float(segment) / float(segment_count)
		pulse.add_point(Vector2.from_angle(pulse_angle) * start_radius)

	pulse_parent.add_child(pulse)
	pulse.global_position = global_position

	var pulse_tween := pulse.create_tween().set_parallel(true)
	var target_scale := maxf(end_radius / start_radius, 1.0)
	pulse_tween.tween_property(pulse, "scale", Vector2.ONE * target_scale, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_OUT)
	pulse_tween.tween_property(pulse, "modulate:a", 0.0, duration) \
		.set_trans(Tween.TRANS_QUAD).set_ease(Tween.EASE_IN)
	pulse_tween.chain().tween_callback(pulse.queue_free)

func _physics_process(delta: float) -> void:
	angle += rotation_speed * delta
	# position each orb evenly around the circle
	for i in range(orbs.size()):
		var offset_angle = angle + i * (TAU / orbs.size())
		var offset = Vector2(cos(offset_angle), sin(offset_angle)) * radius
		orbs[i].position = offset

# --- WeaponManager interface (same as knife & gun) ---
var active: bool = true

func set_active(value: bool) -> void:
	active = value
	visible = value
	set_physics_process(value)
	set_orbs_enabled(value and state == HaloState.ACTIVE)
