extends Node

const AdaptiveWeightControllerScript = preload(
	"res://mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/adaptive_weight_controller.gd"
)
const BotatoLoggerScript = preload(
	"res://mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/botato_logger.gd"
)
var adaptive_controller  # Exposed property for _build_context() to read (D-08)
var debug_logger          # Exposed property for diagnostics (see botato_logger.gd)

signal setting_changed(setting_name, value, mod_name)

# This Mirrors Configs to act as a backup and make reads shorter without string lookups
var enable_autobattler : bool = false
const ENABLE_AUTOBATTLER_OPTION_NAME = "ENABLE_AUTOBATTLER"

var enable_ai_visuals : bool = false
const ENABLE_AI_VISUALS_OPTION_NAME = "ENABLE_AI_VISUALS"

var enable_ai_marker : bool = true
const ENABLE_AI_MARKER_OPTION_NAME = "ENABLE_AI_MARKER"

var enable_smoothing : bool = true
const ENABLE_SMOOTHING_OPTION_NAME = "ENABLE_SMOOTHING"

var smoothing_speed : float = 1
const SMOOTHING_SPEED_OPTION_NAME = "SMOOTHING_SPEED"

var item_weight : float = 0.25
const ITEM_WEIGHT_OPTION_NAME = "ITEM_WEIGHT"

var projectile_weight : float = 4.0
const PROJECTILE_WEIGHT_OPTION_NAME = "PROJECTILE_WEIGHT"

var tree_weight : float = 4.0
const TREE_WEIGHT_OPTION_NAME = "TREE_WEIGHT"

var boss_weight : float = 9.0
const BOSS_WEIGHT_OPTION_NAME = "BOSS_WEIGHT"

var bumper_weight : float = 2.0
const BUMPER_WEIGHT_OPTION_NAME = "BUMPER_WEIGHT"

var egg_weight : float = 25.0
const EGG_WEIGHT_OPTION_NAME = "EGG_WEIGHT"

var bumper_distance : float = 300
const BUMPER_DISTANCE_OPTION_NAME = "BUMPER_DISTANCE"

var consumable_weight : float = 1.0
const CONSUMABLE_WEIGHT_OPTION_NAME = "CONSUMABLE_WEIGHT"

var crate_weight : float = 0.5
const CRATE_WEIGHT_OPTION_NAME = "CRATE_WEIGHT"

var enable_debug_log : bool = false
const ENABLE_DEBUG_LOG_OPTION_NAME = "ENABLE_DEBUG_LOG"

const DEFAULT_COOLDOWN = .2
var option_cooldown = DEFAULT_COOLDOWN

const MOD_NAME = "Pasha-AutoBattlerEnhanced"
const CONFIG_FILENAME = "user://pasha-botato-options.cfg"
const CONFIG_SECTION = "options"


func _ready():
	adaptive_controller = AdaptiveWeightControllerScript.new()
	add_child(adaptive_controller)

	debug_logger = BotatoLoggerScript.new()
	debug_logger.name = "BotatoLogger"
	add_child(debug_logger)

	reset_defaults()
	load_mod_options()

	# Initialize debug logger AFTER load_mod_options so enable_debug_log reflects saved config
	debug_logger.init_logger(enable_debug_log)
	debug_logger.log_line("AutobattlerOptions._ready() complete")
	debug_logger.log_kv("enable_autobattler", enable_autobattler)
	debug_logger.log_kv("enable_debug_log", enable_debug_log)

	if not get_node_or_null("/root/ModLoader") or not $"/root/ModLoader".has_node("dami-ModOptions"):
		debug_logger.log_line("WARN: ModLoader or dami-ModOptions missing — setting_changed signals won't fire")
		return

	var mod_configs_interface = get_node("/root/ModLoader/dami-ModOptions/ModsConfigInterface")

	if mod_configs_interface:
		mod_configs_interface.connect("setting_changed", self, "setting_changed")
		debug_logger.log_line("Connected to dami-ModOptions setting_changed signal")


func _input(event):
	if event is InputEventKey:
		if event.shift and event.scancode == KEY_SPACE and option_cooldown < 0.0:
			option_cooldown = DEFAULT_COOLDOWN
			enable_autobattler = not enable_autobattler
			
			if $"/root/ModLoader".has_node("dami-ModOptions"):
				var mod_configs_interface = get_node("/root/ModLoader/dami-ModOptions/ModsConfigInterface")
				var mod_configs = mod_configs_interface.mod_configs
				if mod_configs.has("Pasha-AutoBattlerEnhanced"):
					var config = mod_configs["Pasha-AutoBattlerEnhanced"]
					config["ENABLE_AUTOBATTLER"] = enable_autobattler
					mod_configs_interface.on_setting_changed("ENABLE_AUTOBATTLER", enable_autobattler, "Pasha-AutoBattlerEnhanced")
					
			emit_signal("setting_changed", ENABLE_AUTOBATTLER_OPTION_NAME, enable_autobattler, "Pasha-AutoBattlerEnhanced")


