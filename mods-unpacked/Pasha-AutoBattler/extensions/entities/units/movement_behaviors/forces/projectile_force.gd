extends "res://mods-unpacked/Pasha-AutoBattler/extensions/entities/units/movement_behaviors/forces/force_result.gd"

# ALGO-01: Perpendicular projectile dodge with threat-aware side selection (D-01)
# Replaces direct-flee ("projectile_to_player.normalized() * -1") with velocity-tangent dodge.
# D-09: Preserves 250k distance cutoff and hitbox shape radius compensation from original.
# D-02: Symmetric cancellation resolved naturally via other force types — no Vector2.ZERO fallback.


func _gather_threats(ctx: Dictionary) -> Array:
	# D-01: Full threat set — other projectiles + enemies + bosses for side selection bias
	var threats = []
	for enemy in ctx.enemies:
		threats.append(enemy.position)
	for boss in ctx.bosses:
		threats.append(boss.position)
	for projectile in ctx.projectiles:
		threats.append(projectile.position)
	return threats


func _get_dodge_direction(projectile_vel: Vector2, player_pos: Vector2, threats: Array) -> Vector2:
	# Perpendicular to velocity = tangent (90 degrees CCW in Godot 3.5)
	var perp = projectile_vel.normalized().tangent()
	var left_dodge = perp
	var right_dodge = -perp

	# Threat-aware side selection: pick the side with fewer threats
	var left_count = 0
	var right_count = 0
	for threat_pos in threats:
		var to_threat = threat_pos - player_pos
		# cross() returns positive if to_threat is to the left of perp
		if perp.cross(to_threat) > 0:
			left_count += 1
		else:
			right_count += 1

	return left_dodge if left_count <= right_count else right_dodge


func calculate(ctx: Dictionary) -> Dictionary:
	var move_vector = Vector2.ZERO
	var debug_items = []
	var player = ctx.player
	var weight = ctx.projectile_weight  # LINEAR per D-11

	var threats = _gather_threats(ctx)

	for projectile in ctx.projectiles:
		# Safe hitbox check — preserved from original
		if not projectile._hitbox or not projectile._hitbox.active:
			continue

		# Pitfall 2: Guard against zero-velocity projectiles (mines) — avoids NaN from normalized()
		if projectile.linear_velocity.length_squared() < 0.001:
			continue

		# Hitbox shape radius compensation — preserved from original (D-09)
		var extra_range = 0.0
		var projectile_shape = projectile._hitbox._collision.shape
		if projectile_shape is CircleShape2D:
			extra_range = projectile_shape.radius
		elif projectile_shape is RectangleShape2D:
			extra_range = projectile_shape.extents.x
			if projectile_shape.extents.y > extra_range:
				extra_range = projectile_shape.extents.y

		var to_projectile = projectile.position - player.position
		var extra_range_sq = extra_range * extra_range
		var dist_sq = to_projectile.length_squared() - extra_range_sq
		if dist_sq < 0.001:
			dist_sq = 0.001

		# D-09: 250k distance cutoff preserved from original
		if dist_sq > 250000.0:
			continue

		# ALGO-01: Perpendicular dodge direction (velocity tangent + threat-aware side selection)
		var dodge_dir = _get_dodge_direction(projectile.linear_velocity, player.position, threats)
		var force = (dodge_dir / dist_sq) * weight
		if not is_nan(force.x) and not is_nan(force.y):
			move_vector += force
			debug_items.append({"position": projectile.position, "force_vector": force, "weight": weight})

	return {"vector": move_vector, "debug_items": debug_items}
