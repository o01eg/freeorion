extends Control


func _ready():
	GlobalFreeOrionNode.start_network_thread()
	GlobalFreeOrionNode.start_parsing_thread()

	GlobalFreeOrionNode.parsing_completed.connect(_on_freeorion_parsing_completed)


func _on_freeorion_parsing_completed():
	if GlobalFreeOrionNode.options_get_bool("quickstart"):
		GlobalFreeOrionNode.new_single_player_game()
