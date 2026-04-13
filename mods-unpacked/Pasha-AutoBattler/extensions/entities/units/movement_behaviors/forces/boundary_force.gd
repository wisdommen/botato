extends "res://mods-unpacked/Pasha-AutoBattler/extensions/entities/units/movement_behaviors/forces/force_result.gd"

# ALGO-03: Analytical 4-wall boundary repulsion — O(1) per frame (D-04)
# Replaces 4 O(n) sampling loops (stepping every 50px across map edges) with direct distance-to-wall.
# Corner effects absorbed naturally: corner = two perpendicular wall forces summed (diagonal result).


func _wall_force(dist_to_wall: float, push_dir: Vector2, weight: float, threshold: float) -> Vector2:
	if dist_to_wall <= 0.0:
		dist_to_wall = 0.001
	var dist_sq = dist_to_wall * dist_to_wall
	var threshold_sq = threshold * threshold
	if dist_sq > threshold_sq:
		return Vector2.ZERO
	return (push_dir / dist_sq) * weight


func calculate(ctx: Dictionary) -> Dictionary:
	var move_vector = Vector2.ZERO
	var debug_items = []
	var player_pos = ctx.player.position
	var far_corner = ctx.far_corner
	var weight = ctx.bumper_weight  # LINEAR per D-11
	var threshold = ctx.bumper_distance

	# 4 walls: analytical distance-to-wall, axis-aligned push toward interior
	var walls = [
		{"dist": player_pos.y,                "push": Vector2(0, 1)},   # top wall (y=0)
		{"dist": far_corner.y - player_pos.y, "push": Vector2(0, -1)},  # bottom wall
		{"dist": player_pos.x,                "push": Vector2(1, 0)},   # left wall (x=0)
		{"dist": far_corner.x - player_pos.x, "push": Vector2(-1, 0)},  # right wall
	]

	for wall in walls:
		var f = _wall_force(wall.dist, wall.push, weight, threshold)
		if not is_nan(f.x) and not is_nan(f.y):
			move_vector += f
			if f != Vector2.ZERO:
				debug_items.append({"position": player_pos, "force_vector": f, "weight": weight})

	return {"vector": move_vector, "debug_items": debug_items}
