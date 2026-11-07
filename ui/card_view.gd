class_name CardView
extends Control
## Draws one card with code (no image files). Face-up shows rank and suit;
## face-down shows a blue patterned back. It only DISPLAYS; it has no rules.

const LIFT_FRACTION: float = 0.15  # how far a selected card rises, as a share of its height
const RED: Color = Color(0.80, 0.10, 0.12)
const BLACK: Color = Color(0.08, 0.08, 0.10)

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


func _draw() -> void:
	var s: Vector2 = size
	var offset: Vector2 = Vector2(0.0, -lift * s.y * LIFT_FRACTION)
	draw_set_transform(offset, 0.0, Vector2.ONE)
	# Soft shadow.
	var shadow: StyleBoxFlat = StyleBoxFlat.new()
	shadow.bg_color = Color(0, 0, 0, 0.25)
	shadow.set_corner_radius_all(int(s.x * 0.09))
	draw_style_box(shadow, Rect2(Vector2(s.x * 0.03, s.y * 0.02), s))
	if face_up and card != null:
		_draw_face(s, offset)
	else:
		_draw_back(s)
	draw_set_transform(Vector2.ZERO, 0.0, Vector2.ONE)


func _draw_face(s: Vector2, offset: Vector2) -> void:
	var sb: StyleBoxFlat = StyleBoxFlat.new()
	sb.bg_color = Color.WHITE
	sb.border_color = Color(0.55, 0.55, 0.58)
	sb.set_border_width_all(maxi(1, int(s.x * 0.012)))
	sb.set_corner_radius_all(int(s.x * 0.09))
	draw_style_box(sb, Rect2(Vector2.ZERO, s))
	var col: Color = _suit_color(card.suit)
	_draw_corner(s, col)
	# Big suit in the middle.
	_draw_suit(card.suit, s * 0.5 + Vector2(0.0, s.y * 0.04), s.x * 0.27, col)
	# Same corner again, upside down, bottom right.
	draw_set_transform(offset + s, PI, Vector2.ONE)
	_draw_corner(s, col)
	draw_set_transform(offset, 0.0, Vector2.ONE)


func _draw_corner(s: Vector2, col: Color) -> void:
	var label: String = card.label()
	var rank_text: String = label.substr(0, label.length() - 1)
	var font: Font = ThemeDB.fallback_font
	var font_size: int = maxi(8, int(s.y * 0.17))
	var text_w: float = font.get_string_size(rank_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size).x
	draw_string(font, Vector2(s.x * 0.12 - text_w * 0.0, s.y * 0.19), rank_text, HORIZONTAL_ALIGNMENT_LEFT, -1, font_size, col)
	_draw_suit(card.suit, Vector2(s.x * 0.12 + s.x * 0.075, s.y * 0.27), s.x * 0.075, col)


func _draw_back(s: Vector2) -> void:
	var outer: StyleBoxFlat = StyleBoxFlat.new()
	outer.bg_color = Color.WHITE
	outer.set_corner_radius_all(int(s.x * 0.09))
	draw_style_box(outer, Rect2(Vector2.ZERO, s))
	var inset: float = s.x * 0.06
	var inner: StyleBoxFlat = StyleBoxFlat.new()
	inner.bg_color = Color(0.13, 0.24, 0.58)
	inner.border_color = Color(0.55, 0.65, 0.90)
	inner.set_border_width_all(maxi(1, int(s.x * 0.015)))
	inner.set_corner_radius_all(int(s.x * 0.06))
	draw_style_box(inner, Rect2(Vector2(inset, inset), s - Vector2(inset, inset) * 2.0))
	# A simple diamond pattern.
	var c: Vector2 = s * 0.5
	var light: Color = Color(0.55, 0.65, 0.90, 0.9)
	for k in range(1, 4):
		var rx: float = s.x * 0.13 * float(k)
		var ry: float = s.y * 0.10 * float(k)
		var pts: PackedVector2Array = PackedVector2Array([
			c + Vector2(0, -ry), c + Vector2(rx, 0), c + Vector2(0, ry), c + Vector2(-rx, 0), c + Vector2(0, -ry)])
		draw_polyline(pts, light, maxf(1.0, s.x * 0.012))


func _suit_color(suit: Card.Suit) -> Color:
	if suit == Card.Suit.DIAMONDS or suit == Card.Suit.HEARTS:
		return RED
	return BLACK


## Draws a suit symbol from basic shapes. `r` is roughly half the symbol's size.
func _draw_suit(suit: Card.Suit, c: Vector2, r: float, col: Color) -> void:
	match suit:
		Card.Suit.DIAMONDS:
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(0, -r * 1.1), c + Vector2(r * 0.75, 0),
				c + Vector2(0, r * 1.1), c + Vector2(-r * 0.75, 0)]), col)
		Card.Suit.HEARTS:
			draw_circle(c + Vector2(-r * 0.5, -r * 0.35), r * 0.58, col)
			draw_circle(c + Vector2(r * 0.5, -r * 0.35), r * 0.58, col)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 1.06, -r * 0.1), c + Vector2(r * 1.06, -r * 0.1),
				c + Vector2(0, r * 1.05)]), col)
		Card.Suit.SPADES:
			draw_circle(c + Vector2(-r * 0.5, r * 0.15), r * 0.58, col)
			draw_circle(c + Vector2(r * 0.5, r * 0.15), r * 0.58, col)
			draw_colored_polygon(PackedVector2Array([
				c + Vector2(-r * 1.06, -r * 0.05), c + Vector2(r * 1.06, -r * 0.05),
				c + Vector2(0, -r * 1.1)]), col)
			_draw_stem(c, r, col)
		Card.Suit.CLUBS:
			draw_circle(c + Vector2(0, -r * 0.5), r * 0.48, col)
			draw_circle(c + Vector2(-r * 0.55, r * 0.2), r * 0.48, col)
			draw_circle(c + Vector2(r * 0.55, r * 0.2), r * 0.48, col)
			_draw_stem(c, r, col)


func _draw_stem(c: Vector2, r: float, col: Color) -> void:
	draw_colored_polygon(PackedVector2Array([
		c + Vector2(0, r * 0.2), c + Vector2(-r * 0.4, r * 1.05), c + Vector2(r * 0.4, r * 1.05)]), col)
