# Phone test checklist (first Wi-Fi test of Gandus Table)

The app file is `build/GandusTable.apk` in the project folder (about 28 MB). It is a **debug build**: made for testing, not for the Play Store. It only runs on 64-bit Android phones (almost every phone from the last 8 years).

## 1. Putting the app on a phone

Pick ONE way. Do the same for every phone and the tablet.

**Way A: copy the file (easiest, no cable tools)**
1. Connect the phone to the computer with a USB cable. On the phone, choose "File transfer" if it asks.
2. Copy `build/GandusTable.apk` into the phone's `Download` folder.
3. On the phone, open the **Files** (or "My Files") app, go to Download, tap `GandusTable.apk`.
4. Android will say it blocks installs from this app. Tap **Settings**, switch on **Allow from this source**, go back, tap **Install**. (This setting can be switched off again afterwards.)

**Way B: install by cable from the computer (what I can do for you, with your OK)**
1. On the phone: Settings -> About phone -> tap **Build number** 7 times (this turns on Developer options). Then Settings -> Developer options -> switch on **USB debugging**.
2. Connect the cable and tap **Allow** on the phone's "Allow USB debugging?" question.
3. Tell me; I will run `adb devices` (lists the connected phones) and `adb install -r build/GandusTable.apk` (puts the app on the phone), and explain each step first.

## 2. The tests

Put all phones on the **same Wi-Fi**. Tick each line, and write down anything odd (what you tapped, what you expected, what happened, which phone).

**First start**
- [ ] 1. The app opens. It asks "What should we call you?". Type a name, tap Continue. Close the app completely and open it again: it should NOT ask again.
- [ ] 2. Settings shows your name and you can change it.
- [ ] 3. Text is easy to read and buttons are easy to tap, in both **upright** (portrait) and **sideways** (landscape).

**Hosting and joining** (phone A hosts, B, C, D join)
- [ ] 4. A: Host Game -> Start game (options screen) -> A goes straight to a **table**: A sits at the bottom, the other three seats are blank ("Tap to add a bot"), and the 4-letter **room code** is shown under the table (with a list of numbers if the code does not work).
- [ ] 5. B: Join Game. After a few seconds A's game appears in the list. Tap it. B sees A's table ("Join ...'s game") with the free seats.
- [ ] 6. C: Join Game, type the **room code** and tap Join. C sees the same table.
- [ ] 7. D: Join Game, type A's **address** (one of the numbers under A's table, for example 192.168.1.5) and tap Join. D sees the same table.
- [ ] 8. B, C and D each tap a **free seat** (it gets a gold ring) and press **Join table**. The table turns so each player is at the bottom, and everyone's screen shows who sits where, live. B can tap another free seat to move. The host's options are shown on every phone and cannot be changed there.
- [ ] 9. Try with only two or three phones too: A taps each blank seat once to put a **bot** there (tap a bot again to remove it). When all four seats are taken, "Starting in 3, 2, 1" appears and the game starts by itself.

**Playing**
- [ ] 10. The table opens on every phone. You see your own cards, your name at the bottom, your partner opposite, and everybody's real name.
- [ ] 11. A whole game can be played to the winner screen. Cards fly to the table, the trick sweeps to the winner, the soft tap plays when a card is laid.
- [ ] 12. Nobody can see another player's cards.
- [ ] 13. Tap a card that is not allowed (greyed out): nothing happens.
- [ ] 14. The round summary appears; tapping **Next round** starts the next deal on every phone.

**When things go wrong**
- [ ] 15. During a game, switch **phone B's screen off** for 20 seconds, then back on. Phone B should say "Reconnecting..." and then rejoin on its own, in the same seat. The others see "Waiting for B to come back..." meanwhile.
- [ ] 16. Turn **B's Wi-Fi off** for 10 seconds, then on. Same result as 15.
- [ ] 17. Turn B's Wi-Fi off for a long time (over 30 seconds). B should return to the start screen saying it could not reach the host. On A, tap **Replace with a bot** and the game should go on.
- [ ] 18. B taps Menu -> Exit to start during a game. B's seat becomes a bot and the game goes on.
- [ ] 19. The **host** (A) taps Menu -> Exit to start. Everyone else returns to the start screen saying the host ended the game.
- [ ] 20. After a game, join a started game from a new phone: it says the game has already started.
- [ ] 21. Join a full game: it says the game is full.

**Different kinds of Wi-Fi**
- [ ] 22. Try the **phone's own hotspot** (one phone shares its internet, the others connect to it). Does finding the game work? Does the typed address work?
- [ ] 23. Try a **guest Wi-Fi** or public Wi-Fi if you have one. Games probably will not appear in the list; the app should say why and the typed address may or may not work. Just note what happens.

**The tablet (Galaxy Tab S6 Lite)**
- [ ] 24. Fonts, colours and card sizes look right. Taps feel right. Both orientations work.
- [ ] 25. The soft tap sound is audible but not harsh; the volume slider in Settings works.

## 3. What to send me

For each failure: the number above, which phones, and a short description. A photo of the screen is very helpful. I will turn every failure into a test first, then fix it.
