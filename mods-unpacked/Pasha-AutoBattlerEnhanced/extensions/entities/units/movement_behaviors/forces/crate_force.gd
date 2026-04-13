extends "res://mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/entities/units/movement_behaviors/forces/force_result.gd"

# Crate/item-box attraction force.
#
# Crates are Consumable nodes stored in _consumables alongside fruit.
# Distinguished by consumable_data.my_id (verified from Brotato source).
# D-04: Simple inverse-distance-squared attraction, no repulsion zone.
# D-05: Crates are NOT in EntitySpawner.neutrals (that is trees only).

const CRATE_IDS = ["consumable_item_box", "consumable_legendary_item_box"]

func calculate(ctx: Dictionary) -> Dictionary:
	var move_vector = Vector2.ZERO
	var debug_items = []
	var player = ctx.player
	var weight = ctx.crate_weight

	for consumable in ctx.consumables:
		if not (consumable.consumable_data.my_id in CRATE_IDS):
			continue
		var to_entity = consumable.position - player.position
		var dist_sq = to_entity.length_squared()
		var force = _safe_force(to_entity, dist_sq, weight)
		if not is_nan(force.x) and not is_nan(force.y):
			move_vector += force
			debug_items.append({
				"position": consumable.position,
				"force_vector": force,
				"weight": weight
			})

	return {"vector": move_vector, "debug_items": debug_items}
