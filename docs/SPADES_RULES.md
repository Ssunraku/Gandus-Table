# Spades rules for Gandus Table (DRAFT for owner approval)

Everything below comes from the owner's answers on 2026-11-08 (see `docs/OPEN_QUESTIONS.md`).
Items marked **[ASSUMPTION]** are not yet confirmed. Nothing here is implemented until the
owner approves this sheet.

## 1. Setup
- 4 players, 2 fixed teams: South+North vs West+East (partners sit opposite).
- Standard 52-card deck, no jokers. Each player gets 13 cards.
- Rank high to low: A K Q J 10 9 8 7 6 5 4 3 2. Spades are always trump.
- The deal passes clockwise after each round. The player to the dealer's left bids first
  (then clockwise) and leads the first trick.

## 2. Redeal (host option, default: on)
- If any player's hand has zero cards of any one suit, the round is dealt again
  automatically, with the same dealer. Players see a message such as
  "Redeal: Tin has no hearts".
- At most 2 redeals in a row; the 3rd deal always stands.
- A hand of 13 spades counts as missing a suit, so it is redealt too.

## 3. Bidding
- Each player bids once, clockwise, a number from 0 to 13. There is no pass.
- 0 is **Nil** (win zero tricks). A normal bid is 1 to 13.
- The team's bid is the sum of the partners' number bids (a Nil bidder adds nothing).
- **Nil** (host option, default: on): +100 if the bidder wins 0 tricks, -100 if they win any.
  If Nil is off, allowed bids are 1-13.
- **Blind Nil** (host option, default: on): bid Nil without looking at your cards, allowed
  at any time (no score condition). +200 / -200. If normal Nil is off and Blind Nil is on,
  Blind Nil scores only +/-100. Both partners may not bid Blind Nil.
- A player who bids Blind Nil does not see their hand until bidding is finished.

## 4. Blind Nil card swap
- Happens after all four players have bid and before the first card is played.
- The Blind Nil bidder looks at their own hand, then chooses 0, 1 or 2 of their own cards
  to give to their partner. They then choose the same number of cards from the partner's
  hand, which they see only as face-down backs (chosen by position, blind).
- The partner makes no choices, but sees which cards they receive and which of theirs were
  taken.

## 5. Playing a round
- Play 13 tricks. The highest card of the led suit wins, unless a spade is played, in which
  case the highest spade wins. The winner of a trick leads the next one.
- A player must follow the led suit if able. A player with none of that suit may play any
  card (including a spade, "cutting"), with this exception:
  **in the first trick of a round nobody may play a spade.**
  (If the cards make that impossible, it is a redeal - see section 2.)
- **Spades broken:** nobody may lead a spade until a spade has been played (a spade played as
  a cut counts). A player who has only spades left may lead one.
- **"Play higher" rule** (host option, default: off): when following suit, a player who holds a
  card of the led suit that beats the highest card of the led suit so far must play such a
  card. If they cannot beat it, they play any card of the suit. A player with none of the
  suit may play anything (no forced cutting, no forced overcutting).
  **[ASSUMPTION]** If a spade has already cut the trick, players who still have the led
  suit may play any card of that suit.

## 6. Scoring each round
- **Team bid made** (tricks won >= bid): 10 x bid, plus 1 point per extra trick (a "bag").
  Example: bid 7, won 8 -> 71.
- **Team bid missed:** lose 10 x bid. No bags are collected that round.
- A Nil bidder's own tricks do not count toward the team's tricks for the bid check
  **[ASSUMPTION - owner said: partner's tricks count for the team, the Nil bidder's own count
  stays separate]**. A failed Nil only costs the Nil penalty; those tricks do not add bags.
- **Bags penalty** (host option, default: on): reaching 10 bags costs -100 and the bag count
  drops by 10. If this option is off, only the penalty goes; the +1 per extra trick stays.

## 7. Winning
- Default target 500 points; default losing score -200. Both are host settings.
- The game ends when a team reaches the target or falls to the losing score. If both teams
  pass the target in the same round, the higher score wins.
  **[ASSUMPTION]** If a team reaches the losing score, the game ends and the other team wins.

## 8. Host options summary (set before hosting)
| Option | Default |
|---|---|
| Blind Nil | on |
| Normal Nil | on |
| Redeal rule | on |
| Bags penalty | on |
| "Play higher" rule | off |
| Winning score | 500 |
| Losing score | -200 |
| When a player disconnects | pause and wait forever (host may choose a bot takeover or a time limit) |
| Bots for empty seats | allowed; simple bots, never bid Blind Nil |

## 9. Still to confirm
1. The assumptions marked above.
2. Which of two readings applies to a Nil bidder's tricks in the bid check (section 6).
3. What exactly the host can choose for disconnects (pause / bot takeover / time limit).
