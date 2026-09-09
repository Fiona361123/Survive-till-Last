extends RefCounted

# Every weapon uses this calculation at the moment damage is dealt. Keeping the
# rule here prevents projectiles, damage-over-time fields, and passive weapons
# from applying different boss-stage bonuses.
const FINAL_BOSS_DAMAGE_MULTIPLIER: float = 1.50


static func calculate(base_damage: int, damage_source: Node) -> int:
	var safe_damage := maxi(base_damage, 0)
	return roundi(float(safe_damage) * get_multiplier(damage_source))


static func get_multiplier(damage_source: Node) -> float:
	return FINAL_BOSS_DAMAGE_MULTIPLIER if is_final_boss_stage(damage_source) else 1.0


static func is_final_boss_stage(damage_source: Node) -> bool:
	if not is_instance_valid(damage_source):
		return false
	var scene_tree := damage_source.get_tree()
	if scene_tree == null:
		return false
	var scene := scene_tree.current_scene
	if scene == null:
		return false

	# Dungeon exposes an explicit flag because Level 4 is unlocked immediately
	# after Level 3, but the bonus should begin only after entering the boss room.
	if "final_boss_damage_bonus_active" in scene:
		return bool(scene.get("final_boss_damage_bonus_active"))
	return "current_level" in scene and int(scene.get("current_level")) == 4
