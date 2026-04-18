extends Node

# AutoLoad singleton mock of ModLoader.
# Real ModLoader exposes many APIs; here we stub only what the mod's init checks.


func has_node(node_name: String) -> bool:
	# autobattler_options.gd calls: get_node("/root/ModLoader").has_node("dami-ModOptions")
	# Return false so the optional ModOptions wiring block is cleanly skipped.
	return false


func get_unpacked_dir() -> String:
	# mod_main.gd uses this to build paths. We don't instantiate mod_main in tests,
	# but include it for safety.
	return "res://mods-unpacked/"
