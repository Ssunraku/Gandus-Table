class_name OpponentHandView
extends Control
## Another player's hand, shown as card BACKS only. It is given just a number,
## so it cannot show faces even by mistake.


func show_count(count: int, area: Rect2, card_size: Vector2, seat: TableState.Seat) -> void:
	for child in get_children():
		remove_child(child)
		child.free()
	position = area.position
	size = area.size
	var sideways: bool = seat == TableState.Seat.WEST or seat == TableState.Seat.EAST
	# Lay the fan out along a horizontal strip, then turn it for the side seats.
	var strip: Rect2 = Rect2(Vector2.ZERO, Vector2(area.size.y, card_size.y)) if sideways else Rect2(Vector2.ZERO, area.size)
	var fan: Array[Dictionary] = TableLayout.fan(count, strip, card_size)
	for item in fan:
		var v: CardView = CardView.new()
		add_child(v)
		v.setup(null, false, card_size)
		v.pivot_offset = card_size / 2.0
		var pos: Vector2 = item["position"]
		var tilt: float = item["rotation"]
		if sideways:
			var along: float = pos.x + card_size.x / 2.0
			var centre: Vector2 = Vector2(area.size.x / 2.0, along)
			v.position = centre - card_size / 2.0
			# WEST's cards face right (turn clockwise), EAST's face left.
			v.rotation = (PI / 2.0 if seat == TableState.Seat.WEST else -PI / 2.0) + tilt
		else:
			v.position = pos
			v.rotation = tilt + (PI if seat == TableState.Seat.NORTH else 0.0)
