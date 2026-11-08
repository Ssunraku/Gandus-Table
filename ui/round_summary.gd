class_name RoundSummary
extends PanelContainer
## The box shown after each round: bids, tricks, Nil results, bags and points per team.

signal next_round_pressed

const TEAM_SEATS: Array = [[0, 2], [1, 3]]

var next_button: Button
var _box: VBoxContainer


func _init() -> void:
	add_theme_stylebox_override("panel", UiStyle.panel_box())
	_box = VBoxContainer.new()
	_box.add_theme_constant_override("separation", 10)
	add_child(_box)


static func bid_text(b: Bid) -> String:
	if b == null:
		return "-"
	match b.kind:
		Bid.Kind.NIL:
			return "Nil"
		Bid.Kind.BLIND_NIL:
			return "Blind Nil"
	return str(b.tricks)


func show_result(result: Dictionary, bids: Dictionary, tricks_won: Dictionary, team_scores: Array[int], team_bags: Array[int], round_number: int, names: Dictionary = {}) -> void:
	for c in _box.get_children():
		_box.remove_child(c)
		c.queue_free()
	_box.add_child(UiStyle.label("Round %d summary" % round_number, 30))
	var grid: GridContainer = GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 24)
	grid.add_theme_constant_override("v_separation", 8)
	_box.add_child(grid)
	_row(grid, "", "Us", "Them", true)
	var bid_cells: Array[String] = []
	var trick_cells: Array[String] = []
	var nil_cells: Array[String] = []
	for team in range(2):
		var parts: Array[String] = []
		var tricks: int = 0
		var nil_lines: Array[String] = []
		for seat in TEAM_SEATS[team]:
			parts.append(bid_text(bids.get(seat)))
			tricks += int(tricks_won.get(seat, 0))
			if (result.get("nil_results", {}) as Dictionary).has(seat):
				var made: bool = result["nil_results"][seat]
				nil_lines.append("%s %s Nil" % [names.get(seat, SpadesSession.seat_name(seat)), "made" if made else "failed"])
		bid_cells.append(" + ".join(parts))
		trick_cells.append(str(tricks))
		nil_cells.append(", ".join(nil_lines) if not nil_lines.is_empty() else "—")
	_row(grid, "Bid", bid_cells[0], bid_cells[1])
	_row(grid, "Tricks won", trick_cells[0], trick_cells[1])
	_row(grid, "Nil result", nil_cells[0], nil_cells[1])
	if result.has("player_points"):
		# "Exact bids" rule: each player's own result instead of bags.
		var cells: Array[String] = []
		for team in range(2):
			var lines: Array[String] = []
			for seat in TEAM_SEATS[team]:
				if (result["player_results"] as Dictionary).has(seat):
					var p: int = int(result["player_points"][seat])
					lines.append("%s %s" % [names.get(seat, SpadesSession.seat_name(seat)), ("+%d" % p) if p >= 0 else ("−%d" % -p)])
			cells.append(", ".join(lines) if not lines.is_empty() else "—")
		_row(grid, "Each player", cells[0], cells[1])
	else:
		var bags: Array = result.get("bags", team_bags)
		_row(grid, "Bags", "%d total" % int(bags[0]), "%d total" % int(bags[1]))
	var pts: Array = result.get("points", [0, 0])
	_row(grid, "Round points", "%+d" % int(pts[0]), "%+d" % int(pts[1]))
	_row(grid, "Game score", str(team_scores[0]), str(team_scores[1]), true)
	var button: Button = Button.new()
	next_button = button
	button.text = "Next round"
	button.custom_minimum_size = Vector2(260, 56)
	button.add_theme_font_size_override("font_size", 22)
	button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	UiStyle.style_button(button, "primary")
	button.pressed.connect(func() -> void: next_round_pressed.emit())
	_box.add_child(button)


func _row(grid: GridContainer, label: String, us: String, them: String, bold: bool = false) -> void:
	var skin: GameSkin = GameSkin.get_current()
	var l: Label = UiStyle.label(label, 18, true, true)
	l.horizontal_alignment = HORIZONTAL_ALIGNMENT_LEFT
	l.custom_minimum_size = Vector2(130, 0)
	grid.add_child(l)
	var a: Label = UiStyle.label(us, 18)
	a.add_theme_color_override("font_color", skin.color("score_us") if bold else skin.color("bar_text"))
	a.custom_minimum_size = Vector2(190, 0)
	grid.add_child(a)
	var b: Label = UiStyle.label(them, 18)
	b.add_theme_color_override("font_color", skin.color("score_them") if bold else skin.color("bar_text"))
	b.custom_minimum_size = Vector2(190, 0)
	grid.add_child(b)
