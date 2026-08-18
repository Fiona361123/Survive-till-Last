@tool
# Huang Wan Jun 2204536
extends Area2D
class_name CollapsingBridgeSection

enum SectionState { READY, WARNING, COLLAPSED, REBUILDING }
enum BridgeDirection { E, N, S, W }

# Huang Wan Jun 2204536 - Each direction selects its matching broad bridge source.
const DIRECTION_SOURCE: Dictionary = {
	BridgeDirection.E: 0,
	BridgeDirection.N: 1,
	BridgeDirection.S: 2,
	BridgeDirection.W: 3,
}

@export var warning_duration: float = 3.0
@export var rebuild_delay: float = 5.0
# Huang Wan Jun 2204536 - Match each unstable section to its bridge direction.
@export_enum("E", "N", "S", "W") var bridge_direction: int = 0:
	set(value):
		bridge_direction = clampi(value, 0, 3)
		if is_node_ready():
			_apply_bridge_direction()
var state: SectionState = SectionState.READY

@onready var _bridge_tile: TileMapLayer = $BridgeTile
@onready var _gap_area: FallHazard = $GapArea
@onready var _warning_timer: Timer = $WarningTimer
@onready var _rebuild_timer: Timer = $RebuildTimer

var _base_tile_position := Vector2.ZERO
var _warning_elapsed := 0.0


func _ready() -> void:
	_base_tile_position = _bridge_tile.position
	_gap_area.monitoring = false
	_apply_bridge_direction()
	if Engine.is_editor_hint():
		return
	body_entered.connect(_on_trigger_body_entered)
	_warning_timer.timeout.connect(_on_warning_timer_timeout)
	_rebuild_timer.timeout.connect(_on_rebuild_timer_timeout)


func _apply_bridge_direction() -> void:
	var source_id: int = DIRECTION_SOURCE.get(bridge_direction, -1)
	if source_id < 0 or _bridge_tile.tile_set == null:
		return
	if not _bridge_tile.tile_set.has_source(source_id):
		return
	_bridge_tile.set_cell(Vector2i.ZERO, source_id, Vector2i.ZERO)


func configure_respawn_markers(left: Marker2D, right: Marker2D) -> void:
	_gap_area.configure_respawn_markers(left, right)


func _on_trigger_body_entered(body: Node2D) -> void:
	if state != SectionState.READY:
		return
	if not (body.is_in_group("player") or body.is_in_group("enemy") or body.is_in_group("level1_enemy")):
		return
	state = SectionState.WARNING
	_warning_elapsed = 0.0
	_warning_timer.start(warning_duration)


func _process(delta: float) -> void:
	if state != SectionState.WARNING:
		return
	_warning_elapsed += delta
	var flash_strength := (sin(_warning_elapsed * 20.0) + 1.0) * 0.5
	_bridge_tile.position = _base_tile_position + Vector2(sin(_warning_elapsed * 40.0) * 4.0, 0.0)
	_bridge_tile.modulate = Color(1.0, 1.0 - flash_strength * 0.45, 1.0 - flash_strength * 0.45)


func _on_warning_timer_timeout() -> void:
	if state != SectionState.WARNING:
		return
	state = SectionState.COLLAPSED
	_restore_bridge_tile()
	_bridge_tile.visible = false
	_bridge_tile.enabled = false
	_gap_area.monitoring = true
	for body in get_overlapping_bodies():
		if body is Node2D:
			_gap_area._on_body_entered(body)
	_rebuild_timer.start(rebuild_delay)


func _on_rebuild_timer_timeout() -> void:
	if state != SectionState.COLLAPSED:
		return
	state = SectionState.REBUILDING
	_gap_area.monitoring = false
	_gap_area.reset_handled_bodies()
	_bridge_tile.enabled = true
	_bridge_tile.visible = true
	_restore_bridge_tile()
	state = SectionState.READY


func _restore_bridge_tile() -> void:
	_bridge_tile.position = _base_tile_position
	_bridge_tile.modulate = Color.WHITE
