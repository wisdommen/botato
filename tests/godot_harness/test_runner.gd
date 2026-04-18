extends Node

# Headless diagnostic harness for the Enhanced mod's get_movement() pipeline.
#
# Run as main scene with:
#   ./tools/godot35/godot --headless --path tests/godot_harness
#
# Main scene loading goes through normal project init → autoloads register as
# globals BEFORE script parsing, so `RunData`/`ZoneService`/etc. bare identifiers
# work at parse time. The `-s script.gd` mode skips that and fails to resolve.
#
# Flow:
#   1. Wire up mock Brotato scene tree (Main, EntitySpawner, Camera, Player) at /root.
#      Singletons (RunData/ZoneService/CoopService/ModLoader) are autoloaded.
#   2. Instantiate the REAL autobattler_options.gd from the mod → /root/AutobattlerOptions.
#   3. Toggle enable_autobattler = true (simulates Shift+Space).
#   4. Attach the REAL player_movement_behavior.gd to mock player.
#   5. Call get_movement() and print diagnostic output.

const MockBrotato = preload("res://mocks/mock_brotato.gd")
const AutobattlerOptionsScript = preload("res://mods-unpacked/Pasha-AutoBattlerEnhanced/autobattler_options.gd")
const PlayerMovementBehaviorScript = preload("res://mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/entities/units/movement_behaviors/player_movement_behavior.gd")


func _ready():
	# Defer actual setup so Godot finishes scene initialization first.
	# Prevents "Parent node is busy setting up children" when add_child chains
	# run inside _ready(). See harness doc for rationale.
	call_deferred("_run_harness")


func _run_harness():
	var root = get_tree().root
	print("=" .repeat(70))
	print("  BOTATO HEADLESS HARNESS — get_movement() diagnostic")
	print("=" .repeat(70))

	# 1. Wire up mock scene tree at /root (singletons are autoloaded)
	print("\n[1/5] Wiring mock Brotato scene tree...")
	var refs = MockBrotato.setup_scene_tree(root)
	print("      ✓ /root/Main, /root/Main/EntitySpawner, /root/Main/EnemyProjectiles, /root/Main/Camera")
	print("      ✓ /root/RunData (autoload, character: %s)" % RunData._character_name)
	print("      ✓ /root/ZoneService (autoload, arena: %s)" % ZoneService.current_zone_max_position)
	print("      ✓ /root/CoopService (autoload, no bots)")
	print("      ✓ /root/ModLoader (autoload stub, no dami-ModOptions)")

	# 2. Instantiate real AutobattlerOptions from the mod
	print("\n[2/5] Loading REAL autobattler_options.gd from mod...")
	var options = AutobattlerOptionsScript.new()
	options.name = "AutobattlerOptions"
	root.add_child(options)
	print("      ✓ AutobattlerOptions._ready() completed")
	print("      ✓ adaptive_controller = %s" % options.adaptive_controller)
	print("      ✓ enable_autobattler initial value: %s" % options.enable_autobattler)

	# 3. Enable AI + turn on debug logger
	print("\n[3/5] Enabling autobattler + debug logger...")
	options.enable_autobattler = true
	options.enable_debug_log = true
	if options.debug_logger:
		options.debug_logger.init_logger(true)
		print("      ✓ debug_logger initialized, log path: %s" % options.debug_logger._path)
	print("      ✓ enable_autobattler = %s" % options.enable_autobattler)

	# 4. Attach real player_movement_behavior.gd to mock player
	print("\n[4/5] Attaching REAL player_movement_behavior.gd to mock player...")
	var player = refs.player
	var movement = PlayerMovementBehaviorScript.new()
	movement.name = "MovementBehavior"
	player.add_child(movement)
	print("      ✓ MovementBehavior instantiated, _ready() ran")
	print("      ✓ _calculators.size() = %d" % movement._calculators.size())
	if movement._calculators.size() == 0:
		print("      ⚠ ZERO CALCULATORS — this alone would cause no movement")
	else:
		for i in range(movement._calculators.size()):
			var c = movement._calculators[i]
			print("         [%d] %s" % [i, c.get_script().resource_path.get_file()])

	# 5. Call get_movement() — empty scenario
	print("\n[5/5a] Calling get_movement() on EMPTY scenario (no entities)...")
	print("-" .repeat(70))
	_run_diagnostic(movement, options, refs)
	print("-" .repeat(70))

	# 5b. Populate scenario with enemies, re-test
	print("\n[5/5b] POPULATED scenario — injecting 3 enemies near player...")
	_inject_enemies(refs)
	print("-" .repeat(70))
	_run_diagnostic(movement, options, refs)
	print("-" .repeat(70))

	# 5c. Call get_movement() 65 times to exercise detailed + summary logging paths
	print("\n[5/5c] Exercising logger (65 frames) to verify detail+summary throttling...")
	for i in range(65):
		movement.get_movement()
	print("      ✓ 65 frames completed. See botato_debug.log for detail+summary.")

	# Verify the log file was actually created
	var log_path = options.debug_logger._path if options.debug_logger else ""
	print("\n[6] Verifying log file at: %s" % log_path)
	var f = File.new()
	if f.file_exists(log_path):
		f.open(log_path, File.READ)
		var size = f.get_len()
		f.close()
		print("      ✓ Log file exists, size = %d bytes" % size)
	else:
		print("      ⚠ Log file NOT created at %s" % log_path)

	print("\n" + "=" .repeat(70))
	print("  HARNESS COMPLETE")
	print("=" .repeat(70))
	get_tree().quit(0)


