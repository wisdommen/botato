extends "res://mods-unpacked/Pasha-AutoBattler/extensions/entities/units/movement_behaviors/forces/force_result.gd"

# Tree attract-far/repel-near force (anti-stuck mechanism).
#
# Behavior source: original player_movement_behavior.gd lines 80-94.
#
# D-06: Tree close-range repulsion is intentional — prevents the AI from getting
# stuck against trees by repelling the player when inside half weapon range.
# This matches original line 90: if squared_distance < (preferred_distance_squared / 2)
#
# D-11: The original code squared tree_weight:
#   var tree_weight_squared = tree_weight * tree_weight
# Linear replacement: ctx.tree_weight is used directly as the multiplier.

func calculate(ctx: Dictionary) -> Dictionary:
	var move_vector = Vector2.ZERO
	var debug_items = []
	var player = ctx.player
	# D-11: LINEAR — was tree_weight * tree_weight in original code
	var weight = ctx.tree_weight
	var preferred_dist_sq = ctx.preferred_distance_sq

	for neutral in ctx.neutrals:
		var to_entity = neutral.position - player.position
		var dist_sq = to_entity.length_squared()
		if dist_sq < 0.001:
			dist_sq = 0.001
		var force = (to_entity.normalized() / dist_sq) * weight

		# D-06: Tree close-range repulsion — intentional anti-stuck mechanism.
		# Negate force when inside half of weapon range squared.
		# Preserves original line 90: if squared_distance_to_neutral < (preferred_distance_squared / 2)
		if dist_sq < (preferred_dist_sq / 2.0):
			force = force * -1.0

		if not is_nan(force.x) and not is_nan(force.y):
			move_vector += force
			debug_items.append({
				"position": neutral.position,
				"force_vector": force,
				"weight": weight
			})

	return {"vector": move_vector, "debug_items": debug_items}
