extends "res://entities/units/player/player.gd"

const MovementBehaviorExt = preload(
	"res://mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/entities/units/movement_behaviors/player_movement_behavior.gd"
)

var ai_icon_scene = preload("res://mods-unpacked/Pasha-AutoBattlerEnhanced/ui/AIScene.tscn")
var ai_icon
var ModsConfigInterface

func _ready():
	# SENTINEL: confirms player.gd extension's _ready() actually fires.
	print("[botato ext] Enhanced player.gd _ready() called on ", self)

	ai_icon = ai_icon_scene.instance()
	add_child(ai_icon)

	# ISSUE #2 OPTION 3 WORKAROUND — force-swap MovementBehavior script.
	# ModLoader's install_script_extension() is broken on Godot 3.7-dev for
	# scripts referenced from packed-scene child nodes (baked .tscn data bypasses
	# the resource cache). player.gd's extension runs correctly (cache-refresh
	# worked for instanced scenes), so we can fix the movement_behavior child
	# from here: set_script() to our extension, then manually invoke _ready()
	# since Godot doesn't re-fire it automatically.
	_force_swap_movement_behavior()

	check_marker_params()
	check_smoother_params()

	var options_node = $"/root/AutobattlerOptions"
	options_node.connect("setting_changed", self, "on_setting_changed")


func _force_swap_movement_behavior() -> void:
	var mb = null
	for child in get_children():
		if child.name.to_lower() == "movementbehavior" or "_movement_behavior" in child.name.to_lower():
			mb = child
			break

	if mb == null:
		print("[botato ext] ERROR: could not find MovementBehavior child. Player children:")
		for child in get_children():
			var s = child.get_script()
			var sp = s.resource_path if s else "no_script"
			print("  - ", child.name, " (", child.get_class(), ") script=", sp)
		return

	var current_script = mb.get_script()
	var current_path = "" if current_script == null else current_script.resource_path
	print("[botato ext] movement_behavior before swap: name=", mb.name, " script=", current_path)

	# Guard against double-swap if future Godot/ModLoader honors the cache refresh
	if current_script == MovementBehaviorExt:
		print("[botato ext] movement_behavior already using extension, no swap needed")
		return

	mb.set_script(MovementBehaviorExt)
	print("[botato ext] movement_behavior script swapped to extension")

	# Godot doesn't re-fire _ready() after set_script() on an in-tree node.
	# Manually invoke it so our extension's init runs (loads _calculators etc).
	# The extension guards against double-init by checking _calculators.size().
	if mb.has_method("_ready"):
		mb._ready()
		print("[botato ext] movement_behavior._ready() manually invoked")


func on_setting_changed(_setting_name:String, _value, _mod_name):
	check_marker_params()
	check_smoother_params()


func check_marker_params():
	var options_node = $"/root/AutobattlerOptions"
	
	options_node.load_mod_options()
	
	var ai_enabled = options_node.enable_autobattler
	var ai_marker_enabled = options_node.enable_ai_marker
	
	if ai_enabled and ai_marker_enabled:
		ai_icon.show()
	else:
		ai_icon.hide()


func check_smoother_params():
	var options_node = $"/root/AutobattlerOptions"
	
	options_node.load_mod_options()
	
	var enable_smoothing = options_node.enable_smoothing
	var smoothing_speed = options_node.smoothing_speed

	$"/root/Main/Camera".smoothing_enabled = enable_smoothing 
	$"/root/Main/Camera".smoothing_speed = smoothing_speed 