func _inject_enemies(refs) -> void:
	# Place 3 enemies: one far (attract), one near (repel), one medium.
	# With SMG max_range=300, preferred_dist_sq = 90000.
	# Near = 150px (<300) → repel. Far = 500px (>300) → attract.
	var positions = [
		Vector2(960 + 500, 540),  # east, far → attract
		Vector2(960 - 150, 540),  # west, near → repel
		Vector2(960, 540 + 200),  # south, medium
	]
	for pos in positions:
		var enemy = MockBrotato.MockEnemy.new()
		enemy.position = pos
		refs.entity_spawner.enemies.append(enemy)
		refs.entity_spawner.add_child(enemy)
	print("      ✓ Injected %d enemies at %s" % [positions.size(), positions])


func _run_diagnostic(movement, options, refs) -> void:
	# TODO (user decision point): what to print for maximum diagnostic value?
	#
	# Design choices that matter — please customize this function:
	#
	# OPTION A: Just call get_movement() and print result + _last_force_results
	#   - Pros: minimal, shows final output + per-calculator breakdown
	#   - Cons: doesn't show ctx construction, misses _build_context crashes
	#
	# OPTION B: Manually replicate get_movement() flow, print each step
	#   - Pros: captures every stage, pinpoints exact failure location
	#   - Cons: duplicates logic (maintenance burden if mod changes)
	#
	# OPTION C: Inject populated entities (enemies, projectiles, consumables) into the
	#   mock scene BEFORE calling get_movement(), so forces are non-trivial
	#   - Pros: realistic scenario, catches "all forces zero because no entities" case
	#   - Cons: requires designing representative test scenario
	#
	# Recommended: start with A (simplest, fast to run), then add C (realistic entities),
	# then B only if A+C don't reveal the bug.
	#
	# Placeholder below does Option A. REPLACE WITH YOUR CHOICE.

	var move_vector = movement.get_movement()
	print("  get_movement() returned: %s" % move_vector)
	print("  length: %.4f" % move_vector.length())
	print("")
	print("  _last_force_results (per-calculator breakdown):")
	for i in range(movement._last_force_results.size()):
		var r = movement._last_force_results[i]
		var calc_name = movement._calculators[i].get_script().resource_path.get_file()
		print("    [%d] %-25s vector=%s debug_items=%d" % [
			i, calc_name, r.vector, r.debug_items.size()
		])
