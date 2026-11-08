class_name SeatView
extends Control
## A player's name bar: circle avatar with initial, name, tricks won, a "D" badge
## for the dealer and a highlight when it is their turn. Display only.

const AVATAR_COLORS: Array[Color] = [
	Color(0.90, 0.45, 0.20), Color(0.30, 0.70, 0.50), Color(0.80, 0.30, 0.55), Color(0.40, 0.50, 0.90),
]

const MIN_FONT_SIZE: int = 8

var seat_name: String = ""
var is_dealer: bool = false
var is_turn: bool = false
var tricks: int = 0
var bid_text: String = ""  # e.g. "bid 3", "Nil"; empty before the player has bid
var bar_color: Color = Color(0.72, 0.85, 1.0)


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(seat_name_value: String, dealer: bool, turn: bool, tricks_won: int, bid: String = "") -> void:
	seat_name = seat_name_value
	bid_text = bid
	is_dealer = dealer
	is_turn = turn
	tricks = tricks_won
	queue_redraw()


## The text drawn next to the avatar: the name, plus the bid once there is one.
func label_text() -> String:
	return seat_name if bid_text == "" else "%s · %s" % [seat_name, bid_text]


func shows_dealer_badge() -> bool:
	return is_dealer


## The biggest font size (not above `start`) at which `text` fits in `max_width`.
static func fit_font_size(text: String, max_width: float, start: int) -> int:
	var font: Font = GameSkin.get_current().get_font()
	var size_px: int = maxi(start, MIN_FONT_SIZE)
	while size_px > MIN_FONT_SIZE:
		if font.get_string_size(text, HORIZONTAL_ALIGNMENT_LEFT, -1, size_px).x <= max_width:
			return size_px
		size_px -= 1
	return MIN_FONT_SIZE


func _draw() -> void:
	var s: Vector2 = size
	var bar: StyleBoxFlat = StyleBoxFlat.new()
	bar.bg_color = bar_color
	bar.set_corner_radius_all(int(s.y * 0.3))
	if is_turn:
		bar.border_color = GameSkin.get_current().color("accent")
		bar.set_border_width_all(maxi(2, int(s.y * 0.08)))
	draw_style_box(bar, Rect2(Vector2.ZERO, s))
	var skin: GameSkin = GameSkin.get_current()
	var font: Font = skin.get_font()
	var text_colour: Color = skin.color("bar_text")
	var r: float = s.y * 0.42
	var avatar_c: Vector2 = Vector2(r + s.y * 0.1, s.y / 2.0)
	var colour: Color = AVATAR_COLORS[absi(seat_name.hash()) % AVATAR_COLORS.size()]
	draw_circle(avatar_c, r, colour)
	var initial: String = seat_name.substr(0, 1).to_upper()
	var fs: int = maxi(8, int(s.y * 0.5))
	var iw: float = font.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
	draw_string(font, avatar_c + Vector2(-iw / 2.0, fs * 0.35), initial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
	# The name gets whatever room is left between the avatar and the tricks number,
	# and shrinks to fit so the two never overlap.
	var name_x: float = avatar_c.x + r + s.y * 0.15
	var tricks_room: float = s.y * 0.9
	var shown: String = label_text()
	var name_fs: int = fit_font_size(shown, s.x - name_x - tricks_room, int(s.y * 0.42))
	draw_string(font, Vector2(name_x, s.y * 0.5 + name_fs * 0.35), shown, HORIZONTAL_ALIGNMENT_LEFT, -1, name_fs, text_colour)
	var trick_fs: int = maxi(MIN_FONT_SIZE, int(s.y * 0.42))
	var trick_text: String = "%d" % tricks
	var tw: float = font.get_string_size(trick_text, HORIZONTAL_ALIGNMENT_LEFT, -1, trick_fs).x
	draw_string(font, Vector2(s.x - tw - s.y * 0.3, s.y * 0.5 + trick_fs * 0.35), trick_text, HORIZONTAL_ALIGNMENT_LEFT, -1, trick_fs, text_colour)
	if is_dealer:
		var badge_c: Vector2 = avatar_c + Vector2(r * 0.9, -r * 0.8)
		draw_circle(badge_c, s.y * 0.2, skin.color("card_black"))
		var bfs: int = maxi(8, int(s.y * 0.3))
		var bw: float = font.get_string_size("D", HORIZONTAL_ALIGNMENT_LEFT, -1, bfs).x
		draw_string(font, badge_c + Vector2(-bw / 2.0, bfs * 0.35), "D", HORIZONTAL_ALIGNMENT_LEFT, -1, bfs, Color.WHITE)
