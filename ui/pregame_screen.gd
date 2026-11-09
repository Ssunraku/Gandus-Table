class_name PreGameScreen
extends MenuScreen
## The table before a game starts. Four seats with an avatar and a name bar each.
## - The host stays at the bottom. Tapping a free seat puts a bot there; tapping a bot
##   sends it away.
## - A player who just connected sees the table from the host's side, taps a free seat and
##   presses "Join table". Once seated the table turns so that player is at the bottom, and
##   tapping another free seat moves them there.
## When all four seats are taken the game starts by itself after a 3-2-1 countdown.

signal seat_chosen(seat: int)
signal bot_add_chosen(seat: int)
signal bot_remove_chosen(seat: int)
signal leave_pressed

const TABLE_SIZE: Vector2 = Vector2(330, 326)
const SLOT_SIZE: Vector2 = Vector2(116, 100)
## Where each seat sits in the table: bottom, left, top, right (as seen by the viewer).
const SLOT_POS: Array[Vector2] = [Vector2(107, 222), Vector2(2, 112), Vector2(107, 4), Vector2(212, 112)]

## Indexed by the real seat number (0 = the host's seat).
var seat_buttons: Array[Button] = []
var name_labels: Array[Label] = []
var avatars: Array[SeatAvatar] = []
var table_panel: Panel
var title_label: Label
var centre_label: Label
var code_label: Label
var info_label: Label
var options_label: Label
var notice_label: Label
var join_button: Button
var leave_button: Button

var _slots: Array[Control] = []
var _bars: Array[StyleBoxFlat] = []
var _kinds: Array[String] = ["empty", "empty", "empty", "empty"]
var _names: Array[String] = ["", "", "", ""]
var _you: int = -1
var _is_host: bool = false
var _selected: int = -1
var _k: float = 1.0  # how much bigger everything is drawn (an upright phone uses more)
var _centre_font_size: int = 16


func _init() -> void:
	super()
	column.add_theme_constant_override("separation", 10)
	title_label = light_label("", 26)
	var table: Panel = Panel.new()
	table_panel = table
	table.custom_minimum_size = TABLE_SIZE
	table.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	var felt: StyleBoxFlat = StyleBoxFlat.new()
	felt.bg_color = GameSkin.get_current().color("felt_center").lightened(0.06)
	felt.border_color = GameSkin.get_current().color("felt_edge").darkened(0.35)
	felt.set_border_width_all(4)
	felt.set_corner_radius_all(28)
	felt.anti_aliasing = true
	table.add_theme_stylebox_override("panel", felt)
	column.add_child(table)
	centre_label = Label.new()
	centre_label.position = Vector2(120, 118)
	centre_label.size = Vector2(90, 90)
	centre_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	centre_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	centre_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	centre_label.add_theme_font_override("font", GameSkin.get_current().get_font())
	centre_label.add_theme_font_size_override("font_size", 16)
	centre_label.add_theme_color_override("font_color", GameSkin.get_current().color("button_text"))
	table.add_child(centre_label)
	for i in range(4):
		_build_slot(table, i)
	code_label = light_label("", 30, true)
	info_label = _small_label(14)
	options_label = _small_label(13)
	notice_label = light_label("", 15, true)
	var row: HBoxContainer = HBoxContainer.new()
	row.add_theme_constant_override("separation", 10)
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	column.add_child(row)
	join_button = add_button("Join table", "primary", 170, row)
	join_button.pressed.connect(func() -> void:
		if _selected >= 0:
			seat_chosen.emit(_selected))
	leave_button = add_button("Leave", "dark", 130, row)
	leave_button.pressed.connect(func() -> void: leave_pressed.emit())


## Draws everything `k` times bigger (1.0 = normal).
func set_ui_scale(k: float) -> void:
	_k = k
	table_panel.custom_minimum_size = TABLE_SIZE * k
	centre_label.position = Vector2(120, 118) * k
	centre_label.size = Vector2(90, 90) * k
	centre_label.add_theme_font_size_override("font_size", int(16 * k))
	title_label.add_theme_font_size_override("font_size", int(26 * k))
	code_label.add_theme_font_size_override("font_size", int(30 * k))
	notice_label.add_theme_font_size_override("font_size", int(15 * k))
	info_label.add_theme_font_size_override("font_size", int(14 * k))
	options_label.add_theme_font_size_override("font_size", int(13 * k))
	info_label.custom_minimum_size = Vector2(330 * k, 0)
	options_label.custom_minimum_size = Vector2(330 * k, 0)
	join_button.custom_minimum_size = Vector2(170 * k, 56)
	leave_button.custom_minimum_size = Vector2(130 * k, 56)
	for seat in range(4):
		_slots[seat].custom_minimum_size = SLOT_SIZE * k
		_slots[seat].size = SLOT_SIZE * k
		avatars[seat].custom_minimum_size = Vector2(SeatAvatar.SIZE, SeatAvatar.SIZE) * k
		avatars[seat].size = Vector2(SeatAvatar.SIZE, SeatAvatar.SIZE) * k
		avatars[seat].position = Vector2((SLOT_SIZE.x - SeatAvatar.SIZE) / 2.0, 0) * k
		name_labels[seat].position = Vector2(2, 64) * k
		name_labels[seat].size = Vector2(SLOT_SIZE.x - 4, 28) * k
	_refresh_seats()


