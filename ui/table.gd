class_name Table
extends Control
## The whole table screen. It DRAWS a TableState and forwards your taps; it owns
## no rules. Layout comes from TableLayout, so it adapts to any screen size.

signal deal_finished
## Live game: you tapped a card to play. The screen above decides whether it is allowed.
signal human_played(card: Card)
signal menu_pressed
signal info_pressed

const SEATS: Array[TableState.Seat] = [
	TableState.Seat.SOUTH, TableState.Seat.WEST, TableState.Seat.NORTH, TableState.Seat.EAST,
]
const DEAL_STAGGER: float = 0.025  # seconds between cards leaving the deck
const DEAL_FLIGHT: float = 0.25    # seconds each card takes to arrive
const PLAY_FLIGHT: float = 0.25
const SWEEP_TIME: float = 0.45    # a finished trick flies to the player who won it

## Tests turn this off so the deal animation does not start by itself.
@export var auto_start: bool = true
## True when a game controller owns the rules: a tap on a card is only REPORTED
## (human_played); the table never changes the TableState itself.
var attached: bool = false

var state: TableState = null
var hand: HandView
var score_box: ScoreBox
var menu_button: Button
var info_button: Button
var opponent_views: Dictionary = {}  # Seat -> OpponentHandView
var seat_views: Dictionary = {}      # Seat -> SeatView

var _played_views: Array[CardView] = []
var _sweeping: Array[CardView] = []
var _temp_cards: Array[CardView] = []
var _flying: Dictionary = {}  # Seat -> number of cards still in flight to that seat
var broken_label: Label
var last_trick_label: Label
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
	menu_button.pressed.connect(func() -> void: menu_pressed.emit())
	info_button.pressed.connect(func() -> void: info_pressed.emit())
	broken_label = _make_chip(skin)
	last_trick_label = _make_chip(skin)
	last_trick_label.get_parent().visible = false
	hand = HandView.new()
	add_child(hand)
	hand.card_played.connect(_on_card_played)


## A small dark pill with a label inside; returns the label (its parent is the pill).
func _make_chip(skin: GameSkin) -> Label:
	var pill: PanelContainer = PanelContainer.new()
	pill.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = skin.color("button_bg")
	box.set_corner_radius_all(14)
	box.content_margin_left = 12.0
	box.content_margin_right = 12.0
	box.content_margin_top = 3.0
	box.content_margin_bottom = 3.0
	pill.add_theme_stylebox_override("panel", box)
	var l: Label = Label.new()
	l.mouse_filter = Control.MOUSE_FILTER_IGNORE
	l.add_theme_font_override("font", skin.get_font())
	l.add_theme_color_override("font_color", skin.color("button_text"))
	pill.add_child(l)
	add_child(pill)
	return l


func _style_button(b: Button, _skin: GameSkin) -> void:
	UiStyle.style_button(b, "dark")


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
		sv.setup(state.seat_names.get(seat, ""), state.dealer_seat == seat, state.turn_seat == seat, state.tricks_won.get(seat, 0), _bid_text(seat))
	var sr: Rect2 = l["score_rect"]
	score_box.position = sr.position
	score_box.size = sr.size
	score_box.show_scores(state.team_scores, state.team_bags)
	_place_chips(l)
	_place_button(menu_button, l["button_rect_left"])
	_place_button(info_button, l["button_rect_right"])
	_refresh_played(l)
	queue_redraw()


## "bid 3", "Nil", "Blind Nil", or "" before the seat has bid.
func _bid_text(seat: int) -> String:
	var b: Bid = state.bids.get(seat)
	if b == null:
		return ""
	if b.kind == Bid.Kind.NUMBER:
		return "bid %d" % b.tricks
	return RoundSummary.bid_text(b)


func _place_chips(l: Dictionary) -> void:
	var btn: Rect2 = l["button_rect_left"]
	var fs: int = maxi(10, int(btn.size.y * 0.34))
	var y: float = btn.end.y + btn.size.y * 0.3
	# The chips must stay left of the partner's name bar, so they shrink their text to fit.
	var max_w: float = (l["seat_rects"][TableState.Seat.NORTH] as Rect2).position.x - btn.position.x - btn.size.y * 0.3
	for chip_label in [broken_label, last_trick_label]:
		var pill: Control = chip_label.get_parent()
		var size_px: int = fs
		chip_label.add_theme_font_size_override("font_size", size_px)
		while size_px > 8 and pill.get_combined_minimum_size().x > max_w:
			size_px -= 1
			chip_label.add_theme_font_size_override("font_size", size_px)
		if pill.visible:
			pill.position = Vector2(btn.position.x, y)
			pill.size = pill.get_combined_minimum_size()
			y += pill.size.y + btn.size.y * 0.2


func _place_button(b: Button, r: Rect2) -> void:
	b.position = r.position
	b.size = r.size
	b.add_theme_font_size_override("font_size", maxi(10, int(r.size.y * 0.45)))


