extends Control

@onready var _btn_turn: Button = $ToolBar/BtnTurn


func _ready() -> void:
	GlobalFreeOrionNode.start_game.connect(_on_freeorion_start_game)
	GlobalFreeOrionNode.turn_update.connect(_on_freeorion_turn_update)
	_update_turn_button()


func _on_freeorion_start_game(_is_new_game: bool) -> void:
	_update_turn_button()


func _on_freeorion_turn_update() -> void:
	_update_turn_button()


func _update_turn_button() -> void:
	# GG picks MAP_BTN_TURN_UNREADY ("Revise %1%") only while a multiplayer turn is
	# being revised; otherwise it shows MAP_BTN_TURN_UPDATE ("Turn %1%"). Substitution
	# happens in MapWnd, not in the i18n layer (UI/MapWnd.cpp, m_btn_turn->SetText).
	var turn: int = GlobalFreeOrionNode.get_current_turn()
	if turn < 1:
		return
	_btn_turn.text = tr("MAP_BTN_TURN_UPDATE").replace("%1%", str(turn))