func _small_label(font_size: int) -> Label:
	var l: Label = light_label("", font_size)
	l.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	l.custom_minimum_size = Vector2(330, 0)
	return l


func _build_slot(table: Control, seat: int) -> void:
	var slot: Control = Control.new()
	slot.custom_minimum_size = SLOT_SIZE
	slot.size = SLOT_SIZE
	table.add_child(slot)
	var avatar: SeatAvatar = SeatAvatar.new()
	avatar.position = Vector2((SLOT_SIZE.x - SeatAvatar.SIZE) / 2.0, 0)
	slot.add_child(avatar)
	var bar: StyleBoxFlat = StyleBoxFlat.new()
	bar.set_corner_radius_all(14)
	bar.anti_aliasing = true
	var label: Label = Label.new()
	label.position = Vector2(2, 64)
	label.size = Vector2(SLOT_SIZE.x - 4, 28)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.clip_text = true
	label.add_theme_stylebox_override("normal", bar)
	label.add_theme_font_override("font", GameSkin.get_current().get_font())
	label.add_theme_color_override("font_color", GameSkin.get_current().color("bar_text"))
	slot.add_child(label)
	var button: Button = Button.new()
	button.flat = true
	button.focus_mode = Control.FOCUS_NONE
	button.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for state in ["normal", "hover", "pressed", "disabled", "focus"]:
		button.add_theme_stylebox_override(state, StyleBoxEmpty.new())
	var s: int = seat
	button.pressed.connect(func() -> void: _on_seat_pressed(s))
	slot.add_child(button)
	_slots.append(slot)
	_bars.append(bar)
	name_labels.append(label)
	avatars.append(avatar)
	seat_buttons.append(button)


## The seat shown at the bottom: yours once you sit, the host's before that.
func _base() -> int:
	return _you if _you >= 0 else 0


func bar_color_of(seat: int) -> Color:
	var skin: GameSkin = GameSkin.get_current()
	return skin.color("bar_own") if posmod(seat - _base(), 2) == 0 else skin.color("bar_other")


func _on_seat_pressed(seat: int) -> void:
	var kind: String = _kinds[seat]
	if _is_host:
		if kind == "empty":
			bot_add_chosen.emit(seat)
		elif kind == "bot":
			bot_remove_chosen.emit(seat)
		return
	if kind != "empty":
		return
	if _you >= 0:
		seat_chosen.emit(seat)  # already seated: this moves you
	else:
		_selected = seat
		_refresh_seats()
		join_button.disabled = false


func set_notice(text: String) -> void:
	notice_label.text = text


## `lobby` is SpadesClient.lobby (the host's lobby_state message).
func show_state(lobby: Dictionary, is_host: bool) -> void:
	_is_host = is_host
	_you = int(lobby.get("you", -1))
	var seats: Array = lobby.get("seats", [])
	for i in range(4):
		_kinds[i] = "empty"
		_names[i] = ""
		if i < seats.size() and seats[i] is Dictionary:
			_kinds[i] = str(seats[i].get("kind", "empty"))
			_names[i] = str(seats[i].get("name", ""))
	if _you >= 0 or (_selected >= 0 and _kinds[_selected] != "empty"):
		_selected = -1
	var countdown: int = int(lobby.get("countdown", 0))
	var seated: bool = _you >= 0
	if countdown > 0:
		title_label.text = "Starting..."
		centre_label.text = "Starting in %d" % countdown
	elif seated or is_host:
		title_label.text = "Waiting for players"
		centre_label.text = "Waiting for players"
	else:
		title_label.text = "Join %s's game" % _names[0]
		centre_label.text = "Choose a seat"
	var room_code: String = str(lobby.get("room_code", ""))
	code_label.visible = is_host and room_code != ""
	code_label.text = "Room code: %s" % room_code
	var lines: Array[String] = []
	if is_host:
		var addresses: Array = lobby.get("addresses", [])
		if not addresses.is_empty():
			var texts: Array[String] = []
			for a in addresses:
				texts.append(str(a))
			lines.append("If friends cannot see the game, they can type: %s" % ", ".join(texts))
	info_label.text = "\n".join(lines)
	info_label.visible = not lines.is_empty()
	var settings: SpadesSettings = Wire.settings_from_dict(lobby.get("settings", {}))
	options_label.text = "\n".join(option_lines(settings))
	join_button.visible = not is_host and not seated
	join_button.disabled = _selected < 0
	_refresh_seats()


func _refresh_seats() -> void:
	for seat in range(4):
		var rel: int = posmod(seat - _base(), 4)
		_slots[seat].position = SLOT_POS[rel] * _k
		var kind: String = _kinds[seat]
		var text: String = _names[seat]
		if kind == "empty":
			text = "Tap to add a bot" if _is_host else "Tap to sit"
		_bars[seat].bg_color = bar_color_of(seat)
		name_labels[seat].text = text
		name_labels[seat].add_theme_font_size_override("font_size", SeatView.fit_font_size(text, (SLOT_SIZE.x - 14) * _k, int(15 * _k)))
		avatars[seat].setup(kind, _names[seat], seat == 0 and kind == "human", seat == _selected)


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
