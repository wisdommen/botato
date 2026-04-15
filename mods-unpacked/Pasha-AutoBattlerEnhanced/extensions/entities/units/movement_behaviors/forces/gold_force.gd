extends "res://mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/entities/units/movement_behaviors/forces/force_result.gd"

# Gold/item pickup attraction force.
#
# Behavior source: original player_movement_behavior.gd lines 70-78.
#
# D-11: The original code used a squared weight pattern — the new code uses
# ctx.item_weight directly as the multiplier (linear mapping).
# Default values in autobattler_options.gd must be re-tuned for Plan 04
# to match original gameplay feel (see Pitfall 6 in 01-RESEARCH.md).

func calculate(ctx: Dictionary) -> Dictionary:
	var move_vector = Vector2.ZERO
	var debug_items = []
	var player = ctx.player
	# D-11: LINEAR — was item_weight * item_weight in original code
	var weight = ctx.item_weight

	for item in ctx.golds:
		var to_entity = item.position - player.position
		var dist_sq = to_entity.length_squared()
		if dist_sq < 0.001:
			dist_sq = 0.001
		var force = (to_entity.normalized() / dist_sq) * weight
		if not is_nan(force.x) and not is_nan(force.y):
			move_vector += force
			debug_items.append({
				"position": item.position,
				"force_vector": force,
				"weight": weight
			})

	return {"vector": move_vector, "debug_items": debug_items}
