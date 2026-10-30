class_name CUIDropDown
extends OptionButton

# GG::CUIDropDownList does not use the stock OptionButton arrow: it draws a
# yellow isosceles triangle inside a small bordered box at the right hand side
# of the control.  Geometry and colours come from UI/CUIControls.cpp
# (CUIDropDownList::InitBuffer / ::Render), UI/CUIDrawUtil.cpp (AdjustBrightness,
# BufferStoreAngledCornerRectangleVertices) and UI/ClientUI.cpp
# ("ui.dropdownlist.arrow.color" = 130,130,0).
const ARROW_MARGIN := 3
const ARROW_WIDTH := 11
const BOX_WIDTH := ARROW_WIDTH + 3 * ARROW_MARGIN  # 20
const BOX_HEIGHT := ARROW_WIDTH + 2 * ARROW_MARGIN  # 17
# GG cuts the bottom-right corner of the control *and* of the arrow box
# (InitBuffer passes lower_right_angled = true; the 5 px angle offset is
# rasterized as a ~7 px chamfer).
const BOX_CHAMFER := 7

const ARROW_FILL_COLOR := Color(0.509804, 0.509804, 0.0, 1)  # (130, 130, 0)
const ARROW_BORDER_COLOR := Color(0.803922, 0.803922, 0.294118, 1)  # (205, 205, 75)
const BOX_BORDER_COLOR := Color(0.486275, 0.486275, 0.486275, 1)  # CtrlBorderColor, (124)
const BOX_BORDER_DISABLED_COLOR := Color(0.498039, 0.498039, 0.498039, 1)  # 127
const BOX_BORDER_FOCUS_COLOR := Color(0.972549, 0.972549, 0.972549, 1)  # LightenClr(124), (248)

# GG::CUIListBox paints the currently selected popup row in (71, 71, 71),
# which PopupHover.tres provides for Godot's popup rows.

var m_popup_open := false


func _ready() -> void:
	update_arrow()
	focus_entered.connect(update_arrow)
	focus_exited.connect(update_arrow)

	var popup := get_popup()
	popup.add_theme_stylebox_override("panel", preload("res://assets/resources/PopupPanel.tres"))
	popup.add_theme_stylebox_override("hover", preload("res://assets/resources/PopupHover.tres"))
	popup.add_theme_color_override("font_color", Color(1, 1, 1))
	popup.add_theme_color_override("font_hover_color", Color(1, 1, 1))
	popup.about_to_popup.connect(_on_popup_about_to_popup)
	popup.popup_hide.connect(_on_popup_hide)
	# PopupMenu has no per-item background colour; it draws the "hover" style
	# box for the focused row, so keep the focused row on the current selection
	# whenever the mouse is not over the list.
	popup.mouse_exited.connect(func() -> void: popup.set_focused_item(selected))


# GG::CUIListBox rows have no check marks, but Godot's OptionButton popup marks
# the selected row with a radio check box by default.
func uncheck_rows() -> void:
	var popup := get_popup()
	for i in range(popup.item_count):
		popup.set_item_as_checkable(i, false)


# The arrow box border follows the control border: 124 normally, 127 when the
# control is disabled and 248 while the drop-down has focus
# (GG::CUIDropDownList::Render uses the same border colour for both).
func update_arrow() -> void:
	var border := BOX_BORDER_COLOR
	if disabled:
		border = BOX_BORDER_DISABLED_COLOR
	elif has_focus() and not m_popup_open:
		border = BOX_BORDER_FOCUS_COLOR
	set("theme_override_icons/arrow", ImageTexture.create_from_image(_make_arrow_texture(border)))


func _on_popup_about_to_popup() -> void:
	m_popup_open = true
	# GG only lightens the border while the control itself has focus; its list
	# is a separate window, so the border stays at 124 while the list is open.
	set("theme_override_styles/focus", preload("res://assets/resources/DropDownNormal.tres"))
	update_arrow()
	_set_window_popup_open(true)

	var popup := get_popup()
	popup.min_size = Vector2i(maxi(0, int(size.x) - 5), 0)
	popup.set_focused_item(selected)


