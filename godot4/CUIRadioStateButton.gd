class_name CUIRadioStateButton
extends Button

# 16 is default font size
const RADIUS := 16.0 / 2.0
# BN_W * (1 + SPACING)
const TEXT_X := 16.0 * (1 + 0.5)
# Godot draws text from its baseline; with the 16 px font the ink runs from
# pos - 12 to pos + 2, so moving the baseline 5 px below the centre centres the
# caption like GG's FORMAT_VCENTER TextControl.
const TEXT_Y_ADJUST := 5.0

# Reuse the GG palette already captured in the shared style boxes; the rest is
# derived with the brightness steps from CUIRadioRepresenter::Render().
const CTRL_BORDER_STYLE := preload("res://assets/resources/ButtonNormal.tres")
const CTRL_BORDER_DISABLED_STYLE := preload("res://assets/resources/ButtonDisabled.tres")
const WND_BG_STYLE := preload("res://assets/resources/WndOuter.tres")
const GRAY_STYLE := preload("res://assets/resources/WndOuterFocus.tres")

const GRAY_COLOR := GRAY_STYLE.border_color
const BRIGHTEN_SCALE := 1.25
const CHECKED_RING_STEP := 50.0 / 255.0
const UNCHECKED_FILL_STEP := -75.0 / 255.0
const UNCHECKED_RING_STEP := 40.0 / 255.0
const DISABLED_GRAY_MIX := 0.75

# ui.control.border.color: ButtonNormal.tres border (124 => 0.486).
const BORDER_COLOR := CTRL_BORDER_STYLE.border_color
# ButtonDisabled.tres border: DisabledColor(124) => 127 => 0.498.
const DISABLED_BORDER_COLOR := CTRL_BORDER_DISABLED_STYLE.border_color
# Rollover scales the border by 1.25 => 155.
const HOVER_BORDER_COLOR := Color(
	BORDER_COLOR.r * BRIGHTEN_SCALE,
	BORDER_COLOR.g * BRIGHTEN_SCALE,
	BORDER_COLOR.b * BRIGHTEN_SCALE,
	1
)
# GG leaves the ring gap transparent; use the window background from WndOuter.tres.
const WINDOW_BG_COLOR := Color(
	WND_BG_STYLE.bg_color.r, WND_BG_STYLE.bg_color.g, WND_BG_STYLE.bg_color.b, 1
)

