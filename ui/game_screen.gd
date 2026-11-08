class_name GameScreen
extends Control
## One playable game: the table, the bid / swap / summary / info / menu boxes, and the
## little loop that lets the bots act with pauses. It owns a SpadesSession and only
## talks to it through its public methods.
## Tests set `pace = 0.0` and call step() themselves instead of waiting for timers.

signal game_finished(winner_team: int, team_scores: Array[int])
signal exit_to_start
## For placeholder sounds: "deal", "play", "trick", "turn", "bid", "win", "lose".
signal sound_event(event: String)

const BOT_PAUSE: float = 0.7    # seconds before each bot action
const TRICK_HOLD: float = 1.2   # seconds a finished trick stays on the table
const SUMMARY_DELAY: float = 0.4
const DEAL_WAIT: float = 1.8

## Multiplies every pause. 0 = no timers at all (tests drive step()).
var pace: float = 1.0
var session: SpadesSession
## What the screen reads and asks. Offline it wraps `session`; online it is a RemoteSource.
var source: GameSource
var settings: SpadesSettings

var table: Table
var partner_picker: PartnerPicker
var bid_panel: BidPanel
var swap_panel: SwapPanel
var summary: RoundSummary
var info_panel: InfoPanel
var menu_panel: PanelContainer
var notice_panel: PanelContainer
var notice_label: Label
var replace_button: Button  # online, host only: give a dropped player's seat to a bot
var input_blocker: ColorRect

var _pending_deal: bool = false   # online: a new deal arrived, animate it after the redraw
var _summary_shown_for: int = 0   # online: the round whose summary has already been shown
var _looked: bool = false     # you have chosen to look at your cards this round
var _bid_mode: String = ""    # "blind" or "bid": which look the bid panel currently has
var _swap_active: bool = false
var _stopped: bool = false
var _timer_pending: bool = false
var _generation: int = 0      # changes on every start/exit so old timers do nothing


func _init() -> void:
	table = Table.new()
	table.auto_start = false
	table.attached = true
	table.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(table)
	table.human_played.connect(_on_human_played)
	table.menu_pressed.connect(_open_menu)
	table.info_pressed.connect(_open_info)

	partner_picker = PartnerPicker.new()
	partner_picker.visible = false
	add_child(partner_picker)
	bid_panel = BidPanel.new()
	swap_panel = SwapPanel.new()
	summary = RoundSummary.new()
	info_panel = InfoPanel.new()
	menu_panel = _build_menu()
	notice_panel = PanelContainer.new()
	notice_panel.add_theme_stylebox_override("panel", UiStyle.panel_box())
	notice_panel.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var notice_box: VBoxContainer = VBoxContainer.new()
	notice_box.add_theme_constant_override("separation", 8)
	notice_panel.add_child(notice_box)
	notice_label = UiStyle.label("", 20)
	notice_box.add_child(notice_label)
	replace_button = Button.new()
	replace_button.text = "Replace with a bot"
	replace_button.custom_minimum_size = Vector2(240, 48)
	replace_button.add_theme_font_size_override("font_size", 19)
	UiStyle.style_button(replace_button, "primary")
	replace_button.visible = false
	replace_button.mouse_filter = Control.MOUSE_FILTER_STOP
	replace_button.pressed.connect(_on_replace_pressed)
	notice_box.add_child(replace_button)
	input_blocker = ColorRect.new()
	input_blocker.color = Color(0, 0, 0, 0.35)
	input_blocker.mouse_filter = Control.MOUSE_FILTER_STOP
	input_blocker.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	for p in [bid_panel, swap_panel, summary, info_panel, notice_panel, input_blocker, menu_panel]:
		p.visible = false
		add_child(p)  # order matters: the blocker sits above everything except the menu
	bid_panel.bid_chosen.connect(_on_bid)
	bid_panel.look_requested.connect(_on_look)
	swap_panel.confirmed.connect(_on_swap)
	summary.next_round_pressed.connect(_on_next_round)
	info_panel.closed.connect(func() -> void: info_panel.visible = false)
	resized.connect(_fit_panels)


