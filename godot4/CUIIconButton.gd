class_name CUIIconButton
extends TextureButton

# GG's icon-only toolbar buttons (UI/MapWnd.cpp) are CUIButton built from three
# SubTextures - unpressed, pressed and rollover - scaled to the icon size and
# with no text.  TextureButton has the same three slots (texture_normal,
# texture_hover, texture_pressed), so the scenes assign them statically and
# only the "window is open" highlight needs code.

var _normal_icon: Texture2D
var _hover_icon: Texture2D


func _ready() -> void:
	_normal_icon = get_texture_normal()
	_hover_icon = get_texture_hover()
	mouse_entered.connect(_on_mouse_entered)
	pressed.connect(_on_pressed)


# MapWnd::ShowMenu() swaps the unpressed and rollover graphics while the
# in-game menu is open, so the toolbar icon stays highlighted.
func set_active(active: bool) -> void:
	if _normal_icon == null or _hover_icon == null:
		return
	set_texture_normal(_hover_icon if active else _normal_icon)
	set_texture_hover(_normal_icon if active else _hover_icon)


func _on_mouse_entered() -> void:
	if not disabled:
		$Rollover.play()


func _on_pressed() -> void:
	$Click.play()
