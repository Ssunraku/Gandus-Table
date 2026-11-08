class_name HandView
extends Control
## Shows YOUR hand as an overlapping fan. Tap a card to lift it; tap the lifted
## card again to play it (the hand emits card_played and removes the card).
## It only displays and reports taps; the table state decides what happens.

signal card_played(card: Card)
## Emitted when the multi-select picks change (see set_multi_select).
signal selection_changed

## Index of the lifted card, or -1 when none is lifted.
var selected_index: int = -1
## Where the most recently played card was on screen (global coordinates), so
## the table can animate it from there.
var last_played_rect: Rect2 = Rect2()

var _cards: Array[Card] = []
var _views: Array[CardView] = []
var _positions: Array[Vector2] = []
var _rotations: Array[float] = []
var _card_size: Vector2 = Vector2(100, 140)
var _area: Rect2 = Rect2()
var _legal: Array[Card] = []
var _restrict: bool = false  # when true only the cards in _legal can be played
var _face_down: bool = false
var _multi_max: int = 0  # 0 = normal lift-and-play; above 0 = pick up to this many cards
var _multi_cards: Array[Card] = []


## Lay out `cards` in `area` (this control moves/resizes to match). A lifted card
## stays lifted if it is still in the hand.
func show_hand(cards: Array[Card], area: Rect2, card_size: Vector2) -> void:
	var keep: Card = null
	if selected_index >= 0 and selected_index < _cards.size():
		keep = _cards[selected_index]
	_cards = cards.duplicate()
	_multi_cards = _multi_cards.filter(func(c: Card) -> bool: return _cards.has(c))
	selected_index = _cards.find(keep) if keep != null else -1
	_area = area
	_card_size = card_size
	_rebuild()


func card_count() -> int:
	return _cards.size()


## Rectangle of card i in this control's own coordinates (ignores the small tilt).
func card_rect(i: int) -> Rect2:
	return Rect2(_positions[i], _card_size)


## Index of the card under `point` (local coordinates); the right-hand card wins
## where cards overlap, because it is drawn on top. -1 if there is none.
func pick_index_at(point: Vector2) -> int:
	for i in range(_cards.size() - 1, -1, -1):
		var r: Rect2 = card_rect(i)
		if i == selected_index or _multi_cards.has(_cards[i]):
			var rise: float = _card_size.y * CardView.LIFT_FRACTION
			r = Rect2(r.position - Vector2(0.0, rise), r.size + Vector2(0.0, rise))
		if r.has_point(point):
			return i
	return -1


func handle_tap(point: Vector2) -> void:
	if _face_down:
		return
	var idx: int = pick_index_at(point)
	if _multi_max > 0:
		if idx != -1:
			_toggle_multi(_cards[idx])
		return
	if idx == -1:
		_select(-1)
	elif not is_playable(_cards[idx]):
		return  # greyed-out card: nothing happens
	elif idx == selected_index:
		_play_selected()
	else:
		_select(idx)


## True if this card may be played now (always true when no restriction is set).
func is_playable(card: Card) -> bool:
	if not _restrict:
		return true
	for c in _legal:
		if c.suit == card.suit and c.rank == card.rank:
			return true
	return false


## Limit play to `cards` (restrict = true) or allow every card (restrict = false).
func set_legal(cards: Array[Card], restrict: bool) -> void:
	_legal = cards.duplicate()
	_restrict = restrict
	if _restrict and selected_index >= 0 and selected_index < _cards.size() and not is_playable(_cards[selected_index]):
		selected_index = -1
	_rebuild()


## Show your cards as backs (used before you decide on Blind Nil). Taps are ignored.
func set_face_down(on: bool) -> void:
	_face_down = on
	if on:
		selected_index = -1
		_multi_cards.clear()
	_rebuild()


## 0 = normal. Above 0: a tap toggles a card up to `max_count` picks (used for the Blind Nil
## swap); nothing is played. Turning it off drops the picks.
func set_multi_select(max_count: int) -> void:
	_multi_max = maxi(max_count, 0)
	_multi_cards.clear()
	if _multi_max > 0:
		selected_index = -1
	_rebuild()
	selection_changed.emit()


func selected_cards() -> Array[Card]:
	return _multi_cards.duplicate()


func _toggle_multi(card: Card) -> void:
	if _multi_cards.has(card):
		_multi_cards.erase(card)
	elif _multi_cards.size() < _multi_max:
		_multi_cards.append(card)
	else:
		return
	_rebuild()
	selection_changed.emit()


## Godot only sends taps that land inside this control's rectangle. A lifted card
## sticks up above that rectangle, so count the raised strip as part of the hand too.
func _has_point(point: Vector2) -> bool:
	return Rect2(Vector2.ZERO, size).has_point(point) or pick_index_at(point) != -1


func clear_selection() -> void:
	_select(-1)


func _gui_input(event: InputEvent) -> void:
	# Touch is converted to a mouse click by Godot, so handling the mouse covers both.
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		handle_tap(event.position)


func _select(idx: int) -> void:
	if selected_index >= 0 and selected_index < _views.size():
		_views[selected_index].set_selected(false)
	selected_index = idx
	if idx >= 0 and idx < _views.size():
		_views[idx].set_selected(true)


func _play_selected() -> void:
	var idx: int = selected_index
	var r: Rect2 = card_rect(idx)
	last_played_rect = Rect2(r.position + global_position, r.size)
	var card: Card = _cards[idx]
	_cards.remove_at(idx)
	selected_index = -1
	_rebuild()
	card_played.emit(card)


func _rebuild() -> void:
	for v in _views:
		remove_child(v)
		v.free()
	_views.clear()
	position = _area.position
	size = _area.size
	var fan: Array[Dictionary] = TableLayout.fan(_cards.size(), Rect2(Vector2.ZERO, _area.size), _card_size)
	_positions.clear()
	_rotations.clear()
	for i in range(_cards.size()):
		var item: Dictionary = fan[i]
		_positions.append(item["position"])
		_rotations.append(item["rotation"])
		var v: CardView = CardView.new()
		add_child(v)
		v.setup(_cards[i], not _face_down, _card_size)
		v.dimmed = _restrict and not is_playable(_cards[i])
		v.pivot_offset = _card_size / 2.0
		v.position = _positions[i]
		v.rotation = _rotations[i]
		if i == selected_index or _multi_cards.has(_cards[i]):
			v.selected = true
			v.lift = 1.0
		_views.append(v)
