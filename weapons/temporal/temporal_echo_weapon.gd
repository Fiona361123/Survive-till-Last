extends Node2D
class_name TemporalEchoWeapon

signal echo_created(echo: TemporalEcho)
signal activation_failed(reason: String)

@export var damage_per_tick: int = 10
@export var attack_cooldown: float = 6.0
@export var record_duration: float = 3.0
@export var sample_interval: float = 0.05
@export var minimum_recording_time: float = 0.15
@export var echo_scene: PackedScene

var snapshots: Array[Dictionary] = []
var recording_time: float = 0.0
var sample_timer: float = 0.0
var cooldown_left: float = 0.0
var active: bool = true
var player: Node2D = null
var player_sprite: AnimatedSprite2D = null


func _ready() -> void:
	add_to_group("weapon")
	player = _find_player()
	player_sprite = _find_player_sprite()
	_record_snapshot()


# Recording intentionally uses _process instead of _physics_process. Unlike the
# other weapons, it must keep collecting history while another weapon is active.
func _process(delta: float) -> void:
	cooldown_left = maxf(0.0, cooldown_left - delta)
	if not _can_record_player():
		return

	recording_time += delta
	sample_timer += delta
	var interval := maxf(sample_interval, 0.001)
	if sample_timer < interval:
		return

	# One current-position snapshot is enough even after a long frame. Recording
	# several identical positions would add data without improving the replay.
	sample_timer = fmod(sample_timer, interval)
	_record_snapshot()
	_remove_expired_snapshots()


func _can_record_player() -> bool:
	if not is_instance_valid(player) or not player.is_inside_tree():
		player = _find_player()
	if not is_instance_valid(player):
		return false
	if not is_instance_valid(player_sprite):
		player_sprite = _find_player_sprite()
	if "current_hp" in player and int(player.get("current_hp")) <= 0:
		return false
	return true


func _find_player() -> Node2D:
	var grouped_player := get_tree().get_first_node_in_group("player") as Node2D
	if grouped_player != null:
		return grouped_player

	# Weapon children enter the tree before Player._ready() adds its group. Walk
	# upward so recording can begin during that first initialization frame.
	var ancestor := get_parent()
	while ancestor != null:
		if ancestor is Node2D and ("current_hp" in ancestor or "last_direction" in ancestor):
			return ancestor as Node2D
		ancestor = ancestor.get_parent()
	return null


func _find_player_sprite() -> AnimatedSprite2D:
	if not is_instance_valid(player):
		return null
	return player.get_node_or_null("AnimatedSprite2D") as AnimatedSprite2D


func _record_snapshot() -> void:
	if not is_instance_valid(player):
		return
	var snapshot := {
		"time": recording_time,
		"position": player.global_position,
		"animation": &"",
		"frame": 0,
		"frame_progress": 0.0,
		"flip_h": false,
		"sprite_position": Vector2.ZERO,
	}
	if is_instance_valid(player_sprite):
		snapshot["animation"] = player_sprite.animation
		snapshot["frame"] = player_sprite.frame
		snapshot["frame_progress"] = player_sprite.frame_progress
		snapshot["flip_h"] = player_sprite.flip_h
		snapshot["sprite_position"] = player_sprite.position
	snapshots.append(snapshot)


func _remove_expired_snapshots() -> void:
	var cutoff := recording_time - maxf(record_duration, 0.0)
	while snapshots.size() > 2 and float(snapshots[0].get("time", 0.0)) < cutoff:
		snapshots.pop_front()


func get_recorded_duration() -> float:
	if snapshots.size() < 2:
		return 0.0
	return maxf(
		0.0,
		float(snapshots[-1].get("time", 0.0))
			- float(snapshots[0].get("time", 0.0))
	)


func trigger_attack() -> void:
	if not active:
		activation_failed.emit("TEMPORAL ECHO IS NOT ACTIVE")
		return
	if cooldown_left > 0.0:
		activation_failed.emit("TEMPORAL ECHO IS RECHARGING")
		return
	if echo_scene == null:
		activation_failed.emit("TEMPORAL ECHO SCENE IS MISSING")
		return
	if snapshots.size() < 2 or get_recorded_duration() < minimum_recording_time:
		activation_failed.emit("NOT ENOUGH MOVEMENT HISTORY")
		return

	var echo := echo_scene.instantiate() as TemporalEcho
	if echo == null:
		activation_failed.emit("TEMPORAL ECHO SCENE IS INVALID")
		return

	var scene_tree := get_tree()
	var spawn_parent: Node = scene_tree.current_scene
	if spawn_parent == null:
		spawn_parent = scene_tree.root
	spawn_parent.add_child(echo)
	echo.begin_replay(snapshots.duplicate(true), damage_per_tick, player_sprite)
	cooldown_left = attack_cooldown
	echo_created.emit(echo)


func set_active(value: bool) -> void:
	active = value
	visible = value
	# Do not disable _process here: the rolling history must be available at the
	# moment key 6 switches to this weapon.
