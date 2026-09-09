extends SceneTree

const WEAPON_DAMAGE = preload("res://systems/weapon_damage.gd")

var failures: int = 0


func _initialize() -> void:
	await process_frame
	var stage := Node2D.new()
	stage.set_script(load("res://tests/final_boss_stage_stub.gd"))
	root.add_child(stage)
	current_scene = stage

	_expect(WEAPON_DAMAGE.calculate(30, stage) == 30,
		"weapon damage is unchanged before the boss room is entered")
	stage.final_boss_damage_bonus_active = true
	_expect(WEAPON_DAMAGE.calculate(30, stage) == 45,
		"Knife and Gun damage increase from thirty to forty-five")
	_expect(WEAPON_DAMAGE.calculate(15, stage) == 23,
		"Chain Lightning damage increases from fifteen to twenty-three")
	_expect(WEAPON_DAMAGE.calculate(15, stage) == 23,
		"Blaze Rod damage rounds from twenty-two point five to twenty-three")
	_expect(WEAPON_DAMAGE.calculate(50, stage) == 75,
		"Gravity Bomb explosion damage increases from fifty to seventy-five")
	_expect(WEAPON_DAMAGE.calculate(10, stage) == 15,
		"Temporal Echo damage increases from ten to fifteen")
	_expect(WEAPON_DAMAGE.calculate(12, stage) == 18,
		"Prism prison damage increases from twelve to eighteen")
	_expect(WEAPON_DAMAGE.calculate(45, stage) == 68,
		"Prism collapse damage increases from forty-five to sixty-eight")

	stage.queue_free()
	await process_frame
	if failures == 0:
		print("Final-boss weapon damage tests passed.")
	else:
		push_error("%d final-boss weapon damage test(s) failed." % failures)
	quit(0 if failures == 0 else 1)


func _expect(condition: bool, message: String) -> void:
	if condition:
		print("PASS: " + message)
	else:
		failures += 1
		push_error("FAIL: " + message)
