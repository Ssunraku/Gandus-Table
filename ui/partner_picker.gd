class_name PartnerPicker
extends Control
## Your partner's cards, face-down, for the Blind Nil swap. You tap the ones you want
## to take (at most `max_count`). It never knows what the cards are.

signal selection_changed

var _count: int = 0
var _max: int = 2
var _picked: Array[int] = []
var _views: Array[CardView] = []


func setup(count: int, max_count: int) -> void:
	_count = count
	_max = max_count
	_picked.clear()
	_rebuild()
	selection_changed.emit()


func selected_positions() -> Array[int]:
	var out: Array[int] = _picked.duplicate()
	out.sort()
	return out


## Tap on card `i` (also what a real tap calls).
func toggle(i: int) -> void:
	if i < 0 or i >= _count:
		return
	if _picked.has(i):
		_picked.erase(i)
	elif _picked.size() < _max:
		_picked.append(i)
	else:
		return
	_rebuild()
	selection_changed.emit()


func _gui_input(event: InputEvent) -> void:
	if event is InputEventMouseButton and event.pressed and event.button_index == MOUSE_BUTTON_LEFT:
		for i in range(_views.size() - 1, -1, -1):
			var r: Rect2 = Rect2(_views[i].position, _views[i].size)
			if r.has_point(event.position):
				toggle(i)
				return


func _notification(what: int) -> void:
	if what == NOTIFICATION_RESIZED:
		_rebuild()


func _rebuild() -> void:
	for v in _views:
		remove_child(v)
		v.free()
	_views.clear()
	if _count == 0 or size.x < 1.0 or size.y < 1.0:
		return
	var h: float = minf(size.y * 0.8, size.x / float(_count) * 1.9)
	var w: float = h * TableLayout.CARD_ASPECT
	var step: float = minf(w * 0.75, (size.x - w) / float(maxi(_count - 1, 1)))
	var x0: float = (size.x - (w + step * float(_count - 1))) / 2.0
	var lift: float = h * CardView.LIFT_FRACTION
	for i in range(_count):
		var v: CardView = CardView.new()
		add_child(v)
		v.setup(null, false, Vector2(w, h))
		v.position = Vector2(x0 + step * float(i), size.y - h - (lift if _picked.has(i) else 0.0))
		if _picked.has(i):
			v.selected = true
		_views.append(v)
