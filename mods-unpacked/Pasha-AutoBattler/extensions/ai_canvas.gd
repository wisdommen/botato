extends Node2D

# Arrow-based force visualization reader
# Consumes _last_force_results from player_movement_behavior.gd
# Zero force calculation logic -- all data from ForceResult contract

# Arrow rendering constants
const ARROW_SCALE = 150.0
const ARROW_MAX_LEN = 80.0
const ARROW_MIN_LEN = 4.0
const ARROWHEAD_SIZE = 6.0
const SUM_ARROW_WIDTH = 3.0
const ENTITY_ARROW_WIDTH = 1.5
const BOUNDARY_TYPE_INDEX = 6

# Color palette indexed to calculator order in player_movement_behavior.gd
# [0] consumable, [1] gold, [2] tree, [3] projectile, [4] enemy, [5] boss, [6] boundary, [7] crate
var _type_colors = []


func _ready():
	_type_colors = [
		Color(0.2, 0.8, 0.2, 0.7),   # consumable: green
		Color(1.0, 0.84, 0.0, 0.7),   # gold: gold/yellow
		Color(0.0, 0.6, 0.4, 0.7),    # tree: teal
		Color(1.0, 0.3, 0.3, 0.7),    # projectile: red
		Color(1.0, 0.5, 0.0, 0.7),    # enemy: orange
		Color(0.8, 0.0, 0.0, 0.7),    # boss: dark red
		Color(0.7, 0.4, 1.0, 0.7),    # boundary: purple
		Color(0.8, 0.6, 0.2, 0.7),    # crate: warm brown/tan
	]


func _draw_arrow(origin: Vector2, force_vec: Vector2, color: Color, width: float) -> void:
	if force_vec.length_squared() < 0.0001:
		return

	var direction = force_vec.normalized()
	var length = min(force_vec.length() * ARROW_SCALE, ARROW_MAX_LEN)

	if length < ARROW_MIN_LEN:
		return

	var tip = origin + direction * length
	draw_line(origin, tip, color, width)

	# Arrowhead: two lines from tip rotated +/- 0.45 radians
	var left = tip - (direction.rotated(0.45) * ARROWHEAD_SIZE)
	var right = tip - (direction.rotated(-0.45) * ARROWHEAD_SIZE)
	draw_line(tip, left, color, width)
	draw_line(tip, right, color, width)


func _draw_boundary_arrows(player, debug_items: Array, color: Color) -> void:
	for item in debug_items:
		var fv = item.force_vector
		var abs_x = abs(fv.x)
		var abs_y = abs(fv.y)
		var origin = player.position

		if abs_y > abs_x:
			if fv.y > 0:
				# Top wall pushes downward (positive y = away from y=0)
				origin = Vector2(player.position.x, 0)
			else:
				# Bottom wall pushes upward
				origin = Vector2(player.position.x, ZoneService.current_zone_max_position.y)
		else:
			if fv.x > 0:
				# Left wall pushes rightward (positive x = away from x=0)
				origin = Vector2(0, player.position.y)
			else:
				# Right wall pushes leftward
				origin = Vector2(ZoneService.current_zone_max_position.x, player.position.y)

		_draw_arrow(origin, item.force_vector, color, ENTITY_ARROW_WIDTH)


func _draw() -> void:
	if $"/root/Main"._wave_timer.time_left < 0.05:
		return

	if not $"/root/AutobattlerOptions".enable_ai_visuals:
		return

	var player = $"/root/Main"._players[0]

	# Weapon range arc -- only standalone computation (not from force results)
	var weapon_range = 1000
	for weapon in player.current_weapons:
		var max_range = weapon.current_stats.max_range
		if max_range < weapon_range:
			weapon_range = max_range
	draw_arc(player.position, weapon_range, 0, 6.28, 100, Color.red)

	# Find movement behavior child that holds _last_force_results
	var movement_behavior = null
	for child in player.get_children():
		if "_last_force_results" in child:
			movement_behavior = child
			break

	if movement_behavior == null:
		return

	var force_results = movement_behavior._last_force_results
	if force_results == null or force_results.empty():
		return

	# Per-entity arrows with sum accumulation
	var sum_vector = Vector2.ZERO
	for i in range(force_results.size()):
		var result = force_results[i]
		sum_vector += result.vector
		var color = _type_colors[i] if i < _type_colors.size() else Color.white

		if i == BOUNDARY_TYPE_INDEX:
			_draw_boundary_arrows(player, result.debug_items, color)
		else:
			for item in result.debug_items:
				_draw_arrow(item.position, item.force_vector, color, ENTITY_ARROW_WIDTH)

	# Composite sum arrow at player position
	_draw_arrow(player.position, sum_vector, Color.white, SUM_ARROW_WIDTH)


func _process(_delta):
	update()
