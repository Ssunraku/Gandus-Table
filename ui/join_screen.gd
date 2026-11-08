class_name JoinScreen
extends MenuScreen
## Find a game to join: nearby games appear in a list, or type the 4-letter room code,
## or (when the network blocks finding games) type the host's address.

signal join_chosen(address: String, port: int)
signal code_chosen(code: String)
signal back_pressed

var code_edit: LineEdit
var join_code_button: Button
var address_edit: LineEdit
var join_address_button: Button
var back_button: Button
var status_label: Label

var _list: VBoxContainer
var _rows: Array[Button] = []


func _init() -> void:
	super()
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_box())
	panel.custom_minimum_size = Vector2(320, 0)
	column.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 10)
	panel.add_child(box)
	box.add_child(UiStyle.label("Join a game", 30))
	status_label = UiStyle.label("Searching...", 16, true, true)
	status_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	status_label.custom_minimum_size = Vector2(300, 0)
	box.add_child(status_label)
	_list = VBoxContainer.new()
	_list.add_theme_constant_override("separation", 8)
	box.add_child(_list)
	box.add_child(UiStyle.label("Room code", 18))
	var code_row: HBoxContainer = HBoxContainer.new()
	code_row.add_theme_constant_override("separation", 8)
	box.add_child(code_row)
	code_edit = _make_edit("ABCD", 8)  # (a little room for spaces; the code is cleaned up afterwards)
	code_edit.text_submitted.connect(func(_t: String) -> void: _join_by_code())
	code_row.add_child(code_edit)
	join_code_button = _small_button("Join", code_row)
	join_code_button.pressed.connect(_join_by_code)
	box.add_child(UiStyle.label("Or type the host's address", 18))
	var addr_row: HBoxContainer = HBoxContainer.new()
	addr_row.add_theme_constant_override("separation", 8)
	box.add_child(addr_row)
	address_edit = _make_edit("192.168.1.5", 21)
	address_edit.text_submitted.connect(func(_t: String) -> void: _join_by_address())
	addr_row.add_child(address_edit)
	join_address_button = _small_button("Join", addr_row)
	join_address_button.pressed.connect(_join_by_address)
	back_button = add_button("Back", "paper_outline", 200, box)
	back_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	back_button.pressed.connect(func() -> void: back_pressed.emit())


func _make_edit(hint: String, max_chars: int) -> LineEdit:
	var e: LineEdit = LineEdit.new()
	e.placeholder_text = hint
	e.max_length = max_chars
	e.custom_minimum_size = Vector2(190, 44)
	e.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	e.add_theme_font_size_override("font_size", 20)
	var skin: GameSkin = GameSkin.get_current()
	var normal: StyleBoxFlat = StyleBoxFlat.new()
	normal.bg_color = Color(1.0, 0.99, 0.96)
	normal.border_color = Color(0.55, 0.53, 0.5)
	normal.set_border_width_all(2)
	normal.set_corner_radius_all(8)
	normal.content_margin_left = 10.0
	normal.content_margin_right = 10.0
	var focused: StyleBoxFlat = normal.duplicate()
	focused.border_color = skin.color("accent")
	e.add_theme_stylebox_override("normal", normal)
	e.add_theme_stylebox_override("focus", focused)
	e.add_theme_color_override("font_color", skin.color("bar_text"))
	e.add_theme_color_override("caret_color", skin.color("bar_text"))
	return e


func _small_button(text: String, parent: Control) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = Vector2(86, 44)
	b.add_theme_font_size_override("font_size", 20)
	UiStyle.style_button(b, "primary")
	parent.add_child(b)
	return b


## Replaces the list of nearby games. Each row joins that game when tapped.
func show_games(games: Array[Dictionary]) -> void:
	for r in _rows:
		_list.remove_child(r)
		r.queue_free()
	_rows.clear()
	for g in games:
		var b: Button = Button.new()
		var free: int = int(g["free_seats"])
		b.text = "%s  ·  %s  ·  %d free" % [g["name"], g["code"], free]
		b.custom_minimum_size = Vector2(300, 52)
		b.add_theme_font_size_override("font_size", 20)
		UiStyle.style_button(b, "dark")
		var address: String = g["address"]
		var port: int = int(g["port"])
		b.pressed.connect(func() -> void: join_chosen.emit(address, port))
		_list.add_child(b)
		_rows.append(b)


func row_count() -> int:
	return _rows.size()


func row_button(index: int) -> Button:
	return _rows[index]


func set_status(text: String) -> void:
	status_label.text = text


func _join_by_code() -> void:
	var code: String = RoomCode.normalize(code_edit.text)
	if code == "":
		set_status("Type the 4 letters of the room code.")
		return
	code_chosen.emit(code)


func _join_by_address() -> void:
	var parsed: Dictionary = parse_address(address_edit.text)
	if parsed.is_empty():
		set_status("That address does not look right. It should be like 192.168.1.5")
		return
	join_chosen.emit(parsed["address"], parsed["port"])


## "192.168.1.5" or "192.168.1.5:24680" -> {address, port}; {} if it is not an address.
static func parse_address(text: String) -> Dictionary:
	var t: String = text.strip_edges()
	var port: int = WifiTransport.GAME_PORT
	if t.contains(":"):
		var pieces: PackedStringArray = t.split(":")
		if pieces.size() != 2 or not pieces[1].is_valid_int():
			return {}
		port = int(pieces[1])
		t = pieces[0]
	if port < 1 or port > 65535:
		return {}
	var parts: PackedStringArray = t.split(".")
	if parts.size() != 4:
		return {}
	for p in parts:
		if not p.is_valid_int() or int(p) < 0 or int(p) > 255 or p.length() > 3:
			return {}
	return {"address": t, "port": port}
