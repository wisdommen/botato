extends "res://mods-unpacked/Pasha-AutoBattler/extensions/entities/units/movement_behaviors/forces/force_result.gd"

# Boss attract-far/repel-near force with charge detection and context flag mutation.
#
# Behavior source: original player_movement_behavior.gd lines 155-172.
#
# D-08: The original code used a distance/4 hack for boss charge amplification:
#   squared_distance_to_boss = squared_distance_to_boss / 4
# This effectively multiplied the force by 4 (since force ~ 1/dist_sq).
# Refactored to use an explicit CHARGE_MULTIPLIER constant for clarity,
# while preserving the same amplification behavior.
#
# D-11: ctx.boss_weight used linearly (was boss_weight * boss_weight in original).
#
# Pitfall 3: ctx.shooting_anyone and ctx.must_run_away are written via dict
# reference mutation. Per-frame only — ctx is rebuilt each frame in _build_context().

# D-08: Explicit charge multiplier replaces the original distance/4 hack.
const CHARGE_MULTIPLIER = 4.0

func calculate(ctx: Dictionary) -> Dictionary:
	var move_vector = Vector2.ZERO
	var debug_items = []
	var player = ctx.player
	# D-11: LINEAR — was boss_weight * boss_weight in original code
	var weight = ctx.boss_weight
	var preferred_dist_sq = ctx.preferred_distance_sq

	for boss in ctx.bosses:
		var to_entity = boss.position - player.position
		var dist_sq = to_entity.length_squared()
		if dist_sq < 0.001:
			dist_sq = 0.001

		var force = (to_entity.normalized() / dist_sq) * weight

		if dist_sq < preferred_dist_sq:
			# Pitfall 3: Set mutable flag — read by Soldier post-processing in get_movement().
			ctx.shooting_anyone = true
			force = force * -1.0

			# D-08: Boss charge detection — use explicit CHARGE_MULTIPLIER instead of distance/4 hack.
			# Original lines 166-169:
			#   squared_distance_to_boss = squared_distance_to_boss / 4
			#   boss_to_player = boss._current_attack_behavior._charge_direction.tangent()
			# Refactored: multiply force by CHARGE_MULTIPLIER for equivalent amplification.
			if boss._current_attack_behavior is ChargingAttackBehavior:
				if boss._move_locked:
					var charge_dir = boss._current_attack_behavior._charge_direction.tangent()
					force = (charge_dir.normalized() / dist_sq) * weight * CHARGE_MULTIPLIER * -1.0

		# Must-run-away: set flag when boss is very close (quarter weapon range).
		var quarter_range_sq = preferred_dist_sq * 0.25
		if dist_sq < quarter_range_sq:
			ctx.must_run_away = true

		if not is_nan(force.x) and not is_nan(force.y):
			move_vector += force
			debug_items.append({
				"position": boss.position,
				"force_vector": force,
				"weight": weight
			})

	return {"vector": move_vector, "debug_items": debug_items}
