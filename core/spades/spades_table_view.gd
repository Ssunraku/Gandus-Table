class_name SpadesTableView
extends RefCounted
## Turns what a SpadesSession lets the human know into the TableState the table draws.
## Only your own cards are real Card objects; other seats are just counts, plus the
## cards they have already played face-up on the table.


static func build(session) -> TableState:  # a SpadesSession or any GameSource
	var v: Dictionary = session.view()
	var st: TableState = TableState.new()
	st.own_hand = Deck.sort_hand(v["hand"])
	var counts: Dictionary = v["hand_counts"]
	for seat in [TableState.Seat.WEST, TableState.Seat.NORTH, TableState.Seat.EAST]:
		st.set_card_count(seat, int(counts[seat]))
	for entry in v["trick"]:
		st.set_played(entry["seat"], entry["card"])
	var names: Dictionary = v["names"]
	for seat in names.keys():
		st.seat_names[seat] = names[seat]
	st.dealer_seat = v["dealer_seat"]
	st.turn_seat = v["turn_seat"]
	st.team_scores = v["team_scores"]
	st.team_bags = v["team_bags"]
	st.tricks_won = (v["tricks_won"] as Dictionary).duplicate()
	st.bids = (v["bids"] as Dictionary).duplicate()
	st.spades_broken = v["spades_broken"]
	st.phase = v["phase"]
	st.can_play = session.human_must_play()
	st.legal_cards = v["legal"]
	st.last_trick = v["last_trick"]
	return st
