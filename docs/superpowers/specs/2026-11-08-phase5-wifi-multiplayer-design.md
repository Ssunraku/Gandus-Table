# Phase 5 design: Wi-Fi multiplayer for Spades

Status: DRAFT, waiting for the owner's approval. Nothing in this document is built yet.

## 1. Intent

Four friends sit together, each with their own phone on the same Wi-Fi. One of them taps
**Host Game**, the other three tap **Join Game**, everybody picks a seat, and they play a full
game of Spades exactly like the offline game against bots, except the other seats are people.
Seats nobody takes can be filled with bots, so two or three friends can still play.

**Done when:** four phones play a whole game of Spades over Wi-Fi, a phone can drop out and
come back, and no phone ever receives another player's private cards.

## 2. Goals, non-goals, anti-goals

Goals
- Host and join on the same Wi-Fi, by room code or by a list of nearby games (both).
- Players choose their own seat. Players have names (the saved username system already exists).
- Disconnect and rejoin without losing the game.
- The host's game options are visible to joiners before they sit down (read-only).
- The network part is a swappable layer, so Bluetooth (later) and online play (maybe later)
  can be added without touching the game rules or the table screen.

Non-goals (not in Phase 5)
- Bluetooth (Phase 6). Online play across different networks (possible later; needs a server
  and the owner's approval of its cost). Host migration. Chat. Spectators. The game 29.
- A time limit per card (owner: none for now, friends can wait).

Anti-goals (it would be a failure even if it "worked")
- A player's phone ever holding another player's hand, even if the screen hides it.
- A game that silently freezes when a phone sleeps or drops out.
- Changing the offline game's behaviour: playing alone against bots must stay exactly as it is.

## 3. Rules the owner decided

| Topic | Decision |
|---|---|
| Joining | Both: a 4-letter room code AND an automatic list of nearby games |
| Empty seats | The host can fill them with bots |
| Seats | Players choose their own seat; partners sit opposite, as now |
| Names | Each player's saved name is shown at the table. Duplicates get a number ("Sam 2") |
| Host options | Joiners see them, read-only |
| Time limit | None |
| Player drops out | The game pauses for everyone and waits. They rejoin the same seat with the same hand. The host may instead let a bot take the seat |
| Player leaves on purpose | A bot takes their seat |
| Host drops out | The game ends (host migration is postponed) |
| Bluetooth | Forgotten for now |
| Online play | Possible later addition, not Phase 5 |

## 4. How it is built (plain-language overview)

The project already keeps four layers apart. Phase 5 fills in the two lower ones.

```
Table screen (what you see)        -> unchanged, reused
Game rules (SpadesGame)            -> unchanged
Protocol  (the messages)           -> NEW: net/protocol
Transport (moving the messages)    -> NEW: net/transport (Wi-Fi now; Bluetooth/online later)
```

**The host is the only place the game really exists.** Clients send requests ("I want to
play the 7 of spades"), the host checks them with the same rules code as offline and answers.
This already exists as `SpadesSession` for one human; Phase 5 teaches it about several humans.

**Private cards.** The host sends each player only: their own hand, how many cards the others
hold, and public facts (cards on the table, bids, scores, whose turn it is). The blind-Nil swap
shows the partner's cards face down and the host performs the swap, so those cards are never sent.

**One transport contract.** Every transport offers the same small set of actions: start
hosting, find hosts, connect, send a message to one player, send to everyone, and tell me when
someone connected, disconnected or sent a message. The Wi-Fi transport is the first one.
A fake in-memory transport (no network at all) lets us test whole games on a computer.

**One message format.** Messages are small dictionaries with a version, a type and a counter,
written as JSON text (easy to read when debugging). Draft message set:
- Lobby: `host_info`, `join_request`, `join_accepted` / `join_refused`, `seat_request`,
  `lobby_state` (who sits where, names, the host's options), `start_game`, `leave`.
- Game, host to player: `deal` (your hand, private), `table_state` (public view plus your
  hand), `your_turn`, `play_made`, `trick_won`, `round_summary`, `game_over`, `action_rejected`.
- Game, player to host: `bid`, `swap`, `play_card`.
- Trouble: `player_dropped`, `game_paused`, `resume`, `rejoin_request` (carries a secret
  rejoin token the player was given when they sat down).

**Finding games (Wi-Fi).** The host announces itself on the local network (UDP broadcast on a
fixed port). A joiner either sees the nearby list or types the 4-letter code, and their phone
asks "who has code ABCD?". The host's reply gives its address. As a last resort a joiner can type
the host's network address by hand. Guest, hotel and school Wi-Fi often block phone-to-phone
traffic; in that case the app should say so in plain words instead of searching forever.

**Pacing.** The host runs the bots' thinking pauses and the trick-hold pause, as the table
screen does today, and tells the others what happened. Each phone animates card plays and the
trick sweep from those messages.

## 5. Screens

- **Join Game** (the button exists but is greyed out): nearby games list, a room-code box,
  a "type address" fallback.
- **Lobby** (new, for host and joiners): four seats, each Free / a player's name / Bot.
  Joiners tap a free seat. The host sees "Fill with bots" and "Start game" (enabled once every
  seat is a human or a bot). Everyone sees the host's options, read-only.
- **Paused** notice during the table: "Waiting for Sam to come back" with the host's
  "Replace with bot" button.
- Host Game keeps its options screen, then leads to the lobby.

## 6. Order of work (two steps, as agreed)

1. **The invisible part**, all testable on the computer: the protocol, the transport contract,
   the fake transport, the host driving several humans, the client side, disconnect and rejoin.
   Finish by playing a whole game with four clients over the fake transport, checking that no
   client ever receives a hand that is not its own.
2. **The visible part**: the real Wi-Fi transport, discovery, the Join and Lobby screens, the
   paused notice, then a real test on the owner's phones.

## 7. Testing

- Automated: whole games over the fake transport (4 humans; 2 humans + 2 bots; a drop and a
  rejoin in the middle; a leave; a request from the wrong seat or out of turn is refused;
  every message sent to each player is searched for other players' cards).
- By hand: the owner's phones on the home Wi-Fi, then on a guest network to see the
  "blocked" message. A written checklist will go with the build.

## 8. Risks

- **Android export is not proven yet.** The Phase 1 tablet run was never done. The app needs
  internet and Wi-Fi permissions in its export settings, and the Android tools on this computer
  have to be set up. Doing the tablet run early is recommended.
- **Router behaviour** differs; broadcast may be blocked. Mitigated by the typed-address fallback.
- **Phones sleeping** mid-game drop the connection; the pause-and-rejoin design covers it, but
  must be tested on real phones.

## 9. Calls I made (the owner can overrule any of these)

1. Wi-Fi uses Godot's built-in ENet networking, wrapped behind our transport contract.
2. Messages are JSON text for now.
3. A rejoining player proves who they are with a secret token given when they sat down.
4. The host decides when to start; it needs every seat to be a human or a bot.
5. Seats can be switched in the lobby until the game starts, not after.
6. Names are shown to everyone; your own seat is still labelled "You" on your own screen.
7. The room code is 4 letters (no confusing ones like O/0), valid only while that host is hosting.
