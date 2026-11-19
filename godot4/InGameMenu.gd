class_name InGameMenu
extends Control

# GG's in-game menu (UI/InGameMenu.cpp): a modal window centered over the map
# with Save, Load (single player) or Concede (multiplayer), Exit to Menu,
# Options and Done.  Enter and Escape behave like "Done".
#
# GG sizes the window as ButtonWidth + 40 by 5.75 * ButtonCellHeight + 40 with
# 160 px wide, 24 px tall buttons in 40 px cells, which is the 200x270 panel
# used here.  Save, Load/Concede, Exit to Menu and Options stay disabled until
# the C++ calls listed in README.md exist; Done closes the window.

signal menu_closed


func _ready() -> void:
	# GG::MODAL windows are the top window while they run, so the outer frame
	# keeps the highlighted border even with no focused control inside.
	$Menu.set_modal(true)

	var save := _button("Save")
	var load_or_concede := _button("LoadOrConcede")
	var exit_to_menu := _button("ExitToMenu")
	var options := _button("Options")
	var done := _button("Done")

	save.text = tr("GAME_MENU_SAVE")
	load_or_concede.text = (
		tr("GAME_MENU_LOAD")
		if GlobalFreeOrionNode.get_single_player_game()
		else tr("GAME_MENU_CONCEDE")
	)
	exit_to_menu.text = tr("GAME_MENU_RESIGN")
	options.text = tr("INTRO_BTN_OPTIONS")
	done.text = tr("DONE")

	save.disabled = true
	load_or_concede.disabled = true
	exit_to_menu.disabled = true
	options.disabled = true

	done.pressed.connect(_on_done_pressed)


func _button(name: String) -> Button:
	return ($Menu/Content/Inner/Buttons).get_node(name)


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		if (
			event.keycode == KEY_ESCAPE
			or event.keycode == KEY_ENTER
			or event.keycode == KEY_KP_ENTER
		):
			_close()


func _on_done_pressed() -> void:
	_close()


func _close() -> void:
	menu_closed.emit()
	queue_free()
