extends Control

# The toolbar icon buttons in GG's layout column order (UI/MapWnd.cpp), each
# mapped to the stringtable key used for its tooltip.
const TOOLBAR_ICON_BUTTONS := {
	"BtnMessages": "MAP_BTN_MESSAGES",
	"BtnSitRep": "MAP_BTN_SITREP",
	"BtnEmpires": "MAP_BTN_EMPIRES",
	"BtnObjects": "MAP_BTN_OBJECTS",
	"BtnResearch": "MAP_BTN_RESEARCH",
	"BtnProduction": "MAP_BTN_PRODUCTION",
	"BtnDesign": "MAP_BTN_DESIGN",
	"BtnGovernment": "MAP_BTN_GOVERNMENT",
	"BtnGraphs": "MAP_BTN_GRAPH",
	"BtnPedia": "MAP_BTN_PEDIA",
	"BtnMenu": "MAP_BTN_MENU",
}

var _turn_base_left := 0.0
var _turn_base_top := 0.0
var _turn_base_width := 0.0
# Authored anchor offsets of every icon button, keyed by node name, so the
# safe-area shift always starts from the scene values.
var _icon_base_offsets := {}
var _icon_base_top := 0.0
var _icon_base_right := -INF
var _menu = null


func _ready() -> void:
	var btn: Button = $ToolBar/BtnTurn
	_turn_base_left = btn.offset_left
	_turn_base_top = btn.offset_top
	_turn_base_width = btn.offset_right - btn.offset_left

	# The icons are assigned per instance in MapWnd.tscn, and CUIIconButton.gd
	# swaps normal and hover while the menu is open, as GG's ShowMenu() does.
	# They are 32x32 like GG's MENU_ICON_SIZE.
	# The MAP_BTN_*_DESC strings are empty in GG, so the tooltips are just the
	# button names.  The stringtable keys are assigned untranslated: the tooltip
	# label is translated when it is shown, so tr() here would translate the text
	# twice.
	for name in TOOLBAR_ICON_BUTTONS:
		var icon: TextureButton = $ToolBar.get_node(name)
		_icon_base_offsets[name] = [icon.offset_left, icon.offset_right]
		_icon_base_top = icon.offset_top
		_icon_base_right = maxf(_icon_base_right, icon.offset_right)
		icon.tooltip_text = TOOLBAR_ICON_BUTTONS[name]

	GlobalFreeOrionNode.start_game.connect(_on_freeorion_start_game)
	GlobalFreeOrionNode.turn_update.connect(_on_freeorion_turn_update)
	btn.set_click_sound(preload("res://assets/sound/turn_button_click.ogg"))
	_update_btn_turn()
	_apply_safe_area()
	get_viewport().size_changed.connect(_apply_safe_area)


func _on_freeorion_start_game(_is_new_game: bool) -> void:
	_update_btn_turn()


func _on_freeorion_turn_update() -> void:
	_update_btn_turn()


func _on_btn_turn_pressed() -> void:
	GlobalFreeOrionNode.start_turn()
	_update_btn_turn()


func _update_btn_turn() -> void:
	var turn: int = GlobalFreeOrionNode.get_current_turn()
	if turn < 1:
		$ToolBar/BtnTurn.disabled = true
		return
	$ToolBar/BtnTurn.disabled = false
	$ToolBar/BtnTurn.text = tr("MAP_BTN_TURN_UPDATE").replace("%1%", str(turn))


func _on_btn_menu_pressed() -> void:
	_show_menu()


# MapWnd::TogglePedia() opens the encyclopedia panel, which the Godot client
# does not have yet, so the button only plays its click sound for now.
func _on_btn_pedia_pressed() -> void:
	pass


# MapWnd::ToggleResearch() shows the ResearchWnd, hides the side panel and the
# competing Production/Design windows, and keeps the icon highlighted with the
# same normal/rollover swap as set_active() while the window is open.  None of
# that exists in the Godot client yet, so the button only plays its click sound
# for now.
func _on_btn_research_pressed() -> void:
	pass


# MapWnd::ToggleProduction() enters the production view mode: it shows the
# ProductionWnd, hides the side panel and the competing Research/Design/Pedia
# windows, and keeps the icon highlighted with the same normal/rollover swap as
# set_active().  None of that exists in the Godot client yet, so the button only
# plays its click sound for now.
func _on_btn_production_pressed() -> void:
	pass


