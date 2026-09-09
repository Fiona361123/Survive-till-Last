extends Node2D

var shoot_animation_calls: int = 0
var cancel_shoot_animation_calls: int = 0


func play_shoot_animation() -> void:
	shoot_animation_calls += 1


func cancel_shoot_animation() -> void:
	cancel_shoot_animation_calls += 1
