extends "res://entities/units/player/player.gd"

var ai_icon_scene = preload("res://mods-unpacked/Pasha-AutoBattlerEnhanced/ui/AIScene.tscn")
var ai_icon
var ModsConfigInterface

func _ready():
	# SENTINEL: confirms player.gd extension's _ready() actually fires.
	# Compare with player_movement_behavior.gd's [botato ext] sentinel — if this
	# one appears in godot.log but the movement one doesn't, the .tscn-level
	# cache issue is specific to movement_behavior (issue #2).
	print("[botato ext] Enhanced player.gd _ready() called on ", self)

	ai_icon = ai_icon_scene.instance()
	add_child(ai_icon)

	# Debug: inspect what movement behavior the player got
	_debug_movement_behavior()

	check_marker_params()
	check_smoother_params()

	var options_node = $"/root/AutobattlerOptions"
	options_node.connect("setting_changed", self, "on_setting_changed")


func _debug_movement_behavior() -> void:
	# Walks the player's children looking for the movement behavior and reports
	# its script path. This tells us whether ModLoader's extension install for
	# player_movement_behavior.gd actually took effect on the instantiated node.
	for child in get_children():
		if "_movement_behavior" in child.name.to_lower() or child.name.to_lower() == "movementbehavior":
			var script = child.get_script()
			if script:
				print("[botato ext] movement_behavior child found: ", child.name, " script=", script.resource_path)
			else:
				print("[botato ext] movement_behavior child found: ", child.name, " script=NULL")
			return
	# Fallback: log ALL children so we can see the actual tree structure
	print("[botato ext] no movement_behavior child found. Player children:")
	for child in get_children():
		var s = child.get_script()
		var sp = s.resource_path if s else "no_script"
		print("  - ", child.name, " (", child.get_class(), ") script=", sp)


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