func _build_menu() -> PanelContainer:
	var p: PanelContainer = PanelContainer.new()
	p.add_theme_stylebox_override("panel", UiStyle.panel_box())
	var box: VBoxContainer = VBoxContainer.new()
	box.add_theme_constant_override("separation", 14)
	p.add_child(box)
	box.add_child(UiStyle.label("Paused", 28))
	var resume: Button = Button.new()
	resume.text = "Resume"
	resume.custom_minimum_size = Vector2(260, 54)
	resume.add_theme_font_size_override("font_size", 22)
	UiStyle.style_button(resume, "primary")
	resume.pressed.connect(_resume)
	box.add_child(resume)
	var leave: Button = Button.new()
	leave.text = "Exit to start"
	leave.custom_minimum_size = Vector2(260, 54)
	leave.add_theme_font_size_override("font_size", 22)
	UiStyle.style_button(leave, "paper_outline")
	leave.pressed.connect(_leave)
	box.add_child(leave)
	return p


func start(game_settings: SpadesSettings, seed_value: int) -> void:
	_generation += 1
	_stopped = false
	_timer_pending = false
	settings = game_settings
	session = SpadesSession.new(settings, seed_value)
	session.start()
	source = LocalSource.new(session)
	_new_round_state()
	for p in [bid_panel, swap_panel, summary, info_panel, menu_panel, notice_panel, input_blocker]:
		p.visible = false
	refresh()
	_announce_redeal()
	_start_deal_animation()
	_kick()


## Starts a game that is played over the network: the host runs it and sends snapshots,
## this screen only draws them and sends the player's choices. No timers run here.
func start_online(src: RemoteSource) -> void:
	_generation += 1
	_stopped = false
	_timer_pending = false
	source = src
	session = null
	settings = src.settings()
	_summary_shown_for = 0
	_new_round_state()
	for p in [bid_panel, swap_panel, summary, info_panel, menu_panel, notice_panel, input_blocker]:
		p.visible = false
	src.event.connect(_on_remote_event)
	src.changed.connect(_on_remote_changed)
	src.paused_changed.connect(_on_remote_paused)
	src.client.rejected.connect(_on_remote_rejected)
	refresh()
	_announce_redeal()
	_start_deal_animation()
	if src.is_paused():
		_on_remote_paused(true, "a player")
	if src.round_over():
		_on_remote_changed()


func _on_remote_event(kind: String, seat: int, card: Card) -> void:
	match kind:
		"play":
			table.animate_card_played(seat, card)  # before the redraw, like offline
			sound_event.emit("play")
		"trick":
			table.sweep_trick(seat)  # `seat` is the trick's winner
			sound_event.emit("trick")
		"deal":
			_new_round_state()
			_pending_deal = true
		"bid":
			sound_event.emit("bid")


func _on_remote_changed() -> void:
	refresh()
	if _pending_deal:
		_pending_deal = false
		_announce_redeal()
		_start_deal_animation()
	if source.round_over() and _summary_shown_for != source.round_number():
		_summary_shown_for = source.round_number()
		_show_summary()
	elif not source.round_over():
		summary.visible = false
	if source.human_must_play():
		sound_event.emit("turn")


func _on_remote_paused(is_paused: bool, who: String) -> void:
	if is_paused:
		notice_label.text = "Waiting for %s to come back..." % who
		notice_panel.visible = true
		replace_button.visible = source is RemoteSource and (source as RemoteSource).client.is_host
		_fit_panels()
		_fit_panels.call_deferred()
	else:
		replace_button.visible = false
		notice_panel.visible = false


func _on_replace_pressed() -> void:
	if source is RemoteSource:
		var client: SpadesClient = (source as RemoteSource).client
		client.replace_with_bot(client.paused_seat)


