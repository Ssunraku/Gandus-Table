class_name InfoPanel
extends PanelContainer
## Small panel with this round's bids and the last finished trick.

signal closed

var _box: VBoxContainer


func _init() -> void:
	add_theme_stylebox_override("panel", UiStyle.panel_box())
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	add_child(_box)


## `room_code` ("" = none) is shown big at the top so a friend can be told it; `addresses`
## are the host phone's network addresses, shown small as the backup way to join.
func show_info(bids: Dictionary, names: Dictionary, last_trick: Dictionary, room_code: String = "", addresses: Array[String] = []) -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	_box.add_child(UiStyle.label("Info", 30))
	if room_code != "":
		_box.add_child(UiStyle.label("Room code", 18, true, true))
		_box.add_child(UiStyle.label(room_code, 52))
		if not addresses.is_empty():
			var a: Label = UiStyle.label("Or type: %s" % ", ".join(addresses), 15, true, true)
			a.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
			a.custom_minimum_size = Vector2(300, 0)
			_box.add_child(a)
	_box.add_child(UiStyle.label("Bids this round", 18, true, true))
	for seat in [0, 1, 2, 3]:
		var row: HBoxContainer = HBoxContainer.new()
		var n: Label = UiStyle.label(str(names.get(seat, "")), 18)
		n.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
		n.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		var v: Label = UiStyle.label(RoundSummary.bid_text(bids.get(seat)), 18)
		v.horizontal_alignment = HORIZONTAL_ALIGNMENT_RIGHT
		row.add_child(n)
		row.add_child(v)
		_box.add_child(row)
	var cards: Array = last_trick.get("cards", [])
	if cards.is_empty():
		_box.add_child(UiStyle.label("No trick yet", 18, true, true))
	else:
		var winner_name: String = str(names.get(last_trick.get("winner", -1), ""))
		_box.add_child(UiStyle.label("Last trick (won by %s)" % winner_name, 18, true, true))
		var strip: HBoxContainer = HBoxContainer.new()
		strip.alignment = BoxContainer.ALIGNMENT_CENTER
		strip.add_theme_constant_override("separation", 14)
		_box.add_child(strip)
		for entry in cards:
			var col: VBoxContainer = VBoxContainer.new()
			col.alignment = BoxContainer.ALIGNMENT_CENTER
			var cv: CardView = CardView.new()
			cv.setup(entry["card"], true, Vector2(60, 84))
			col.add_child(cv)
			col.add_child(UiStyle.label(str(names.get(entry["seat"], "")), 14))
			strip.add_child(col)
	var close: Button = Button.new()
	close.text = "Close"
	close.custom_minimum_size = Vector2(200, 52)
	close.add_theme_font_size_override("font_size", 20)
	close.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiStyle.style_button(close, "paper_outline")
	close.pressed.connect(func() -> void: closed.emit())
	_box.add_child(close)
