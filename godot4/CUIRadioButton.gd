class_name CUIRadioButton
extends Button

# GG::CUIRadioRepresenter draws a black circle with a grey border and an inner
# disc that is green when checked.  The caption is drawn left aligned just
# after the circle, which a plain Button cannot do (it centers its text).
# Geometry and colours are taken from UI/CUIControls.cpp, UI/CUIDrawUtil.cpp
# and GG/src/Button.cpp (StateButtonRepresenter::DoLayout):
#   the circle is the font point size (16px) wide, the caption starts at
#   BN_W * (1 + SPACING) = 24px, colours come from
#   ClientUI::CtrlBorderColor() = 124, ClientUI::StateButtonColor() = (0,127,0),
#   DisabledColor(x) moves x 75% of the way to grey,
#   AdjustBrightness(x, n) adds n to each channel.
const RADIUS := 8.0
const TEXT_X := 24.0
# Godot's draw_string() places the *baseline* of the text a couple of pixels
# above pos: with the 16 px UI font the ink runs from pos - 12 to pos + 2.
# Putting pos slightly below the button's vertical centre therefore centers
# the ink on the circle, as GG's FORMAT_VCENTER TextControl does.
const TEXT_Y_ADJUST := 5.0

const WINDOW_BG_COLOR := Color(0.137255, 0.137255, 0.137255, 1)

const BORDER_COLOR := Color(0.486275, 0.486275, 0.486275, 1)
const DISABLED_BORDER_COLOR := Color(0.498039, 0.498039, 0.498039, 1)
const HOVER_BORDER_COLOR := Color(0.607843, 0.607843, 0.607843, 1)

const CHECKED_INSIDE_COLOR := Color(0.0, 0.498039, 0.0, 1)
const CHECKED_OUTSIDE_COLOR := Color(0.196078, 0.694118, 0.196078, 1)
const DISABLED_CHECKED_INSIDE_COLOR := Color(0.376471, 0.498039, 0.376471, 1)
const DISABLED_CHECKED_OUTSIDE_COLOR := Color(0.572549, 0.694118, 0.572549, 1)

const OFF_INSIDE_COLOR := Color(0.192157, 0.192157, 0.192157, 1)
const OFF_OUTSIDE_COLOR := Color(0.349020, 0.349020, 0.349020, 1)
const DISABLED_OFF_INSIDE_COLOR := Color(0.203922, 0.203922, 0.203922, 1)
const DISABLED_OFF_OUTSIDE_COLOR := Color(0.360784, 0.360784, 0.360784, 1)
const HOVER_OFF_INSIDE_COLOR := Color(0.313725, 0.313725, 0.313725, 1)
const HOVER_OFF_OUTSIDE_COLOR := Color(0.470588, 0.470588, 0.470588, 1)

var checked := false
var caption := ""
var hovered := false


func _ready() -> void:
	caption = tr(text)
	text = ""
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)


func _on_mouse_entered() -> void:
	hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	hovered = false
	queue_redraw()


func _draw() -> void:
	var center := Vector2(RADIUS, size.y * 0.5)

	var border := BORDER_COLOR
	if disabled:
		border = DISABLED_BORDER_COLOR
	elif hovered:
		border = HOVER_BORDER_COLOR

	# Outer circle: 1px border, then a gap of window background, then the
	# inner disc.  GG draws the same three rings for checked and unchecked
	# buttons, only the inner colours differ.
	draw_circle(center, RADIUS, border)
	draw_circle(center, RADIUS - 1.0, WINDOW_BG_COLOR)

	if checked:
		var inside := DISABLED_CHECKED_INSIDE_COLOR if disabled else CHECKED_INSIDE_COLOR
		var outside := DISABLED_CHECKED_OUTSIDE_COLOR if disabled else CHECKED_OUTSIDE_COLOR
		draw_circle(center, RADIUS - 2.0, outside)
		draw_circle(center, RADIUS - 3.0, outside)
		draw_circle(center, RADIUS - 4.0, inside)
	else:
		var inside := OFF_INSIDE_COLOR
		var outside := OFF_OUTSIDE_COLOR
		if disabled:
			inside = DISABLED_OFF_INSIDE_COLOR
			outside = DISABLED_OFF_OUTSIDE_COLOR
		elif hovered:
			inside = HOVER_OFF_INSIDE_COLOR
			outside = HOVER_OFF_OUTSIDE_COLOR
		draw_circle(center, RADIUS - 2.0, outside)
		draw_circle(center, RADIUS - 3.0, inside)

	if caption != "":
		var font := get_theme_font("normal", "Button")
		var font_size := get_theme_font_size("normal", "Button")
		var text_top := size.y * 0.5 + TEXT_Y_ADJUST
		draw_string(
			font,
			Vector2(TEXT_X, text_top),
			caption,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			Color(1, 1, 1)
		)
