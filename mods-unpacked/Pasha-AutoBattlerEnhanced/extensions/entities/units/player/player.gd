extends "res://entities/units/player/player.gd"

const MovementBehaviorExt = preload(
	"res://mods-unpacked/Pasha-AutoBattlerEnhanced/extensions/entities/units/movement_behaviors/player_movement_behavior.gd"
)

var ai_icon_scene = preload("res://mods-unpacked/Pasha-AutoBattlerEnhanced/ui/AIScene.tscn")
var ai_icon
var ModsConfigInterface


func _ready():
	# First sentinel — if the process crashes before this line reaches the log,
	# the crash is WITHIN base ._ready() or earlier in Godot's scene setup.
	print("[botato ext] Enhanced player.gd _ready() ENTER (v2.1.5)")

	# v2.1.5 FIX: chain to base ._ready() so Player fully initializes before we
	# mutate its child tree. v2.1.4 skipped this and caused a native crash.
	._ready()
	print("[botato ext] Enhanced player.gd base _ready() chain done")

	ai_icon = ai_icon_scene.instance()
	add_child(ai_icon)
	print("[botato ext] Enhanced player.gd ai_icon added")

	# v2.1.5 FIX: defer the tree mutation to the next idle frame so Player's
	# entire _ready() chain (base + extension) completes first. Tree is stable
	# when _replace_movement_behavior runs.
	call_deferred("_replace_movement_behavior")
	print("[botato ext] Enhanced player.gd _replace_movement_behavior deferred")

	check_marker_params()
	check_smoother_params()

	var options_node = $"/root/AutobattlerOptions"
	options_node.connect("setting_changed", self, "on_setting_changed")
	print("[botato ext] Enhanced player.gd _ready() EXIT")


func _replace_movement_behavior() -> void:
	# Runs on the next idle frame via call_deferred. Tree is stable here.
	print("[botato ext] _replace BEGIN")

	var mb_old = null
	for child in get_children():
		if child.name.to_lower() == "movementbehavior" or "_movement_behavior" in child.name.to_lower():
			mb_old = child
			break

	if mb_old == null:
		print("[botato ext] _replace ERROR: could not find MovementBehavior child. Player children:")
		for child in get_children():
			var s = child.get_script()
			var sp = s.resource_path if s else "no_script"
			print("  - ", child.name, " (", child.get_class(), ") script=", sp)
		return

	print("[botato ext] _replace found mb_old=", mb_old, " name=", mb_old.name)

	# Behavioral guard: skip if extension is already actually running on the old node.
	var current_script = mb_old.get_script()
	var ext_actually_ran = current_script == MovementBehaviorExt \
		and "_calculators" in mb_old \
		and mb_old._calculators.size() > 0
	print("[botato ext] _replace guard: script=",
		("" if current_script == null else current_script.resource_path),
		" ext_actually_ran=", ext_actually_ran)
	if ext_actually_ran:
		print("[botato ext] _replace SKIP: extension already active")
		return

	# v2.1.5 CHANGE: don't free the old node. Disable its processing and rename
	# it. This preserves Object identity for anyone in the base Player that
	# cached the reference (Brotato pattern: `var movement_behavior = $MovementBehavior`
	# in base._ready()). Old node becomes an inert sibling; new node takes over
	# by name (so `$MovementBehavior` / `get_node("MovementBehavior")` finds us).
	var mb_name = mb_old.name
	var mb_groups = mb_old.get_groups()
	print("[botato ext] _replace about to detach mb_old (set_process false + rename)")
	mb_old.set_process(false)
	mb_old.set_physics_process(false)
	mb_old.set_process_input(false)
	mb_old.name = "MovementBehavior_baked_inert"
	print("[botato ext] _replace mb_old detached+renamed to ", mb_old.name)

	print("[botato ext] _replace about to MovementBehaviorExt.new()")
	var mb_new = MovementBehaviorExt.new()
	print("[botato ext] _replace new() done, type=", mb_new.get_class(),
		" script=", (mb_new.get_script().resource_path if mb_new.get_script() else "NULL"))

	mb_new.name = mb_name
	for g in mb_groups:
		mb_new.add_to_group(g)
	print("[botato ext] _replace about to add_child(mb_new)")
	add_child(mb_new)
	print("[botato ext] _replace add_child done; mb_new in tree")
	print("[botato ext] _replace END")


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