func _process(delta):
	option_cooldown -= delta


func setting_changed(key:String, value, mod) -> void:
	if mod != MOD_NAME:
		return
	
	if key == ENABLE_AUTOBATTLER_OPTION_NAME:
		enable_autobattler = value
	elif key == ENABLE_AI_VISUALS_OPTION_NAME:
		enable_ai_visuals = value
	elif key == ENABLE_AI_MARKER_OPTION_NAME:
		enable_ai_marker = value
	elif key == ENABLE_SMOOTHING_OPTION_NAME:
		enable_smoothing = value
	elif key == SMOOTHING_SPEED_OPTION_NAME:
		smoothing_speed = value
	elif key == ITEM_WEIGHT_OPTION_NAME:
		item_weight = value
	elif key == PROJECTILE_WEIGHT_OPTION_NAME:
		projectile_weight = value
	elif key == TREE_WEIGHT_OPTION_NAME:
		tree_weight = value
	elif key == BOSS_WEIGHT_OPTION_NAME:
		boss_weight = value
	elif key == BUMPER_WEIGHT_OPTION_NAME:
		bumper_weight = value
	elif key == EGG_WEIGHT_OPTION_NAME:
		egg_weight = value
	elif key == BUMPER_DISTANCE_OPTION_NAME:
		bumper_distance = value
	elif key == CONSUMABLE_WEIGHT_OPTION_NAME:
		consumable_weight = value
	elif key == CRATE_WEIGHT_OPTION_NAME:
		crate_weight = value
	elif key == ENABLE_DEBUG_LOG_OPTION_NAME:
		enable_debug_log = value
		if debug_logger:
			debug_logger.set_enabled(value)
			if value:
				debug_logger.log_line("Debug log toggled ON via mod options")
	else:
		print_debug("WARNING, UNKNOWN CHANGE ", key)

	save_configs()


func load_mod_options():
	if not $"/root/ModLoader".has_node("dami-ModOptions"):
		return
	
	var mod_configs_interface = get_node("/root/ModLoader/dami-ModOptions/ModsConfigInterface")
	
	var config = ConfigFile.new()
	var err = config.load(CONFIG_FILENAME)
	
	if err != OK:
		return
	
	enable_autobattler = config.get_value(CONFIG_SECTION, ENABLE_AUTOBATTLER_OPTION_NAME, false)
	mod_configs_interface.on_setting_changed(ENABLE_AUTOBATTLER_OPTION_NAME, enable_autobattler, MOD_NAME)
	
	enable_ai_visuals  = config.get_value(CONFIG_SECTION, ENABLE_AI_VISUALS_OPTION_NAME, false)
	mod_configs_interface.on_setting_changed(ENABLE_AI_VISUALS_OPTION_NAME, enable_ai_visuals, MOD_NAME)
	
	enable_ai_marker   = config.get_value(CONFIG_SECTION, ENABLE_AI_MARKER_OPTION_NAME, true)
	mod_configs_interface.on_setting_changed(ENABLE_AI_MARKER_OPTION_NAME, enable_ai_marker, MOD_NAME)
	
	enable_smoothing   = config.get_value(CONFIG_SECTION, ENABLE_SMOOTHING_OPTION_NAME, true)
	mod_configs_interface.on_setting_changed(ENABLE_SMOOTHING_OPTION_NAME, enable_smoothing, MOD_NAME)
	
	smoothing_speed    = config.get_value(CONFIG_SECTION, SMOOTHING_SPEED_OPTION_NAME, 1)
	mod_configs_interface.on_setting_changed(SMOOTHING_SPEED_OPTION_NAME, smoothing_speed, MOD_NAME)
	
	item_weight        = config.get_value(CONFIG_SECTION, ITEM_WEIGHT_OPTION_NAME, 0.25)
	mod_configs_interface.on_setting_changed(ITEM_WEIGHT_OPTION_NAME, item_weight, MOD_NAME)

	projectile_weight  = config.get_value(CONFIG_SECTION, PROJECTILE_WEIGHT_OPTION_NAME, 4.0)
	mod_configs_interface.on_setting_changed(PROJECTILE_WEIGHT_OPTION_NAME, projectile_weight, MOD_NAME)

	tree_weight        = config.get_value(CONFIG_SECTION, TREE_WEIGHT_OPTION_NAME, 4.0)
	mod_configs_interface.on_setting_changed(TREE_WEIGHT_OPTION_NAME, tree_weight, MOD_NAME)

	boss_weight        = config.get_value(CONFIG_SECTION, BOSS_WEIGHT_OPTION_NAME, 9.0)
	mod_configs_interface.on_setting_changed(BOSS_WEIGHT_OPTION_NAME, boss_weight, MOD_NAME)

	bumper_weight      = config.get_value(CONFIG_SECTION, BUMPER_WEIGHT_OPTION_NAME, 2.0)
	mod_configs_interface.on_setting_changed(BUMPER_WEIGHT_OPTION_NAME, bumper_weight, MOD_NAME)

	egg_weight         = config.get_value(CONFIG_SECTION, EGG_WEIGHT_OPTION_NAME, 25.0)
	mod_configs_interface.on_setting_changed(EGG_WEIGHT_OPTION_NAME, egg_weight, MOD_NAME)

	bumper_distance    = config.get_value(CONFIG_SECTION, BUMPER_DISTANCE_OPTION_NAME, 300)
	mod_configs_interface.on_setting_changed(BUMPER_DISTANCE_OPTION_NAME, bumper_distance, MOD_NAME)

	consumable_weight = config.get_value(CONFIG_SECTION, CONSUMABLE_WEIGHT_OPTION_NAME, 1.0)
	mod_configs_interface.on_setting_changed(CONSUMABLE_WEIGHT_OPTION_NAME, consumable_weight, MOD_NAME)

	crate_weight = config.get_value(CONFIG_SECTION, CRATE_WEIGHT_OPTION_NAME, 0.5)
	mod_configs_interface.on_setting_changed(CRATE_WEIGHT_OPTION_NAME, crate_weight, MOD_NAME)

	enable_debug_log = config.get_value(CONFIG_SECTION, ENABLE_DEBUG_LOG_OPTION_NAME, false)
	mod_configs_interface.on_setting_changed(ENABLE_DEBUG_LOG_OPTION_NAME, enable_debug_log, MOD_NAME)


