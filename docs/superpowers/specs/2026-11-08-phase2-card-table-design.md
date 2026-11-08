# Phase 2 Design: Card Table Screen (UI only)

Status: **DRAFT, awaiting owner approval.** Nothing in this document is built yet.
Date: 2026-11-08

## Intent and why
Gandus Table needs a table screen that feels as clear and friendly as worldofcardgames.com. Phase 2 builds that screen with **dummy cards and no game rules**. It proves we can draw cards, fan a hand, tap and play cards, and fit different screen sizes, before rules and networking exist. It also keeps the architecture rule that the **user interface is a separate layer** from game logic.

The owner likes that site's look, UX and sounds. We take inspiration from the *experience* only. We do **not** copy its artwork, sounds or code (see Anti-goals).

## Reference observations (owner-approved study of the Spades table, 2026-11-08)
- Green felt table, top-down. Player at the bottom, partner at the top, opponents left and right.
- Each seat: a name bar plus an avatar. Opponent hands shown as curved fans of card backs.
- Own hand fanned along the bottom edge, overlapping, large corner numbers/suits.
- Score box top right; menu/info/settings buttons in the top corners.
- Short status text ("Dealing cards..."), animated dealing, dealer badge, per-player trick counters.
- Sounds could not be observed (browser had no audio). Owner to describe the ones they like.

## Goals (what Phase 2 delivers)
1. A table scene with four seats: you (bottom), partner (top), left, right.
2. Your hand of 13 dummy cards, fanned, readable, overlapping.
3. Opponent/partner hands shown as card backs only (a count of cards, never faces).
4. Tap a card: it lifts. Tap again (or tap the table area): it slides to the centre of the table (a "played card" spot per seat).
5. A deal animation (cards fly from a deck to each seat).
6. Name bar, placeholder avatar and a dealer badge at each seat; a score box; corner buttons (menu, info) that do nothing yet.
7. Layout adapts to **portrait and landscape** and to different screen sizes, including the Galaxy Tab S6 Lite (2000 x 1200 pixels).
8. Runs on the PC from the Godot editor. Checked at several window sizes.

## Non-goals (not in Phase 2)
- No game rules, bidding, scoring logic or legal-move checks.
- No networking, bots, or real player accounts.
- No sounds yet (we collect licensed sounds later; see open items).
- No settings screens, lobby or menus beyond placeholder buttons.
- Running on the tablet (owner postponed it; the design must simply not prevent it).

## Anti-goals (would make this a failure even if it technically works)
- Any artwork, sound or code copied from worldofcardgames.com or another site without a licence.
- UI code that contains game rules, or game state that the UI quietly owns. The table only *displays* a state it is given.
- Showing another player's card faces anywhere, even for dummy data. Opponent seats receive only a card count.
- Layout that only works at one screen size.

## Constraints
- Godot 4.7.2, GDScript with static typing, Compatibility renderer, 2D only.
- Follows `docs/ARCHITECTURE.md` layering. Card data (rank/suit) lives in a plain script with no UI code. A separate "view" draws it.
- Every artwork/font/sound file used is recorded in `docs/ASSETS.md` with source and licence.
- Small, understandable steps; owner can read and maintain the code.

## Decided by the owner
- Inspiration from worldofcardgames.com's UI/UX; not a copy.
- Both portrait and landscape.
- Android first; tablet is the real test device.
- Private game for friends only (no store release now).

## My calls (not yet agreed by the owner; please check)
1. **Cards are drawn by code in Phase 2** (shapes and a free font), not imported artwork. Reason: no licence worries, sharp at any size, easy to restyle. A proper artwork set can replace it later without changing game logic.
2. **Placeholder avatars** are simple coloured circles with initials. Real avatar art later.
3. **Layout is computed from the screen size** (not hard-coded pixel positions), so portrait/landscape and different tablets work.
4. **Dummy data:** a fixed shuffled deck for display only, so we can see and test the screen.
5. **A tiny "table state" object** (hand cards, opponent card counts, played cards, scores, whose turn) is what the screen draws. Later, the network layer will fill it. This is the seam that keeps UI and rules apart.
6. **Tests:** automated tests for card data (52 unique cards, sorting) and for the layout maths (all hand cards stay inside the screen at several sizes). Visual checks are done by running the screen and comparing with what the owner sees.

## Left to the builder
Exact scene/node structure, animation timing and easing, fan curve parameters, colour values, font choice (any free, licence-recorded font).

## Test and verification plan
- Automated: card model tests; layout tests at 1280x720, 720x1280, 2000x1200, 1200x2000.
- Run headless to confirm no errors.
- Owner opens the project in Godot, runs the scene, and reports what they see. I do not claim it works visually until verified.

## Open items for later phases
- Sound set (owner to describe the sounds they like; we pick licensed equivalents).
- Final card artwork choice (code-drawn vs a licensed set).
- Test framework choice (see question in the message that accompanies this draft).

## Addendum (2026-11-08, owner request after trying the table): skins and polish
The owner found the code-drawn cards, logos and UI choppy, uneven and plain, and wants to swap in real images later and restyle other UI parts later.
- **Skin system (new goal):** one `Skin` object, loaded from a folder `skins/<name>/`, supplies card images (`cards/<label>.png`, `cards/back.png`; label = the existing short name such as `AS`, `10H`), a colour palette, and an optional font. Missing images fall back to the code-drawn cards, so the game never breaks. The active skin is chosen in `skins/active.cfg`.
- **Colours** now come from the skin (editable in `skins/classic/skin.cfg`), not from constants in code.
- **Smoother drawing:** 2D multisample anti-aliasing turned on; hearts and spades drawn from smooth curves; textures filtered smoothly.
- **A nicer font** is wired through the skin; the actual font file needs the owner's approval to download (source and licence recorded in `docs/ASSETS.md`).
- **Out of scope for now:** a skin picker screen (settings phase), and image-based avatars/table/buttons (the same skin folder can hold them later).
