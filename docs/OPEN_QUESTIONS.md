# Open Questions (need the owner's input)

## Answered so far (2026-11-07)
- App name: **Gandus Table**.
- GitHub: owner has an account; repository will be **private**.
- Test device: one **Samsung Galaxy Tab S6 Lite** (tablet). Number of other devices available: still unknown.
- Godot 4: owner says it is installed; location not yet found by Claude (to confirm).
- Java: JDK 17 recommended for Android export (awaiting approval to install).
- Codex reviews: postponed, decide later.
- Orientation: both portrait and landscape.
- Audience: personal use with friends (no Play Store for now).

The sections below are the original questions; items answered above are done.

No rules have been assumed. Please answer these before the relevant phase.

## A. Project / setup
1. Working title of the game / app name?
2. Do you have a GitHub account? Should the repository be private or public?
3. Do you have an Android phone for testing? Model and Android version? (And ideally 4 phones for real testing — which do you have access to?)
4. May we install Godot 4 (Standard), Android Studio / Android SDK, and a suitable JDK? (Installed JDK is 25; Godot's Android export typically needs 17 — to be checked before changing anything.)
5. Do you have OpenAI Codex installed/accounts ready for reviews?

## B. 29 (Twenty-Nine) — regional variants
Please describe the exact version you play, or point me to a written rule source. I will not guess. Things I need to know:
1. Number of cards, which cards are removed, card order and point values.
2. Players and partnerships (who partners with whom), dealing direction.
3. How cards are dealt (all at once, or in stages) and when bidding happens.
4. Bidding: minimum and maximum bid, who may bid, passing rules, what happens if everyone passes, whether partners can raise each other.
5. How trump is chosen, and whether it is hidden or revealed (and when/how it can be revealed).
6. Any special declarations or bonuses (e.g. pairs of certain cards) and when they can be called.
7. Scoring: how a game is won, game points vs. round points, what happens on failed bids.
8. Rules for the last trick, for following suit, and for what is illegal.
9. Special rules for re-deals, misdeals, or penalty rules.
10. Name of the region/community whose variant you want first.

## C. Spades — variants

### Owner's answers so far (2026-11-08) — still being collected, not yet a final rule sheet
- 2 fixed teams of 2 (South+North vs West+East); 52 cards, no jokers.
- Spades must be "broken" before they can be led (unless the player has nothing else).
- Nil allowed: +100 if the bidder wins 0 tricks, -100 otherwise.
- Blind Nil allowed: +200 / -200. Can be bid at any time (no score condition).
  Host can turn Blind Nil on or off before hosting a game (setting).
- Card swap happens only with Blind Nil, two-way. The bidder bids without looking, then looks
  at their own hand. They choose 1 or 2 of their own cards to give away, then choose the
  same number of cards to take from the partner's hand, which they cannot see (the partner's
  cards are hidden, chosen blind). (Supersedes the earlier "highest/lowest" wording.)
  Swap details (confirmed): the partner's hand is shown as face-down backs and the bidder taps
  positions; the swap is OPTIONAL (0, 1 or 2 cards); the partner makes no choices, just hands
  over the picked cards; the partner sees what they receive and which of their cards were
  taken; the swap happens after all four have bid and before the first card is played;
  both partners bidding Blind Nil is NOT allowed.
- A partner's tricks count for the team; the Nil bidder's own count stays separate.
- Bags: each overtrick = 1 point; reaching 10 bags = -100 (count then drops by 10).
- Normal bid: made = 10 x bid + 1 per bag; missed = -(10 x bid).
- Winning score default 500, losing score default -200; both host-changeable settings.
- Team score = bids and Nil scored separately; no "pass" in bidding (everyone bids 0-13, 0 = Nil).
- If both teams pass the target in the same round, the higher score wins.
- Round flow: deal passes clockwise; the player left of the dealer bids first (then clockwise)
  and leads the first trick. Ace high, spades are trump. Must follow suit if able; if void,
  any card may be played (cutting with a spade allowed) EXCEPT in the first trick of a round,
  where nobody may play a spade (or cut). A hand of only spades is a misdeal (redeal).
- Spades broken: a spade played as a cut counts as breaking. A player with only spades left
  may lead one.
- Host option switches (all chosen before hosting): Blind Nil on/off; normal Nil on/off;
  redeal rule on/off; bags penalty on/off; "play higher" rule on/off.
  - Normal Nil off + Blind Nil on is allowed. When ONLY Blind Nil is on, its bonus/penalty is
    the same as normal Nil (+/-100, not 200). With normal Nil on, Blind Nil stays +/-200.
  - With normal Nil off, allowed bids are 1-13.
  - Bags off: only the -100 penalty at 10 bags goes away; the +1 per extra trick still counts.
  - "Play higher" rule (optional, host): when following suit, a player who holds a card of the
    led suit that beats the highest card of the trick so far must play such a card. If they
    cannot beat it they play any card of the suit. A void player may play anything (no forced
    cutting). Nobody is forced to overcut with a higher spade.
- A failed Nil bidder's tricks cost only the Nil penalty (they do NOT add bags).
- A team that misses its bid gets no bags that round.
- Redeal rule (owner, 2026-11-08): the deal is redone AUTOMATICALLY when a player's hand is
  missing a suit (and for a dealing mistake, which cannot happen in a digital deal). At most
  2 redeals in a row. Host can enable/disable the redeal rule before hosting.
  Confirmed: "missing a suit" = a hand with zero cards of any one of the 4 suits; the 3rd deal
  always stands; the dealer stays the same on a redeal; players see a short message such as
  "Redeal: Tin has no hearts" before the new deal.
1. Partnership (2v2) assumed? Please confirm.
2. Deck: 52 cards only, or jokers included?
3. Bidding: allow Nil? Blind Nil? Any other special bids?
4. Bags / overtricks: penalty rules?
5. Winning score (e.g. 250/500) and losing score?
6. Can spades be led before they are "broken"?
7. Scoring details for failed bids.

## D. Multiplayer behavior

### Owner's answers (2026-11-08)
- Disconnect: the game pauses and waits by default; the host can choose other behaviours
  (e.g. bot takes over) in a setting before the game. Default wait time: forever; the host
  can set a time limit.
- Empty seats can be filled by bots. Bots are simple and never bid Blind Nil.
- One connection type per game (Wi-Fi OR Bluetooth); mixed games are not needed.
- Chat AND quick emoji reactions are wanted.

### Original questions
1. If a player disconnects: wait for them, replace with a bot, or let others vote?
2. Should empty seats be fillable by bots in a game with fewer than 4 humans?
3. Should the lobby support chat or emojis?
4. Is cross-play (Wi-Fi and Bluetooth players in the same game) wanted, or does each game use a single connection type?

## E. Product
1. Portrait, landscape, or both?
2. Card visuals: do you have art, or should we start with a simple generated style? (Any art we use must be legally usable.)
3. Sound and music wanted?
4. Languages needed (English only first? Bangla?)
5. Will this be published (Play Store) or just personal use? This affects licensing, privacy and release steps.
