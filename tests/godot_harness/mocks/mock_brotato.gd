extends Node

# Mock Brotato scene tree: Main, EntitySpawner, EnemyProjectiles, Camera, Player.
# Singletons (RunData, ZoneService, CoopService, ModLoader) are autoloaded — see project.godot.
# This file only creates the scene tree nodes the mod looks up via $"/root/Main/..." paths.


# ---- Nested mock classes ----

class MockWeapon:
	var current_stats
	func _init(max_range: float):
		current_stats = {"max_range": max_range}


class MockStatsDict:
	var health: int
	var _max_health: int
	func _init(hp: int):
		health = hp
		_max_health = hp


class MockPlayer extends Node2D:
	var player_index: int = 0
	var current_weapons: Array = []
	var max_stats
	var current_stats

	func _ready():
		max_stats = MockStatsDict.new(100)
		current_stats = MockStatsDict.new(100)


class MockEntitySpawner extends Node:
	var neutrals: Array = []   # trees
	var enemies: Array = []
	var bosses: Array = []


class MockEnemyProjectiles extends Node:
	pass


class MockEnemyStats:
	var base_drop_chance: int = 0  # non-egg


class MockEnemy extends Node2D:
	var _attack_behavior = null  # not SpawningAttackBehavior
	var _current_attack_behavior = null  # not ChargingAttackBehavior
	var _move_locked: bool = false
	var stats

	func _ready():
		stats = MockEnemyStats.new()


class MockWaveTimer:
	var time_left: float = 15.0  # mid-wave default


class MockMain extends Node:
	var _consumables: Array = []
	var _active_golds: Array = []
	var _players: Array = []
	var _wave_timer

	func _ready():
		_wave_timer = MockWaveTimer.new()


# ---- Factory helper used by test_runner.gd ----

static func setup_scene_tree(root: Node) -> Dictionary:
	# Create and attach the Brotato scene-tree mocks to /root.
	# Autoloaded singletons (RunData, ZoneService, CoopService, ModLoader) are already at /root.

	var main = MockMain.new()
	main.name = "Main"
	root.add_child(main)

	var entity_spawner = MockEntitySpawner.new()
	entity_spawner.name = "EntitySpawner"
	main.add_child(entity_spawner)

	var projectiles = MockEnemyProjectiles.new()
	projectiles.name = "EnemyProjectiles"
	main.add_child(projectiles)

	var camera = Node.new()
	camera.name = "Camera"
	camera.set("smoothing_enabled", true)
	main.add_child(camera)

	var player = MockPlayer.new()
	player.name = "Player"
	player.position = Vector2(960, 540)  # arena center
	player.current_weapons = [MockWeapon.new(300)]  # SMG-ish range
	main.add_child(player)
	main._players.append(player)

	return {
		"main": main,
		"entity_spawner": entity_spawner,
		"projectiles": projectiles,
		"camera": camera,
		"player": player,
	}
