class_name HostOptionsScreen
extends MenuScreen
## The host chooses the rules before a game starts.

signal start_pressed(settings: SpadesSettings)
signal back_pressed

const WIN_MIN: int = 100
const WIN_MAX: int = 1000
const LOSE_MIN: int = -1000
const LOSE_MAX: int = -50
const SCORE_STEP: int = 50

var start_button: Button
var back_button: Button

var exact_button: Button

var _exact: int = 0           # SpadesSettings.ExactMode
var _bags_choice: bool = true # the bags setting to restore when Exact bids is turned off
var _toggles: Dictionary = {}
var _win: int = 500
var _lose: int = -200
var _win_label: Label
var _lose_label: Label


func _init() -> void:
	super()
	var defaults: SpadesSettings = SpadesSettings.new()
	_win = defaults.win_score
	_lose = defaults.lose_score
	var panel: PanelContainer = PanelContainer.new()
	panel.add_theme_stylebox_override("panel", UiStyle.panel_box())
	panel.custom_minimum_size = Vector2(520, 0)
	column.add_child(panel)
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 12)
	panel.add_child(box)
	box.add_child(UiStyle.label("Host game", 30))
	_add_toggle(box, "blind_nil", "Blind Nil", defaults.blind_nil_enabled)
	_add_toggle(box, "nil", "Normal Nil", defaults.nil_enabled)
	_add_toggle(box, "redeal", "Redeal when a hand has no suit", defaults.redeal_enabled)
	_add_toggle(box, "bags", "Bags penalty (−100 at 10 bags)", defaults.bags_penalty_enabled)
	_add_toggle(box, "play_higher", "Play higher than the trick", defaults.play_higher_enabled)
	var exact_row: HBoxContainer = _row(box, "Exact bids (own bid per player)")
	exact_button = Button.new()
	exact_button.custom_minimum_size = Vector2(110, 38)
	exact_button.add_theme_font_size_override("font_size", 18)
	exact_button.pressed.connect(_cycle_exact)
	exact_row.add_child(exact_button)
	_refresh_exact()
	_win_label = _add_stepper(box, "Winning score", func(d: int) -> void: step_win(d))
	_lose_label = _add_stepper(box, "Losing score", func(d: int) -> void: step_lose(d))
	var row: HBoxContainer = HBoxContainer.new()
	row.alignment = BoxContainer.ALIGNMENT_CENTER
	row.add_theme_constant_override("separation", 16)
	box.add_child(row)
	back_button = add_button("Back", "paper_outline", 200, row)
	start_button = add_button("Start game", "primary", 260, row)
	back_button.pressed.connect(func() -> void: back_pressed.emit())
	start_button.pressed.connect(func() -> void: start_pressed.emit(settings()))
	_refresh_labels()


func _row(box: VBoxContainer, text: String) -> HBoxContainer:
	var row: HBoxContainer = HBoxContainer.new()
	var l: Label = UiStyle.label(text, 19)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	row.add_child(l)
	box.add_child(row)
	return row


func _add_toggle(box: VBoxContainer, key: String, text: String, on: bool) -> void:
	var row: HBoxContainer = _row(box, text)
	var b: Button = Button.new()
	b.toggle_mode = true
	b.custom_minimum_size = Vector2(84, 38)
	b.add_theme_font_size_override("font_size", 18)
	b.button_pressed = on
	b.toggled.connect(func(_on: bool) -> void: _style_toggle(b))
	row.add_child(b)
	_toggles[key] = b
	_style_toggle(b)


func _style_toggle(b: Button) -> void:
	b.text = "On" if b.button_pressed else "Off"
	UiStyle.style_button(b, "primary" if b.button_pressed else "paper_outline")


func _add_stepper(box: VBoxContainer, text: String, on_step: Callable) -> Label:
	var row: HBoxContainer = _row(box, text)
	var minus: Button = Button.new()
	minus.text = "−"
	minus.custom_minimum_size = Vector2(42, 42)
	minus.add_theme_font_size_override("font_size", 22)
	UiStyle.style_button(minus, "number")
	minus.pressed.connect(func() -> void: on_step.call(-1))
	row.add_child(minus)
	var value: Label = UiStyle.label("", 20)
	value.custom_minimum_size = Vector2(70, 0)
	row.add_child(value)
	var plus: Button = Button.new()
	plus.text = "+"
	plus.custom_minimum_size = Vector2(42, 42)
	plus.add_theme_font_size_override("font_size", 22)
	UiStyle.style_button(plus, "number")
	plus.pressed.connect(func() -> void: on_step.call(1))
	row.add_child(plus)
	return value


## Off -> Easy -> Normal -> Hard -> Off.
func _cycle_exact() -> void:
	_exact = (_exact + 1) % 4
	_refresh_exact()


## While Exact bids is on, the bags penalty is shown as Off and cannot be changed.
## The host's earlier bags choice comes back when Exact bids goes back to Off.
func _refresh_exact() -> void:
	var names: Array[String] = ["Off", "Easy", "Normal", "Hard"]
	exact_button.text = names[_exact]
	UiStyle.style_button(exact_button, "paper_outline" if _exact == 0 else "primary")
	var bags: Button = _toggles["bags"]
	if _exact != 0:
		if not bags.disabled:
			_bags_choice = bags.button_pressed
		bags.button_pressed = false
		bags.disabled = true
	elif bags.disabled:
		bags.disabled = false
		bags.button_pressed = _bags_choice


func toggle(key: String) -> Button:
	return _toggles[key]


## Winning score up (+) or down (-) in steps of 50, between 100 and 1000.
func step_win(delta: int) -> void:
	_win = clampi(_win + delta * SCORE_STEP, WIN_MIN, WIN_MAX)
	_refresh_labels()


## Losing score: "+" moves it towards zero (-50 at most), "-" makes it more negative (-1000 at most).
func step_lose(delta: int) -> void:
	_lose = clampi(_lose + delta * SCORE_STEP, LOSE_MIN, LOSE_MAX)
	_refresh_labels()


func _refresh_labels() -> void:
	_win_label.text = str(_win)
	_lose_label.text = str(_lose).replace("-", "−")


func settings() -> SpadesSettings:
	var s: SpadesSettings = SpadesSettings.new()
	s.blind_nil_enabled = (_toggles["blind_nil"] as Button).button_pressed
	s.nil_enabled = (_toggles["nil"] as Button).button_pressed
	s.redeal_enabled = (_toggles["redeal"] as Button).button_pressed
	s.bags_penalty_enabled = (_toggles["bags"] as Button).button_pressed
	s.exact_mode = _exact as SpadesSettings.ExactMode
	s.play_higher_enabled = (_toggles["play_higher"] as Button).button_pressed
	s.win_score = _win
	s.lose_score = _lose
	return s
