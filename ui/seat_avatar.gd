class_name SeatAvatar
extends Control
## The round picture above a seat's name bar before a game starts. For now it is drawn,
## not a real picture: a coloured circle with the player's first letter, a small robot face
## for a bot, a dashed circle with a plus for a free seat, and a gold star for the host.
## The same name always gets the same colour, so a player looks the same on every phone.

const SIZE: float = 58.0

## "empty", "human" or "bot".
var kind: String = "empty"
var player_name: String = ""
var is_host: bool = false
## A free seat the player has picked but not confirmed yet (gold ring).
var selected: bool = false


func _init() -> void:
	custom_minimum_size = Vector2(SIZE, SIZE)
	size = Vector2(SIZE, SIZE)
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func setup(seat_kind: String, seat_name: String, host: bool, picked: bool) -> void:
	kind = seat_kind
	player_name = seat_name
	is_host = host
	selected = picked
	queue_redraw()


## The colour of a person's circle, from their name.
static func colour_for(seat_name: String) -> Color:
	return SeatView.AVATAR_COLORS[absi(seat_name.hash()) % SeatView.AVATAR_COLORS.size()]


func _draw() -> void:
	var skin: GameSkin = GameSkin.get_current()
	var c: Vector2 = size / 2.0
	var r: float = minf(size.x, size.y) * 0.46
	match kind:
		"human":
			draw_circle(c, r, colour_for(player_name))
			var font: Font = skin.get_font()
			var fs: int = int(r * 1.1)
			var initial: String = player_name.substr(0, 1).to_upper()
			var w: float = font.get_string_size(initial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
			draw_string(font, c + Vector2(-w / 2.0, fs * 0.35), initial, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, Color.WHITE)
		"bot":
			draw_circle(c, r, Color(0.62, 0.66, 0.72))
			var head: Rect2 = Rect2(c + Vector2(-r * 0.55, -r * 0.4), Vector2(r * 1.1, r * 0.95))
			draw_rect(head, Color(0.93, 0.95, 0.97))
			draw_circle(c + Vector2(-r * 0.22, -r * 0.05), r * 0.13, Color(0.15, 0.2, 0.3))
			draw_circle(c + Vector2(r * 0.22, -r * 0.05), r * 0.13, Color(0.15, 0.2, 0.3))
			draw_line(c + Vector2(-r * 0.25, r * 0.3), c + Vector2(r * 0.25, r * 0.3), Color(0.15, 0.2, 0.3), 2.0)
			draw_line(c + Vector2(0, -r * 0.4), c + Vector2(0, -r * 0.65), Color(0.93, 0.95, 0.97), 2.0)
			draw_circle(c + Vector2(0, -r * 0.7), r * 0.09, Color(0.93, 0.35, 0.3))
		_:
			draw_circle(c, r, Color(0, 0, 0, 0.22))
			draw_arc(c, r, 0.0, TAU, 40, Color(1, 1, 1, 0.45), 2.0, true)
			draw_line(c + Vector2(-r * 0.35, 0), c + Vector2(r * 0.35, 0), Color(1, 1, 1, 0.7), 3.0)
			draw_line(c + Vector2(0, -r * 0.35), c + Vector2(0, r * 0.35), Color(1, 1, 1, 0.7), 3.0)
	if selected:
		draw_arc(c, r + 3.0, 0.0, TAU, 40, skin.color("accent"), 4.0, true)
	if is_host:
		var star_c: Vector2 = c + Vector2(r * 0.8, -r * 0.8)
		var pts: PackedVector2Array = PackedVector2Array()
		for i in range(10):
			var ang: float = -PI / 2.0 + i * PI / 5.0
			var rad: float = 9.0 if i % 2 == 0 else 4.0
			pts.append(star_c + Vector2(cos(ang), sin(ang)) * rad)
		draw_colored_polygon(pts, skin.color("accent"))