func _refresh_played(l: Dictionary) -> void:
	for v in _played_views:
		remove_child(v)
		v.free()
	_played_views.clear()
	var card_size: Vector2 = l["play_card_size"]
	for seat in SEATS:
		var card: Card = state.get_played(seat)
		if card == null:
			continue
		if _flying.get(seat, 0) > 0:
			continue  # the card is still flying there
		var v: CardView = CardView.new()
		add_child(v)
		v.setup(card, true, card_size)
		v.position = l["play_spots"][seat] - card_size / 2.0
		_played_views.append(v)


func _on_card_played(card: Card) -> void:
	if attached:
		human_played.emit(card)  # the game decides; the screen redraws from the new state
		return
	state.play_own_card(card)
	_fly_card(TableState.Seat.SOUTH, card)


## Live game: draws `st` (hand, counts, bids, chips, played cards, which cards are legal).
## To animate a card that was just played, call animate_card_played BEFORE this.
func show_game_state(st: TableState) -> void:
	broken_label.text = "Spades broken: %s" % ("yes" if st.spades_broken else "no")
	var trick: Dictionary = st.last_trick
	var has_trick: bool = not trick.is_empty()
	last_trick_label.get_parent().visible = has_trick
	if has_trick:
		last_trick_label.text = "Last trick: won by %s" % st.seat_names.get(trick["winner"], "")
	set_state(st)
	hand.set_legal(st.legal_cards, st.can_play)


## A face-up card flies from `seat` to its place on the table. Tell the table first, then
## call show_game_state: the card is not drawn at its place until the flight is over.
func animate_card_played(seat: int, card: Card) -> void:
	_fly_card(seat, card)


func played_view_count() -> int:
	return _played_views.size()


func flying_count() -> int:
	var total: int = 0
	for n in _flying.values():
		total += int(n)
	return total


func _fly_card(seat: int, card: Card) -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	var l: Dictionary = TableLayout.compute(size)
	var hand_size: Vector2 = l["card_size"]
	var play_size: Vector2 = l["play_card_size"]
	var start_size: Vector2 = hand_size if seat == TableState.Seat.SOUTH else hand_size * 0.55
	var fly: CardView = CardView.new()
	add_child(fly)
	fly.setup(card, true, start_size)
	fly.custom_minimum_size = Vector2.ZERO  # lets the card shrink while it flies
	if seat == TableState.Seat.SOUTH:
		fly.position = hand.last_played_rect.position - global_position
	else:
		fly.position = (l["opponent_fan_rects"][seat] as Rect2).get_center() - start_size / 2.0
	var target: Vector2 = l["play_spots"][seat] - play_size / 2.0
	_flying[seat] = int(_flying.get(seat, 0)) + 1
	var tw: Tween = create_tween().set_parallel(true)
	tw.tween_property(fly, "position", target, PLAY_FLIGHT).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_OUT)
	tw.tween_property(fly, "size", play_size, PLAY_FLIGHT)
	tw.finished.connect(func() -> void:
		fly.queue_free()
		_flying[seat] = int(_flying.get(seat, 1)) - 1
		relayout())


## The four cards of a finished trick fly to the name bar of the player who won it,
## shrinking and fading, so everybody sees who took them.
func sweep_trick(winner: int) -> void:
	if _played_views.is_empty() or size.x < 1.0 or size.y < 1.0:
		return
	var l: Dictionary = TableLayout.compute(size)
	var target: Vector2 = (l["seat_rects"][winner] as Rect2).get_center()
	var views: Array[CardView] = _played_views.duplicate()
	_played_views.clear()  # relayout must not delete them while they fly
	for v in views:
		_sweeping.append(v)
		v.custom_minimum_size = Vector2.ZERO
		var end_size: Vector2 = v.size * 0.4
		var tw: Tween = create_tween().set_parallel(true)
		tw.tween_property(v, "position", target - end_size / 2.0, SWEEP_TIME).set_trans(Tween.TRANS_CUBIC).set_ease(Tween.EASE_IN)
		tw.tween_property(v, "size", end_size, SWEEP_TIME)
		tw.tween_property(v, "modulate:a", 0.0, SWEEP_TIME * 0.4).set_delay(SWEEP_TIME * 0.6)
		tw.finished.connect(func() -> void:
			_sweeping.erase(v)
			v.queue_free())


func sweeping_count() -> int:
	return _sweeping.size()


## Average distance from the cards still lying on the table to `point` (for tests).
func played_view_centre_distance_to(point: Vector2) -> float:
	return _average_distance(_played_views, point)


## Average distance from the cards being swept to `point` (for tests).
func sweeping_centre_distance_to(point: Vector2) -> float:
	return _average_distance(_sweeping, point)


func _average_distance(views: Array[CardView], point: Vector2) -> float:
	if views.is_empty():
		return 0.0
	var total: float = 0.0
	for v in views:
		total += (v.position + v.size / 2.0).distance_to(point)
	return total / float(views.size())


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
