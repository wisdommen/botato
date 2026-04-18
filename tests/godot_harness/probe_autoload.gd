extends SceneTree

func _init():
	print("PROBE: autoload bare-identifier test")
	# Bare identifier (the way the mod accesses it):
	print("RunData bare identifier: ", RunData)
	print("RunData._character_name: ", RunData._character_name)
	print("RunData.get_player_character(0): ", RunData.get_player_character(0))
	print("ZoneService.current_zone_max_position: ", ZoneService.current_zone_max_position)
	print("CoopService.is_bot_by_index: ", CoopService.is_bot_by_index)
	print("PROBE DONE")
	quit(0)
