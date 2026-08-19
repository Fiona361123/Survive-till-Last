# weapon_manager.gd
extends Node2D

# Weapon scenes assigned in the Inspector
@export var weapon_scenes: Array[PackedScene] = []

var weapons: Array[Node2D] = []
var active_index: int = 0

func _ready() -> void:
	# Instance every weapon once, keep them all as children
	for scene in weapon_scenes:
		var weapon = scene.instantiate()
		add_child(weapon)
		weapons.append(weapon)
	_activate(active_index)

func _process(_delta: float) -> void:
	# Number keys 1..N switch weapon
	for i in range(weapons.size()):
		if Input.is_action_just_pressed("weapon_%d" % (i + 1)):
			switch_to(i)

func switch_to(index: int) -> void:
	if index < 0 or index >= weapons.size():
		return
	if index == active_index:
		return
	active_index = index
	_activate(index)

func _activate(index: int) -> void:
	# Enable only the active weapon; disable the rest
	for i in range(weapons.size()):
		var weapon = weapons[i]
		var is_active := (i == index)
		weapon.set_active(is_active)