## A short message in the middle of the table ("" hides it). Used for "Reconnecting...".
func set_notice(text: String) -> void:
	replace_button.visible = false
	if text == "":
		notice_panel.visible = false
		return
	notice_label.text = text
	notice_panel.visible = true
	_fit_panels()
	_fit_panels.call_deferred()


func _on_remote_rejected(_reason: String) -> void:
	refresh()  # the host said no: put a lifted card back


## Tells the player when a hand with a missing suit forced a new deal.
func _announce_redeal() -> void:
	var messages: Array[String] = source.redeal_messages()
	if messages.is_empty():
		notice_panel.visible = false
		return
	notice_label.text = "Redeal: " + "; ".join(messages)
	notice_panel.visible = true
	_fit_panels()
	if pace > 0.0 and is_inside_tree():
		var gen: int = _generation
		await get_tree().create_timer(4.0 * pace).timeout
		if gen == _generation:
			notice_panel.visible = false


func _new_round_state() -> void:
	_looked = not settings.blind_nil_enabled
	_bid_mode = ""
	if _swap_active:
		_swap_active = false
		table.hand.set_multi_select(0)


func _start_deal_animation() -> void:
	if pace > 0.0:
		table.play_deal_animation()
		sound_event.emit("deal")


## Redraws everything from the session. Safe to call at any time.
func refresh() -> void:
	var st: TableState = SpadesTableView.build(source)
	table.show_game_state(st)
	var hide_hand: bool = settings.blind_nil_enabled and source.phase() == SpadesGame.Phase.BIDDING and not _looked
	table.hand.set_face_down(hide_hand)
	if source.human_must_bid():
		var mode: String = "blind" if hide_hand else "bid"
		if mode != _bid_mode:
			_bid_mode = mode
			if mode == "blind":
				bid_panel.show_blind_choice()
			else:
				bid_panel.show_bidding(settings.nil_enabled)
		bid_panel.visible = true
	else:
		bid_panel.visible = false
		_bid_mode = ""
	var need_swap: bool = source.human_must_swap()
	if need_swap and not _swap_active:
		_swap_active = true
		table.hand.set_multi_select(2)
		partner_picker.setup(13, 2)
		swap_panel.setup(table.hand, partner_picker)
	elif not need_swap and _swap_active:
		_swap_active = false
		table.hand.set_multi_select(0)
	swap_panel.visible = need_swap
	partner_picker.visible = need_swap
	table.opponent_views[TableState.Seat.NORTH].visible = not need_swap and not table.is_dealing()
	_fit_panels()
	_fit_panels.call_deferred()


## Does the next automatic thing (a bot action, clearing a finished trick, showing the
## round summary). Returns false when it is waiting for you (or stopped).
func step() -> bool:
	if _stopped or source == null or source.is_online() or table.is_dealing():
		return false  # (online, the host runs the bots and the pauses)
	if source.trick_pending():
		table.sweep_trick(source.last_trick()["winner"])  # cards fly to whoever won them
		source.clear_trick()
		refresh()
		sound_event.emit("trick")
		return true
	if source.round_over():
		if summary.visible:
			return false
		_show_summary()
		return true
	var r: Dictionary = source.advance_bots()
	if r.is_empty():
		return false
	if r["kind"] == "play":
		table.animate_card_played(r["seat"], r["card"])
		sound_event.emit("play")
	elif r["kind"] == "bid":
		sound_event.emit("bid")
	refresh()
	if source.human_must_play():
		sound_event.emit("turn")
	return true


func _show_summary() -> void:
	var v: Dictionary = source.view()
	summary.show_result(source.round_result(), v["bids"], v["tricks_won"], v["team_scores"], v["team_bags"], source.round_number(), v["names"])
	summary.next_button.text = "See result" if source.game_over() else "Next round"
	summary.visible = true
	_fit_panels()
	_fit_panels.call_deferred()


func _human_must_act() -> bool:
	return source.human_must_bid() or source.human_must_swap() or source.human_must_play()


