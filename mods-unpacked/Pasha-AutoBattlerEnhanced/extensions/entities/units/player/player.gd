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

	# ISSUE #2 OPTION B (v2.1.4) — REPLACE MovementBehavior with fresh instance.
	#
	# Godot 3.7-dev freezes packed-scene children's virtual-dispatch table at
	# scene-pack time. v2.1.3 proved that neither cache-refresh nor set_script()+
	# manual _ready() can re-route dispatch — the node's methods still resolve
	# to the baked base class no matter what we set `.script` to.
	#
	# Workaround: construct a FRESH Object via MovementBehaviorExt.new(). Its
	# class is determined at construction time (no packed-scene involved), so
	# dispatch binds correctly. remove_child() the baked one, add_child() the
	# fresh one under the same name — Godot's natural _ready() path fires on
	# entry to the tree and routes through the extension class normally.
	_replace_movement_behavior()

	check_marker_params()
	check_smoother_params()

	var options_node = $"/root/AutobattlerOptions"
	options_node.connect("setting_changed", self, "on_setting_changed")


func _replace_movement_behavior() -> void:
	var mb_old = null
	for child in get_children():
		if child.name.to_lower() == "movementbehavior" or "_movement_behavior" in child.name.to_lower():
			mb_old = child
			break

	if mb_old == null:
		print("[botato ext] ERROR: could not find MovementBehavior child. Player children:")
		for child in get_children():
			var s = child.get_script()
			var sp = s.resource_path if s else "no_script"
			print("  - ", child.name, " (", child.get_class(), ") script=", sp)
		return

	# Behavioral guard: if the extension's _ready() has ACTUALLY run on the
	# existing node (e.g. future Godot/ModLoader fixed the dispatch bug), we
	# don't need to replace.
	var current_script = mb_old.get_script()
	var ext_actually_ran = current_script == MovementBehaviorExt \
		and "_calculators" in mb_old \
		and mb_old._calculators.size() > 0

	print("[botato ext] mb_old before replace: name=", mb_old.name,
		" script=", ("" if current_script == null else current_script.resource_path),
		" ext_actually_ran=", ext_actually_ran)

	if ext_actually_ran:
		print("[botato ext] extension already active, no replace needed")
		return

	# Preserve identity attributes from the old node
	var mb_name = mb_old.name
	var mb_groups = mb_old.get_groups()

	# Remove + free old packed-scene child. queue_free() defers destruction to
	# next idle frame, which is safe because we're done inspecting mb_old.
	remove_child(mb_old)
	mb_old.queue_free()
	print("[botato ext] removed baked mb_old from Player")

	# Fresh instance — class bound at construction, not at pack time
	var mb_new = MovementBehaviorExt.new()
	mb_new.name = mb_name
	for g in mb_groups:
		mb_new.add_to_group(g)
	add_child(mb_new)
	# Note: owner is set by add_child if not explicitly assigned; scene export
	# cares about owner but we're not exporting this scene.

	print("[botato ext] mb_new added to Player: ", mb_new, " script=",
		(mb_new.get_script().resource_path if mb_new.get_script() else "NULL"))
	# add_child() triggers Godot's natural _ready() dispatch on the new node —
	# the extension's _ready() should now fire and populate _calculators.


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
