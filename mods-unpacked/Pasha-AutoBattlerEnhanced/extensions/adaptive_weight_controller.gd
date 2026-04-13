extends Node

# AdaptiveWeightController -- EMA-based dynamic weight adjustment.
# Owned by AutobattlerOptions node (D-05, ADAPT-04).
# _process() updates EMA before _physics_process() reads multipliers (D-07).
#
# This is a standalone Node, NOT a Script Extension.
# Never registered in mod_main.gd (ADAPT-04).

# Group assignments (D-09): defensive weights increase under threat,
# offensive/pickup weights decrease under threat.
const DEFENSIVE_TYPES = ["projectile", "boss", "bumper"]
const OFFENSIVE_TYPES = ["consumable", "item", "tree"]

const EMA_RATE = 0.02   # D-11: ~3-second convergence at 60fps
const MULT_MIN = 0.7    # D-10: minimum multiplier
const MULT_MAX = 1.3    # D-10: maximum multiplier

# EMA accumulators
var _ema_damage_rate: float = 0.0
var _ema_health_ratio: float = 1.0
var _prev_health: float = -1.0    # -1.0 = sentinel for first frame (Pitfall 1)

# Wave boundary detection (D-03)
var _prev_wave_time_left: float = 1.0

# Per-type multipliers (D-10: clamped [0.7, 1.3])
var _multipliers: Dictionary = {}


func _ready():
	_reset()


func _reset():
	_ema_damage_rate = 0.0
	_ema_health_ratio = 1.0
	_prev_health = -1.0
	_prev_wave_time_left = 1.0
	_multipliers = {}
	for t in DEFENSIVE_TYPES + OFFENSIVE_TYPES:
		_multipliers[t] = 1.0


func get_multiplier(force_type: String) -> float:
	return _multipliers.get(force_type, 1.0)


func _process(delta):
	var main = $"/root/Main"
	var players = main._players
	if players.empty():
		return

	var player = players[0]
	var wave_time_left = main._wave_timer.time_left

	# Wave boundary: previous time was near-zero and current jumped above 1.0 (D-03, D-12)
	if _prev_wave_time_left < 0.05 and wave_time_left > 1.0:
		_reset()
		_prev_wave_time_left = wave_time_left
		return

	_prev_wave_time_left = wave_time_left
	_update_ema(player, delta)
	_update_multipliers()


func _update_ema(player, delta: float):
	var cur_hp = float(player.current_stats.health)

	# First-frame guard: initialize _prev_health without computing damage (Pitfall 1)
	if _prev_health < 0.0:
		_prev_health = cur_hp
		# Still update health_ratio EMA so it starts converging (mirrors Python port)
		var max_hp_first = float(player.max_stats.health)
		if max_hp_first > 0.0:
			var raw_health_ratio_first = cur_hp / max_hp_first
			_ema_health_ratio = lerp(_ema_health_ratio, raw_health_ratio_first, EMA_RATE)
		return

	var max_hp = float(player.max_stats.health)

	# damage_rate: HP lost per second, normalized to max_hp -> [0, 1]
	# Clamped to [0, 1]: healing produces 0 damage rate, not negative (D-01)
	var raw_damage_rate = 0.0
	if max_hp > 0.0:
		raw_damage_rate = clamp((_prev_health - cur_hp) / (delta * max_hp), 0.0, 1.0)

	# health_ratio: fraction of max HP remaining -> [0, 1]
	var raw_health_ratio = 1.0
	if max_hp > 0.0:
		raw_health_ratio = cur_hp / max_hp

	_prev_health = cur_hp

	# Apply EMA: ema = lerp(ema, raw, rate)
	_ema_damage_rate = lerp(_ema_damage_rate, raw_damage_rate, EMA_RATE)
	_ema_health_ratio = lerp(_ema_health_ratio, raw_health_ratio, EMA_RATE)


func _update_multipliers():
	# threat_level: 0.0 = safe (full health), 1.0 = dying (0% health) (D-09)
	var threat_level = 1.0 - _ema_health_ratio

	# DEFENSIVE group: increase toward MULT_MAX under threat, decrease toward MULT_MIN when safe
	var defensive_target = lerp(MULT_MIN, MULT_MAX, threat_level)
	for t in DEFENSIVE_TYPES:
		var updated = lerp(_multipliers[t], defensive_target, EMA_RATE)
		_multipliers[t] = clamp(updated, MULT_MIN, MULT_MAX)

	# OFFENSIVE group: decrease toward MULT_MIN under threat, increase toward MULT_MAX when safe
	var offensive_target = lerp(MULT_MAX, MULT_MIN, threat_level)
	for t in OFFENSIVE_TYPES:
		var updated = lerp(_multipliers[t], offensive_target, EMA_RATE)
		_multipliers[t] = clamp(updated, MULT_MIN, MULT_MAX)
