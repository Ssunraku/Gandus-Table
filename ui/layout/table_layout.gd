class_name TableLayout
extends RefCounted
## Pure maths: turns a screen size into rectangles and card positions.
## No drawing happens here, so it can be tested without a window.

const CARD_ASPECT: float = 5.0 / 7.0  # card width / card height


static func compute(screen: Vector2) -> Dictionary:
	var portrait: bool = screen.y > screen.x
	var m: float = minf(screen.x, screen.y) * 0.02
	var card_h: float = minf(screen.y * 0.22, screen.x * 0.30)
	var card_size: Vector2 = Vector2(card_h * CARD_ASPECT, card_h)
	var opp_size: Vector2 = card_size * 0.55
	var bar_h: float = card_h * 0.28
	var centre: Vector2 = screen / 2.0

	# Own hand: bottom strip. Slightly taller than a card so the fan's curve fits.
	var hand_h: float = card_h * 1.1
	var hand_rect: Rect2 = Rect2(m, screen.y - m - hand_h, screen.x - 2.0 * m, hand_h)

	# Corner buttons and the score box come first: the partner's fan and name bar
	# must stay clear of them.
	var btn: float = card_h * 0.3
	var button_left: Rect2 = Rect2(m, m, btn * 3.0, btn)
	var button_right: Rect2 = Rect2(screen.x - m - btn * 2.0, m, btn * 2.0, btn)
	var score_w: float = maxf(card_size.x, screen.x * 0.11)
	var score_rect: Rect2 = Rect2(screen.x - m - score_w, button_right.end.y + m, score_w, card_h * 0.5)
	var edge: float = maxf(button_left.end.x, screen.x - minf(button_right.position.x, score_rect.position.x)) + m
	var top_w: float = screen.x - 2.0 * edge  # room left for the partner at the top

	# Side fans are centred on the screen; keep them short enough that they end
	# above your own name bar (which sits just above your hand).
	var room_below: float = hand_rect.position.y - 2.0 * m - bar_h - centre.y
	var fan_len: float = maxf(minf(minf(screen.y * 0.35, screen.x * 0.35), room_below * 2.0), opp_size.x * 2.0)
	var fan_w: float = minf(screen.x * 0.5, top_w)
	var north_fan: Rect2 = Rect2((screen.x - fan_w) / 2.0, m, fan_w, opp_size.y)
	var west_fan: Rect2 = Rect2(m, centre.y - fan_len / 2.0, opp_size.y, fan_len)
	var east_fan: Rect2 = Rect2(screen.x - m - opp_size.y, centre.y - fan_len / 2.0, opp_size.y, fan_len)

	# Name bars: partner below their fan; the two sides ABOVE their fans (so they
	# never run into the cards played in the middle); you above your hand.
	var side_bar_w: float = maxf(opp_size.y, screen.x * (0.26 if portrait else 0.18))
	var top_bar_w: float = minf(screen.x * (0.6 if portrait else 0.36), top_w)
	var seat_rects: Dictionary = {
		TableState.Seat.SOUTH: Rect2((screen.x - top_bar_w) / 2.0, hand_rect.position.y - bar_h - card_h * 0.12, top_bar_w, bar_h),
		TableState.Seat.NORTH: Rect2((screen.x - top_bar_w) / 2.0, north_fan.end.y + m, top_bar_w, bar_h),
		TableState.Seat.WEST: Rect2(m, west_fan.position.y - m - bar_h, side_bar_w, bar_h),
		TableState.Seat.EAST: Rect2(screen.x - m - side_bar_w, east_fan.position.y - m - bar_h, side_bar_w, bar_h),
	}

	# The middle: cards played to the table sit between the partner's name bar (top) and
	# yours (bottom). They shrink a little if the space is tight.
	var area_top: float = (seat_rects[TableState.Seat.NORTH] as Rect2).end.y + m
	var area_bottom: float = (seat_rects[TableState.Seat.SOUTH] as Rect2).position.y - m
	var play_h: float = clampf((area_bottom - area_top) / 2.1, card_h * 0.3, card_h)
	# The side cards sit 0.9 card widths left/right of centre: keep them clear of the side name bars.
	var side_room: float = centre.x - side_bar_w - 2.0 * m
	play_h = minf(play_h, maxf(side_room / 1.4 / CARD_ASPECT, card_h * 0.3))
	var play_card_size: Vector2 = Vector2(play_h * CARD_ASPECT, play_h)
	var mid: Vector2 = Vector2(centre.x, (area_top + area_bottom) / 2.0)
	var play_spots: Dictionary = {
		TableState.Seat.SOUTH: mid + Vector2(0.0, play_h * 0.55),
		TableState.Seat.NORTH: mid + Vector2(0.0, -play_h * 0.55),
		TableState.Seat.WEST: mid + Vector2(-play_card_size.x * 0.9, 0.0),
		TableState.Seat.EAST: mid + Vector2(play_card_size.x * 0.9, 0.0),
	}

	return {
		"is_portrait": portrait,
		"card_size": card_size,
		"hand_rect": hand_rect,
		"seat_rects": seat_rects,
		"opponent_fan_rects": {
			TableState.Seat.WEST: west_fan,
			TableState.Seat.NORTH: north_fan,
			TableState.Seat.EAST: east_fan,
		},
		"play_card_size": play_card_size,
		"play_spots": play_spots,
		"deck_spot": centre,
		"score_rect": score_rect,
		"button_rect_left": button_left,
		"button_rect_right": button_right,
	}


## Top-left position and tilt (radians) for each of `count` cards, spread across
## `area`, overlapping when there is not enough room, centred, edges tilted/lower.
static func fan(count: int, area: Rect2, card_size: Vector2) -> Array[Dictionary]:
	var items: Array[Dictionary] = []
	if count <= 0:
		return items
	if count == 1:
		items.append({
			"position": area.position + (area.size - card_size) / 2.0,
			"rotation": 0.0,
		})
		return items
	var step: float = minf(card_size.x * 0.6, (area.size.x - card_size.x) / float(count - 1))
	step = maxf(step, 0.0)
	var total: float = step * float(count - 1) + card_size.x
	var x0: float = area.position.x + (area.size.x - total) / 2.0
	for i in range(count):
		var t: float = (float(i) / float(count - 1) - 0.5) * 2.0  # -1 .. 1
		items.append({
			"position": Vector2(x0 + step * float(i), area.position.y + t * t * card_size.y * 0.06),
			"rotation": t * 0.10,
		})
	return items