## Seconds (before scaling by pace) until the next automatic step, or -1 if none is due.
func _next_delay() -> float:
	if table.is_dealing():
		return 0.3
	if source.trick_pending():
		return TRICK_HOLD
	if source.round_over():
		return -1.0 if summary.visible else SUMMARY_DELAY
	if _human_must_act():
		return -1.0
	return BOT_PAUSE


func _kick() -> void:
	if pace <= 0.0 or _stopped or _timer_pending or source == null or source.is_online() or not is_inside_tree():
		return
	var delay: float = _next_delay()
	if delay < 0.0:
		return
	_timer_pending = true
	var gen: int = _generation
	await get_tree().create_timer(delay * pace).timeout
	if gen != _generation or not is_inside_tree():
		return  # the game was restarted or left: this timer belongs to an old game
	_timer_pending = false
	if _stopped:
		return
	step()
	_kick()


# ---------- what you do ----------

func _on_bid(b: Bid) -> void:
	if source.submit_bid(b):
		_looked = true
		sound_event.emit("bid")
		refresh()
		_kick()


func _on_look() -> void:
	_looked = true
	refresh()


func _on_human_played(card: Card) -> void:
	if source.is_online():
		# The host decides. The card flies when its snapshot arrives; if the host says no,
		# _on_remote_rejected redraws the hand.
		if not source.submit_play(card):
			refresh()
		return
	if source.submit_play(card):
		table.animate_card_played(TableState.Seat.SOUTH, card)
		sound_event.emit("play")
		refresh()
		_kick()
	else:
		refresh()  # puts the card back


func _on_swap(give: Array[Card], positions: Array[int]) -> void:
	if source.submit_swap(give, positions):
		refresh()
		_kick()
	else:
		refresh()


func _on_next_round() -> void:
	summary.visible = false
	if source.game_over():
		sound_event.emit("win" if source.winner_team() == 0 else "lose")
		game_finished.emit(source.winner_team(), source.view()["team_scores"])
		return
	if source.is_online():
		source.next_round()  # the host starts the new deal and tells everyone
		return
	source.next_round()
	_new_round_state()
	refresh()
	_announce_redeal()
	_start_deal_animation()
	_kick()


func _open_menu() -> void:
	_stopped = true
	input_blocker.visible = true
	menu_panel.visible = true
	_fit_panels()


func _resume() -> void:
	menu_panel.visible = false
	input_blocker.visible = false
	_stopped = false
	_kick()


func _leave() -> void:
	_generation += 1
	_stopped = true
	menu_panel.visible = false
	input_blocker.visible = false
	exit_to_start.emit()


func _open_info() -> void:
	var v: Dictionary = source.view()
	info_panel.show_info(v["bids"], v["names"], v["last_trick"])
	info_panel.visible = true
	_fit_panels()
	_fit_panels.call_deferred()


# ---------- layout ----------

func _fit_panels() -> void:
	if size.x < 1.0 or size.y < 1.0:
		return
	_fit(bid_panel, 760.0)
	_fit(swap_panel, 560.0)
	_fit(summary, 700.0)
	_fit(info_panel, 520.0)
	_fit(menu_panel, 360.0)
	if notice_panel.visible:
		notice_panel.size = notice_panel.get_combined_minimum_size()
		notice_panel.position = Vector2((size.x - notice_panel.size.x) / 2.0, size.y * 0.16)
	if partner_picker.visible:
		var l: Dictionary = TableLayout.compute(size)
		var card_h: float = (l["card_size"] as Vector2).y
		var fan: Rect2 = l["opponent_fan_rects"][TableState.Seat.NORTH]  # already clear of the corner widgets
		partner_picker.size = Vector2(fan.size.x, card_h * 0.62)
		partner_picker.position = fan.position


func _fit(p: Control, max_width: float) -> void:
	if not p.visible:
		return
	var w: float = minf(max_width, size.x * 0.94)
	p.size = Vector2(w, 0.0)
	p.position = Vector2((size.x - p.size.x) / 2.0, maxf(8.0, (size.y - p.size.y) * 0.42))
