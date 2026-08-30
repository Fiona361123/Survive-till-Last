extends RefCounted


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

