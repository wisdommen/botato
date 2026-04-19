extends "res://entities/units/movement_behaviors/player_movement_behavior.gd"

var _calculators = []
var _last_force_results = []  # Phase 2 visualization reads this


func _get_logger():
	# Fetch BotatoLogger via AutobattlerOptions singleton. Nullable — harness and
	# pre-ready frames may not have it yet.
	var opts = get_node_or_null("/root/AutobattlerOptions")
	if opts == null:
		return null
	return opts.debug_logger


func _ready():
	# Idempotency guard: prevents double-init when player.gd force-swaps our
	# script via set_script() + mb._ready() (issue #2 Option 3 workaround).
	# If _calculators is already populated, our init has already run — skip
	# base ._ready() re-entry (which could duplicate signal connections) and
	# exit early.
	if _calculators.size() > 0:
		print("[botato ext] player_movement_behavior._ready() re-entry SKIPPED (already initialized)")
		return

	._ready()

	# EXTENSION-LOADED SENTINEL: if this line doesn't appear in godot.log, ModLoader
	# did NOT register this script as an extension for player_movement_behavior.
	print("[botato ext] Enhanced player_movement_behavior._ready() called on ", self)

	var base = "res://mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/entities/units/movement_behaviors/forces/"
	_calculators = [
		load(base + "consumable_force.gd").new(),
		load(base + "gold_force.gd").new(),
		load(base + "tree_force.gd").new(),
		load(base + "projectile_force.gd").new(),
		load(base + "enemy_force.gd").new(),
		load(base + "boss_force.gd").new(),
		load(base + "boundary_force.gd").new(),
		load(base + "crate_force.gd").new(),
	]
	print("[botato ext] loaded ", _calculators.size(), " force calculators")

	var logger = _get_logger()
	if logger:
		logger.log_section("player_movement_behavior._ready()")
		logger.log_kv("calculators loaded", _calculators.size())
		logger.log_kv("parent (player)", get_parent())


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
	var ctrl = options.adaptive_controller  # cached property, no node lookup (Pitfall 3)

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
		"consumable_weight": (1.0 - (cur_hp / max_hp)) * 2.0 * options.consumable_weight * ctrl.get_multiplier("consumable"),
		"item_weight": options.item_weight * ctrl.get_multiplier("item"),
		"projectile_weight": options.projectile_weight * ctrl.get_multiplier("projectile"),
		"tree_weight": options.tree_weight * ctrl.get_multiplier("tree"),
		"boss_weight": options.boss_weight * ctrl.get_multiplier("boss"),
		"bumper_weight": options.bumper_weight * ctrl.get_multiplier("bumper"),
		"egg_weight": options.egg_weight,  # egg: NO adaptive multiplier (Pitfall 4, D-09 scope)
		"crate_weight": options.crate_weight * ctrl.get_multiplier("crate"),
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
	var logger = _get_logger()
	var frame = 0
	if logger:
		frame = logger.next_frame()

	if not options.enable_autobattler and not CoopService.is_bot_by_index[player.player_index]:
		$"/root/Main/Camera".smoothing_enabled = false
		if logger and logger.should_log_detailed():
			logger.log_section("get_movement() frame " + str(frame) + " — AI DISABLED BRANCH")
			logger.log_kv("enable_autobattler", options.enable_autobattler)
			logger.log_kv("is_bot", CoopService.is_bot_by_index[player.player_index])
			logger.log_line("returning .get_movement() [parent = base class human input]")
		return .get_movement()

	var ctx = _build_context(options)
	_last_force_results = []
	var move_vector = Vector2.ZERO

	var detailed = logger != null and logger.should_log_detailed()
	if detailed:
		logger.log_section("get_movement() frame " + str(frame) + " — AI ENABLED")
		logger.log_kv("player.position", player.position)
		logger.log_kv("ctx.consumables.size", ctx.consumables.size())
		logger.log_kv("ctx.golds.size", ctx.golds.size())
		logger.log_kv("ctx.enemies.size", ctx.enemies.size())
		logger.log_kv("ctx.bosses.size", ctx.bosses.size())
		logger.log_kv("ctx.projectiles.size", ctx.projectiles.size())
		logger.log_kv("ctx.neutrals.size", ctx.neutrals.size())
		logger.log_kv("preferred_distance_sq", ctx.preferred_distance_sq)
		logger.log_kv("item_weight (adj)", ctx.item_weight)
		logger.log_kv("projectile_weight (adj)", ctx.projectile_weight)
		logger.log_kv("is_soldier", ctx.is_soldier)

	for i in range(_calculators.size()):
		var calc = _calculators[i]
		var result = calc.calculate(ctx)
		move_vector += result.vector
		_last_force_results.append(result)
		if detailed:
			logger.log_line("  calc[%d] %-25s vector=%s debug_items=%d" % [
				i, calc.get_script().resource_path.get_file(), result.vector, result.debug_items.size()
			])

	if detailed:
		logger.log_vec("accumulated move_vector", move_vector)

	# Post-processing: Soldier freeze (D-13)
	if ctx.is_soldier and ctx.shooting_anyone and not ctx.must_run_away:
		if detailed:
			logger.log_line("SOLDIER FREEZE triggered (shooting_anyone=%s must_run_away=%s) -> return ZERO" % [ctx.shooting_anyone, ctx.must_run_away])
		return Vector2.ZERO

	var final_move = move_vector.normalized()
	if detailed:
		logger.log_vec("final return (normalized)", final_move)
	elif logger and logger.should_log_summary():
		logger.log_line("frame %d summary: move=%s len=%.4f enemies=%d projectiles=%d" % [
			frame, str(final_move), final_move.length(), ctx.enemies.size(), ctx.projectiles.size()
		])
	return final_move
