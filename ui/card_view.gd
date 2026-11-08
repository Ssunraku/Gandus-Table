class_name CardView
extends Control
## Draws one card. If the current skin has a picture for it, that picture is
## used; otherwise the card is drawn with code. Face-down shows the card back.
## It only DISPLAYS; it has no rules.

const LIFT_FRACTION: float = 0.15  # how far a selected card rises, as a share of its height

var card: Card = null
var face_up: bool = false
var selected: bool = false
## 0 = resting, 1 = fully lifted. Animated by set_selected.
var lift: float = 0.0:
	set(value):
		lift = value
		queue_redraw()

var _tween: Tween = null


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE  # taps are handled by the hand, not each card
	texture_filter = CanvasItem.TEXTURE_FILTER_LINEAR_WITH_MIPMAPS  # smooth pictures when scaled


func setup(c: Card, face_up_value: bool, size_px: Vector2) -> void:
	card = c
	face_up = face_up_value and c != null
	custom_minimum_size = size_px
	size = size_px
	queue_redraw()


func set_selected(v: bool) -> void:
	selected = v
	var target: float = 1.0 if v else 0.0
	if _tween != null:
		_tween.kill()
	if is_inside_tree():
		_tween = create_tween()
		_tween.tween_property(self, "lift", target, 0.12)
	else:
		lift = target


## True when the skin supplies a picture for this card (or its back).
func is_drawn_from_image() -> bool:
	return _picture() != null


func _picture() -> Texture2D:
	var skin: GameSkin = GameSkin.get_current()
	if face_up and card != null:
		return skin.card_texture(card)
	return skin.back_texture()


func _draw() -> void:
	var s: Vector2 = size
	var skin: GameSkin = GameSkin.get_current()
	var offset: Vector2 = Vector2(0.0, -lift * s.y * LIFT_FRACTION)
	draw_set_transform(offset, 0.0, Vector2.ONE)
	# Soft shadow.
	var shadow: StyleBoxFlat = StyleBoxFlat.new()
	shadow.bg_color = Color(0, 0, 0, 0.28)
	shadow.set_corner_radius_all(int(s.x * 0.09))
	shadow.shadow_size = 0
	draw_style_box(shadow, Rect2(Vector2(s.x * 0.03, s.y * 0.02), s))
	var picture: Texture2D = _picture()
	if picture != null:
		draw_texture_rect(picture, Rect2(Vector2.ZERO, s), false)
	elif face_up and card != null:
		_draw_face(s, offset, skin)
	else:
		_draw_back(s, skin)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_face(s: Vector2, offset: Vector2, skin: GameSkin) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = skin.color("card_face")
	sb.border_color = skin.color("card_border")
	sb.set_border_width_all(maxi(1, int(s.x * 0.014)))
	sb.set_corner_radius_all(int(s.x * 0.09))
	sb.anti_aliasing = true
	draw_style_box(sb, Rect2(Vector2.ZERO, s))
	var col: Color = _suit_color(card.suit, skin)
	_draw_corner(s, col, skin)
	# Big suit in the middle.
	_draw_suit(card.suit, s * 0.5 + Vector2(0.0, s.y * 0.04), s.x * 0.27, col)
	# Same corner again, upside down, bottom right.
	draw_set_transform(offset + s, PI, Vector2.ONE)
	_draw_corner(s, col, skin)
	draw_set_transform(offset, 0.0, Vector2.ONE)


