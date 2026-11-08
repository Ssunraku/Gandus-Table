class_name Table
extends Control
## The whole table screen. It DRAWS a TableState and forwards your taps; it owns
## no rules. Layout comes from TableLayout, so it adapts to any screen size.

signal deal_finished

const SEATS: Array[TableState.Seat] = [
	TableState.Seat.SOUTH, TableState.Seat.WEST, TableState.Seat.NORTH, TableState.Seat.EAST,
]
const DEAL_STAGGER: float = 0.025  # seconds between cards leaving the deck
const DEAL_FLIGHT: float = 0.25    # seconds each card takes to arrive
const PLAY_FLIGHT: float = 0.25

## Tests turn this off so the deal animation does not start by itself.
@export var auto_start: bool = true

var state: TableState = null
var hand: HandView
var score_box: ScoreBox
var menu_button: Button
var info_button: Button
var opponent_views: Dictionary = {}  # Seat -> OpponentHandView
var seat_views: Dictionary = {}      # Seat -> SeatView

var _played_views: Array[CardView] = []
var _temp_cards: Array[CardView] = []
var _flying: int = 0
var _dealing: bool = false
var _felt: GradientTexture2D


func _init() -> void:
	var skin: GameSkin = GameSkin.get_current()
	var g: Gradient = Gradient.new()
	g.colors = PackedColorArray([skin.color("felt_center"), skin.color("felt_edge")])
	_felt = GradientTexture2D.new()
	_felt.gradient = g
	_felt.fill = GradientTexture2D.FILL_RADIAL
	_felt.fill_from = Vector2(0.5, 0.5)
	_felt.fill_to = Vector2(1.0, 0.5)
	_felt.width = 256
	_felt.height = 256

	for seat in [TableState.Seat.WEST, TableState.Seat.NORTH, TableState.Seat.EAST]:
		var ov: OpponentHandView = OpponentHandView.new()
		add_child(ov)
		opponent_views[seat] = ov
	for seat in SEATS:
		var sv: SeatView = SeatView.new()
		add_child(sv)
		sv.bar_color = skin.color("bar_own") if seat == TableState.Seat.SOUTH or seat == TableState.Seat.NORTH else skin.color("bar_other")
		seat_views[seat] = sv
	score_box = ScoreBox.new()
	add_child(score_box)
	menu_button = Button.new()
	menu_button.text = "Menu"
	_style_button(menu_button, skin)
	add_child(menu_button)
	info_button = Button.new()
	info_button.text = "Info"
	_style_button(info_button, skin)
	add_child(info_button)
	hand = HandView.new()
	add_child(hand)
	hand.card_played.connect(_on_card_played)


func _style_button(b: Button, skin: GameSkin) -> void:
	var bg: StyleBoxFlat = StyleBoxFlat.new()
	bg.bg_color = skin.color("button_bg")
	bg.set_corner_radius_all(20)
	bg.border_color = skin.color("accent")
	bg.border_color.a = 0.55
	bg.set_border_width_all(2)
	var hover: StyleBoxFlat = bg.duplicate()
	hover.bg_color = skin.color("button_bg").lightened(0.15)
	var pressed: StyleBoxFlat = bg.duplicate()
	pressed.bg_color = skin.color("button_bg").darkened(0.2)
	b.add_theme_stylebox_override("normal", bg)
	b.add_theme_stylebox_override("hover", hover)
	b.add_theme_stylebox_override("pressed", pressed)
	b.add_theme_stylebox_override("focus", StyleBoxEmpty.new())
	b.add_theme_color_override("font_color", skin.color("button_text"))
	b.add_theme_color_override("font_hover_color", skin.color("button_text"))
	b.add_theme_color_override("font_pressed_color", skin.color("accent"))
	b.add_theme_font_override("font", skin.get_font())


func _ready() -> void:
	resized.connect(relayout)
	if auto_start:
		set_state(TableState.dummy())
		play_deal_animation()


func set_state(new_state: TableState) -> void:
	state = new_state
	relayout()


func is_dealing() -> bool:
	return _dealing


func temp_card_count() -> int:
	return _temp_cards.size()


## Puts a lifted card back down (used when you tap empty table).
func clear_selection() -> void:
	hand.clear_selection()


