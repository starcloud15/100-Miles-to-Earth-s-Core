# 100 Miles to Earth's Core: Game Design Document and Proposal

Nov 19, 2026 · @Star · **Status: proposal. Nothing here is built. Each section is up for owner approval.**

**Sources:**
- The reference recording, analysed frame by frame in [research/reference-recording-analysis.md](research/reference-recording-analysis.md).
- The Run a Resort knowledge base: Roblox Home signals, bounce, retention, economy and atmosphere.

**Number labels**, as in our other docs:

| Label | Meaning |
|---|---|
| **(recording)** | Read off the reference footage |
| **(live)** | Run a Resort's own analytics |
| **(research)** | An outside source |
| **(judgement)** | An estimate |

---

## 1. Vision and pillars

**100 Miles to Earth's Core** is a 1–6 player co-op Roblox survival game. Your crew builds a raft on the surface and rides one underground river **100 miles straight down to the Core**. The current carries you; your paddles steer and speed you. Every few minutes the river offers a place to stop. Then the **Lights Out** comes, and something in the dark follows the light.

**Elevator pitch:** "Raft down a river to the centre of the Earth with your friends, and make camp before the lights go out."

### Pillars

1. **The river is the level.** A guided path you can steer, not a track you ride. Every bend shows something new.
2. **Always deeper.** The depth counter is the score, the goal and the brag. It always moves, and it always shows the next stop.
3. **Stop, scramble, go.** Stops are short, busy and optional. The crew chooses between "camp here" and "push for the next one".
4. **Light is safety.** Warm light means safe and cold dark means danger, everywhere: camps, lanterns, the raft, the Core itself.
5. **Every layer of the Earth feels new.** Each zone changes the palette, the river, the fish, the threats and **one survival rule**.

### Audience and session

