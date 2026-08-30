# weapon_manager.gd
extends Node2D

signal active_weapon_changed(weapon_id: StringName)
signal weapon_switch_blocked(weapon_id: StringName, requirement: String)

# Weapon scenes assigned in the Inspector
@export var weapon_scenes: Array[PackedScene] = []

const SCENE_PATH_TO_ID := {
	"res://weapons/Knife.tscn": &"knife",
	"res://weapons/gun/Gun.tscn": &"gun",
	"res://weapons/lightning/ChainLightning.tscn": &"chain_lightning",
	"res://weapons/gravity/GravityBombWeapon.tscn": &"gravity_bomb",
}

const INPUT_TO_WEAPON_ID := {
	&"weapon_1": &"knife",
	&"weapon_2": &"gun",
	&"weapon_4": &"chain_lightning",
	&"weapon_5": &"gravity_bomb",
}

var weapons: Array[Node2D] = []
var weapon_ids: Array[StringName] = []
var active_index: int = -1
var active_weapon_id: StringName = &""
@onready var weapon_progress: Node = get_node("/root/WeaponProgress")

func _ready() -> void:
	# Instance every weapon once, keep them all as children
	for scene in weapon_scenes:
		var weapon := scene.instantiate() as Node2D
		if weapon == null:
			continue
		var weapon_id: StringName = SCENE_PATH_TO_ID.get(
			scene.resource_path,
			StringName(scene.resource_path.get_file().get_basename().to_snake_case())
		)
		add_child(weapon)
		weapons.append(weapon)
		weapon_ids.append(weapon_id)

	# Knife is the starter weapon.
	switch_to_weapon_id(&"knife", true)

func _process(_delta: float) -> void:
	# Slots are explicit: 1 Knife, 2 Gun, 4 Chain Lightning, 5 Gravity Bomb.
	for action in INPUT_TO_WEAPON_ID:
		if Input.is_action_just_pressed(action):
			var weapon_id: StringName = INPUT_TO_WEAPON_ID[action]
			if switch_to_weapon_id(weapon_id) and weapon_id == &"gravity_bomb":
				_trigger_manual_attack(weapon_id)

func switch_to(index: int) -> bool:
	if index < 0 or index >= weapons.size():
		return false
	return switch_to_weapon_id(weapon_ids[index])


func switch_to_weapon_id(weapon_id: StringName, force: bool = false) -> bool:
	var index := weapon_ids.find(weapon_id)
	if index < 0:
		return false
	if not force and not weapon_progress.is_weapon_unlocked(weapon_id):
		weapon_switch_blocked.emit(
			weapon_id,
			weapon_progress.get_requirement_text(weapon_id)
		)
		return false
	if index == active_index:
		return true

	active_index = index
	active_weapon_id = weapon_id
	_activate(index)
	active_weapon_changed.emit(weapon_id)
	return true


func get_weapon_id_for_action(action: StringName) -> StringName:
	return INPUT_TO_WEAPON_ID.get(action, &"")


func _trigger_manual_attack(weapon_id: StringName) -> void:
	var index := weapon_ids.find(weapon_id)
	if index < 0:
		return
	var weapon := weapons[index]
	if weapon.has_method("trigger_attack"):
		weapon.trigger_attack()

func _activate(index: int) -> void:
	# Enable only the active weapon; disable the rest
	for i in range(weapons.size()):
		var weapon = weapons[i]
		var is_active := (i == index)
		if weapon.has_method("set_active"):
			weapon.set_active(is_active)
