extends GutTest

const MAX_ROUNDS: int = 300


## Plays one whole game with four bots. Returns the number of rounds, or -1 if a bot
## action was rejected or the game never ended.
func _play_game(settings: SpadesSettings, seed_value: int) -> int:
	var game: SpadesGame = SpadesGame.new(settings, seed_value % 4)
	var bot: SpadesBot = SpadesBot.new(seed_value)
	game.start_round(seed_value * 1000)
	var rounds: int = 0
	while rounds < MAX_ROUNDS:
		rounds += 1
		if not _play_round(game, bot):
			return -1
		if game.phase == SpadesGame.Phase.GAME_OVER:
			return rounds
		game.next_round(seed_value * 1000 + rounds)
	return -1


func _play_round(game: SpadesGame, bot: SpadesBot) -> bool:
	if _dealt_cards_are_wrong(game):
		return false
	while game.phase == SpadesGame.Phase.BIDDING:
		if not game.bid(game.turn_seat, bot.choose_bid(game, game.turn_seat)):
			return false
	while game.phase == SpadesGame.Phase.SWAP:
		return false  # the bots never bid Blind Nil, so this must not happen
	var played: int = 0
	while game.phase == SpadesGame.Phase.PLAYING:
		var seat: int = game.turn_seat
		if not game.play(seat, bot.choose_card(game, seat)):
			return false
		played += 1
	return played == 52 and (game.phase == SpadesGame.Phase.ROUND_OVER or game.phase == SpadesGame.Phase.GAME_OVER)


## Right after dealing every seat must hold 13 cards and the 52 cards must all be different.
func _dealt_cards_are_wrong(game: SpadesGame) -> bool:
	var seen: Dictionary = {}
	for seat in range(4):
		if game.hand_of(seat).size() != 13:
			return true
		for c in game.hand_of(seat):
			seen[c.label()] = true
	return seen.size() != 52


func _run_many(settings: SpadesSettings, first_seed: int, count: int) -> void:
	var failures: Array[int] = []
	for s in range(first_seed, first_seed + count):
		if _play_game(settings, s) == -1:
			failures.append(s)
	assert_eq(failures, [] as Array[int], "games that broke or never ended (seeds)")


func test_200_default_games_all_finish_with_no_rejected_bot_action() -> void:
	_run_many(SpadesSettings.new(), 1, 200)


func test_games_with_normal_nil_off() -> void:
	var s: SpadesSettings = SpadesSettings.new()
	s.nil_enabled = false
	_run_many(s, 1000, 30)


func test_games_with_bags_penalty_off() -> void:
	var s: SpadesSettings = SpadesSettings.new()
	s.bags_penalty_enabled = false
	_run_many(s, 2000, 30)


func test_games_with_play_higher_on() -> void:
	var s: SpadesSettings = SpadesSettings.new()
	s.play_higher_enabled = true
	_run_many(s, 3000, 30)


func test_games_with_redeal_off() -> void:
	var s: SpadesSettings = SpadesSettings.new()
	s.redeal_enabled = false
	_run_many(s, 4000, 30)


func test_games_with_small_target_scores() -> void:
	var s: SpadesSettings = SpadesSettings.new()
	s.win_score = 100
	s.lose_score = -100
	_run_many(s, 5000, 30)


func test_bot_never_bids_blind_nil() -> void:
	var settings: SpadesSettings = SpadesSettings.new()
	var bot: SpadesBot = SpadesBot.new(1)
	for s in range(1, 60):
		var game: SpadesGame = SpadesGame.new(settings, 0)
		game.start_round(s)
		assert_ne(bot.choose_bid(game, game.turn_seat).kind, Bid.Kind.BLIND_NIL)
