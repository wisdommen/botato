extends "res://mods-unpacked/Pasha-AutoBattler/extensions/entities/units/movement_behaviors/forces/force_result.gd"

# Health-weighted consumable attraction force.
#
# Behavior source: original player_movement_behavior.gd lines 60-68.
#
# D-09: The *10 multiplier is intentional — consumables must be strongly attractive
# when health is low so the AI prioritizes healing pickups over other targets.
#
# Weight scaling:
# ctx.consumable_weight is pre-computed as (1 - hp_ratio) * 2 in _build_context().
# This already encodes health urgency. The *10 amplifier is an additional fixed
# scaling term from the original design (not a tunable parameter).
#
# D-11: No squared weight — ctx.consumable_weight used linearly.

func calculate(ctx: Dictionary) -> Dictionary:
	var move_vector = Vector2.ZERO
	var debug_items = []
	var player = ctx.player
	# consumable_weight is pre-computed: (1.0 - hp_ratio) * 2.0
	var weight = ctx.consumable_weight

	for consumable in ctx.consumables:
		var to_entity = consumable.position - player.position
		var dist_sq = to_entity.length_squared()
		if dist_sq < 0.001:
			dist_sq = 0.001
		# D-09: *10 multiplier is intentional — preserves strong health pickup attraction
		var force = (to_entity.normalized() / dist_sq) * 10.0 * weight
		if not is_nan(force.x) and not is_nan(force.y):
			move_vector += force
			debug_items.append({
				"position": consumable.position,
				"force_vector": force,
				"weight": weight
			})

	return {"vector": move_vector, "debug_items": debug_items}