# ui.button.state.color (0, 127, 0): its green is the disabled border gray.
const CHECKED_INSIDE_COLOR := Color(0, DISABLED_BORDER_COLOR.g, 0, 1)
# Checked outer ring adds 50 => (50, 177, 50).
const CHECKED_OUTSIDE_COLOR := Color(
	CHECKED_INSIDE_COLOR.r + CHECKED_RING_STEP,
	CHECKED_INSIDE_COLOR.g + CHECKED_RING_STEP,
	CHECKED_INSIDE_COLOR.b + CHECKED_RING_STEP,
	1
)
# DisabledColor() mixes 75% toward the gray in WndOuterFocus.tres (128).
const DISABLED_CHECKED_INSIDE_COLOR := Color(
	CHECKED_INSIDE_COLOR.r + (GRAY_COLOR.r - CHECKED_INSIDE_COLOR.r) * DISABLED_GRAY_MIX,
	CHECKED_INSIDE_COLOR.g + (GRAY_COLOR.g - CHECKED_INSIDE_COLOR.g) * DISABLED_GRAY_MIX,
	CHECKED_INSIDE_COLOR.b + (GRAY_COLOR.b - CHECKED_INSIDE_COLOR.b) * DISABLED_GRAY_MIX,
	1
)
# Its outer ring adds 50.
const DISABLED_CHECKED_OUTSIDE_COLOR := Color(
	DISABLED_CHECKED_INSIDE_COLOR.r + CHECKED_RING_STEP,
	DISABLED_CHECKED_INSIDE_COLOR.g + CHECKED_RING_STEP,
	DISABLED_CHECKED_INSIDE_COLOR.b + CHECKED_RING_STEP,
	1
)
# Unchecked: border - 75 => 49, then + 40 => 89.
const OFF_INSIDE_COLOR := Color(
	BORDER_COLOR.r + UNCHECKED_FILL_STEP,
	BORDER_COLOR.g + UNCHECKED_FILL_STEP,
	BORDER_COLOR.b + UNCHECKED_FILL_STEP,
	1
)
const OFF_OUTSIDE_COLOR := Color(
	OFF_INSIDE_COLOR.r + UNCHECKED_RING_STEP,
	OFF_INSIDE_COLOR.g + UNCHECKED_RING_STEP,
	OFF_INSIDE_COLOR.b + UNCHECKED_RING_STEP,
	1
)
# Disabled border 127: - 75 => 52, + 40 => 92.
const DISABLED_OFF_INSIDE_COLOR := Color(
	DISABLED_BORDER_COLOR.r + UNCHECKED_FILL_STEP,
	DISABLED_BORDER_COLOR.g + UNCHECKED_FILL_STEP,
	DISABLED_BORDER_COLOR.b + UNCHECKED_FILL_STEP,
	1
)
const DISABLED_OFF_OUTSIDE_COLOR := Color(
	DISABLED_OFF_INSIDE_COLOR.r + UNCHECKED_RING_STEP,
	DISABLED_OFF_INSIDE_COLOR.g + UNCHECKED_RING_STEP,
	DISABLED_OFF_INSIDE_COLOR.b + UNCHECKED_RING_STEP,
	1
)
# Rollover border 155: - 75 => 80, + 40 => 120.
const HOVER_OFF_INSIDE_COLOR := Color(
	HOVER_BORDER_COLOR.r + UNCHECKED_FILL_STEP,
	HOVER_BORDER_COLOR.g + UNCHECKED_FILL_STEP,
	HOVER_BORDER_COLOR.b + UNCHECKED_FILL_STEP,
	1
)
const HOVER_OFF_OUTSIDE_COLOR := Color(
	HOVER_OFF_INSIDE_COLOR.r + UNCHECKED_RING_STEP,
	HOVER_OFF_INSIDE_COLOR.g + UNCHECKED_RING_STEP,
	HOVER_OFF_INSIDE_COLOR.b + UNCHECKED_RING_STEP,
	1
)

@export var checked := false
var _caption := ""
var _hovered := false

@onready var _rollover_player := get_node_or_null("Rollover") as AudioStreamPlayer
@onready var _click_player := get_node_or_null("Click") as AudioStreamPlayer


func _ready() -> void:
	_caption = tr(text)
	text = ""
	auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
	mouse_entered.connect(_on_mouse_entered)
	mouse_exited.connect(_on_mouse_exited)
	pressed.connect(_on_pressed)


func _on_mouse_entered() -> void:
	# GG's CUIRadioRepresenter::OnChanged() only plays this on entering hover
	# from BN_UNPRESSED, and SetState() ignores disabled buttons.
	if not disabled and _rollover_player != null:
		_rollover_player.play()
	_hovered = true
	queue_redraw()


func _on_mouse_exited() -> void:
	_hovered = false
	queue_redraw()


func _on_pressed() -> void:
	# Unlike the checkbox representer, CUIRadioRepresenter::OnChecked() plays
	# the click sound unconditionally, including a click on the checked button.
	if _click_player != null:
		_click_player.play()


func _draw() -> void:
	var center := Vector2(RADIUS, size.y * 0.5)

	var border := BORDER_COLOR
	if disabled:
		border = DISABLED_BORDER_COLOR
	elif _hovered:
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
		elif _hovered:
			inside = HOVER_OFF_INSIDE_COLOR
			outside = HOVER_OFF_OUTSIDE_COLOR
		draw_circle(center, RADIUS - 2.0, outside)
		draw_circle(center, RADIUS - 3.0, inside)

	if _caption != "":
		var font := get_theme_font("normal", "Button")
		var font_size := get_theme_font_size("normal", "Button")
		var text_top := size.y * 0.5 + TEXT_Y_ADJUST
		draw_string(
			font,
			Vector2(TEXT_X, text_top),
			_caption,
			HORIZONTAL_ALIGNMENT_LEFT,
			-1.0,
			font_size,
			Color(1, 1, 1)
		)
