extends Node

# AutoLoad singleton mock of Brotato's CoopService.
# Tracks which player slots are bot-controlled in co-op mode.

var is_bot_by_index: Array = [false, false, false, false]
