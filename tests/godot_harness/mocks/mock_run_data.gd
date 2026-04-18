extends Node

# AutoLoad singleton mock of Brotato's RunData.
# Real RunData tracks run progress (character, level, etc.) — we only stub
# the methods the mod's code calls.

var _character_name: String = "character_well_rounded"


func get_player_character(_idx: int):
	return {"name": _character_name}


func set_character(name: String) -> void:
	# Test helper — change character mid-run
	_character_name = name
