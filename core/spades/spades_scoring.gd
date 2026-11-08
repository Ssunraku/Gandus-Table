class_name SpadesScoring
extends RefCounted
## Scoring for one round and for the whole game. Pure maths, no state.
## Teams: 0 = South+North, 1 = West+East (a seat's team is its index % 2).

const BAGS_LIMIT: int = 10
const BAGS_PENALTY: int = 100


static func team_of(seat: int) -> int:
	return seat % 2


## `bids`: seat -> Bid. `tricks_by_seat`: seat -> tricks won. `bags_before`: [team0, team1].
## Returns {points: [int, int], bags: [int, int], nil_results: {seat: bool made}}.
static func score_round(bids: Dictionary, tricks_by_seat: Dictionary, bags_before: Array[int], settings: SpadesSettings) -> Dictionary:
	var points: Array[int] = [0, 0]
	var bags: Array[int] = [bags_before[0], bags_before[1]]
	var nil_results: Dictionary = {}
	if settings.exact_mode != SpadesSettings.ExactMode.OFF:
		return _score_exact(bids, tricks_by_seat, bags, settings)
	for team in range(2):
		var bid_total: int = 0
		var has_number_bid: bool = false
		var team_tricks: int = 0  # only players who did NOT bid Nil count towards the bid
		for seat in range(4):
			if team_of(seat) != team:
				continue
			var b: Bid = bids[seat]
			var won: int = int(tricks_by_seat[seat])
			if b.is_nil_kind():
				var value: int = settings.nil_value() if b.kind == Bid.Kind.NIL else settings.blind_nil_value()
				var made: bool = won == 0
				nil_results[seat] = made
				points[team] += value if made else -value
			else:
				has_number_bid = true
				bid_total += b.tricks
				team_tricks += won
		if has_number_bid:
			if team_tricks >= bid_total:
				var extra: int = team_tricks - bid_total
				points[team] += 10 * bid_total + extra
				bags[team] += extra
			else:
				points[team] -= 10 * bid_total
		if settings.bags_penalty_enabled:
			while bags[team] >= BAGS_LIMIT:
				points[team] -= BAGS_PENALTY
				bags[team] -= BAGS_LIMIT
	return {"points": points, "bags": bags, "nil_results": nil_results}


## "Exact bids" rule: each number bid is judged on its own. Safe = min(tricks, bid) x 10,
## otherwise minus = -bid x 10. Nil / Blind Nil work as usual. No bags are collected.
## Also returns player_points {seat: int} and player_results {seat: "safe"/"minus"}.
static func _score_exact(bids: Dictionary, tricks_by_seat: Dictionary, bags: Array[int], settings: SpadesSettings) -> Dictionary:
	var points: Array[int] = [0, 0]
	var nil_results: Dictionary = {}
	var player_points: Dictionary = {}
	var player_results: Dictionary = {}
	for seat in range(4):
		var b: Bid = bids[seat]
		var won: int = int(tricks_by_seat[seat])
		var gained: int
		if b.is_nil_kind():
			var value: int = settings.nil_value() if b.kind == Bid.Kind.NIL else settings.blind_nil_value()
			var made: bool = won == 0
			nil_results[seat] = made
			gained = value if made else -value
		else:
			var safe: bool = is_safe(settings.exact_mode, b.tricks, won)
			player_results[seat] = "safe" if safe else "minus"
			gained = 10 * mini(won, b.tricks) if safe else -10 * b.tricks
		player_points[seat] = gained
		points[team_of(seat)] += gained
	return {"points": points, "bags": [bags[0], bags[1]], "nil_results": nil_results, "player_points": player_points, "player_results": player_results}


## Is `won` tricks safe for a bid of `bid` in this exact-bids mode?
static func is_safe(mode: int, bid: int, won: int) -> bool:
	match mode:
		SpadesSettings.ExactMode.EASY:
			return won >= bid - 1 and won <= bid + 1
		SpadesSettings.ExactMode.NORMAL:
			return won >= bid and won <= bid + 1
		SpadesSettings.ExactMode.HARD:
			return won == bid
	return true


## 0 or 1 = the winning team, -1 = the game goes on.
static func game_winner(scores: Array[int], settings: SpadesSettings) -> int:
	var reached: Array[bool] = [scores[0] >= settings.win_score, scores[1] >= settings.win_score]
	if reached[0] or reached[1]:
		return _higher_team(scores)
	var lost: Array[bool] = [scores[0] <= settings.lose_score, scores[1] <= settings.lose_score]
	if lost[0] and lost[1]:
		return _higher_team(scores)
	if lost[0]:
		return 1
	if lost[1]:
		return 0
	return -1


static func _higher_team(scores: Array[int]) -> int:
	if scores[0] == scores[1]:
		return -1
	return 0 if scores[0] > scores[1] else 1
