extends Control

const ART_DIR := "res://assets/art/"
const KEYBOARD_MARGIN := 8.0


func _ready():
	GlobalFreeOrionNode.parsing_completed.connect(_on_freeorion_parsing_completed)
	GlobalFreeOrionNode.start_game.connect(_on_freeorion_start_game)

	GlobalFreeOrionNode.start_network_thread()
	GlobalFreeOrionNode.start_parsing_thread()

	var dpi := DisplayServer.screen_get_dpi()
	if dpi > 300:
		get_window().content_scale_factor = 1.75
	elif dpi > 200:
		get_window().content_scale_factor = 1.35
	else:
		get_window().content_scale_factor = 1.0

	var date := Time.get_date_dict_from_system(false)
	var time := Time.get_time_dict_from_system(false)
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
	$Splash.texture = load(ART_DIR + splash)
	$Logo.texture = load(ART_DIR + logo)

	var window := get_window()
	var margins := SafeArea.margins(window)
	var corner_margin := SafeArea.corner_inset(
		SafeArea.corner_radius(window, SafeArea.CORNER_BOTTOM_RIGHT)
	)
	$Version.offset_right = -maxf(margins.z, corner_margin)
	$Version.offset_bottom = -maxf(margins.w, corner_margin)
	$Version.text = GlobalFreeOrionNode.get_version()


func _process(_delta: float) -> void:
	if $Popup.visible:
		_keep_popup_above_keyboard()


func _keep_popup_above_keyboard() -> void:
	var popup: Control = $Popup
	var keyboard_height := _virtual_keyboard_height()
	popup.position.y = _popup_target_y(popup, keyboard_height)


func _virtual_keyboard_height() -> float:
	if not DisplayServer.has_feature(DisplayServer.FEATURE_VIRTUAL_KEYBOARD):
		return 0.0
	var physical_height := DisplayServer.virtual_keyboard_get_height()
	if physical_height <= 0:
		return 0.0
	return float(physical_height) / get_window().content_scale_factor


func _popup_target_y(popup: Control, keyboard_height: float) -> float:
	var viewport_height := get_viewport_rect().size.y
	var centered_y := (viewport_height - popup.size.y) * 0.5
	if keyboard_height <= 0.0:
		return centered_y

	var focus := get_viewport().gui_get_focus_owner()
	if focus == null or not popup.is_ancestor_of(focus):
		return centered_y

	var focus_bottom := focus.get_global_rect().end.y - popup.get_global_rect().position.y
	var keyboard_top := viewport_height - keyboard_height
	var target_bottom := centered_y + focus_bottom
	if focus_bottom > popup.size.y * 0.5:
		# When editing the address (or another lower field), keep the whole
		# window including the OK/Cancel row above the keyboard.
		target_bottom = centered_y + popup.size.y
	var shift := maxf(0.0, target_bottom + KEYBOARD_MARGIN - keyboard_top)
	return centered_y - shift


func _on_freeorion_parsing_completed():
	if GlobalFreeOrionNode.options_get_bool("quickstart"):
		$Menu/VBoxContainer/MenuButtons/MarginContainer/VBoxContainer/QuickStart.disabled = true
		GlobalFreeOrionNode.new_single_player_game()
	else:
		$Menu/VBoxContainer/MenuButtons/MarginContainer/VBoxContainer/QuickStart.disabled = false
		$Menu/VBoxContainer/MenuButtons/MarginContainer/VBoxContainer/MultiPlayer.disabled = false


func _on_credits_pressed() -> void:
	var credits_wnd := preload("res://CreditsWnd.tscn").instantiate()
	credits_wnd.menu_left = $Menu.get_global_rect().position.x
	add_child(credits_wnd)


func _on_exit_game_pressed() -> void:
	get_tree().quit()


func _on_quick_start_pressed() -> void:
	$Menu/VBoxContainer/MenuButtons/MarginContainer/VBoxContainer/QuickStart.disabled = true
	GlobalFreeOrionNode.new_single_player_game()


func _on_freeorion_start_game(_is_new_game: bool) -> void:
	get_tree().change_scene_to_file("res://MapWnd.tscn")


func _multi_player_bn() -> Button:
	return $Menu/VBoxContainer/MenuButtons/MarginContainer/VBoxContainer/MultiPlayer


func _on_multi_player_pressed() -> void:
	_multi_player_bn().disabled = true
	var scw = preload("res://ServerConnectWnd.tscn").instantiate()
	scw.cancel_pressed.connect(_on_server_connect_cancelled)
	scw.ok_pressed.connect(_on_server_connect_ok)
	# Show the frame first so the window can take focus in its _ready()
	# (GG does this in ServerConnectWnd::ModalInit).
	$Popup.visible = true
	$Popup.add_child(scw)


func _on_server_connect_cancelled() -> void:
	for child in $Popup.get_children():
		child.queue_free()
	$Popup.visible = false
	_multi_player_bn().disabled = false
	_multi_player_bn().grab_focus()


func _on_server_connect_ok() -> void:
	_on_server_connect_cancelled()