| Item | Target |
|---|---|
| Audience | Roblox 9–16, fans of raft/river, *99 Nights*-style survival and co-op journey games. Kid-friendly scary, never gory. |
| Players | 1–6 per raft (public crews of 4, private up to 6). Solo is fully playable. |
| Full descent | **100 miles in about 100–120 min** (the reference does about 0.84 mi/min, recording). Spread over **3–5 sessions** through Waystation saves. |
| One zone | **Grows as you go down:** 10, 10, 15, 20, 22 and 23 miles, about 9 to 24 min each (the reference's ladder, measured from its route bar). |
| One day loop | Camp, ride, landing, ride, dusk race, camp: **7–8 min** (the reference's rhythm, recording). |
| Session goal | **20 min average, 15 min minimum** (owner's target). One session should reach at least one Waystation. |
| Win | Reach Mile 100 and survive the Core finale. |
| Fail | The whole crew is down, or the raft sinks with nobody to rebuild it. You keep meta rewards and resume from the last Waystation. |

### The "not enclosed" rule (assumption, please confirm)

I read "platform must not be enclosed" in two ways. I've designed for both.

1. **The raft is always an open deck.** No walls, roofs or cages, ever, including upgrades: corner posts, lanterns and low cleats only. Being knocked off, swimming back and pulling a crewmate up is core drama. A walled raft kills it.
2. **The world must never feel like a closed tube.** Underground does not mean tunnel. Every zone is a chain of **huge open caverns**: ceilings 200–800 studs high, light shafts, glowing "skies" of fungus, crystal or magma, side vistas, waterfalls in and out. Tight tunnels appear only as short, deliberate squeezes (5–15 s) between big reveals. This keeps it readable on phones, lets fog and light do their work, and avoids the claustrophobia that sends players away.

---

## 2. What we take from the reference, and what we change

| Reference (recording) | Our version | Why |
|---|---|---|
| Control about 65 s after Play: party pad, loading, 25 s cutscene | **Control within 10 s of load.** Solo players skip the pad. The cutscene becomes in-world: the monster is glimpsed from the raft at 1:20. | Bounce is a top Home signal. Run a Resort's 22 s cutscene didn't help, and 60% skipped within 3 s (live). |
| "Punch trees for wood 0/12", then "Put wood in raft 40/60", raft leaves at about 35 s | The same verbs, faster. Punch trees, logs fly to the raft and visibly snap into planks, **launch at about 30 s**. | Same verb, early payoff. Something you made gets used within seconds. |
| Day and sun dusk, "Reach camp before dark!" | The surface has a real sun. Underground, the **Lights Out**: the cavern glow dims on a clock. | Keeps the tempo device; makes sense underground. |
| Monster "fears fire", stalks the camp ring | **The Hollow**: fears light, stalks the camp, hunts rafts with no lantern in the dark. | Signature threat, pressure not punishment. |
| Night bar with "Add wood to go faster" (up to 2.9×) and crew portraits | Kept, as a **Beacon Fire** fed with fuel that changes by zone: wood, then glowcaps, then coal, then crystals, then magma stone. | Turns waiting into a crew job. Fuel changing by zone is the "new rule per zone" hook. |
| Gator SPAM! QTE | One river threat per zone with the same QTE language. | Readable on phones, gives one-tap agency. |
| Fishing, cooking (Cooked Fish, Fish Stew) | Fishing gets 3–4 new species per zone. 12+ recipes with buffs. | Collection plus survival. |
| Journal lore notes from 4 factions | **Field Notes** from 5 earlier expeditions. 40 to collect. | Curiosity is the best predictor of free playtime (research). |
| "% of explorers have made it this far" | Kept, at every 5 miles. | Social proof and a dare, and it costs nothing. |
| No visible saves; 2 of 4 players gone at about 13 min | **Waystations** at every zone border, plus mid-zone in the long zones, save the expedition and are the D1 hook. NPC deckhands fill empty seats. | Lets 100 miles span sessions; protects solo players and dropped crews. |
| Push Off costs 19 R$ | **Free crew push** (hold F together, 3 s) or a 5 s solo shove. Robux is only the instant version. | Avoid a toll; "skips must pay what they advertise" (Run a Resort rule). |
| Starter Pack 49 R$: pet, oar, head-start kit | Kept as a model (section 13). | The best seller in Run a Resort too: 21 of 44 sales (live). |

---

## 3. Core loop

Four nested loops. Each outer loop raises the stakes of the inner one.

| Loop | Length | The player is asking | Ends with |
|---|---|---|---|
| **Stroke** | 5–30 s | "Can I dodge that rock, grab that crate, land this fish?" | Loot, a catch, a dodge, a crewmate saved |
| **Day** | 7–8 min | "Do we make camp before Lights Out?" | Surviving the Dark at a camp |
| **Zone** | 9–24 min, longer each zone | "What's down there, and can our raft handle it?" | A Waystation: save, shop, upgrade |
| **Descent and meta** | Hours to weeks | "Can we reach the Core? Faster? With every note?" | Badges, journal, classes, leaderboards, cosmetics |

---

## 4. The first three minutes (second-by-second target)

Targets from the knowledge base:
- Control in about 5 s, main verb within about 10 s, first payoff inside 60 s.
- A whole-scene "after" by 60–90 s.
- The biggest moment of joy *inside* the first 3 minutes.
- Bright light the whole time.
- One-line guidance in the world, never a dialogue wall.

| Time after load | Beat | Screen |
|---|---|---|
| 0–3 s | Spawn on a sunny riverbank at noon, next to a half-built raft frame. Camera already framed like the thumbnail: river, giant sinkhole on the horizon, a beam of light far below. | "0 Miles Down" with the sun badge. |
| 3–5 s | Objective, **one line**: 👊 "Punch trees for wood 0/8". A glowing outline on the nearest tree. | No text box, no NPC wall. |
| 5–25 s | Punch: wood chips, a log pops out and **flies to the raft by itself**, and a plank snaps onto the ghost outline. The raft visibly grows. | Counter rises. Juice on every hit (animated feedback is worth about +18%, research). |
| 25–30 s | Raft complete. "⛵ Hop on!" with a beam on the raft. Everyone aboard means **launch**. A raft that waits 10 s leaves anyway, with a RAFT IS LEAVING timer. | |
| 30–45 s | Paddle tutorial **is** the river: "Click to paddle". The first bend shows the sinkhole opening. Two floating crates sit in reach. | MPH gauge appears. |
| 45–60 s | First catch moment: a crate gives a **fishing rod**. "Cast for a fish!" (bites within 5 s the first time). | First payoff. |
| 60–90 s | **The Drop.** The river pours over the lip of the giant sinkhole. A slow, safe waterfall descent. The sky turns to a cavern full of glowing mushrooms. "1 Mile Down". | **The whole-scene "after", and the thumbnail moment.** |
| 90–120 s | The first cavern is bright with fungus glow. "🏕 Paddle to camp 1.2 mi". | |
| 120–150 s | The glow starts to fade. "🌙 Reach camp before Lights Out!" The Hollow is **glimpsed** on a ridge, far away, gone in a lightning flash. | First tension, no damage. |
| 150–180 s | Arrive at **Camp Ember** (Mile 2.5). "Safe in the light." Feed the Beacon Fire, and the first night bar appears. Cook the fish you caught. | The first night lands inside 180 s, like the reference (2:55), but brighter and calmer. |

**Rules:**
- Never dim the screen in the first 30 s.
- Keep the first night short (60–80 s with any fuel added).
- No shop popup until the first Waystation, and never in the 2 min after any milestone. Run a Resort lost 46% of finishers right after a burst of popups (live).

---

## 5. The river: guided path with paddle control

### 5.1 How it moves
- The river is authored as a **spline** with a width per point (30–120 studs) and a current speed per point.
- The raft follows the current automatically. **It never needs input to make progress**, so AFK players aren't stranded (judgement).

**Inputs:**

| Input | What it does |
|---|---|
| **Click / tap Paddle** (each crew member, left or right side by where you stand) | +speed and a turn toward the opposite side, like a canoe. 4 crew paddling together hits the "sync bonus" (+15% when strokes land within 0.4 s). |
| Lateral position | Clamped to the channel. The raft can drift ±45% of the width, so the "path" is guided but steering matters. |
| **Brake / backpaddle** (hold) | Slows the raft near a stop or before rapids. |
| **Turbo** (crew-shared) | Free from Boost Mushrooms found on the river. Instant with Robux. |

### 5.2 Speeds (in the reference's MPH so players read them the same, recording)

| State | MPH |
|---|---|
| Drift | 10–18 |
| Crew paddling | 25–40 |
| Rapids | 45–60 |
| Turbo | +20 for 20 s |

**Distance pacing:** about **1 mile a minute average** including stops. 100 miles is about 100–120 min.

### 5.3 What's on the river
- **Loot:** floating crates, barrels, driftwood and Boost Mushrooms. Steer to grab them.
- **Hazards:**
  - Rocks and stalagmites: raft damage, can knock players off.
  - Sandbars: stuck.
  - Whirlpools: spin and lose speed.
  - Low ceilings: "DUCK!" Crouch or be knocked off.
- **Forks** (2–3 per zone): a **safe channel** (longer, calm) or a **risky channel** (rapids, a shortcut, a loot cave). Signposted 15 s ahead with a yellow diamond sign; the reference uses these well (recording).
- **Warning signs** before every hazard type: the same yellow diamond pictogram language.

### 5.4 Falling off
- Knocked off: "KNOCKED OFF!" toast, then swim.
- "DON'T GET LEFT BEHIND!" with a red vignette and a RAFT marker with distance.
- Crewmates can throw a **rope ring** (a free tool) to reel you in. That's co-op.
- More than 220 m behind: "SWEPT AWAY: the river carried you back". Respawn on the raft at -10% health. No death loop.

### 5.5 Getting stuck
- Beached on a sandbar: **Push Off**. Hold F with 2+ crew for 3 s, or alone for 5 s. Optional Robux instant push.
- Never charge to make progress.

---

## 6. The raft: an open platform you grow

### 6.1 Deck
| Size | Grid | Seats | Gained |
|---|---|---|---|
| Base | 3×4 planks | 4 | Start |
| Wide | 4×5 | 6 | First Waystation |
| Long | 5×6 | 8 | Zone 4 Waystation |

**Always open:** no walls, roofs or cages.

### 6.2 Raft health
- 100–400 HP depending on the hull.
- Repair with wood (or zone fuel) at any stop, or on the move with a hammer (slow).
- At 0 HP the raft breaks apart: everyone swims, then must rebuild a base raft from drift planks within 60 s, or the run ends at the Waystation.

### 6.3 Upgrades (bought at Waystations with run currency; carried for the rest of the descent)

| Slot | Upgrade path | Effect |
|---|---|---|
| Hull | Lashed logs, then Plank deck, then Iron-banded, then Crystal-plated, then Obsidian | HP and impact resistance. Obsidian is needed in the magma zone. |
| Floats | Barrels, then Pontoons, then Air bladders | Less knock-off chance, better in rapids. |
| Lantern posts (4 corners) | Oil lantern, then Glowcap lamp, then Crystal lamp | **Light radius while moving.** The Hollow won't touch a raft inside its own light. Lanterns burn fuel. |
| Prow | Plain, then Ram, then Ice-breaker | Smash small hazards and floes. |
| Galley | Cook pot on deck | Cook while moving (slower than a camp). |
| Rod holders | ×2 / ×4 | Passive fishing while paddling. |
| Harpoon mount | Crew-operated | Fight river threats (zone 4 onwards: the Longneck, Snapjaws). |
| Deckhand bench | NPC rower | Fills an empty seat: solo and dropped-crew insurance. |

---

## 7. Stopping points

Three kinds of stop on a fixed rhythm. Spacing comes from the reference's average of about 3.2 mi between stops (recording).

| Stop | How often | Length | What's there |
|---|---|---|---|
| **Camp** (night stop) | About every 6 mi: 1 in zone 1, rising to 4 in zones 5–6 | The Dark lasts 60–120 s (shorter with fuel) | Beacon Fire safe ring, dock for fishing, cookfire, trees or fuel nodes, repair bench, 1–2 chests, 1 Field Note. Named: Camp Ember, Glowcap Hollow, Shard Hut… |
| **Landing** (day stop) | Between camps: 1 in zones 1–2, 3 in zones 3–6 | 45–90 s, the crew leaves when ready | Something **unique** each time: a trader NPC, a rescue (a stranded explorer joins as a deckhand), a wreck to loot, a puzzle door, a shrine buff, a rare fish pool. |
| **Waystation** (save stop) | Every zone border (10, 20, 35, 55, 77) plus mid-zone in the long zones (45, 66, 88). 8 in total. | No timer | **Saves the expedition.** Shop (raft upgrades, tools), meta-currency exchange, crew rejoin point, zone badge, "% of explorers" milestone. Safe: no Dark here. |

**Departure:**
- Ready ticks, then "LEAVING IN 30", which skips to 3 s when all are aboard.
- A crewmate still ashore when the raft leaves gets the RAFT IS LEAVING marker and timer, the same as the reference.

**Stay or push:** at a landing with Lights Out more than 60% away, the HUD offers "🏕 Next camp 3.1 mi". The crew decides whether to race for it. The reference crew did exactly this at 8.9 mi (recording).

---

## 8. Lights Out (the underground day/night)

- Zone 1 (the surface) has a real sun.
- Below the sinkhole, light comes from the cavern itself: fungus, crystals, magma. That **glow cycle** is the day.
  - **Bright:** about 5–6 min.
  - **Dimming:** about 60 s. Orange HUD: "🌙 Reach camp before Lights Out! 1.4 mi".
  - **Lights Out:** the Dark, 60–120 s at a camp.
- Lights Out while still on the river: "He's hunting! Get to camp 0.3 mi" (red). The Hollow starts closing in. The raft is only safe inside its lantern light, and lanterns burn fuel fast.
- At camp, the **Beacon Fire** sets the night bar speed:
  - Each crew member inside the ring adds speed (the portrait goes green).
  - Each fuel item adds +0.1×, up to 3.0×.
  - The fire burns down: "Fire's dying! Add fuel". At zero: "Fire's out! He's coming!" and the Hollow enters the ring.
- Lore explanation: the Core breathes. Its light pulses up through the rock, and the Hollow lives in the gaps between the pulses.

---

## 9. Zones: a ladder that gets longer

**Measured from the reference's route bar** (see [analysis §2.1](research/reference-recording-analysis.md)): the reference has **6 zones of 10, 10, 15, 20, about 22 and about 23 miles**. Real time per zone grows from 9 to 12 to 18 min. We use the same ladder.

Why a growing ladder works (judgement):
- **The first zones are short**, so a new player clears zone 1 in about 9 min and zone 2 inside a first session. That gives early "zone complete" wins and two badges on day one.
- **Later zones are long expeditions** for committed crews. Their length is the challenge.
- **The bar sells it.** Six blocks of growing width tell the player at a glance that the deep part is the big part.

Each zone adds **one rule** (pillar 5). The long zones (4–6) are **split into two sub-biomes**, so 20+ miles never feel like one place. Stops stay about 3 mi apart, so **longer zones mean more stops, not longer gaps**, exactly like the reference (2, then 3, then 5 stops in its zones 1–3, recording).

### 9.1 The ladder

| # | Miles | Length | Target time | Zone and sub-biomes | Look and light | River | New rule | Stops (camps / landings / saves) |
|---|---|---|---|---|---|---|---|---|
| 1 | 0–10 | **10** | about 9 min | **Sunfall Gorge**: surface valley, then the sinkhole | Sunny noon, green forest, red canyon. **The Drop** (a waterfall into the first glowing cavern) at about mile 1. | Calm, then the falls | The basics: hunger, health, punch, fish, cook | 1 / 1 / Waystation at 10 |
| 2 | 10–20 | **10** | about 11 min | **Glowshroom Grotto** | Teal and violet bioluminescent mushroom forests, spore "snow", a fungus "sky" | Wide and slow, lily pads | **Lights Out** begins (the glow cycle) | 2 / 1 / Waystation at 20 |
| 3 | 20–35 | **15** | about 16 min | **Crystal Hollows** (20–28), then **Old Deepmine** (28–35) | Ice blue crystal cathedrals, then warm lamplit mine works, rails and steam pipes | Ice floes, then canal locks and a mine-cart fork | **Cold** (warmth meter). The Deepmine half adds **mining**. | 2 / 3 / Waystation at 35 |
| 4 | 35–55 | **20** | about 20 min | **Fossil Sea** (35–46), then **Sporewood Shores** (46–55) | A vast open underground ocean with a horizon, giant skeletons and a geode "moon". Then a giant red and green mushroom jungle with warm mist. | Open water with a weak current (paddle!), then twisting rapids | **Navigation**: the current is weak, so you must paddle. The shores add **spores**. | 3 / 3 / Waystations at 45 (mid) and 55 |
| 5 | 55–77 | **22** | about 22 min | **Emberflow** (55–66), then **Obsidian Rapids** (66–77) | Black basalt, magma rivers beside the water, rising embers. Then glassy black canyons lit orange from below. | Hot water and geysers, then the fastest rapids in the game | **Heat**: an Obsidian hull and water bottles | 4 / 3 / Waystations at 66 (mid) and 77 |
| 6 | 77–100 | **23** | about 24 min + finale | **Heartstone Ruins** (77–90), then **The Core Approach** (90–100) | Ancient gold and stone temples of the people who tended the Core-fire. Then rock turning to light, the Core rising like a dawn. | Temple aqueducts and gate puzzles, then a whirlpool spiral | **Pulses**: the light comes in beats, so move between them | 4 / 3 / Waystation at 88 (mid), then the Core |

**Totals:**
- **16 night camps, 14 landings, 8 Waystations** (5 zone borders, 3 mid-zone).
- About **102 min** of play plus the finale (judgement), against the reference's projected 2 h.
- The longest stretch between saves is about 12 mi (about 12–14 min), inside one Home session.

**Why the mid-zone Waystations:** zones 4–6 take 20–24 min, longer than the 20 min average session target. A save halfway lets a player stop without losing the zone. The reference has no saves, and half its crew left at about 13 min (recording).

### 9.2 Threats, fish and fuel by zone

| # | River threat | Land threat | Fish (+1 rare) | Fire fuel |
|---|---|---|---|---|
| 1 | River otters steal floating loot (comic) | None. The Hollow is glimpsed. | Sun Trout, Pebble Perch, (Golden Minnow) | Wood |
| 2 | Lantern Eels grab swimmers (SPAM! QTE) | Spore Puffs pop and blind for 3 s | Glow Minnow, Cap Carp, (Moonscale) | Glowcaps |
| 3 | Shardback Turtles flip floes. In the Deepmine half, Rust Pikes. | Crystal Bats swarm lanterns. In the Deepmine half, Tunnel Moles burst from banks. | Frost Pike, Prism Fish, Blind Cavefish, (Iron Gar) | Crystal shards, then coal |
| 4 | **The Longneck** (a gentle giant that capsizes rafts if startled). On the shores, Snapjaws. | Bone Crabs. On the shores, Vine Creepers pull players off. | Coelacanth, Ammonite, Spotted Snapper, (Jungle Ray) | Driftwood and bone oil, then dry stalks |
| 5 | Magma Salamanders, lava splashes | Cinder Imps steal fuel | Lava Eel, Ember Koi, (Obsidian Gar) | Magma stone (very strong) |
| 6 | Temple Guardians (stone fish statues) | **The Hollow hunts every pulse** | Golden Arowana, (Corelight Koi) | Sacred oil |

### 9.3 Route bar (our version of the reference's)
- **6 segments sized 10 / 10 / 15 / 20 / 22 / 23**, with thin dark dividers.
- Passed zones light up in their own colour; zones ahead stay dark.
- The white marker is the raft, linear in miles. A yellow tick marks Mile 100.
- **Small Waystation pips** on the bar at 10, 20, 35, 45, 55, 66, 77 and 88. This is our addition.
- Zone colours: forest green, grotto teal, ice blue, sea blue, ember orange and core gold.

**Finale (judgement):**
- At Mile 100 the crew must keep the **Core Beacon** lit for 3 minutes while the Hollow makes its last hunt. All fuel collected that run counts.
- Win: the Core flares, the Hollow is burned away and a light rises up the whole river.
- Reward: the "Corewalker" title, a crew photo board in the lobby, unlocking **Deep Mode** (harder, new modifiers).

---

## 10. Monsters

**Rules** (from the Run a Resort *consent rule*, research):
- Danger must be **telegraphed** (sound, glow, sign) before it acts.
- It must be **answerable** with a single readable action (light, QTE, dodge).
- It **never feels random**.
- Scares are for tension. Deaths are rare and recoverable.

### 10.1 The Hollow (signature stalker)

**Look:**
- 25–40 studs tall, gaunt, stooped, arms that reach the ground with long rock-shard fingers.
- Body of shifting shadow over cracked stone. **Two small ember-white eyes.**
- Moves silently, then **clicks like falling pebbles** when hunting.
- It is the reverse of the Core: it eats light.

**Behaviour by phase:**

| Phase | What it does | Answer |
|---|---|---|
| Bright | Never appears. Glimpses only: a silhouette on a ridge, a hand on a far wall. | — |
| Dimming | Follows along the cliffs, closer each minute. Pebble clicks. | Get to camp. |
| Lights Out at camp | Circles the fire ring. Reaches in when the fire is low. Sweeping **dark beams** (shadow searchlights) cross the ground; a player caught outside the ring is grabbed. | Stay in the light, add fuel. |
| Lights Out on the river | Wades after the raft. Strikes when the raft's lantern light drops. | Lanterns lit, paddle hard. |

**Grabbed:** a SPAM! QTE (crewmates can shine a lantern to help). A failure means "Taken!" and a respawn at the fire with -50% health.

**Kid-safe:** no gore, no jumpscare sting louder than the ambience mix. The scare comes from scale and silence.

### 10.2 Per-zone threats (see the zones table)
- Each zone has **one river threat** (SPAM! QTE, knock-offs, stealing loot) and **one land threat** (at stops).
- Introduce each with a yellow warning sign plus a Field Note before its first attack.

### 10.3 Set-piece moments (one per zone from zone 2, more in the long zones; no health-bar fights)
| Zone | Moment |
|---|---|
| 2 | The Lantern Eel swarm at a narrow |
| 3 | A Tunnel Mole bursts through the river bed in the Old Deepmine and the raft has to jump the gap |
| 4 | The Longneck rises under the raft in the Fossil Sea: steer between its legs. Then a Snapjaw ambush on the Sporewood rapids. |
| 5 | A magma geyser chase, then the Obsidian Rapids run (the fastest stretch in the game) |
| 6 | The Hollow walks the temple aqueduct beside the raft through three pulses |

---

## 11. Survival and activities

### Stats
| Stat | Zones | How it works |
|---|---|---|
| **Hunger** | All | Drains about 1% every 6 s, faster while paddling. 0 means health drains. |
| **Health** | All | Damage from monsters, falls and heat. Regenerates by the fire. |
| **Warmth** | 3 | Cold drains near ice and in the Dark. Stay in light or eat hot food. |
| **Breath / spores** | 6 | Spore clouds. Mask or antidote. |
| **Heat** | 7 | Overheat. Water bottles, Ember-proof gear. |

Only Hunger and Health show on the HUD by default. The zone stat appears only in its zone, so the HUD stays clean (owner rule).

### Activities
- **Chopping and mining:**
  - Punch at first (zone 1, the reference's opener).
  - An axe drops from the first chest: 3× faster.
  - A pickaxe in the Old Deepmine half of zone 3, for ore, coal and crystals.
  - Nodes respawn per stop and are shared by the crew.
- **Fishing:**
  - Cast, wait ("…"), a "!" bite cue, then a short reel minigame (hold in the green zone, 2–5 s).
  - Rods: Twig, Bamboo, Iron, Crystal, Ember. Better rods mean rarer fish and faster bites.
  - Works from the dock or the moving raft.
  - Each zone has 3–4 species plus 1 rare. A **Fish Log** collection (40 fish).
- **Cooking:**
  - Cookfire panel: pick a recipe, see ingredients, **hold COOK** (the reference's hold-to-fill).
  - Recipes unlock by finding them in Field Notes or buying them from traders.
- **Eating and dropping:**
  - Holding food: "Click Eat · Q Drop".
  - Dropped items float on water for 30 s (a crewmate can grab them) or stay on land until the raft leaves.
  - A downed player drops half their bag.
  - **Sharing food with a crewmate is a featured co-op act.** It counts toward a "Good Crewmate" badge.
- **Looting:**
  - Floating crates (steer to them), chests at stops, wrecks of earlier expeditions.
  - Every chest shows a toast with the item and one line on what it's for.

---

## 12. Items

### 12.1 Tools
| Item | Where it comes from | Use |
|---|---|---|
| Fists | Start | Punch trees, slow |
| Paddle (Wooden, then Ironwood, then Crystal) | Start / Waystations | Speed. Better paddles add +5/+10% |
| Fishing Rod (Twig, Bamboo, Iron, Crystal, Ember) | First crate / shops | Fishing |
| Axe (Stone, then Iron) | First chest / zone 2 shop | Chop 3× and 5× faster |
| Pickaxe (Iron, then Crystal) | Zone 3 (Old Deepmine) | Ore, coal, crystals |
| Rope Ring | Start (free) | Reel in a crewmate who fell overboard |
| Hand Lantern | Zone 2 | Personal light radius in the Dark (uses fuel) |
| Hammer | Zone 1 Waystation | Repair the raft on the move |
| Harpoon | Zone 4 Waystation | Fight river threats from the mount |
| Water Bottle | Zone 7 | Cools Heat |
| Spore Mask | Zone 6 | Immunity to spores |

### 12.2 Resources
- Wood, Glowcaps, Crystal shards, Coal, Iron ore, Bone, Fossil, Magma stone, Sacred oil.
- Rope, Cloth, Drift planks.
- **Core Shards** (run currency: earned from stops, chests and distance, spent at Waystations).
- **Deepstones** (meta currency, kept between runs, spent in the lobby).

### 12.3 Food
| Food | Made from | Fills | Bonus |
|---|---|---|---|
| Raw Fish (any) | Fishing | 10% | Small chance of a "Sick" slowdown |
| Wild Berries | Zone 1 bushes | 8% | — |
| Cooked Fish | Fish + fire | 30% | — |
| Glowcap Skewer | 2 Glowcaps + fire | 25% | +light radius for 60 s |
| Fish Stew | 3 fish + Cave Herb | 60% | Slower hunger drain for 3 min |
| Crab Boil | Bone Crab + Water | 50% | +10 max HP for 3 min |
| Hot Chowder | 2 fish + Crystal Salt | 50% | **Warmth** (zone 3) |
| Antidote Stew | Mushroom + Herb | 30% | **Spore immunity** for 2 min (zone 4, Sporewood Shores) |
| Ember Chili | Lava Eel + Pepper | 40% | +paddle power, adds Heat |
| Golden Feast | Golden Arowana + 3 rare items | 100% | The whole crew, all buffs |

### 12.4 Camp and world props
- Beacon Fire ring, fish drying racks, docks, lantern poles.
- Supply chests, wrecked rafts and boats of earlier expeditions, mine carts.
- Field Note boards, waystones (zone markers), trader tents.

---

## 13. Atmosphere: how we make it

The owner's view, backed by the knowledge base: atmosphere drives early staying more than mechanics, **as long as it never blocks or confuses**. Concrete rules:

1. **Light is the language.**
   - Warm (2,700K amber) means safe: camps, lanterns, Waystations.
   - Cold (teal, violet, blue) means wonder and danger.
   - Red means "act now".
   - Every zone has one key light colour and one accent (in the zones table).
2. **Start bright.**
   - The surface is sunny at noon, and the first cavern glows teal.
   - Average frame brightness target **at least 140 for the first 3 minutes**. Run a Resort's 94 against rivals at 169–172 hurt it (live).
3. **Scale, then squeeze.**
   - Alternate huge open caverns with short squeezes.
   - Put a **reveal at every bend**: a giant skeleton, a waterfall, a city of lamps, a crystal cathedral.
   - Never a long dark tunnel (the "not enclosed" rule).
4. **Fog sells depth.**
   - Roblox Atmosphere density 0.3–0.45 per zone, tinted by zone.
   - Hide far geometry. Let set pieces fade in, never pop in.
   - Light shafts from cracks above (beams and volumetric parts).
5. **Earlier explorers were here.**
   - Wrecked rafts, abandoned camps, skeletons with a lantern, Field Notes signed by five expeditions (the Gorge Settlers, the Steam Barge Crew, the Miners' Guild, the Survey Scientists, the Last Expedition).
   - The "% of explorers have made it this far" line. This is the reference's best atmosphere trick and it's nearly free.
6. **Monster cadence: seen, heard, hunted.**
   - Glimpse in zone 1, clicks in zone 2, the first ring hunt at the first camp.
   - **Silence before a scare:** duck the ambience for 1–2 s.
7. **Sound** (ambience, not music; music had no measured playtime effect, research):
   - A river loop whose intensity follows speed.
   - Positional drips, distant rumbles, the Hollow's pebble clicks.
   - Camp crackle with a warm low hum.
   - At most 4 one-shot voices at once, pitch varied 0.9–1.15.
   - Music only for the zone banner sting and the finale.
8. **Particles per zone:**

   | Zone | Particles |
   |---|---|
   | Surface | Pollen |
   | Grotto | Spores |
   | Crystal | Snow-glints |
   | Mine | Dust |
   | Sea | Mist |
   | Jungle | Fireflies |
   | Emberflow | Rising embers |
   | Ruins | Golden motes |

   Capped for phones.
9. **The world reacts:**
   - Fish jump near the raft.
   - Bats scatter when lanterns pass.
   - Glowcaps brighten when touched.
   - The raft's wake lights up bioluminescent water.
   - Something reacts to the crew within seconds of anything they do.
10. **Stylised, calm palette:** chunky low-poly rock, readable silhouettes, no noisy textures. The reference's flat-shaded style reads well on phones.

**Lighting tech per zone (judgement):**
- `Lighting.Technology = Future`. ClockTime fixed underground.
- Per-zone `Atmosphere`, `ColorCorrection` (saturation +0.1, tint), `Bloom` (0.6–1.2) and `SunRays` only on the surface.
- Tween all of them over 4–6 s at zone borders.
- Phone fallback: fewer PointLights, emissive Neon parts instead.

---

## 14. Meta progression and retention

### 14.1 Lobby (the reference's layout, kept)
- Party pads: 1–6, with a 10 s countdown. **Solo "Start now" button.**
- Leaderboards: Deepest, Fastest to Mile 25/50/100, Fish caught, Deepstones.
- Journal: Field Notes 0/40 and the Fish Log.
- Badges: one per zone, plus feats.
- Classes hut. Invite. Free Revive board (join the group and like: 1 free revive per day).
- The player list shows lifetime Miles.

### 14.2 Classes (bought with Deepstones; one active per run)
| Class | Perk |
|---|---|
| Rower | +15% paddle power |
| Angler | Faster bites, rare fish chance |
| Cook | Recipes cook 2× faster, +25% food value |
| Lamplighter | Lanterns burn 40% slower |
| Lumberjack | Chop and mine 2× |
| Medic | Revive crewmates faster, bandages heal more |
| Scout | Sees hazards and loot through fog, longer warning signs |
| Engineer | Repairs 2×, upgrades 20% cheaper |
| Diver | Swims 2× faster, never Swept Away |

Each class levels from 1 to 10 through use. Levels unlock cosmetics, never big power.

### 14.3 Retention hooks by horizon (from the knowledge base)

| Horizon | Hook |
|---|---|
| Session | Next stop always 1–3 min away. A Waystation every 9–14 min (zone borders, plus mid-zone saves in the long zones). **End each session mid-leg**: the HUD says "Next: Waystation 3 · Crystal Hollows". |
| D1 | **The expedition is saved** at the Waystation and the lobby shows "Continue: Mile 35". A crate found at Mile 10 opens "at the next Waystation **or tomorrow**". Opt-in notification: "Your crew's raft is waiting at Mile 35." |
| D2–7 | Daily Expedition Orders (3 small tasks, such as "catch 2 Prism Fish"), a streak with a grace day, Field Notes to complete, class levels. |
| D8–28 | A content drop every 2–4 weeks (new fish, notes, a fork). Weekly events: **Quake Night** (river shifts, new forks), **Glow Bloom** (double rare fish), **Hollow Moon** (harder nights, double Deepstones). Deep Mode after the first finale. |
| Social | Co-op is an "Important" Home signal (research). Invite button, crew bonus (+10% Core Shards per friend aboard), share food and rescues for the Good Crewmate badge. |

### 14.4 Saves
- Waystations save: mile, raft, upgrades, inventory and run currency, **for the crew leader and each member**.
- Anyone can start a new crew from their own furthest Waystation.
- Run a Resort lesson: never hand out a fresh save on a failed read; retry, then ask the player to rejoin.

---

## 15. Monetisation

Principles (owner rules and the knowledge base):
- **Free beats paid.** No Robux item out-earns the best free item.
- **No paid randomness** without shown odds, and hidden where PolicyService restricts it.
- **Skips pay what they advertise.**
- No popups in the first 3 minutes or in the 2 min after a milestone.
- Contextual prompts sit next to the problem they solve: the reference's Turbo pill and Push Off prompt.

| Product | Type | Price (R$) | Where it shows | Notes |
|---|---|---|---|---|
| **Starter Pack** (pet pup with name and colours, Driftwood Oar cosmetic, head-start kit: axe, 3 cooked fish, lantern) | Gamepass | **49** | HUD button always. One popup at the **first Waystation** (Mile 10, about 9–10 min). | The reference's best-shaped offer (popup about 15 min, bought at about 25 min, recording). Best seller in Run a Resort (live). |
| **Turbo** (crew-wide +20 MPH, 20 s) | Dev product | **25** | Pill under the speedometer (T) | Free Boost Mushrooms also exist. |
| **Instant Push Off** | Dev product | **15** | World prompt when beached | The free crew push is always there too. |
| **Revive** (self, on the spot) | Dev product | **19** | Down screen | 1 free per day through the group. Medic class revives free. |
| **Raft skins** (Pirate, Viking, Crystal Swan, Bathtub, Pizza…) | Gamepass / shop | 99–249 | Waystation and lobby | Cosmetic only, still an open deck. |
| **Paddle skins, campfire skins, trails, pets** | Shop | 49–199 | Lobby | Pets follow you and fetch dropped items (QoL). |
| **Big Raft** (+2 seats and cargo from the start) | Gamepass | 199 | Lobby | Convenience. Base raft grows anyway. |
| **Deepstone packs** | Dev product | 49 / 129 / 299 | Lobby only | Buy classes faster. Classes are also earnable. |
| **Expedition Pass** (season) | Pass | 299 | Lobby | Deterministic free plus premium cosmetic tracks. No crates. |
| **Private crew server** | VIP server | 100/month | Roblox | Co-play signal. |

**Projected first purchase window (judgement):**
- First Waystation (Mile 10, about 9–10 min) and the post-first-night high (about 3–5 min, button only, no popup).
- **Target payer conversion 1.5–3%** of new players. The GameAnalytics median is 3.8% for big games (research); Run a Resort ran under 1% (live).

---

## 16. UI: 1:1 with the reference, reskinned for depth

**Full mockup:** [ui/ui-mockup.html](ui/ui-mockup.html). Open it in a browser. Positions and sizes are measured from the 2560×1440 recording, and every screen is a 16:9 frame.

| Reference | Ours | Change |
|---|---|---|
| "0.2 Miles" + sun badge | "0.2 Miles Down" + glow badge (sun on the surface, a glowing crystal underground, a moon in the Dark) | Wording only |
| "Reach camp before dark!" | "Reach camp before Lights Out!" | |
| "He's hunting! Get to camp" | Same | |
| Zone-segmented route bar | Same: **6 segments sized 10/10/15/20/22/23 mi**, passed zones lit in their own colour, white raft marker, yellow Mile 100 tick. We add Waystation pips. | Pips added |
| Hunger and Health bars | Same, plus a zone stat bar only when relevant (Warmth, Heat) | |
| Speedometer + Turbo 25 R$ | Same | |
| Starter Pack puppy button 49 R$ | Same | |
| Hotbar + Bag, "Click · Paddle" hint | Same | |
| Night bar, crew portraits, "Add wood to go faster" | Same. "Add fuel to end the Dark". | Fuel icon changes per zone |
| LEAVING IN / ALL ABOARD / WAITING FOR CREW | Same | |
| RAFT IS LEAVING / DON'T GET LEFT BEHIND / SWEPT AWAY | Same | |
| Cookfire, Starter Pack, Journal note, Meet your puppy, SPAM! | Same layouts, our content | |
| Lobby: Journal / Invite / Badges + currency + PLAY | Same + "Continue Mile X" | Continue button added |

**Implementation notes:**
- Build as ScreenGuis with `UIScale` from the 2560×1440 reference. Positions use Scale, not Offset.
- Font: `Enum.Font.Cartoon` / FontFace "Comic Neue Angular" Bold and Bold Italic, as in the reference. Use `UIStroke` 2.5–3 px black on HUD text, no stroke inside panels.
- HUD icons are flat 2D paintings (2–3 tones, thick dark outline), per the owner's rule.
- Phone: test on a real phone. Caps: popups at 50% of screen height, safe area respected, the hotbar never covers the joystick, and the PADDLE button matches the Roblox jump button.

---

## 17. Metrics and targets

| Metric | Target | Basis |
|---|---|---|
| Time to control after load | **≤ 10 s** (reference about 65 s from Play) | Bounce research |
| Home bounce under 60 s | **≤ 15%** | Benchmark median about 14–18% (research) |
| Home bounce 61–180 s | **≤ 18%** | PRISON RP median 20.4% (research) |
| Home PTR | ≥ 3% | Band about 2.0–4.7% (research) |
| Avg playtime per Home player | **≥ 20 min** | Owner target. D1 rises until about 19–24 min sessions (research). |
| D1 | ≥ 10% (median of big games), stretch 15% | GameAnalytics 2026 (research) |
| D7 | ≥ 2.5% | |
| Reach first camp | ≥ 85% of new players | judgement |
| Reach first Waystation (Mile 10) | ≥ 70% | The reference shows 76% reaching Mile 10 (recording) |

**Telemetry from day one** (Run a Resort's counters that paid off):
- Per-version first-session counters: under 60 s, under 180 s, reached camp 1, reached Waystation 1.
- Mile reached and quit mile.
- Stuck taps.
- Quit reason context: open window, in the Dark or not, in water or not.
- Frame rate, crew size at quit.
- The **% of explorers per mile**: the same data drives the in-game toast.

---

## 18. Thumbnail and promise
- **Same verb, bigger scale.** A crew on an open raft, paddles up, going over **the Drop** into a glowing cavern, the Hollow's silhouette faint on the wall. Players do all of it in the first 90 s.
- Tile 2: the Beacon Fire ring at night, the crew safe in warm light and the Hollow's eyes outside.
- Title tile text, if any: "100 MILES DOWN".
- Upload a plain gameplay video of the first 90 s.

---

## 19. Build plan (proposal)

| Milestone | Scope | Outcome |
|---|---|---|
| **M0: Greybox river** (1 week) | Spline river, current, paddle and steer, open raft physics, knock-off and swim, HUD (distance, speed) | The core verb feels good on a phone |
| **M1: Zone 1 vertical slice** (2 weeks) | First 3 minutes as scripted. Punching and the raft build, fishing, cooking, Camp Ember, Lights Out, the Hollow glimpse and ring hunt, 1 Landing, Waystation 1 save. Full UI set from the mockup. Telemetry. | **Soft launch.** Measure bounce and first-camp reach. |
| **M2: Zone 2** (2 weeks) | Glowshroom Grotto, Lantern Eels QTE, forks, Field Notes, Starter Pack, Turbo, Push Off | First monetisation read |
| M3: Zones 3–4 (15 and 20 mi) | Warmth, mining, navigation, spores, raft upgrades, classes, mid-zone saves | D1/D7 read |
| M4: Zones 5–6 (22 and 23 mi) + Core finale | The full descent | Full launch |

Engineering follows the OneWayToSpace setup: Rojo, `src/client`, `src/server`, `src/shared`. The river spline is shared config.

---

## 20. Decisions for the owner

1. **"Not enclosed":** is it the open raft deck, the open caverns, or both (as designed)?
2. **Monster name:** "The Hollow". Alternatives: "The Long Man", "The Dimmer".
3. **Crew size:** a 4 public cap (like the reference) or 6?
4. **Session shape:** Waystation saves (proposed) or a single-session run like the reference?
5. **Push Off:** OK to keep a free crew push and sell only the instant version?
6. **First build target:** start M0 now, in this repo, with the OneWayToSpace Rojo layout?
