# guard_halo.gd
extends Node2D

@export var orb_scene: PackedScene
@export var orb_count: int = 3
@export var radius: float = 80.0
@export var rotation_speed: float = 2.5   # radians per second

var orbs: Array[Node2D] = []
var angle: float = 0.0

@onready var player = get_tree().get_first_node_in_group("player")

func _ready() -> void:
	_spawn_orbs()

func _spawn_orbs() -> void:
	for i in range(orb_count):
		var orb = orb_scene.instantiate()
		add_child(orb)
		orbs.append(orb)

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
