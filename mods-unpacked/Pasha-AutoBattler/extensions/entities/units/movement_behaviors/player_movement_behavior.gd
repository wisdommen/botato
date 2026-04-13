extends "res://entities/units/movement_behaviors/player_movement_behavior.gd"

var _calculators = []
var _last_force_results = []  # Phase 2 visualization reads this


func _ready():
	._ready()
	var base = "res://mods-unpacked/Pasha-AutoBattler/extensions/entities/units/movement_behaviors/forces/"
	_calculators = [
		load(base + "consumable_force.gd").new(),
		load(base + "gold_force.gd").new(),
		load(base + "tree_force.gd").new(),
		load(base + "projectile_force.gd").new(),
		load(base + "enemy_force.gd").new(),
		load(base + "boss_force.gd").new(),
		load(base + "boundary_force.gd").new(),
	]


func _compute_weapon_range(player, char_name: String, max_hp: float, cur_hp: float) -> int:
	var weapon_range = 1000
	if char_name == "character_bull":
		if cur_hp / max_hp < 0.6:
			weapon_range = 1000
		else:
			weapon_range = 0
	for weapon in player.current_weapons:
		var max_range = weapon.current_stats.max_range
		if max_range < weapon_range:
			weapon_range = max_range
	return weapon_range


func _build_context(options) -> Dictionary:
	var player = get_parent()
	var char_name = RunData.get_player_character(0).name.to_lower()
	var max_hp = float(player.max_stats.health)
	var cur_hp = float(player.current_stats.health)
	var weapon_range = _compute_weapon_range(player, char_name, max_hp, cur_hp)

	return {
		"player": player,
		"consumables": $"/root/Main/"._consumables,
		"golds": $"/root/Main/"._active_golds,
		"neutrals": $"/root/Main/EntitySpawner".neutrals,
		"enemies": $"/root/Main/EntitySpawner".enemies,
		"bosses": $"/root/Main/EntitySpawner".bosses,
		"projectiles": $"/root/Main/EnemyProjectiles".get_children(),
		"far_corner": ZoneService.current_zone_max_position,
		"preferred_distance_sq": weapon_range * weapon_range,
		"consumable_weight": (1.0 - (cur_hp / max_hp)) * 2.0,
		"item_weight": options.item_weight,
		"projectile_weight": options.projectile_weight,
		"tree_weight": options.tree_weight,
		"boss_weight": options.boss_weight,
		"bumper_weight": options.bumper_weight,
		"egg_weight": options.egg_weight,
		"bumper_distance": options.bumper_distance,
		"is_soldier": char_name == "character_soldier",
		"is_bull": char_name == "character_bull",
		# Mutable flags -- deliberate exception to immutability (see plan rationale)
		# Written by enemy_force and boss_force calculators via dict reference mutation.
		# Per-frame scope only: ctx is rebuilt each frame, no cross-frame state leakage.
		"shooting_anyone": false,
		"must_run_away": false,
	}


func get_movement() -> Vector2:
	var options = $"/root/AutobattlerOptions"
	var player = get_parent()

	if not options.enable_autobattler and not CoopService.is_bot_by_index[player.player_index]:
		$"/root/Main/Camera".smoothing_enabled = false
		return .get_movement()

	var ctx = _build_context(options)
	_last_force_results = []
	var move_vector = Vector2.ZERO

	for calc in _calculators:
		var result = calc.calculate(ctx)
		move_vector += result.vector
		_last_force_results.append(result)

	# Post-processing: Soldier freeze (D-13)
	if ctx.is_soldier and ctx.shooting_anyone and not ctx.must_run_away:
		return Vector2.ZERO

	return move_vector.normalized()
