extends "res://mods-unpacked/Pasha-AutoBattler/extensions/entities/units/movement_behaviors/forces/force_result.gd"

# Enemy attract-far/repel-near force with egg handling and context flag mutation.
#
# Behavior source: original player_movement_behavior.gd lines 128-152.
#
# Attract-far/repel-near: attract enemies when far (keep them in weapon range),
# repel when inside weapon range (avoid getting hit at close range).
#
# D-07: Egg strong attraction is intentional — eggs hatch into many enemies,
# so the AI must prioritize killing them quickly.
# Preservation: base_drop_chance == 1 identifies egg entities.
# Extra multiplier: force * egg_weight * 4.0 for base_drop_chance eggs.
# Additional egg_weight multiplier applied at end for all egg-type enemies.
#
# D-11: ctx.egg_weight used linearly (was egg_weight * egg_weight in original).
#
# Pitfall 3: ctx.shooting_anyone and ctx.must_run_away are written via dict
# reference mutation. GDScript 3.5 dicts are passed by reference — mutations
# are visible in get_movement() after the accumulation loop.
# These flags are per-frame only: ctx is rebuilt each frame in _build_context().

func calculate(ctx: Dictionary) -> Dictionary:
	var move_vector = Vector2.ZERO
	var debug_items = []
	var player = ctx.player
	# D-11: LINEAR — was egg_weight * egg_weight in original code
	var egg_weight = ctx.egg_weight
	var preferred_dist_sq = ctx.preferred_distance_sq

	for enemy in ctx.enemies:
		var is_egg = enemy._attack_behavior is SpawningAttackBehavior
		var to_entity = enemy.position - player.position
		var dist_sq = to_entity.length_squared()
		if dist_sq < 0.001:
			dist_sq = 0.001

		var force = to_entity.normalized() / dist_sq

		# D-07: Egg strong attraction — base_drop_chance == 1 identifies eggs.
		# Original line 136 used a squared weight pattern multiplied by 4.
		# Linear equivalent: force * egg_weight * 4.0
		if enemy.stats.base_drop_chance == 1:
			force = force * egg_weight * 4.0

		# Attract-far / repel-near based on weapon range.
		if dist_sq < preferred_dist_sq:
			# Pitfall 3: Set mutable flag — read by Soldier post-processing in get_movement().
			ctx.shooting_anyone = true
			force = force * -1.0

			# Charging enemy: dodge perpendicular to charge direction.
			# Original lines 142-144: tangent dodge when enemy is move-locked during charge.
			if enemy._current_attack_behavior is ChargingAttackBehavior:
				if enemy._move_locked:
					force = enemy._current_attack_behavior._charge_direction.tangent().normalized() / dist_sq
					force = force * -4.0  # Original: to_add * 4

		# Must-run-away: set flag when enemy is very close (quarter weapon range).
		var quarter_range_sq = preferred_dist_sq * 0.25
		if dist_sq < quarter_range_sq:
			ctx.must_run_away = true

		# Additional egg_weight multiplier for all egg-type enemies.
		# Original line 150 used a squared weight pattern for eggs.
		# Linear equivalent: multiply by egg_weight once more.
		if is_egg:
			force = force * egg_weight

		if not is_nan(force.x) and not is_nan(force.y):
			move_vector += force
			debug_items.append({
				"position": enemy.position,
				"force_vector": force,
				"weight": egg_weight if is_egg else 1.0
			})

	return {"vector": move_vector, "debug_items": debug_items}
