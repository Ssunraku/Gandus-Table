class_name LocalSource
extends GameSource
## The offline game: forwards everything to a SpadesSession running on this phone.

var session: SpadesSession


func _init(s: SpadesSession) -> void:
	session = s


func phase() -> int:
	return session.phase()


func turn_seat() -> int:
	return session.turn_seat()


func human_must_bid() -> bool:
	return session.human_must_bid()


func human_must_play() -> bool:
	return session.human_must_play()


func human_must_swap() -> bool:
	return session.human_must_swap()


func submit_bid(b: Bid) -> bool:
	return session.submit_bid(b)


func submit_swap(give: Array[Card], positions: Array[int]) -> bool:
	return session.submit_swap(give, positions)


func submit_play(card: Card) -> bool:
	return session.submit_play(card)


func advance_bots() -> Dictionary:
	return session.advance_bots()


func trick_pending() -> bool:
	return session.trick_pending()


func shown_trick() -> Array[Dictionary]:
	return session.shown_trick()


func last_trick() -> Dictionary:
	return session.last_trick()


func clear_trick() -> void:
	session.clear_trick()


func round_over() -> bool:
	return session.round_over()


func game_over() -> bool:
	return session.game_over()


func winner_team() -> int:
	return session.winner_team()


func round_result() -> Dictionary:
	return session.round_result()


func round_number() -> int:
	return session.round_number()


func next_round() -> bool:
	return session.next_round()


func view() -> Dictionary:
	return session.view()


func redeal_messages() -> Array[String]:
	return session.redeal_messages()
