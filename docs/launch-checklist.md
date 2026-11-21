# Launch checklist

Everything here needs the owner's account. The code side is done and tested (see "Tested" below).

## Before publishing

- [ ] **Starport, Publish tab:** Get latest, then **Publish all** to the Test places. This builds the Lobby and Game from the Rojo projects and merges them into the live places.
- [ ] **Game icon:** Creator Dashboard → the experience → Places → Game icon. Upload `assets/store/icon.png` (512 × 512).
- [ ] **Thumbnail:** same page → Thumbnails. Upload `assets/store/thumbnail1.png` (1920 × 1080). More can be made with `python tools/build_store_art.py`.
- [ ] **Description and genre:** for example: "Drill 100 miles down to the Earth's Core with your crew. Mine glowstone at stops, keep your rig repaired, survive the nights by the Beacon, and don't get left behind. Something lives in the dark between the camps..."
- [ ] **Maturity questionnaire:** fill in Roblox's questionnaire. The game has mild fantasy peril: a hooded creature that grabs players, with no blood or gore.
- [ ] **Start place:** check that the Lobby (76938279277561) is the universe's start place. If someone joins the Game place directly, it now sends them to the Lobby.
- [ ] *(Optional)* **Lighting:** in Studio, set Game place → Lighting → Technology to **Future**, then publish. Starport keeps the live place's lighting.

## Monetization (optional, off until set up)

- [ ] **Push Off (R$19):** create a Developer Product on the dashboard and put its id in `Config.PushOff.PRODUCT_ID`. Until then the Push Off prompt is hidden on live servers. It works in Studio.
- [ ] **Turbo:** the speedometer's TURBO badge is hidden until Turbo is built as a product.

## First live test (on the Test places, with two or three friends)

1. Join the Lobby, make a party in a bay and start.
2. Check that everyone lands in the same run at the right zone. Before the first run that's zone 1. After that, the leader's save decides.
3. Play to the first camp and through one night: feed the Beacon, mine, repair.
4. One player quits mid-run. Rejoin, and check that their miles were saved.
5. Finish zone 1. Check that everyone returns to the Lobby and that the next run starts zone 2.

## Tested in Studio

- Every zone, from its start to its Waystation, with no script errors or warnings. Zone 6 ends at The Core with the finale message.
- Mid-zone saves: Midsea (45), Ashfall (66) and Heartstone (88).
- Session-locked saves: the lock is taken on load and released on leave and on shutdown. Shutdown waits for saves still in flight.
- The Lobby panels (Journal, Badges, party creation) at phone size (686 × 393).
- The uploaded creature models, with paint, both on deck and while grabbing.
- Zone 6 Pulses: the light cycle, the Dark meter and the safe circle round the furnace lamp.

These can't be tested in Studio: teleports between places, reserved servers, MemoryStore and real multiplayer. That's what the live test is for.
