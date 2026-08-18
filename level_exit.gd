extends Area2D

signal level_entered(level_number: int)

@export_range(2, 99, 1) var target_level: int = 2
var unlocked: bool = false
var entry_triggered: bool = false


func lock_exit() -> void:
	unlocked = false
	entry_triggered = false


func unlock_exit() -> void:
	unlocked = true


func _on_body_entered(body: Node2D) -> void:
	if not unlocked or entry_triggered:
		return

	if not body.is_in_group("player"):
		return

	entry_triggered = true
	level_entered.emit(target_level)
