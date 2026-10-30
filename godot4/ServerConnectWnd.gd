class_name ServerConnectWnd
extends VBoxContainer

signal ok_pressed
signal cancel_pressed

const VALID_NAME_CHARS := "abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789_-"
const EDIT_NORMAL_STYLE := preload("res://assets/resources/EditNormal.tres")
const EDIT_DISABLED_STYLE := preload("res://assets/resources/EditDisabled.tres")
const EDIT_FOCUS_STYLE := preload("res://assets/resources/EditFocus.tres")
const LIST_NORMAL_STYLE := preload("res://assets/resources/ListNormal.tres")
const LIST_DISABLED_STYLE := preload("res://assets/resources/ListDisabled.tres")

var m_host_selected := true
var m_servers: Array[String] = []


func _ready() -> void:
	var client_type := _client_type()
	client_type.add_item("PLAYER")
	client_type.add_item("MODERATOR")
	client_type.add_item("OBSERVER")
	client_type.select(0)
	client_type.uncheck_rows()

	_host_bn().pressed.connect(_on_host_pressed)
	_join_bn().pressed.connect(_on_join_pressed)
	_refresh_bn().pressed.connect(_on_refresh_pressed)
	_ok_bn().pressed.connect(_on_ok_pressed)
	_cancel_bn().pressed.connect(_on_cancel_pressed)
	_name_edit().text_changed.connect(_on_name_changed)
	_ip_edit().text_changed.connect(_on_ip_changed)

	_set_radio_states(true)
	_populate_server_list()
	_enable_disable_controls()
	# GG::ServerConnectWnd::ModalInit() moves the focus to the player name edit,
	# which also gives the window its highlighted outer border.
	_name_edit().grab_focus()


func _input(event: InputEvent) -> void:
	if event is InputEventKey and not event.echo:
		if event.key_code == KEY_ESCAPE:
			_on_cancel_pressed()
		elif event.key_code == KEY_ENTER or event.key_code == KEY_KP_ENTER:
			_on_ok_pressed()


func _host_bn() -> Button:
	return $Panel/Rows/ModeRow/RadioGroup/Host


func _join_bn() -> Button:
	return $Panel/Rows/ModeRow/RadioGroup/Join


func _client_type() -> CUIDropDown:
	return $Panel/Rows/ModeRow/ClientTypeBox/ClientType


func _lan_label() -> Label:
	return $Panel/Rows/LanLabel


func _server_list() -> PanelContainer:
	return $Panel/Rows/ServerList


func _refresh_bn() -> Button:
	return $Panel/Rows/RefreshRow/Refresh


func _internet_label() -> Label:
	return $Panel/Rows/InternetLabel


func _ip_edit() -> LineEdit:
	return $Panel/Rows/IPEdit


func _name_edit() -> LineEdit:
	return $Panel/Rows/NameRow/NameEdit


func _ok_bn() -> Button:
	return $Panel/Rows/OkCancelRow/Ok


func _cancel_bn() -> Button:
	return $Panel/Rows/OkCancelRow/Cancel


func _set_radio_states(host: bool) -> void:
	_host_bn().checked = host
	_join_bn().checked = not host
	_host_bn().queue_redraw()
	_join_bn().queue_redraw()


func _populate_server_list() -> void:
	# Stub: the real client runs LAN discovery and adds the known server list.
	m_servers = []
	var list: VBoxContainer = _server_list().get_node("List")
	for child in list.get_children():
		child.queue_free()
	for server_name in m_servers:
		var row := Label.new()
		row.auto_translate_mode = Node.AUTO_TRANSLATE_MODE_DISABLED
		row.text = server_name
		list.add_child(row)


func _name_ok(name: String) -> bool:
	if name.is_empty():
		return false
	for i in range(name.length()):
		if VALID_NAME_CHARS.find(name[i]) == -1:
			return false
	return true


func _enable_disable_controls() -> void:
	var host_selected := m_host_selected
	var server_selected := not m_servers.is_empty()
	var ip_entered := not _ip_edit().text.is_empty()

	_client_type().disabled = host_selected
	_client_type().update_arrow()
	_server_list().set("theme_override_styles/panel", _list_style(host_selected))
	_refresh_bn().disabled = host_selected
	_ip_edit().editable = not host_selected
	_apply_edit_style(_ip_edit(), host_selected)

	_ok_bn().disabled = (
		not _name_ok(_name_edit().text)
		or (not host_selected and not server_selected and not ip_entered)
	)

	_host_bn().queue_redraw()
	_join_bn().queue_redraw()


func _list_style(disabled: bool) -> StyleBoxFlat:
	if disabled:
		return LIST_DISABLED_STYLE
	return LIST_NORMAL_STYLE


# GG::CUIEdit renders its border in CtrlBorderColor (124), lightened to 248
# while it has focus, and DisabledColor() of those when it is disabled.
func _apply_edit_style(edit: LineEdit, disabled: bool) -> void:
	if disabled:
		edit.set("theme_override_styles/read_only", EDIT_DISABLED_STYLE)
		edit.set("theme_override_styles/normal", EDIT_DISABLED_STYLE)
		edit.set("theme_override_styles/focus", EDIT_DISABLED_STYLE)
	else:
		edit.set("theme_override_styles/normal", EDIT_NORMAL_STYLE)
		edit.set("theme_override_styles/focus", EDIT_FOCUS_STYLE)
		edit.set("theme_override_styles/read_only", EDIT_NORMAL_STYLE)


func _on_host_pressed() -> void:
	m_host_selected = true
	_set_radio_states(true)
	_enable_disable_controls()


func _on_join_pressed() -> void:
	m_host_selected = false
	_set_radio_states(false)
	_enable_disable_controls()


func _on_refresh_pressed() -> void:
	_populate_server_list()
	_enable_disable_controls()


func _on_name_changed(_text: String) -> void:
	_enable_disable_controls()


func _on_ip_changed(_text: String) -> void:
	_enable_disable_controls()


func _on_ok_pressed() -> void:
	if _ok_bn().disabled:
		return
	print(
		(
			"ServerConnectWnd OK: name=%s type=%s host=%s"
			% [
				_name_edit().text,
				_client_type().current_item,
				_ip_edit().text,
			]
		)
	)
	ok_pressed.emit()


func _on_cancel_pressed() -> void:
	cancel_pressed.emit()
