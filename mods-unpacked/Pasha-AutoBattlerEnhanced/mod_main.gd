extends Node

const MOD_DIR = "Pasha-AutoBattlerEnhanced/"
const MOD_VERSION = "2.1.0"  # keep in sync with manifest.json

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
	_boot("mod_main._init() complete")


func _install_and_log(rel_path: String) -> void:
	var full_path = ext_dir + rel_path
	ModLoaderMod.install_script_extension(full_path)
	_boot("install_script_extension: " + rel_path)


func _boot(msg: String) -> void:
	# Prefixed console output → appears in godot.log, greppable by user.
	print("[botato boot] " + msg)