## Recomputes every position from the current size. Safe to call at any time.
func relayout() -> void:
	if state == null or size.x < 1.0 or size.y < 1.0:
		return
	var l: Dictionary = TableLayout.compute(size)
	var card_size: Vector2 = l["card_size"]
	var opp_size: Vector2 = card_size * 0.55

	hand.show_hand(state.own_hand, l["hand_rect"], card_size)
	for seat in opponent_views:
		var ov: OpponentHandView = opponent_views[seat]
		ov.show_count(state.get_card_count(seat), l["opponent_fan_rects"][seat], opp_size, seat)
	for seat in seat_views:
		var sv: SeatView = seat_views[seat]
		var r: Rect2 = l["seat_rects"][seat]
		sv.position = r.position
		sv.size = r.size
		sv.setup(state.seat_names.get(seat, ""), state.dealer_seat == seat, state.turn_seat == seat, state.tricks_won.get(seat, 0))
	var sr: Rect2 = l["score_rect"]
	score_box.position = sr.position
	score_box.size = sr.size
	score_box.show_scores(state.team_scores, state.team_bags)
	_place_button(menu_button, l["button_rect_left"])
	_place_button(info_button, l["button_rect_right"])
	_refresh_played(l)
	queue_redraw()


func _place_button(b: Button, r: Rect2) -> void:
	b.position = r.position
	b.size = r.size
	b.add_theme_font_size_override("font_size", maxi(10, int(r.size.y * 0.45)))


func _refresh_played(l: Dictionary) -> void:
	for v in _played_views:
		remove_child(v)
		v.free()
	_played_views.clear()
	var card_size: Vector2 = l["card_size"]
	for seat in SEATS:
		var card: Card = state.get_played(seat)
		if card == null:
			continue
		if seat == TableState.Seat.SOUTH and _flying > 0:
			continue  # the card is still flying there
		var v: CardView = CardView.new()
		add_child(v)
		v.setup(card, true, card_size)
		v.position = l["play_spots"][seat] - card_size / 2.0
		_played_views.append(v)


func _on_card_played(card: Card) -> void:
	state.play_own_card(card)
	var l: Dictionary = TableLayout.compute(size)
	var card_size: Vector2 = l["card_size"]
	var fly: CardView = CardView.new()
	add_child(fly)
	fly.setup(card, true, card_size)
	fly.position = hand.last_played_rect.position - global_position
	var target: Vector2 = l["play_spots"][TableState.Seat.SOUTH] - card_size / 2.0
	_flying += 1
	var tw: Tween = create_tween()
	tw.tween_property(fly, "position", target, PLAY_FLIGHT).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.finished.connect(func() -> void:
		fly.queue_free()
		_flying -= 1
		relayout())


## Cards fly from the middle to each seat, one at a time, round the table.
func play_deal_animation() -> void:
	if state == null or size.x < 1.0 or size.y < 1.0:
		return
	_dealing = true
	hand.visible = false
	for ov in opponent_views.values():
		ov.visible = false
	var l: Dictionary = TableLayout.compute(size)
	var opp_size: Vector2 = (l["card_size"] as Vector2) * 0.55
	var targets: Dictionary = {
		TableState.Seat.SOUTH: (l["hand_rect"] as Rect2).get_center(),
		TableState.Seat.WEST: (l["opponent_fan_rects"][TableState.Seat.WEST] as Rect2).get_center(),
		TableState.Seat.NORTH: (l["opponent_fan_rects"][TableState.Seat.NORTH] as Rect2).get_center(),
		TableState.Seat.EAST: (l["opponent_fan_rects"][TableState.Seat.EAST] as Rect2).get_center(),
	}
	var tw: Tween = create_tween()
	for i in range(52):
		var seat: TableState.Seat = SEATS[i % 4]
		var c: CardView = CardView.new()
		add_child(c)
		c.setup(null, false, opp_size)
		c.position = (l["deck_spot"] as Vector2) - opp_size / 2.0
		_temp_cards.append(c)
		tw.parallel().tween_property(c, "position", (targets[seat] as Vector2) - opp_size / 2.0, DEAL_FLIGHT).set_delay(DEAL_STAGGER * float(i))
	tw.finished.connect(_finish_deal)


func _finish_deal() -> void:
	for c in _temp_cards:
		c.queue_free()
	_temp_cards.clear()
	_dealing = false
	hand.visible = true
	for ov in opponent_views.values():
		ov.visible = true
	relayout()
	deal_finished.emit()


func _gui_input(event: InputEvent) -> void:
	# Taps that land on empty table put a lifted card back down.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		clear_selection()


func _draw() -> void:
	draw_texture_rect(_felt, Rect2(Vector2.ZERO, size), false)
