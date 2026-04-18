extends Node

# Stub of Brotato's base player_movement_behavior.gd
# Provides the minimal surface the Enhanced mod's override needs to extend.
# Real base class in Brotato does collision checks + input handling — we only
# need enough to let the mod's refactored get_movement() execute.

func _ready():
	pass


func get_movement() -> Vector2:
	# Base class returns human-input vector in real Brotato.
	# In tests we return ZERO so we can detect if the mod delegates to super (AI disabled path).
	return Vector2.ZERO