func _draw_corner(s: Vector2, col: Color, skin: GameSkin) -> void:
	var label: String = card.label()
	var rank_text: String = label.substr(0, label.length() - 1)
	var font: Font = skin.get_font()
	var font_size: int = maxi(8, int(s.y * 0.18))
	draw_string(font, Vector2(s.x * 0.11, s.y * 0.19), rank_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
	_draw_suit(card.suit, Vector2(s.x * 0.11 + s.x * 0.085, s.y * 0.285), s.x * 0.08, col)


func _draw_back(s: Vector2, skin: GameSkin) -> void:
	var outer: StyleBoxFlat = StyleBoxFlat.new()
	outer.bg_color = skin.color("back_frame")
	outer.set_corner_radius_all(int(s.x * 0.09))
	outer.anti_aliasing = true
	draw_style_box(outer, Rect2(Vector2.ZERO, s))
	var inset: float = s.x * 0.06
	var inner: StyleBoxFlat = StyleBoxFlat.new()
	inner.bg_color = skin.color("back_base")
	inner.border_color = skin.color("back_pattern")
	inner.set_border_width_all(maxi(1, int(s.x * 0.018)))
	inner.set_corner_radius_all(int(s.x * 0.06))
	inner.anti_aliasing = true
	draw_style_box(inner, Rect2(Vector2(inset, inset), s - Vector2(inset, inset) * 2.0))
	# Nested diamonds in the pattern colour.
	var c: Vector2 = s * 0.5
	var line: Color = skin.color("back_pattern")
	for k in range(1, 4):
		var rx: float = s.x * 0.13 * float(k)
		var ry: float = s.y * 0.10 * float(k)
		var pts: PackedVector2Array = PackedVector2Array([
			c + Vector2(0, -ry), c + Vector2(rx, 0), c + Vector2(0, ry), c + Vector2(-rx, 0), c + Vector2(0, -ry)])
		draw_polyline(pts, line, maxf(1.0, s.x * 0.014), true)
	draw_circle(c, s.x * 0.035, line)


func _suit_color(suit: Card.Suit, skin: GameSkin) -> Color:
	if suit == Card.Suit.DIAMONDS or suit == Card.Suit.HEARTS:
		return skin.color("card_red")
	return skin.color("card_black")


## A smooth heart outline centred on (0, 0), about 2.1 * r wide.
static func heart_points(r: float, segments: int = 64) -> PackedVector2Array:
	var pts: PackedVector2Array = PackedVector2Array()
	var s: float = r * 1.05 / 16.0
	for i in range(segments):
		var t: float = TAU * float(i) / float(segments)
		var x: float = 16.0 * pow(sin(t), 3.0)
		var y: float = -(13.0 * cos(t) - 5.0 * cos(2.0 * t) - 2.0 * cos(3.0 * t) - cos(4.0 * t))
		pts.append(Vector2(x * s, (y - 2.55) * s))
	return pts


func _moved(points: PackedVector2Array, by: Vector2, flip: bool = false) -> PackedVector2Array:
	var out: PackedVector2Array = PackedVector2Array()
	for p in points:
		out.append(by + Vector2(p.x, -p.y if flip else p.y))
	return out


## Draws a suit symbol. `r` is roughly half the symbol's size.
func _draw_suit(suit: Card.Suit, c: Vector2, r: float, col: Color) -> void:
	match suit:
		Card.Suit.DIAMONDS:
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -r * 1.12), c + Vector2(r * 0.78, 0),
				c + Vector2(0, r * 1.12), c + Vector2(-r * 0.78, 0)]), col)
		Card.Suit.HEARTS:
			draw_colored_polygon(_moved(heart_points(r), c), col)
		Card.Suit.SPADES:
			var body_c: Vector2 = c + Vector2(0, -r * 0.12)
			draw_colored_polygon(_moved(heart_points(r * 0.95), body_c, true), col)
			_draw_stem(c, r, col)
		Card.Suit.CLUBS:
			draw_circle(c + Vector2(0, -r * 0.52), r * 0.5, col)
			draw_circle(c + Vector2(-r * 0.56, r * 0.2), r * 0.5, col)
			draw_circle(c + Vector2(r * 0.56, r * 0.2), r * 0.5, col)
			draw_circle(c + Vector2(0, r * 0.08), r * 0.34, col)
			_draw_stem(c, r, col)


func _draw_stem(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(-r * 0.12, r * 0.3), c + Vector2(r * 0.12, r * 0.3),
		c + Vector2(r * 0.42, r * 1.08), c + Vector2(-r * 0.42, r * 1.08)]), col)
