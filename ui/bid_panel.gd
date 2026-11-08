class_name BidPanel
extends PanelContainer
## The box you bid with. Two looks: the Blind Nil question (before you see your cards)
## and the row of number buttons plus Nil. It only reports what you tapped.

signal bid_chosen(bid: Bid)
signal look_requested

var _box: VBoxContainer


func _init() -> void:
	add_theme_stylebox_override("panel", UiStyle.panel_box())
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 14)
	_box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(_box)


func _clear() -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()  # a button may be mid-signal when the panel is rebuilt


func _button(text: String, kind: String, size_px: Vector2) -> Button:
	var b: Button = Button.new()
	b.text = text
	b.custom_minimum_size = size_px
	b.add_theme_font_size_override("font_size", 20)
	UiStyle.style_button(b, kind)
	return b


func show_blind_choice() -> void:
	_clear()
	_box.add_child(UiStyle.label("Your bid", 28))
	_box.add_child(UiStyle.label("Bid Blind Nil before you look at your cards?", 18, true, true))
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	_box.add_child(row)
	var blind: Button = _button("Blind Nil", "primary", Vector2(190, 56))
	blind.pressed.connect(func() -> void: bid_chosen.emit(Bid.blind_nil()))
	row.add_child(blind)
	var look: Button = _button("Look at my cards", "paper_outline", Vector2(230, 56))
	look.pressed.connect(func() -> void: look_requested.emit())
	row.add_child(look)


func show_bidding(nil_enabled: bool) -> void:
	_clear()
	_box.add_child(UiStyle.label("Your bid", 28))
	var flow: HFlowContainer = HFlowContainer.new()
	flow.alignment = FlowContainer.ALIGNMENT_CENTER
	flow.add_theme_constant_override("h_separation", 6)
	flow.add_theme_constant_override("v_separation", 6)
	flow.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_box.add_child(flow)
	for n in range(1, 14):
		var b: Button = _button(str(n), "number", Vector2(48, 48))
		b.pressed.connect(func() -> void: bid_chosen.emit(Bid.number(n)))
		flow.add_child(b)
	if nil_enabled:
		var nil_row: HBoxContainer = HBoxContainer.new()
		nil_row.alignment = BoxContainer.ALIGNMENT_CENTER
		_box.add_child(nil_row)
		var nil_button: Button = _button("Nil", "paper_outline", Vector2(160, 50))
		nil_button.pressed.connect(func() -> void: bid_chosen.emit(Bid.nil()))
		nil_row.add_child(nil_button)
	_box.add_child(UiStyle.label("Tap a number to bid that many tricks.", 16, true, true))
