# Skins: changing how the game looks

A skin is a folder in `skins/`. The game uses the one named in `skins/active.cfg`.

## Add your own card pictures
1. Copy `skins/classic` and rename the copy, for example `skins/mycards`.
2. Put your pictures in `skins/mycards/cards/`:
   - 52 faces named by rank and suit letter:
     `2C.png` ... `9C.png`, `10C.png`, `JC.png`, `QC.png`, `KC.png`, `AC.png`
     (the suit letter is C = clubs, D = diamonds, H = hearts, S = spades; the
     same pattern for every suit, e.g. `10H.png`, `QD.png`, `AS.png`)
   - the card back: `back.png`
3. Open `skins/active.cfg` and change `name="classic"` to `name="mycards"`.
4. Open the project in Godot once (it imports the pictures), then run the game.

Tips for the pictures:
- PNG (or WebP/JPG/SVG), every card the same size and shape, about 500 x 700 pixels.
- Rounded corners with a transparent background look best.
- Missing pictures are fine: that card is simply drawn by code instead.
- You must have the right to use the pictures. Write where each set came from in
  `docs/ASSETS.md`.

## Important when building the Android app
Godot leaves plain `.cfg` text files out of an exported app unless told to include
them. When we first create the Android export, add `*.cfg` to the export preset's
"Resources -> Filters to export non-resource files" box. Otherwise the phone would
show the built-in colours and ignore `skins/active.cfg`.
Card pictures: in Godot's Import tab, turn on "Mipmaps -> Generate" for them, so
large pictures look smooth when shown small.

## Change the colours or the font
- Colours: edit `skin.cfg` in your skin folder (`#rrggbb`).
- Font: put a `font.ttf` (or `font.otf`) in the skin's `fonts/` folder.
