extends RefCounted


static func is_living_enemy(enemy: Node) -> bool:
	if not is_instance_valid(enemy) or not enemy.is_inside_tree() or enemy.is_queued_for_deletion():
		return false
	if not enemy.is_in_group("enemy") or not enemy.has_method("take_damage"):
		return false
	var scene := enemy.get_tree().current_scene
	if scene != null and "current_level" in scene:
		var required_group: String = str({
			1: "level1_enemy",
			2: "level2_enemy",
			3: "level3_enemy",
			4: "boss_enemy",
		}.get(int(scene.current_level), ""))
		if not required_group.is_empty() and not enemy.is_in_group(required_group):
			return false
	var health: Variant = enemy.get("current_health")
	if health is int or health is float:
		return health > 0
	return true


# Returns the nearest valid decoy inside its attraction radius. If no decoy can
# attract this enemy, the real player remains the combat target.
static func choose_target(enemy: Node2D, real_player: Node2D) -> Node2D:
	if not is_instance_valid(enemy) or enemy.get_tree() == null:
		return real_player if is_instance_valid(real_player) else null

	var selected_decoy: Node2D = null
	var nearest_distance := INF
	for node in enemy.get_tree().get_nodes_in_group("temporal_decoy"):
		var decoy := node as Node2D
		if decoy == null or not is_instance_valid(decoy):
			continue
		if not decoy.has_method("can_attract_enemy") or not decoy.can_attract_enemy(enemy):
			continue
		var distance := enemy.global_position.distance_to(decoy.global_position)
		if distance < nearest_distance:
			nearest_distance = distance
			selected_decoy = decoy

	if selected_decoy != null:
		return selected_decoy
	return real_player if is_instance_valid(real_player) else null