func save_configs() -> void:
	var config = ConfigFile.new()
	
	config.set_value(CONFIG_SECTION, ENABLE_AUTOBATTLER_OPTION_NAME, enable_autobattler)
	config.set_value(CONFIG_SECTION, ENABLE_AI_VISUALS_OPTION_NAME , enable_ai_visuals)
	config.set_value(CONFIG_SECTION, ENABLE_AI_MARKER_OPTION_NAME  , enable_ai_marker)
	config.set_value(CONFIG_SECTION, ENABLE_SMOOTHING_OPTION_NAME  , enable_smoothing)
	config.set_value(CONFIG_SECTION, SMOOTHING_SPEED_OPTION_NAME   , smoothing_speed)
	config.set_value(CONFIG_SECTION, ITEM_WEIGHT_OPTION_NAME       , item_weight)
	config.set_value(CONFIG_SECTION, PROJECTILE_WEIGHT_OPTION_NAME , projectile_weight)
	config.set_value(CONFIG_SECTION, TREE_WEIGHT_OPTION_NAME       , tree_weight)
	config.set_value(CONFIG_SECTION, BOSS_WEIGHT_OPTION_NAME       , boss_weight)
	config.set_value(CONFIG_SECTION, BUMPER_WEIGHT_OPTION_NAME     , bumper_weight)
	config.set_value(CONFIG_SECTION, EGG_WEIGHT_OPTION_NAME        , egg_weight)
	config.set_value(CONFIG_SECTION, BUMPER_DISTANCE_OPTION_NAME   , bumper_distance)
	config.set_value(CONFIG_SECTION, CONSUMABLE_WEIGHT_OPTION_NAME, consumable_weight)
	config.set_value(CONFIG_SECTION, CRATE_WEIGHT_OPTION_NAME     , crate_weight)
	config.set_value(CONFIG_SECTION, ENABLE_DEBUG_LOG_OPTION_NAME , enable_debug_log)

	config.save(CONFIG_FILENAME)


func reset_defaults() -> void:
	enable_autobattler = false
	enable_ai_marker = true
	enable_ai_visuals = false
	enable_smoothing = true

	smoothing_speed = 1
	item_weight = 0.25
	projectile_weight = 4.0
	tree_weight = 4.0
	boss_weight = 9.0
	bumper_weight = 2.0
	egg_weight = 25.0
	bumper_distance = 300
	consumable_weight = 1.0
	crate_weight = 0.5
	enable_debug_log = false
