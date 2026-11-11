extends PanelContainer

# GG::CUIWnd draws its outer border in ClientUI::WndOuterBorderColor() (64) and
# lightens it to LightenClr(64) = 128 while the window — or one of its children —
# has focus (see UI/CUIWnd.cpp, CUIWnd::Render).  Attach this script to the
# PanelContainer that uses WndOuter.tres to reproduce that behaviour.

const NORMAL_STYLE := preload("res://assets/resources/WndOuter.tres")
const FOCUSED_STYLE := preload("res://assets/resources/WndOuterFocus.tres")

# GG's drop-down list is a separate window, so the window below it loses focus
# while the list is open.  CUIDropDown calls set_popup_open() for that case.
var _popup_open := false

# A GG::MODAL window is the top window for as long as it runs, so its frame
# stays highlighted even when nothing inside it has keyboard focus.
var _modal := false


func _ready() -> void:
	get_viewport().gui_focus_changed.connect(_on_focus_changed)
	visibility_changed.connect(_update_border)
	_update_border()


func _on_focus_changed(_control: Control) -> void:
	_update_border()


func set_popup_open(open: bool) -> void:
	_popup_open = open
	_update_border()


func set_modal(modal: bool) -> void:
	_modal = modal
	_update_border()


func _update_border() -> void:
	# GUIImpl::FocusWnd() returns the top window of the modal stack while one is
	# open, so a GG::MODAL window is always the focus window and its outer border
	# stays lightened.
	var focused := _modal
	if not focused and not _popup_open:
		var focus_owner := get_viewport().gui_get_focus_owner()
		focused = focus_owner != null and (focus_owner == self or is_ancestor_of(focus_owner))
	add_theme_stylebox_override("panel", FOCUSED_STYLE if focused else NORMAL_STYLE)
