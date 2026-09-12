extends Control

const ART_DIR := "res://assets/art/"


static func select_artwork(date: Dictionary, time: Dictionary) -> Dictionary:
	var splash := "splash.png"
	var logo := "logo.png"

	if date.month == 4 and date.day == 1:
		splash = "splash0104.png"
		logo = "logo0104.png"
	elif date.month == 12 and date.day == 25:
		splash = "splash2512.png"
		logo = "logo2512.png"
	elif date.month == 10 and date.day == 31:
		splash = "splash3110.png"
		logo = "logo3110.png"
	elif time.second == 42:
		logo = "logo0104.png"

	return {"splash": splash, "logo": logo}


func _ready():
	GlobalFreeOrionNode.start_network_thread()
	GlobalFreeOrionNode.start_parsing_thread()

	GlobalFreeOrionNode.parsing_completed.connect(_on_freeorion_parsing_completed)

	_setup_artwork()


func _setup_artwork():
	var artwork := select_artwork(
		Time.get_date_dict_from_system(false), Time.get_time_dict_from_system(false)
	)
	$BackgroundTex.texture = load(ART_DIR + artwork.splash)
	$LogoTex.texture = load(ART_DIR + artwork.logo)


func _on_freeorion_parsing_completed():
	if GlobalFreeOrionNode.options_get_bool("quickstart"):
		GlobalFreeOrionNode.new_single_player_game()
