class_name SwapPanel
extends PanelContainer
## Explains the Blind Nil swap, shows how many cards you give and take, and has the
## confirm button (which says "Skip swap" when you pick nothing).

signal confirmed(give: Array[Card], positions: Array[int])

var confirm_button: Button
var status_label: Label

var _hand: HandView
var _picker: PartnerPicker


func _init() -> void:
	add_theme_stylebox_override("panel", UiStyle.panel_box())
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	box.alignment = BoxContainer.ALIGNMENT_CENTER
	add_child(box)
	box.add_child(UiStyle.label("Blind Nil swap", 28))
	var help: Label = UiStyle.label("Give 1 or 2 of your cards to your partner and take the same number of their hidden cards. You may also skip.", 18, true, true)
	help.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	help.custom_minimum_size = Vector2(420, 0)
	box.add_child(help)
	status_label = UiStyle.label("Giving 0 · taking 0", 20)
	box.add_child(status_label)
	confirm_button = Button.new()
	confirm_button.custom_minimum_size = Vector2(240, 56)
	confirm_button.add_theme_font_size_override("font_size", 22)
	UiStyle.style_button(confirm_button, "primary")
	confirm_button.pressed.connect(_on_confirm)
	box.add_child(confirm_button)
	_update()


## `hand` must already be in multi-select mode (max 2).
func setup(hand: HandView, picker: PartnerPicker) -> void:
	_hand = hand
	_picker = picker
	if not hand.selection_changed.is_connected(_update):
		hand.selection_changed.connect(_update)
	if not picker.selection_changed.is_connected(_update):
		picker.selection_changed.connect(_update)
	_update()


func _update() -> void:
	var n: int = _hand.selected_cards().size() if _hand != null else 0
	var m: int = _picker.selected_positions().size() if _picker != null else 0
	status_label.text = "Giving %d · taking %d" % [n, m]
	confirm_button.disabled = n != m
	confirm_button.text = "Skip swap" if n == 0 and m == 0 else "Confirm swap"


func _on_confirm() -> void:
	if confirm_button.disabled:
		return
	confirmed.emit(_hand.selected_cards(), _picker.selected_positions())
