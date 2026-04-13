extends Reference

# ForceResult Contract
#
# Every force calculator in this directory must implement:
#   func calculate(ctx: Dictionary) -> Dictionary
#
# Return value format:
#   {
#       "vector":      Vector2  -- raw (un-normalized) accumulated force contribution
#       "debug_items": Array    -- list of debug_item dicts (may be empty)
#   }
#
# debug_item format (one entry per entity that contributed force this frame):
#   {
#       "position":     Vector2  -- world position of the source entity
#       "force_vector": Vector2  -- force vector applied from this entity
#       "weight":       float    -- weight multiplier used (positive = attraction, negative = repulsion)
#   }
#
# Sign convention (D-10):
#   positive weight -> attraction (vector points toward entity)
#   negative weight -> repulsion  (vector points away from entity)
#   Each calculator determines vector direction internally.
#
# Weight scaling (D-11):
#   Weights are LINEAR -- the slider value from ModOptions is used directly as
#   the multiplier. Do NOT square weights. (Squared pattern was removed in Phase 1.)
#
# NaN guard:
#   Always check `is_nan(result.x) or is_nan(result.y)` before adding to move_vector.
#   Use _safe_force() below to apply both distance-floor and NaN guard in one call.
#
# Distance floor:
#   Minimum dist_sq is 0.001 to prevent division-by-zero when entities overlap.


# Base calculate() -- concrete calculators override this method.
# Returns zero vector and empty debug_items by default.
func calculate(ctx: Dictionary) -> Dictionary:
	return {"vector": Vector2.ZERO, "debug_items": []}


# _safe_force: Apply inverse-distance-squared force with NaN guard and distance floor.
#
# direction  -- vector from player toward (or away from) the source entity
# dist_sq    -- squared distance to the entity (length_squared() of direction)
# weight     -- force multiplier; positive = attraction, negative = repulsion
#
# Returns the computed force Vector2, or Vector2.ZERO if result contains NaN.
func _safe_force(direction: Vector2, dist_sq: float, weight: float) -> Vector2:
	if dist_sq < 0.001:
		dist_sq = 0.001
	var result = (direction.normalized() / dist_sq) * weight
	if is_nan(result.x) or is_nan(result.y):
		return Vector2.ZERO
	return result
