extends Node

const MOD_DIR = "Pasha-AutoBattlerEnhanced/"
const MOD_VERSION = "2.1.5"  # keep in sync with manifest.json

# Workaround for Godot 3.7-dev custom build where ModLoader 6.1's
# GDScript.duplicate() call raises "Can't call non-static function 'duplicate'",
# causing script extension cache swaps to silently no-op. Affected base scripts
# are those loaded into cache BEFORE install_script_extension — notably
# player_movement_behavior.gd, which gets pre-loaded many times during engine
# boot (see issue #2). The fix is to force-reload these scripts via
# ResourceLoader.CACHE_MODE_REPLACE after all extensions have been installed,
# so the cache picks up the newly-extended version before Player.tscn
# instantiates its movement behavior node.
const CACHE_REPLACE = 2  # ResourceLoader.CACHE_MODE_REPLACE (Godot 3.5+ int literal)
const EXTENSIONS_NEEDING_CACHE_REFRESH = [
	"res://entities/units/movement_behaviors/player_movement_behavior.gd",
	"res://entities/units/player/player.gd",
]

var dir = ""
var ext_dir = ""
var trans_dir = ""


func _init():
	# mod_main._init() runs BEFORE any autoloads, so we can't use BotatoLogger here.
	# Use print() — these lines appear in godot.log with the [botato boot] prefix,
	# so the user can grep for them regardless of ENABLE_DEBUG_LOG setting.
	_boot("mod_main._init() entered")
	_boot("mod version: " + MOD_VERSION)

	dir = ModLoaderMod.get_unpacked_dir() + MOD_DIR
	ext_dir = dir + "extensions/"
	trans_dir = dir + "translations/"

	_boot("unpacked dir: " + dir)

	# Add extensions — each logged individually so we can see which registered
	_install_and_log("main.gd")
	_install_and_log("entities/units/movement_behaviors/player_movement_behavior.gd")
	_install_and_log("entities/units/player/player.gd")
	_install_and_log("singletons/coop_service.gd")
	_install_and_log("ui/menus/global/focus_emulator.gd")
	_install_and_log("ui/menus/ingame/upgrades_ui.gd")
	_install_and_log("ui/menus/pages/main_menu.gd")
	_install_and_log("ui/menus/run/coop_join_panel.gd")

	ModLoaderMod.add_translation(trans_dir + "autobattler_options.en.translation")
	_boot("translation added")

	# Force cache-refresh for extensions affected by Godot 3.7-dev duplicate() bug.
	# Must run AFTER all install_script_extension calls so the cache gets the
	# newly-extended scripts, not the original base classes.
	for base_path in EXTENSIONS_NEEDING_CACHE_REFRESH:
		var refreshed = ResourceLoader.load(base_path, "", CACHE_REPLACE)
		if refreshed != null:
			_boot("cache-refresh OK: " + base_path)
		else:
			_boot("cache-refresh FAILED (null): " + base_path)

	_boot("mod_main._init() complete")


func _install_and_log(rel_path: String) -> void:
	var full_path = ext_dir + rel_path
	ModLoaderMod.install_script_extension(full_path)
	_boot("install_script_extension: " + rel_path)


func _boot(msg: String) -> void:
	# Prefixed console output → appears in godot.log, greppable by user.
	print("[botato boot] " + msg)
