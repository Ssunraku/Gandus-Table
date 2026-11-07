class_name ScoreBox
extends Control
## Small box showing each team's score and bags. Display only.

var scores: Array[int] = [0, 0]
var bags: Array[int] = [0, 0]


func _init() -> void:
	mouse_filter = Control.MOUSE_FILTER_IGNORE


func show_scores(new_scores: Array[int], new_bags: Array[int]) -> void:
	scores = new_scores.duplicate()
	bags = new_bags.duplicate()
	queue_redraw()


func _draw() -> void:
	var s: Vector2 = size
	var box: StyleBoxFlat = StyleBoxFlat.new()
	box.bg_color = Color(0.96, 0.96, 0.98)
	box.set_corner_radius_all(int(s.y * 0.12))
	draw_style_box(box, Rect2(Vector2.ZERO, s))
	var font: Font = ThemeDB.fallback_font
	var fs: int = maxi(8, int(s.y * 0.28))
	var small: int = maxi(8, int(s.y * 0.18))
	var col_w: float = s.x / 2.0
	var colours: Array[Color] = [Color(0.15, 0.35, 0.75), Color(0.80, 0.25, 0.30)]
	for i in range(2):
		var cx: float = col_w * float(i) + col_w / 2.0
		var score_text: String = str(scores[i])
		var bag_text: String = str(bags[i])
		var w1: float = font.get_string_size(score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		var w2: float = font.get_string_size(bag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs).x
		draw_string(font, Vector2(cx - w1 / 2.0, s.y * 0.38), score_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, colours[i])
		draw_string(font, Vector2(cx - w2 / 2.0, s.y * 0.88), bag_text, HORIZONTAL_ALIGNMENT_LEFT, -1, fs, colours[i])
	draw_string(font, Vector2(s.x * 0.04, s.y * 0.58), "Score", HORIZONTAL_ALIGNMENT_LEFT, -1, small, Color(0.35, 0.35, 0.4))
	draw_string(font, Vector2(s.x * 0.04, s.y * 0.99), "Bags", HORIZONTAL_ALIGNMENT_LEFT, -1, small, Color(0.35, 0.35, 0.4))
