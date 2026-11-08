# Proposed Architecture

Status: **proposal**, not yet approved. Nothing here is implemented.

## The four layers
```
[ UI / presentation ]   scenes, card visuals, animations, input
          |
[ Game logic ]          pure rules: deal, bid, legal plays, scoring (no UI, no network)
          |
[ Protocol ]            logical messages: "player X played card Y", "your hand is ..."
          |
[ Transport ]           moves bytes: WifiTransport, BluetoothTransport (swappable)
```
Why: each layer can be tested and replaced on its own. Game rules can be unit-tested without a phone. Bluetooth can be added without touching the rules.

## Host authority
- One phone is the **host** and also a player.
- Clients send *requests* ("I want to play 7♠"). The host checks legality against the rules and either accepts or rejects.
- The host holds the only full game state.
- Clients receive only: their own hand + public info (cards on the table, bids, scores, whose turn).
- Other players' hands are never sent to a client. Even the host's UI must only display the host's own hand.

## Protocol (draft idea)
- Messages are small dictionaries with a `type` and a `version`, serialized (e.g. JSON at first for easy debugging; can be made compact later).
- Examples: `join_request`, `seat_assigned`, `game_start`, `hand_dealt` (private), `turn_started`, `play_card`, `action_rejected`, `state_update` (public), `player_disconnected`, `resume_request`.
- Each message carries a sequence number so we can detect missed/duplicate messages, which matters for Bluetooth and for reconnecting.
- The same messages are used on Wi-Fi and Bluetooth.

## Transport interface (draft idea)
One small contract every transport implements: start hosting, discover hosts, connect, send(to_player, message), broadcast(message), signals for connected / disconnected / message received.
- **Wi-Fi:** Godot has built-in networking (ENet / WebSocket). Host discovery on a local network is typically done with UDP broadcast. Needs testing on real phones/routers (some guest or hotspot networks block device-to-device traffic).
- **Bluetooth:** Godot does **not** include Bluetooth. We'd write a small Android plugin (Kotlin/Java) and expose it to GDScript. Classic Bluetooth (RFCOMM) vs Bluetooth Low Energy is an open decision; to be decided after a spike.
- **iOS later:** iOS uses different Bluetooth APIs. Android↔iOS Bluetooth interoperability is **unverified** and must be tested, not assumed.

## Disconnect and reconnect
- Host keeps the seat reserved when a player drops and pauses (or lets a bot take over, owner's choice - see OPEN_QUESTIONS).
- Reconnecting player sends `resume_request`; host re-sends that player's private hand and the current public state.
- Host migration (host drops) postponed.

## Folder layout (as of Phase 2)
```
res://
  core/        plain data and logic, no UI/network: card, deck, table_state, game_skin
  ui/          what you see: table, hand_view, card_view, seat_view, score_box, ...
  ui/layout/   table_layout.gd: pure maths from screen size to positions
  skins/       looks you can swap: classic/ (colours, font, optional card pictures)
  tests/       automated tests (GUT)
  addons/gut/  the test framework (outside code, MIT)
  net/         (later) protocol + transports
  games/       (later) spades/, twentynine/ rules
docs/
```

## Display and skins (Phase 2)
- `TableState` is the only thing the screen draws. It holds your real hand but only a card COUNT for every other seat, so the screen cannot show an opponent's cards. A played card is public and is stored per seat.
- `TableLayout` turns a screen size into rectangles, so portrait, landscape and different tablets all work.
- `GameSkin` supplies card pictures (optional), colours and the font from a folder in `skins/`. If a picture is missing the card is drawn by code. Everything visual asks the current skin; new screens must do the same so they can be re-skinned.

## Testing
- Game logic and layout are tested with GUT (chosen and approved in Phase 2).
- Network logic tested with a fake in-memory transport before real devices.

## Decision needed (will ask owner)
- Test framework choice; Bluetooth type (Classic vs BLE); message format.
