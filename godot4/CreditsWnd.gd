class_name CreditsWnd
extends Control

## Displays the scrolling credits, mirroring the GG CreditsWnd of the C++ client.
##
## The window darkens the part of the splash screen between the two lines and
## scrolls the text read from default/credits.xml upwards.  Clicking, pressing
## Escape or resizing the window closes it.  When the text has scrolled past the
## top edge the window closes itself.

signal closed

const SIDE_PAD := 30.0
const SCROLL_SPEED := 25.0  # pixels per second, the same as GG's ticks / 40
const WHEEL_STEP := 50.0  # GG scrolls 2000 ticks, 2000 / 40 = 50 pixels
const UPPER_LINE := 79.0
const LOWER_LINE := 692.0
const SPLASH_HEIGHT := 768.0

@export var menu_left := -1.0

var _scroll := 0.0
var _content_height := 0.0
var _closing := false

@onready var _text: RichTextLabel = $Text


func _ready() -> void:
	var viewport_size := get_viewport_rect().size
	var upper := floorf(UPPER_LINE * viewport_size.y / SPLASH_HEIGHT)
	var lower := floorf(LOWER_LINE * viewport_size.y / SPLASH_HEIGHT)
	position = Vector2(0.0, upper)
	size = Vector2(viewport_size.x, lower - upper)

	if menu_left < 0.0:
		menu_left = viewport_size.x * 0.75
	_text.position = Vector2(SIDE_PAD, size.y * 0.5)
	_text.size = Vector2(maxf(menu_left - SIDE_PAD, 1.0), 0.0)
	_text.text = _read_credits()
	_content_height = maxf(_text.get_content_height(), _text.get_combined_minimum_size().y)

	get_viewport().size_changed.connect(_close)
	set_process(true)


func _process(delta: float) -> void:
	_scroll += SCROLL_SPEED * delta
	_text.position.y = size.y * 0.5 - _scroll
	if _content_height > 0.0 and _scroll > _content_height + size.y * 0.5:
		_close()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed:
		if event.button_index == MOUSE_BUTTON_WHEEL_UP:
			_scroll = maxf(_scroll - WHEEL_STEP, 0.0)
			_text.position.y = size.y * 0.5 - _scroll
			accept_event()
		elif event.button_index == MOUSE_BUTTON_WHEEL_DOWN:
			_scroll += WHEEL_STEP
			_text.position.y = size.y * 0.5 - _scroll
			accept_event()
		elif event.button_index == MOUSE_BUTTON_LEFT:
			_close()


func _unhandled_input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_ESCAPE:
		get_viewport().set_input_as_handled()
		_close()


func _close() -> void:
	if _closing:
		return
	_closing = true
	set_process(false)
	closed.emit()
	queue_free()


func _read_credits() -> String:
	var groups: Array = GlobalFreeOrionNode.get_credits()
	if groups.is_empty():
		push_warning("Unable to read credits.xml")
		return "[center][color=#cccccc]credits.xml not found[/color][/center]"

	var credits := "[center]"
	for group in groups:
		credits += _escape(group["name"]) + "\n\n"
		for item in group["items"]:
			match item["type"]:
				"PERSON":
					credits += _person(item) + "\n"
				"RESOURCE":
					credits += _resource(item) + "\n"
		credits += "\n\n"
	credits += "[/center]"
	return credits


func _person(item: Dictionary) -> String:
	var line := _escape(item.get("name", ""))
	var nick := String(item.get("nick", ""))
	if not nick.is_empty():
		line += " [color=#999999](%s)[/color]" % _escape(nick)
	var task := String(item.get("task", ""))
	if not task.is_empty():
		line += " - [color=#cccccc]%s[/color]" % _escape(task)
	return line


func _resource(item: Dictionary) -> String:
	var author := _escape(item.get("author", ""))
	var title := _escape(item.get("title", ""))
	var license := _escape(item.get("license", ""))
	var line := (
		"%s - [color=#999999]%s[/color]\n%s %s"
		% [
			author,
			title,
			tr("INTRO_CREDITS_LICENSE"),
			license,
		]
	)
	var source := String(item.get("source", ""))
	if not source.is_empty():
		line += " - [color=#999999]%s[/color]" % _escape(source)
	line += "\n"
	var notes := String(item.get("notes", ""))
	if not notes.is_empty():
		line += "[color=#cccccc](%s)[/color]\n" % _escape(notes)
	return line


func _escape(text: String) -> String:
	return text.replace("[", "[lb]")