func _on_popup_hide() -> void:
	m_popup_open = false
	set("theme_override_styles/focus", preload("res://assets/resources/DropDownFocus.tres"))
	# GG keeps the focus on the drop-down after its list closes, so the border
	# is lightened again.
	grab_focus()
	update_arrow()
	_set_window_popup_open(false)


# The drop-down list is a separate window in GG, so the window that owns this
# control loses focus (and its highlighted border) while the list is open.
func _set_window_popup_open(open: bool) -> void:
	var node := get_parent()
	while node:
		if node.has_method("set_popup_open"):
			node.set_popup_open(open)
			return
		node = node.get_parent()


func _make_arrow_texture(border_color: Color) -> Image:
	var img := Image.create(BOX_WIDTH, BOX_HEIGHT, true, Image.FORMAT_RGBA8)
	# Pixels on or beyond this diagonal are outside the chamfered box.
	var chamfer := (BOX_WIDTH - 1) + (BOX_HEIGHT - 1) - BOX_CHAMFER  # 28

	for y in range(BOX_HEIGHT):
		for x in range(BOX_WIDTH):
			var on_edge := x == 0 or y == 0 or x == BOX_WIDTH - 1 or y == BOX_HEIGHT - 1
			if x + y > chamfer:
				img.set_pixel(x, y, Color(0, 0, 0, 0))
			elif on_edge or x + y == chamfer:
				img.set_pixel(x, y, border_color)
			else:
				img.set_pixel(x, y, Color(0, 0, 0, 0))

	# Triangle in box local coordinates: GG::BufferStoreIsoscelesTriangle uses
	# the top edge of its rect as the base and the apex at the bottom center.
	# GG: base at control y = 2 * margin, apex at control y = sz.y - 2 * margin,
	# i.e. 3 px inside the box on both sides.
	var base_ul := Vector2(ARROW_MARGIN + 1.5, ARROW_MARGIN)
	var base_lr := Vector2(BOX_WIDTH - ARROW_MARGIN - 1.5, ARROW_MARGIN)
	var apex := Vector2((base_ul.x + base_lr.x) * 0.5, BOX_HEIGHT - ARROW_MARGIN - 1.0)

	_fill_triangle(img, _grow_triangle(base_ul, base_lr, apex, 0.6), ARROW_BORDER_COLOR, chamfer)
	_fill_triangle(img, [base_ul, base_lr, apex], ARROW_FILL_COLOR, chamfer)
	return img


func _grow_triangle(a: Vector2, b: Vector2, c: Vector2, amount: float) -> Array:
	var center := (a + b + c) / 3.0
	return [
		center + (a - center) * (1.0 + amount / max(0.001, (a - center).length())),
		center + (b - center) * (1.0 + amount / max(0.001, (b - center).length())),
		center + (c - center) * (1.0 + amount / max(0.001, (c - center).length())),
	]


func _fill_triangle(img: Image, triangle: Array, color: Color, chamfer: int) -> void:
	for y in range(BOX_HEIGHT):
		for x in range(BOX_WIDTH):
			if x + y > chamfer:
				continue
			var p := Vector2(x + 0.5, y + 0.5)
			if _inside_triangle(p, triangle[0], triangle[1], triangle[2]):
				img.set_pixel(x, y, color)


func _inside_triangle(p: Vector2, a: Vector2, b: Vector2, c: Vector2) -> bool:
	var d1 := (b - a).cross(p - a)
	var d2 := (c - b).cross(p - b)
	var d3 := (a - c).cross(p - c)
	return (d1 >= 0 and d2 >= 0 and d3 >= 0) or (d1 <= 0 and d2 <= 0 and d3 <= 0)
