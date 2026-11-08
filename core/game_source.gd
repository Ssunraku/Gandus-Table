class_name GameSource
extends RefCounted
## What the game screen needs from "the game", whether it runs on this phone (LocalSource)
## or comes from a host over the network (RemoteSource). The method names are the same
## as SpadesSession's, and view() has the same shape with seats seen from the viewer
## (the viewer is always seat 0 = South).


func is_online() -> bool:
	return false


func phase() -> int:
	return 0


func turn_seat() -> int:
	return 0


func human_must_bid() -> bool:
	return false


func human_must_play() -> bool:
	return false


func human_must_swap() -> bool:
	return false


func submit_bid(_b: Bid) -> bool:
	return false


func submit_swap(_give: Array[Card], _positions: Array[int]) -> bool:
	return false


func submit_play(_card: Card) -> bool:
	return false


## One bot action, or {} (online: always {}, the host runs the bots).
func advance_bots() -> Dictionary:
	return {}


func trick_pending() -> bool:
	return false


func shown_trick() -> Array[Dictionary]:
	return []


func last_trick() -> Dictionary:
	return {}


func clear_trick() -> void:
	pass


func round_over() -> bool:
	return false


func game_over() -> bool:
	return false


func winner_team() -> int:
	return -1


func round_result() -> Dictionary:
	return {}


func round_number() -> int:
	return 1


func next_round() -> bool:
	return false


func view() -> Dictionary:
	return {}


func redeal_messages() -> Array[String]:
	return []
