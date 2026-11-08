extends GutTest

var link: LocalLink
var host: SpadesHost
var me: SpadesClient
var runner: HostRunner


func _make(seed_value: int = 8) -> void:
	var s: SpadesSettings = SpadesSettings.new()
	s.blind_nil_enabled = false
	link = LocalLink.new(null)
	host = SpadesHost.new(link, s, seed_value)
	me = SpadesClient.new(link.local_client())
	runner = HostRunner.new(host, link)
	runner.pace = 0.0
	add_child_autofree(runner)
	me.join("Me", true)
	link.poll()
	me.request_seat(0)
	link.poll()
	me.add_bots()
	me.start_game()
	link.poll()


func _run_frames(n: int, delta: float = 0.016) -> void:
	for i in range(n):
		runner._process(delta)


func test_next_delay_is_minus_one_before_the_game_starts() -> void:
	link = LocalLink.new(null)
	host = SpadesHost.new(link, SpadesSettings.new(), 1)
	assert_eq(host.next_delay(), -1.0)


func test_next_delay_values() -> void:
	_make()
	assert_eq(host.next_delay(), SpadesHost.DEAL_WAIT, "a bot bids first, after the deal")
	host.step()
	link.poll()
	assert_eq(host.next_delay(), SpadesHost.BOT_PAUSE, "the second bot bids after a normal pause")
	while not host.session.must_bid(0):
		assert_true(host.step())
	link.poll()
	assert_eq(host.next_delay(), -1.0, "now it is my turn to bid: nothing is due")
	me.send_bid(Bid.number(3))
	link.poll()
	assert_eq(host.next_delay(), SpadesHost.BOT_PAUSE, "a bot leads after the bidding")


func test_a_finished_trick_waits_the_trick_hold() -> void:
	_make()
	var guard: int = 0
	while not host.session.trick_pending() and guard < 400:
		guard += 1
		_run_frames(1)
		if me.view["must_bid"]:
			me.send_bid(Bid.number(3))
			link.poll()
		elif me.view["must_play"]:
			me.send_play((me.view["legal"] as Array)[0])
			link.poll()
	assert_true(host.session.trick_pending())
	assert_eq(host.next_delay(), SpadesHost.TRICK_HOLD)


func test_runner_steps_bots_until_a_human_is_needed() -> void:
	_make()
	_run_frames(20)
	assert_true(me.view["must_bid"] or host.session.must_bid(0), "stopped at my turn to bid")
	assert_eq(host.next_delay(), -1.0)


func test_runner_waits_the_real_pause_when_pace_is_one() -> void:
	_make()
	runner.pace = 1.0
	var before: int = host.session.view_for_seat(0)["bids"].size()
	runner._process(0.5)
	assert_eq(host.session.view_for_seat(0)["bids"].size(), before, "0.5 s is shorter than the deal wait")
	runner._process(2.0)
	assert_eq(host.session.view_for_seat(0)["bids"].size(), before + 1, "after the wait the bot has bid")


func test_runner_does_not_step_while_paused() -> void:
	_make()
	host.paused = true
	var before: int = host.session.view_for_seat(0)["bids"].size()
	_run_frames(20)
	assert_eq(host.session.view_for_seat(0)["bids"].size(), before)


func test_runner_polls_the_link() -> void:
	_make()
	_run_frames(10)  # the bots bid, then it is my turn
	assert_true(host.session.must_bid(0))
	me.send_bid(Bid.number(3))  # only the runner's polling delivers it to the host
	assert_true(host.session.must_bid(0), "not delivered yet")
	_run_frames(1)
	assert_false(host.session.must_bid(0), "the runner polled and the host took my bid")


func test_stop_ends_all_activity() -> void:
	_make()
	runner.stop()
	var before: int = host.session.view_for_seat(0)["bids"].size()
	_run_frames(20)
	assert_eq(host.session.view_for_seat(0)["bids"].size(), before)
	assert_eq(host.phase_name(), "closed")