# MapWnd::ToggleDesign() shows the ship DesignWnd and keeps the icon highlighted
# with the same normal/rollover swap as set_active() while it is open.  The
# design window is not implemented yet, so the button only plays its click sound
# for now.
func _on_btn_design_pressed() -> void:
	pass


# MapWnd::ToggleGovernment() shows the GovernmentWnd and keeps the icon
# highlighted with the same normal/rollover swap as set_active() while it is
# open.  The government window is not implemented yet, so the button only plays
# its click sound for now.
func _on_btn_government_pressed() -> void:
	pass


# MapWnd::ShowGraphs() opens the encyclopedia side panel with the "ENC_GRAPH"
# entry, so this needs the same side panel as the Pedia button.  Until then the
# button only plays its click sound.
func _on_btn_graphs_pressed() -> void:
	pass


# MapWnd::ToggleMessages() shows ui.GetMessageWnd() unless the Production,
# Research or Design windows are open, and keeps the icon highlighted with the
# same normal/rollover swap as set_active() while it is visible.  The message
# window is not implemented yet, so the button only plays its click sound.
func _on_btn_messages_pressed() -> void:
	pass


# MapWnd::ToggleSitRep() shows the sitrep panel on the map (m_sitrep_panel) and
# swaps the icon graphics while it is open, unless the Production, Research or
# Design windows are visible.  The sitrep panel is a follow-up, so the button
# only plays its click sound for now.
func _on_btn_sitrep_pressed() -> void:
	pass


# MapWnd::ToggleEmpires() shows ui.GetPlayerListWnd() and keeps the icon
# highlighted while it is open, again suppressed by the Production, Research and
# Design windows.  The player list window does not exist in the Godot client yet,
# so the button only plays its click sound.
func _on_btn_empires_pressed() -> void:
	pass


# MapWnd::ToggleObjects() shows the object list window (m_object_list_wnd),
# hiding the Research, Production and Design windows first, and swaps the icon
# graphics while the list is open.  The object list is not implemented yet, so
# the button only plays its click sound for now.
func _on_btn_objects_pressed() -> void:
	pass


func _unhandled_input(event: InputEvent) -> void:
	# GG's ui.gamemenu hotkey (F10 by default) opens the same menu.
	if _menu == null and event.is_action_pressed("ui_gamemenu"):
		_show_menu()


func _show_menu() -> void:
	if _menu != null:
		return
	# MapWnd::ShowMenu() ignores repeat calls while the modal menu is open.
	var menu = preload("res://InGameMenu.tscn").instantiate()
	menu.menu_closed.connect(_on_menu_closed)
	add_child(menu)
	_menu = menu
	$ToolBar/BtnMenu.set_active(true)


func _on_menu_closed() -> void:
	_menu = null
	$ToolBar/BtnMenu.set_active(false)


func _apply_safe_area() -> void:
	if OS.get_name() != "Android":
		return
	var window := get_window()
	var btn: Button = $ToolBar/BtnTurn
	var shift := maxf(_safe_area_inset() - _turn_base_left, 0.0)
	btn.offset_left = _turn_base_left + shift
	btn.offset_right = btn.offset_left + _turn_base_width

	var icon_shift := _icon_button_shift(
		_icon_base_right,
		_icon_base_top,
		SafeArea.corner_radius(window, SafeArea.CORNER_TOP_RIGHT),
		SafeArea.margins(window).z
	)
	# The icon buttons sit side by side at the right edge of the toolbar, so the
	# same shift keeps all of them inside the safe area.
	for name in TOOLBAR_ICON_BUTTONS:
		var icon: TextureButton = $ToolBar.get_node(name)
		var base: Array = _icon_base_offsets[name]
		icon.offset_left = base[0] - icon_shift
		icon.offset_right = base[1] - icon_shift


func _safe_area_inset() -> float:
	var window := get_window()
	return maxf(
		SafeArea.margins(window).x,
		SafeArea.corner_clearance(
			SafeArea.corner_radius(window, SafeArea.CORNER_TOP_LEFT), _turn_base_top
		)
	)


# The icon buttons are anchored to the right edge of the toolbar, so their
# clearance from that edge is the mirror image of the Turn button's clearance
# from the left edge; the resulting shift moves them left.
func _icon_button_shift(base_right: float, top: float, radius: float, safe_right: float) -> float:
	var margin := maxf(maxf(-base_right, safe_right), SafeArea.corner_clearance(radius, top))
	return margin + base_right
