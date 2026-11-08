class_name LobbyScreen
extends MenuScreen
## Before the game: four seats to sit in, the host's options (read-only), and for the host
## the room code, "Fill with bots" and "Start game".

signal seat_chosen(seat: int)
signal add_bots_pressed
signal start_pressed
signal leave_pressed

const SEAT_NAMES: Array[String] = ["South", "West", "North", "East"]

var seat_buttons: Array[Button] = []
var bots_button: Button
var start_button: Button
var leave_button: Button
var code_label: Label
var options_label: Label
var info_label: Label

var _box: VBoxContainer
var _free_seats: int = 4


func _init() -> void:
	super()
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_box())
	panel.custom_minimum_size = Vector2(320, 0)
	column.add_child(panel)
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 6)
	panel.add_child(_box)
	_box.add_child(UiStyle.label("Lobby", 28))
	code_label = UiStyle.label("", 22)
	_box.add_child(code_label)
	info_label = UiStyle.label("", 15, true, true)
	info_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	info_label.custom_minimum_size = Vector2(300, 0)
	_box.add_child(info_label)
	for i in range(4):
		var b: Button = Button.new()
		b.custom_minimum_size = Vector2(300, 46)
		b.add_theme_font_size_override("font_size", 19)
		var seat: int = i
		b.pressed.connect(func() -> void: _on_seat_pressed(seat))
		_box.add_child(b)
		seat_buttons.append(b)
	options_label = UiStyle.label("", 15, true, true)
	options_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	options_label.custom_minimum_size = Vector2(300, 0)
	_box.add_child(options_label)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 8)
	_box.add_child(row)
	bots_button = _compact_button("Fill with bots", "dark", 146, row)
	bots_button.pressed.connect(func() -> void: add_bots_pressed.emit())
	start_button = _compact_button("Start game", "primary", 146, row)
	start_button.pressed.connect(func() -> void: start_pressed.emit())
	leave_button = _compact_button("Leave", "paper_outline", 300, _box)
	leave_button.pressed.connect(func() -> void: leave_pressed.emit())


func _compact_button(text: String, kind: String, width: float, parent: Control) -> Button:
	var b: Button = add_button(text, kind, width, parent)
	b.custom_minimum_size = Vector2(width, 46)
	b.add_theme_font_size_override("font_size", 19)
	return b


func _on_seat_pressed(seat: int) -> void:
	if seat_buttons[seat].has_meta("free") and seat_buttons[seat].get_meta("free"):
		seat_chosen.emit(seat)


## `lobby` is SpadesClient.lobby (the host's lobby_state message).
func show_lobby(lobby: Dictionary, is_host: bool, room_code: String, addresses: Array[String]) -> void:
	var seats: Array = lobby.get("seats", [])
	var you: int = int(lobby.get("you", -1))
	_free_seats = 0
	for i in range(4):
		var b: Button = seat_buttons[i]
		var kind: String = "empty"
		var player_name: String = ""
		if i < seats.size() and seats[i] is Dictionary:
			kind = str(seats[i].get("kind", "empty"))
			player_name = str(seats[i].get("name", ""))
		var free: bool = kind == "empty"
		if free:
			_free_seats += 1
		b.set_meta("free", free)
		match kind:
			"human":
				b.text = "%s: %s%s" % [SEAT_NAMES[i], player_name, "  (you)" if i == you else ""]
			"bot":
				b.text = "%s: %s (bot)" % [SEAT_NAMES[i], player_name]
			_:
				b.text = "%s: free, tap to sit" % SEAT_NAMES[i]
		UiStyle.style_button(b, "primary" if i == you else ("dark" if free else "paper_outline"))
	var settings: SpadesSettings = Wire.settings_from_dict(lobby.get("settings", {}))
	options_label.text = "\n".join(option_lines(settings))
	code_label.visible = is_host and room_code != ""
	code_label.text = "Room code: %s" % room_code
	if is_host:
		var lines: Array[String] = ["Friends join from the Join Game screen. Partners sit opposite."]
		if not addresses.is_empty():
			lines.append("If they cannot see this game, they can type: %s" % ", ".join(addresses))
		info_label.text = "\n".join(lines)
	else:
		info_label.text = "Waiting for the host to start the game. Partners sit opposite."
	bots_button.visible = is_host
	start_button.visible = is_host
	start_button.disabled = _free_seats > 0
	bots_button.disabled = _free_seats == 0


## The host's rules as short read-only lines.
static func option_lines(s: SpadesSettings) -> Array[String]:
	var lines: Array[String] = []
	lines.append("Blind Nil: %s    Nil: %s" % [_yes(s.blind_nil_enabled), _yes(s.nil_enabled)])
	lines.append("Redeal: %s    Play higher: %s" % [_yes(s.redeal_enabled), _yes(s.play_higher_enabled)])
	if s.exact_mode != SpadesSettings.ExactMode.OFF:
		var modes: Array[String] = ["", "Easy", "Normal", "Hard"]
		lines.append("Exact bids: %s (no bags)" % modes[s.exact_mode])
	else:
		lines.append("Bags penalty: %s" % _yes(s.bags_penalty_enabled))
	lines.append("Win at %d, lose at %s" % [s.win_score, str(s.lose_score).replace("-", "−")])
	return lines


static func _yes(on: bool) -> String:
	return "on" if on else "off"
