# 100 Miles to Earth's Core: Game Design Document and Proposal

Nov 19, 2026 · @Star · **Status: proposal. Nothing here is built.**

**Approved by the owner so far:**
- The Drill Rig as the vehicle.
- Crews of 1–5 (default 4).
- Growing zones (10/10/15/20/22/23 mi).
- The reference's **UI and core gameplay structure**: one resource that builds, repairs and keeps the safe light going; a food activity; stops and nights; Push Off (shove a player off); nothing ever gets the rig stuck; the monster calm at first and faster further down; the lobby and meta loop.
- **Our own content** (approved Nov 19, 2026): Glowstone, Delving (the food action), the tools, the Glow Mole pet, Deepstones, and the Prospector / Delver / Lamplighter classes.
- UI art drawn in the reference's glossy style, using its exact font (Comic Neue Angular Bold).

**Sources:**
- The reference gameplay recording, analysed frame by frame in [research/reference-recording-analysis.md](research/reference-recording-analysis.md).
- The reference lobby recording, analysed in [research/reference-lobby-analysis.md](research/reference-lobby-analysis.md).
- The Run a Resort knowledge base: Roblox Home signals, bounce, retention, economy and atmosphere.

**How we use the reference.** The reference is a raft game on a river. It is **a model, not a source of content**:
- **We copy its UI and its core gameplay structure:** the loop, the pacing, what each system is *for*, the lobby and the monetisation shape.
- **We do not copy its resources, food, items, pets or names.** Every one of those is our own and fits a journey down through the Earth. This is an original game, not a reskin.

**Number labels**, as in our other docs:

| Label | Meaning |
|---|---|
| **(recording)** | Read off the reference footage |
| **(live)** | Run a Resort's own analytics |
| **(research)** | An outside source |
| **(judgement)** | An estimate |

---

## 1. Vision and pillars

**100 Miles to Earth's Core** is a 1–5 player co-op Roblox survival game. At the surface, your crew powers up an old **Drill Rig** with **Glowstone**, the warm glowing rock that is the only light underground. Then you drill **100 miles down to the Core**. The rig follows a planned route on its own; your crew cranks the treads to speed it up and steer it. Every few minutes the route breaks out into a cavern where you can stop and mine, and anywhere along the way you can cast a hook into the rock to dig up food. Then the **Lights Out** comes, and something in the dark follows the light.

**Elevator pitch:** "Drill to the centre of the Earth with your friends, and keep the light alive."

### Pillars

1. **The route is the level.** A guided path you can steer, not a track you ride. Every turn shows something new.
2. **Always deeper.** The depth counter is the score, the goal and the brag. It always moves, and it always shows the next stop.
3. **Stop, scramble, go.** Stops are short, busy and optional. The crew chooses between "camp here" and "push for the next one".
4. **Light is life.** The one resource *is* light. Glowstone is **everywhere**, and crews gather lots of it. The question is never "do we have enough?" but "do we have time?": mine one more vein, or reach the Beacon before Lights Out.
5. **Every layer of the Earth feels new.** Each zone changes the palette, the rock, the creatures, the threats, what you dig up to eat and **one survival rule**.

### Audience and session

| Item | Target |
|---|---|
| Audience | Roblox 9–16, fans of *99 Nights*-style survival and co-op journey games. Kid-friendly scary, never gory. |
| Players | **1–5 per rig. The party creator picks the size; 4 is the default** (the reference's lobby, recording). Solo is fully playable. |
| Full descent | **100 miles in about 100–120 min** (the reference does about 0.84 mi/min, recording; its fastest crews take about 51 min, recording). Spread over **3–5 sessions** through Waystation saves. |
| One zone | **Grows as you go down:** 10, 10, 15, 20, 22 and 23 miles, about 9 to 24 min each (the reference's ladder, measured from its route bar). |
| One day loop | Camp, drill, landing, drill, dusk race, camp: **7–8 min** (the reference's rhythm, recording). |
| Session goal | **20 min average, 15 min minimum** (owner's target). One session should reach at least one Waystation. |
| Win | Reach Mile 100 and survive the Core finale. |
| Fail | The whole crew is down, or the rig stalls with nobody to repair it. You keep meta rewards and resume from the last Waystation. |

### The "not enclosed" rule (assumption, please confirm)

I read "platform must not be enclosed" in two ways. I've designed for both.

1. **The rig is always an open deck.** No walls, roofs, cabins or cages, ever, including what the crew builds on it: railings at knee height, lantern posts and low cargo crates only. Being thrown off, running to catch up and pulling a crewmate back aboard is core drama. A closed cabin kills it.
2. **The world must never feel like a closed tube.** Drilling does not mean a tunnel all the way down. The route is a chain of **huge open caverns** joined by **short bores** (5–15 s each). In the caverns the rig crawls down spiral ledges, crosses rock bridges and drives along causeways, under ceilings 200–800 studs high with glowing "skies" of fungus, crystal or magma. This keeps it readable on phones, lets fog and light do their work, and avoids the claustrophobia that sends players away.

---

## 2. The model, system by system: the reference's role, our own content

Each row keeps **what the system does** in the reference and replaces **what it is** with something of our own.

| System | Its role in the reference (recording) | Our version | Why |
|---|---|---|---|
| Vehicle | A raft on a river | **An open-deck Drill Rig on a planned route down through the Earth** | The owner's theme. The guided-but-steerable feel stays. |
| Moving and steering | Paddling: each player paddles on their side; strokes add speed and turn the raft | **Cranking: each player pumps a crank on their side of the deck; it drives that side's tread** (section 5) | Same feel, same "everyone has a job", our own verb. |
| The one resource | Wood: builds the raft, repairs it, feeds the fire | **Glowstone**: a warm, glowing rock. It **powers up the rig** at the start, **repairs** it, and **feeds the Beacon** and lanterns that keep the Hollow away (section 11) | One resource with three uses keeps every stop readable. Making the resource *light itself* ties it to the monster. **Plentiful, like the reference's wood** (owner): the pressure is time, not supply. |
| How you get it | Punching, then chopping trees | **Smashing glowing rock, then mining veins with a pickaxe**; loose chunks on the route can be scooped up by steering over them | Digging fits a journey into the Earth. |
| Food | Fishing: an action you can do from the raft or the shore, then cooking | **Delving**: cast a weighted **Delver's Hook** into any rock or earth, from the ground or the moving rig, wait for the tug, then reel up a root, tuber, truffle or cave fruit with a timing minigame. Cook at the **Cookpot** (section 11) | Same role and same feel as fishing (cast, wait, bite, reel, anywhere), but an underground action of our own. |
| The safe place at night | A campfire ring, "Add wood to go faster" | The **Beacon**: a glowstone lamp tower at each camp. "Add glowstone to end the Dark" | Same night bar and crew job, our own object. |
| Opening | "Punch trees for wood 0/12", then "Put wood in raft 40/60", the raft leaves at about 35 s | "Smash glowstone 0/8": chunks fly into the rig's core and its lights switch on one by one. **Launch at about 30 s**. | Same pace, early payoff. |
| Control | About 65 s after Play: party pad, loading, 25 s cutscene | **Control within 10 s of load.** The monster is glimpsed from the rig at 1:20 instead of a cutscene. | Bounce is a top Home signal. Run a Resort's 22 s cutscene didn't help, and 60% skipped within 3 s (live). |
| Day and night | Sun dusk, "Reach camp before dark!" | The surface has a sun. Underground, the **Lights Out**: the cavern glow dims on a clock. | Keeps the tempo device; makes sense underground. |
| Monster | Fears fire, stalks the camp ring; **calm at the first few camps, faster further down** (owner) | **The Hollow**: eats light, stalks the Beacon. Watches only at the first camps, then gets faster at each camp further down. | Pressure, not punishment, and a difficulty curve that follows depth. |
| Grab QTE | A gator grabs a player: SPAM! | One route threat per zone with the same SPAM! QTE (Lantern Eels, Snapjaws…) | Readable on phones, gives one-tap agency. |
| Push Off | Shoves another player off the raft for 19 R$ (owner); **nothing gets the raft stuck** (owner) | The same mechanic on the rig. Nothing in the route ever stops the rig. | Getting stuck would break pacing; the shove is a funny, social paid moment. |
| Collection | Journal: 6 notes + 2 pages per zone (recording) | Same shape: 6 **Field Notes** + 2 **Journal Pages** per zone, 49 in all, from 5 earlier expeditions, plus our own **Delve Log** | Curiosity is the best predictor of free playtime (research). |
| Social proof | "% of explorers have made it this far" | Kept, every 5 miles and on the Stats panel. | It's a dare, and it costs nothing. |
| Saves | None seen; 2 of 4 players gone at about 13 min | **Waystations** at every zone border, plus mid-zone in the long zones | Lets 100 miles span sessions. |
| Starter Pack | 49 R$: a puppy pet, an oar skin, a head-start kit | 49 R$: a **Glow Mole** pet, a **Brass Crank** skin, a head-start kit (section 15) | Same offer shape, our own items. Best seller in Run a Resort too: 21 of 44 sales (live). |
| Meta currency | Embers, claimed in the lobby | **Deepstones**, claimed at Topside Camp | Same claim loop, our own currency. |
| Classes | Lumberjack, Cook, Medic at 150 / 750 / 1500 | **Prospector, Delver, Lamplighter** at the same 150 / 750 / 1500 ladder (section 14.3) | Same price ladder, our own roles tied to our own systems. |
| Lobby | Party pads 1–5, 20 s countdown, leaderboards, Free Revive, badges | The same structure as **Topside Camp** (section 14) | The reference gets players into a run in 20 s and gives a reason to come back. |

---

## 3. Core loop

Four nested loops. Each outer loop raises the stakes of the inner one.

| Loop | Length | The player is asking | Ends with |
|---|---|---|---|
| **Crank** | 5–30 s | "Can I dodge that rock and scoop that glowstone?" | Glowstone, loot, a dodge, a crewmate saved |
| **Day** | 7–8 min | "Do we make camp before Lights Out, with enough glowstone?" | Surviving the Dark at the Beacon |
| **Zone** | 9–24 min, longer each zone | "What's down there, and can our rig handle it?" | A Waystation: save, repair, badge |
| **Descent and meta** | Hours to weeks | "Can we reach the Core? Faster? With every note and find?" | Badges, journal, Delve Log, classes, leaderboards, cosmetics |

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
| 0–3 s | Spawn in a sunny quarry at the edge of a forest, beside the old Drill Rig: dark and silent, its lamps empty. Glowing amber rocks stud the quarry walls. Behind the rig, the giant sinkhole. | "0 Miles Down" with the sun badge. |
| 3–5 s | Objective, **one line**: 👊 "Smash glowstone 0/8". A glowing outline on the nearest rock. | No text box, no NPC wall. |
| 5–25 s | Smash: sparks, a glowing chunk pops out and **flies into the rig's core by itself**. One by one the rig's lamps switch on and its treads twitch. | Counter rises. Juice on every hit (animated feedback is worth about +18%, research). |
| 25–30 s | The core is full. The engine roars and every lamp lights. "🛠 Hop on!" with a beam on the rig. Everyone aboard means **launch**. A rig that waits 10 s leaves anyway, with a RIG IS LEAVING timer. | |
| 30–45 s | The crank tutorial **is** the route: "Click to crank". A crank pump appears in your hand; the rig rolls toward the sinkhole lip. Loose glowstone glints just off the path. | MPH gauge appears. |
| 45–60 s | First steering moment: "Crank on the left to turn right!" Steering into a supply crate gives a **Delver's Hook**: "Cast at the rock!" From the moving deck, the first cast bites within 3 s and reels up a Puffball. | First payoff. |
| 60–90 s | **The Drop.** The drill bites into the sinkhole wall and the rig spirals down it on a ledge it carves as it goes. The sky shrinks to a coin of light above, and a cavern full of glowing mushrooms opens below. "1 Mile Down". | **The whole-scene "after", and the thumbnail moment.** |
| 90–120 s | The first cavern is bright with fungus glow. Loose glowstone glows on the route: steer over it to scoop it. "🏕 Drill to camp 1.2 mi". | |
| 120–150 s | The glow starts to fade. "🌙 Reach camp before Lights Out!" The Hollow is **glimpsed** on a ridge, far away, gone in a flash of crystal light. | First tension, no damage. At the first camps it only watches. |
| 150–180 s | Arrive at **Camp Ember** (Mile 2.5). "Safe in the light." Feed glowstone to the Beacon, and the first night bar appears. Cook what you delved at the Cookpot. | The first night lands inside 180 s, like the reference (2:55), but brighter and calmer. |

**Rules:**
- Never dim the screen in the first 30 s.
- Keep the first night short (60–80 s with any glowstone added).
- No shop popup until the first Waystation, and never in the 2 min after any milestone. Run a Resort lost 46% of finishers right after a burst of popups (live).

---

## 5. The route: guided path with crank control

### 5.1 How the route is built
- **The route is planned in advance**, not dug by the players. It is a 3D spline that always trends downward, with a lane width per point (30–120 studs) and a base speed per point. A fixed route protects pacing, session length, atmosphere and the monster's paths, and runs well on phones (judgement).
- **The drill carves the route as the rig moves.** In the short bores, rock crumbles away in front of the bit, so the crew feels like it is cutting its own way down.
- **The route is assembled from modular pieces per zone**: straight bores, spiral ledges, ramps, rock bridges, causeways across lakes, drops (lift shafts, collapses, spiral chutes) and forks. Each server shuffles the pieces between a zone's fixed set pieces from a seed. Zone lengths and set-piece positions never change, so pacing holds and every run still feels different.
- The rig follows the route automatically. **It never needs input to make progress**, so AFK crews aren't stranded (judgement).

### 5.2 The Drill Rig controls: two treads, one per side
Steering keeps the feel of the reference's paddle: **the side you stand on decides the direction.**

| Input | What it does |
|---|---|
| **Click / tap Crank** (anywhere on your half of the deck) | Pumps your side's tread: +speed, and a turn toward the **opposite** side. Left side only turns right; right side only turns left; both sides together go straight and fastest. |
| **Sync bonus** | +15% when cranks on both sides land within 0.4 s of each other. |
| **Hold Crank** | Brakes your side's tread: a sharp turn, or a stop at a ledge. |
| Lateral position | Clamped to the lane. The rig can drift ±45% of the lane width, so the path is guided but steering matters. |
| **Turbo** (crew-shared) | Free from Boost Crystals found on the route. Instant with Robux. |

- **Steering is left and right only.** The route handles going down, so nobody has to steer up or down. Easy in the first minute, simple on a phone.
- **No fixed seats.** Each player gets a crank pump and uses it anywhere on their half of the deck, so 5 players never crowd one spot.
- **Odd crews work.** With 1, 3 or 5 players, the HUD shows which side is weaker and the spare player helps there. A solo player walks across the deck (about 2 s) to switch sides.
- **Visuals:** each player pumps a railway-handcar handle up and down. Each tread's speed shows on the deck, and HUD bars show the turn.
- **Why not one steering wheel:** one driver steers while everyone else watches. Every player should have a job at every moment.

### 5.3 Speeds (MPH, like the reference, so players read them the same)

| State | MPH |
|---|---|
| Idle creep (nobody cranking) | 10–18 |
| Crew cranking | 25–40 |
| Downhill chutes | 45–60 |
| Turbo | +20 for 20 s |

**Distance pacing:** about **1 mile a minute average** including stops. 100 miles is about 100–120 min. The counter reads **Miles Down**, measured along the route.

### 5.4 What's on the route
Steering always has a reason:
- **Loot:** loose glowstone on the route (steer over it to scoop it), supply crates, wrecked rigs of earlier expeditions and Boost Crystals.
- **Hazards** (they cost health and can throw players off; none of them stop the rig):
  - **Gas pockets** (green haze): drive through and the crew coughs and slows. Steer around.
  - **Falling stalactites:** a shadow on the deck 1 s before impact.
  - **Cracks and edges** on ledges: steer away or the rig scrapes and loses health.
  - **Low ceilings:** "DUCK!" Crouch or be knocked off.
- **Forks** (2–3 per zone): a **safe tunnel** (longer, calm) or a **risky tunnel** (a steep chute, a shortcut, a loot cave). Signposted 15 s ahead with a yellow diamond sign; the reference uses these well (recording). Steering toward a tunnel is the vote.
- **Warning signs** before every hazard type: the same yellow diamond pictogram language.

### 5.5 Falling off
- Thrown off: "THROWN OFF!" toast, then run after the rig.
- "DON'T GET LEFT BEHIND!" with a red vignette and a RIG marker with distance.
- Crewmates can fire the **Tow Line** (a free tool) to reel you back aboard. That's co-op.
- More than 220 m behind: "LEFT BEHIND: the winch hauled you back". Respawn on the deck at -10% health. No death loop.

### 5.6 Nothing gets the rig stuck; Push Off shoves players
- **The rig never stops on its own.** No hazard, blockage or jam ever halts it (owner). Hazards cost health and can throw players off; the rig keeps moving.
- **Push Off** (the reference's mechanic; owner): look at another player on the deck and press F to shove them off. **19 R$ per shove**, the reference's price.
  - The pushed player gets "PUSHED OFF!" and runs back or is towed in, the same as being thrown off.
  - Proposed safeguards (judgement): not during the Dark or in the first 3 minutes, a short cooldown per target, and it never sends anyone past the 220 m Left Behind line.
- Never charge to make progress.

---

## 6. The Drill Rig: an open platform you grow

### 6.1 Deck
| Size | Grid | Room for | Gained |
|---|---|---|---|
| Base | 3×4 plates | 5 crew, small cargo | Start |
| Wide | 4×5 | 5 crew, a cookpot and more cargo | First Waystation |
| Long | 5×6 | 5 crew, every station, big cargo | Zone 4 Waystation |

**Always open:** no walls, roofs, cabins or cages.

### 6.2 Rig health
- 100–400 HP depending on how much it has been built up.
- **Repair with glowstone** at any stop: pressing a chunk into a cracked plate fuses it shut with light. On the move, the Patch Kit tool repairs slowly.
- At 0 HP the rig **stalls**: everyone hops off, and the crew must patch it with glowstone from the cavern within 60 s, or the run ends at the last Waystation.

### 6.3 Building it up with glowstone (no shop, no second resource)
The rig grows when the crew **loads glowstone into it** at camps and Waystations: the same "Load glowstone 0/60" counter as the start.

| Build | Glowstone | Effect |
|---|---|---|
| Wide deck | 60 | More room: the First Waystation goal |
| Lantern posts (4 corners) | 40 | **Light radius while moving.** The Hollow won't touch a rig inside its own light. Lanterns burn glowstone. |
| Railings (knee height, still open) | 40 | Less chance of being knocked off by hazards (Push Off still works) |
| Deck cookpot | 30 | Cook while moving (slower than at camp) |
| Long deck | 120 | Room for every station: the Zone 4 goal |

A **deckhand** (an NPC who cranks an empty side) joins from a landing rescue, not from a shop.

---

## 7. Stopping points

The route breaks out into a cavern at every stop. Three kinds of stop on a fixed rhythm. Spacing comes from the reference's average of about 3.2 mi between stops (recording).

| Stop | How often | Length | What's there |
|---|---|---|---|
| **Camp** (night stop) | About every 6 mi: 1 in zone 1, rising to 4 in zones 5–6 | The Dark lasts 60–120 s (shorter with more glowstone in the Beacon) | The Beacon's safe ring, the Cookpot, glowstone veins to mine, 1–2 chests, 1 Field Note. Named: Camp Ember, Glowcap Hollow, Shard Hut… |
| **Landing** (day stop) | Between camps: 1 in zones 1–2, 3 in zones 3–6 | 45–90 s, the crew leaves when ready | Something **unique** each time: a trader NPC, a rescue (a stranded explorer joins as a deckhand), a wreck to loot, a puzzle door, a shrine buff, a rich delving wall (rare finds bite more often), or a **side cave** to explore for notes. |
| **Waystation** (save stop) | Every zone border (10, 20, 35, 55, 77) plus mid-zone in the long zones (45, 66, 88). 8 in total. | No timer | **Saves the expedition.** Free rig repair, a build spot, crew rejoin point, zone badge, "% of explorers" milestone. Safe: no Dark here. |

**Departure:**
- Ready ticks, then "LEAVING IN 30", which skips to 3 s when all are aboard.
- A crewmate still off the rig when it leaves gets the RIG IS LEAVING marker and timer, as in the reference.

**Stay or push:** at a landing with Lights Out more than 60% away, the HUD offers "🏕 Next camp 3.1 mi". The crew decides whether to race for it. The reference crew did exactly this at 8.9 mi (recording).

---

## 8. Lights Out (the underground day/night)

- Zone 1 (the surface) has a real sun.
- Below the sinkhole, light comes from the caverns themselves: fungus, crystals, magma. That **glow cycle** is the day.
  - **Bright:** about 5–6 min.
  - **Dimming:** about 60 s. Orange HUD: "🌙 Reach camp before Lights Out! 1.4 mi".
  - **Lights Out:** the Dark, 60–120 s at a camp.
- Lights Out while still on the route: "He's hunting! Get to camp 0.3 mi" (red). The Hollow starts closing in. The rig is only safe inside its lantern light, and lanterns burn glowstone fast.
- At camp, the **Beacon** sets the night bar speed:
  - Each crew member inside the ring adds speed (the portrait goes green).
  - Each glowstone chunk adds +0.1×, up to 3.0×.
  - The Beacon dims over time: "Beacon's fading! Add glowstone". At zero: "The light's out! He's coming!" and the Hollow enters the ring.
- Lore explanation: the Core breathes. Its light pulses up through the rock and soaks into glowstone; the Hollow lives in the gaps between the pulses and feeds on the dark.

---

## 9. Zones: a ladder that gets longer

**Measured from the reference's route bar** (see [analysis §2.1](research/reference-recording-analysis.md)): the reference has **6 zones of 10, 10, 15, 20, about 22 and about 23 miles**. Real time per zone grows from 9 to 12 to 18 min. We use the same ladder.

Why a growing ladder works (judgement):
- **The first zones are short**, so a new player clears zone 1 in about 9 min and zone 2 inside a first session. That gives early "zone complete" wins and two badges on day one.
- **Later zones are long expeditions** for committed crews. Their length is the challenge.
- **The bar sells it.** Six blocks of growing width tell the player at a glance that the deep part is the big part.

Each zone adds **one rule** (pillar 5). The long zones (3–6) are **split into two sub-biomes**, so 15+ miles never feel like one place. Stops stay about 3 mi apart, so **longer zones mean more stops, not longer gaps**, exactly like the reference (2, then 3, then 5 stops in its zones 1–3, recording).

The zones follow the Earth's real layers loosely: **crust** (zones 1–4), **mantle** (zone 5) and **core** (zone 6).

### 9.1 The ladder

| # | Miles | Length | Target time | Zone and sub-biomes | Look and light | Route | New rule | Stops (camps / landings / saves) |
|---|---|---|---|---|---|---|---|---|
| 1 | 0–10 | **10** | about 9 min | **Sunfall Gorge**: the surface quarry, then the sinkhole | Sunny noon, green forest, red canyon. **The Drop** (spiralling down the sinkhole wall into the first glowing cavern) at about mile 1. | Forest track, then the spiral ledge | The basics: hunger, health, mining, delving, cooking | 1 / 1 / Waystation at 10 |
| 2 | 10–20 | **10** | about 11 min | **Glowshroom Grotto** | Teal and violet bioluminescent mushroom forests, spore "snow", a fungus "sky" | Wide soft-rock bores, mushroom bridges | **Lights Out** begins (the glow cycle) | 2 / 1 / Waystation at 20 |
| 3 | 20–35 | **15** | about 16 min | **Crystal Hollows** (20–28), then **Old Deepmine** (28–35) | Ice blue crystal cathedrals, then warm lamplit mine works, rails and steam pipes | Slippery ice ledges, then old mine shafts and a lift-cage drop | **Cold** (warmth meter) | 2 / 3 / Waystation at 35 |
| 4 | 35–55 | **20** | about 20 min | **Fossil Sea** (35–46), then **Sporewood Shores** (46–55) | A vast underground ocean with a horizon, giant skeletons and a geode "moon". Then a giant red and green mushroom jungle with warm mist. | Long causeways across the sea, then twisting jungle ramps | **Navigation**: the causeways are narrow and the edges crumble, so steering matters most here. The shores add **spores**. | 3 / 3 / Waystations at 45 (mid) and 55 |
| 5 | 55–77 | **22** | about 22 min | **Emberflow** (55–66), then **Obsidian Rifts** (66–77) | Black basalt, magma rivers below the ledges, rising embers. Then glassy black canyons lit orange from below. | Ledges over lava and geysers, then the steepest chutes in the game | **Heat** (a meter that rises away from cool rock; eat the zone's cooling dish) | 4 / 3 / Waystations at 66 (mid) and 77 |
| 6 | 77–100 | **23** | about 24 min + finale | **Heartstone Ruins** (77–90), then **The Core Approach** (90–100) | Ancient gold and stone temples of the people who tended the Core-light. Then rock turning to light, the Core rising like a dawn. | Temple roads and gate puzzles, then a spiral down into the light | **Pulses**: the light comes in beats, so move between them | 4 / 3 / Waystation at 88 (mid), then the Core |

**Totals:**
- **16 night camps, 14 landings, 8 Waystations** (5 zone borders, 3 mid-zone).
- About **102 min** of play plus the finale (judgement), against the reference's projected 2 h.
- The longest stretch between saves is about 12 mi (about 12–14 min), inside one Home session.

**Why the mid-zone Waystations:** zones 4–6 take 20–24 min, longer than the 20 min average session target. A save halfway lets a player stop without losing the zone. The reference has no saves, and half its crew left at about 13 min (recording).

### 9.2 Threats, delving finds and glowstone by zone

| # | Route threat | Camp threat | Delving finds (+1 rare) | Glowstone looks like |
|---|---|---|---|---|
| 1 | Burrow Rats steal glowstone off the deck (comic) | None. The Hollow is glimpsed. | Puffball, Root Tuber, (Golden Truffle) | Amber nuggets in quarry rock |
| 2 | Lantern Eels lunge from glow pools and grab a player (SPAM! QTE) | Spore Puffs pop and blind for 3 s | Glowcap, Lantern Fig, (Moon Morel) | Teal clusters inside mushroom roots |
| 3 | Shardback Beetles drop onto the deck. In the Deepmine half, Rail Rats. | Crystal Bats swarm lanterns. In the Deepmine half, Tunnel Moles burst from the walls. | Frost Truffle, Prism Berry, Miner's Cap, (Iron Morel) | Pale blue veins in ice, then old miners' seams |
| 4 | **The Longneck** (a gentle giant that rocks the causeway if startled). On the shores, Snapjaws. | Bone Crabs. On the shores, Vine Creepers pull players off. | Sea Grape, Fossil Fern, Spore Melon, (Jungle Orchid Fruit) | Green-gold pockets inside fossils |
| 5 | Magma Salamanders, lava splashes | Cinder Imps steal glowstone from the Beacon pile | Ash Potato, Ember Pepper, (Obsidian Fig) | Orange-hot chunks in basalt |
| 6 | Temple Guardians (stone statues that wake) | **The Hollow at full speed** | Sun Grain, (Corelight Peach) | Pure gold light set into temple walls |

Glowstone is always the same item; only where it's found and how it looks change, so each zone feels new without adding a resource.

### 9.3 Route bar (our version of the reference's)
- **6 segments sized 10 / 10 / 15 / 20 / 22 / 23**, with thin dark dividers.
- Passed zones light up in their own colour; zones ahead stay dark.
- The white marker is the rig, linear in miles. A yellow tick marks Mile 100.
- **Small Waystation pips** on the bar at 10, 20, 35, 45, 55, 66, 77 and 88. This is our addition.
- Zone colours: forest green, grotto teal, ice blue, sea blue, ember orange and core gold.
- Horizontal like the reference (1:1). A vertical depth bar is an option (section 20).

**Finale (judgement):**
- At Mile 100 the crew must keep the **Core Beacon** lit for 3 minutes while the Hollow makes its last hunt. Every glowstone chunk the crew saved that run counts.
- Win: the Core flares, the Hollow is burned away and a light rises up the whole route to the surface.
- Reward: the "Corewalker" title, a crew photo board at the surface camp, unlocking **Deep Mode** (harder, new modifiers).

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
| Dimming | Follows along the cavern walls, closer each minute. Pebble clicks. | Get to camp. |
| Lights Out at camp | Circles the Beacon's ring. Reaches in when the Beacon is low. Sweeping **dark beams** (shadow searchlights) cross the ground; a player caught outside the ring is grabbed. | Stay in the light, add glowstone. |
| Lights Out on the route | Climbs after the rig. Strikes when the rig's lantern light drops. | Lanterns lit, crank hard. |

**Grabbed:** a SPAM! QTE (crewmates can shine a lantern to help). A failure means "Taken!" and a respawn at the Beacon with -50% health.

**Aggression grows with depth** (owner, from the reference model):

| Where | What the Hollow does |
|---|---|
| Camps 1–3 (zones 1–2) | **Not aggressive.** It watches from the edge of the light and never grabs. It teaches the rules safely. |
| Zone 3 | First real hunts at camp, slow: easy to outrun into the light. |
| Zones 4–5 | Faster at each camp further down; reaches into a low Beacon. |
| Zone 6 and the finale | Full speed. Hunts every pulse. |

Speed rises a little at every camp (for example +8% per camp from zone 3; tune in playtests).

**Kid-safe:** no gore, no jumpscare sting louder than the ambience mix. The scare comes from scale and silence.

### 10.2 Per-zone threats (see the zones table)
- Each zone has **one route threat** (SPAM! QTE, throwing players off, stealing glowstone) and **one camp threat** (at stops).
- Introduce each with a yellow warning sign plus a Field Note before its first attack.

### 10.3 Set-piece moments (one per zone from zone 2, more in the long zones; no health-bar fights)
| Zone | Moment |
|---|---|
| 2 | The Lantern Eel swarm across a mushroom bridge |
| 3 | A Tunnel Mole bursts through the floor in the Old Deepmine and the rig has to jump the gap |
| 4 | The Longneck rises beside the causeway in the Fossil Sea: steer between its legs. Then a Snapjaw ambush on the Sporewood ramps. |
| 5 | A magma geyser chase, then the Obsidian Rifts run (the fastest stretch in the game) |
| 6 | The Hollow walks the temple wall beside the rig through three pulses |

---

## 11. Survival and activities

### Stats
| Stat | Zones | How it works |
|---|---|---|
| **Hunger** | All | Drains about 1% every 6 s, faster while cranking. 0 means health drains. |
| **Health** | All | Damage from monsters, falls and heat. Regenerates near the Beacon. |
| **Warmth** | 3 | Cold drains near ice and in the Dark. Stay in light or eat the warming dish. |
| **Breath / spores** | 4 (Sporewood Shores) | Spore clouds. The zone's dish clears them. |
| **Heat** | 5 | Overheat. The zone's cooling dish, and shade at stops. |

Only Hunger and Health show on the HUD by default. The zone stat appears only in its zone, so the HUD stays clean (owner rule).

### Glowstone: the one resource
- **Plentiful by design** (owner: in the reference, wood piles up; there were hundreds left over a quarter of the way down). Gathering is fast and generous, and crews should finish most stops with **more than they need**. The pressure comes from time (the stop timer, Lights Out, the Hollow), never from running short.
- **Getting it:**
  - Smash it with fists at first (the opener).
  - A pickaxe from the first camp chest mines 3× faster.
  - Every stop has **many** glowstone veins in its walls; they look different in each zone (section 9.2). A vein never runs dry during a stop, and mined spots regrow in about 20 s.
  - Loose chunks lie all along the route; steering over them scoops them up.
  - Veins are shared by the crew; every player gets their own chunks.
- **Rates** (targets, judgement; tune in playtests):

  | Source | Rate |
  |---|---|
  | Fists | About 1 chunk a second |
  | Pickaxe | 2–3 chunks a second |
  | A 60 s stop, one player with a pickaxe | About 100 chunks |
  | Loose chunks on the route | About 15–25 a mile with light steering |

- **Spending it** goes to three places. Costs are small next to income, so the crew decides **what to do first**, not whether it can afford it:
  1. **Repair the rig** (5–10 chunks a crack, section 6.2).
  2. **Feed the light:** the Beacon at camp (about 20–30 chunks for a fast night) and the rig's lanterns at night (section 8).
  3. **Build up the rig** (30–120 chunks per build, section 6.3).
- **Target:** by Mile 25 a typical player carries a few hundred spare chunks. The bag stack goes to 999, so a big haul shows as a big number.
- **Feel:** chunks glow warmer the more you hold, and the crew's carried glowstone lights up the deck. A rich haul is a good feeling, not a reason to hoard.

### Delving: the food
Delving is our action in the role fishing plays in the reference: **you can do it anywhere**, it's a skill moment, and it feeds a collection.

- **The action:**
  1. **Cast** the Delver's Hook at any rock or earth surface: a cavern wall, the floor, a ledge beside the route, even **from the moving rig's deck**. The weighted hook bites into the stone and the line goes taut.
  2. **Wait** for the tug: "…", then a "!" and the line shakes. Something has grabbed the hook: a root, a tuber, a truffle, a cave fruit.
  3. **Reel** with the Pull: hold to reel; a meter fills while the line strains and glows. **Let go when it glows green** for a perfect catch (a full-size find, sometimes a double). Too early and the line slips (a small piece); too late and it snaps (nothing, try again).
- **Anywhere, always:** there are no patches or special spots. Every surface in every zone can be delved, so a player can feed themselves on the move, at a stop, or while waiting out the Dark inside the Beacon's ring.
- **Plentiful by design** (owner: in the reference you can catch a fish about every 10 s). Bites come in 2–6 s and a reel takes 2–4 s, so **about one find every 10 s**.
- **Richer spots:** glowing cracks and old roots bite faster and give rare finds more often. Optional, never required.
- **Junk and surprises:** now and then the hook brings up a glowstone chunk, an old miner's boot (comic) or a sealed Field Note.
- **Tools:** the Delver's Hook (Bone, then Iron, then Crystal). Better hooks bite faster, widen the green zone and raise the chance of rare finds.
- **Collection:** each zone has 3–4 finds plus 1 rare. The **Delve Log** collects all of them (about 25), with a sketch and one line each.
- **Cooking** at the camp **Cookpot**: pick a recipe, see ingredients, **hold COOK** (the reference's hold-to-fill UI). Recipes unlock from Field Notes and traders.
- **Eating and dropping:**
  - Holding food: "Click Eat · Q Drop".
  - Dropped items stay on the deck or ground until the rig leaves that stop.
  - A downed player drops half their bag.
  - **Sharing food with a crewmate is a featured co-op act.** It counts toward the Camp Chef and crew badges.
- **Looting:** supply crates on the route (steer into them) and chests at stops, wrecked rigs of earlier expeditions. Every chest shows a toast with the item and one line on what it's for.

---

## 12. Items

### 12.1 Tools
| Item | Where it comes from | Use |
|---|---|---|
| Fists | Start | Smash glowstone, slow |
| Crank Pump (Wooden, then Iron, then Brass) | Start / Waystation rewards | Tread power. Better pumps add +5/+10% |
| Pickaxe (Stone, then Iron, then Crystal) | First camp chest, then chests | Mine glowstone 3× and 5× faster |
| Delver's Hook (Bone, then Iron, then Crystal) | First route crate, then chests and rescues | Delving for food anywhere: faster bites, wider green zone, rarer finds |
| Tow Line | Start (free) | Reel a thrown-off crewmate back aboard |
| Hand Lantern | Zone 2 | Personal light radius in the Dark (burns glowstone) |
| Patch Kit | Zone 1 Waystation | Repair the rig on the move (slow) |
| Revive Flare | Free Revive board / rare chests | Come back on the spot when downed |

### 12.2 Resources and currency
- **Glowstone** is the only resource. It builds, repairs and lights.
- **Delving** is the only food source.
- **Deepstones** are the meta currency, kept between runs and claimed and spent at Topside Camp. There is no run currency and no in-run shop.

### 12.3 Food (all from delving)
| Food | Made from | Fills | Bonus |
|---|---|---|---|
| Raw find (any) | Delving | 10% | Small chance of a "Queasy" slowdown |
| Roasted Cap | 1 find + Cookpot | 30% | — |
| Cave Stew | 3 finds + Cookpot | 60% | Slower hunger drain for 3 min |
| Lantern Fig Tart | 2 Lantern Figs | 25% | +light radius for 60 s (zone 2) |
| Frost Truffle Soup | 2 Frost Truffles | 50% | **Warmth** (zone 3) |
| Spore Melon Slices | 1 Spore Melon | 30% | **Spore immunity** for 2 min (zone 4) |
| Ash Potato Mash | 2 Ash Potatoes | 40% | **Cools Heat** (zone 5) |
| Corelight Feast | Corelight Peach + 2 rare finds | 100% | The whole crew, all buffs |

### 12.4 Camp and world props
- The Beacon and its safe ring, the Cookpot, lantern poles, glowing delving cracks.
- Supply chests, wrecked rigs, mine carts and lift cages of earlier expeditions.
- Field Note boards, waystones (zone markers), trader tents.

---

## 13. Atmosphere: how we make it

The owner's view, backed by the knowledge base: atmosphere drives early staying more than mechanics, **as long as it never blocks or confuses**. Concrete rules:

1. **Light is the language.**
   - Warm (2,700K amber) means safe: the Beacon, lanterns, glowstone, Waystations.
   - Cold (teal, violet, blue) means wonder and danger.
   - Red means "act now".
   - Every zone has one key light colour and one accent (in the zones table).
2. **Start bright.**
   - The surface is sunny at noon, and the first cavern glows teal.
   - Average frame brightness target **at least 140 for the first 3 minutes**. Run a Resort's 94 against rivals at 169–172 hurt it (live).
3. **Scale, then squeeze.**
   - Alternate huge open caverns with short bores.
   - Put a **reveal at every breakout**: a giant skeleton, a waterfall, a city of lamps, a crystal cathedral.
   - Never a long dark tunnel (the "not enclosed" rule).
4. **Sell the depth.**
   - The route always heads down: spirals, drops and lift shafts every few miles.
   - Looking up shows how far you've come: the light of the last cavern far above.
   - Roblox Atmosphere density 0.3–0.45 per zone, tinted by zone. Hide far geometry; let set pieces fade in, never pop in.
   - Light shafts from cracks above (beams and volumetric parts).
5. **Earlier explorers were here.**
   - Wrecked rigs, abandoned camps, skeletons with a dead lantern, Field Notes signed by five expeditions (the Gorge Settlers, the Steam Drill Crew, the Miners' Guild, the Survey Scientists, the Last Expedition).
   - The "% of explorers have made it this far" line. One of the reference's best atmosphere tricks, and nearly free.
6. **Monster cadence: seen, heard, hunted.**
   - Glimpse in zone 1, clicks in zone 2, the first real hunt in zone 3 (section 10.1).
   - **Silence before a scare:** duck the ambience for 1–2 s.
7. **Sound** (ambience, not music; music had no measured playtime effect, research):
   - A drill-and-tread loop whose intensity follows speed, crunching louder in bores.
   - Positional drips, distant rumbles, the Hollow's pebble clicks.
   - The Beacon's warm hum; glowstone chimes softly when picked up.
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

   Plus rock dust from the drill bit in every bore. Capped for phones.
9. **The world reacts:**
   - Bats scatter when lanterns pass.
   - Glowcaps brighten when touched.
   - Crystals ring when the drill passes.
   - Glowstone veins pulse when a crewmate with a pickaxe walks near.
   - Something reacts to the crew within seconds of anything they do.
10. **Stylised, calm palette:** chunky low-poly rock, readable silhouettes, no noisy textures. A flat-shaded style reads well on phones.

**Lighting tech per zone (judgement):**
- `Lighting.Technology = Future`. ClockTime fixed underground.
- Per-zone `Atmosphere`, `ColorCorrection` (saturation +0.1, tint), `Bloom` (0.6–1.2) and `SunRays` only on the surface.
- Tween all of them over 4–6 s at zone borders.
- Phone fallback: fewer PointLights, emissive Neon parts instead.

---

## 14. The surface camp (lobby), meta progression and retention

The lobby copies the **structure** of the reference's lobby (see the [lobby analysis](research/reference-lobby-analysis.md)) with our own content.

### 14.1 Topside Camp
The lobby is **Topside Camp**, a sunny quarry clearing at the mouth of the dig. The sinkhole is in view, so the first thing a player sees is the hole they're about to go down.

- **Launch bays** (the reference's party pads, recording):
  - Step into a bay to create a party: pick **1–5 players (4 selected by default)** and tick **Friends Only** if you want.
  - Empty bays read "PLAY / Step in to make a party". Taken bays glow green and read "N/M PLAYERS / Starting in Xs" with the leader's name. Yours has a yellow outline.
  - The **countdown starts at 20 s and never resets** when people join. It **drops to 5 s when the party is full**. A party that isn't full starts anyway; solo is allowed.
  - "STARTING! Teleporting…", then the party goes to its own reserved run server.
- **The big PLAY button** (always on screen) puts you in the fullest open public party. If there isn't one, it starts a 1-player party with the 20 s timer.
- **New players** spawn facing the bays with a bouncing arrow on PLAY and no panels open, so a first-timer is on the way down well inside 60 s (bounce research, Run a Resort KB).
- **Continue: Mile X** on the bays and PLAY button when the player has a Waystation save.
- **Leaderboards** with **Global / Friends** tabs and a pinned "You" row: **Fastest Descent**, **Deepstones Earned** and **Deepest Total**. An empty Friends tab says "Play with friends to fill this board!" with an **Invite Friends** button.
- **Free Revive board:** a free Revive Flare for joining the group. The reference also rewards liking the game; we only add that after checking the current Roblox rules on incentivised votes.
- **Classes tent** with a try-on spot that shows the outfit on your own avatar.
- **The player list** shows lifetime Miles Down.
- **Your Glow Mole follows you** in camp and in the run.
- **Server sizes:** about 24 players per camp server (the reference showed 14+), and one reserved server per party for the run. Friends starting together on a reserved server count as intentional co-play, an "Important" Home signal (Run a Resort KB, official).

### 14.2 Rewards are claimed at camp
- The **Journal**, **Delve Log** and **Badges** pay **Deepstones**, claimed at camp with a big "+N DEEPSTONES" pop-up and red notification counts on the HUD icons. In the reference, all of the player's currency after 2 runs came from claims like these (recording).
- Rewards: Field Note +10, Journal Page +25, new Delve Log entry +5 (structure from the reference, recording; the Delve Log is ours).
- Badge rewards follow the reference's curve: 25 / 25 / 75 / 200 for distance badges, 200 for challenge badges (recording).
- Every return to camp therefore has a reward moment right beside the Classes tent (judgement).

### 14.3 Classes (bought with Deepstones or Robux; one active per run)

Same price ladder as the reference (recording), our own roles built on our own systems:

| Class | Deepstones | Robux | What you get |
|---|---|---|---|
| **Prospector** | 150 | 49 | Starts with an Iron Pickaxe, +1 glowstone per vein |
| **Delver** | 750 | 149 | Starts with an Iron Hook, bites come 20% faster and the green zone is wider, food fills 15% more |
| **Lamplighter** | 1500 | 299 | Starts with a Hand Lantern; the Beacon and rig lanterns burn glowstone 15% slower |

- Perks stay small and help the crew.
- Later classes (content drops): Medic (revives faster), Engineer (repairs faster), Scout (sees hazards through fog).

### 14.4 Collection, badges and stats
- **Journal:** 6 zone tabs. Each zone has **6 Field Notes** (pencil sketches with one line of story, signed by an expedition) and **2 Journal Pages**. **49 in all** (36 notes, 13 pages; the extra page is at the Core). Locked items show as grey "?" cards.
- **Delve Log:** a second Journal tab with every delving find, about 25, found or "?".
- **Badges (13), in three groups:**

  | Group | Badges |
  |---|---|
  | **Distance** | Breaking Ground (start), Ten Miles Down, Quarter Way (25), Halfway There (50), Almost There (75), The Core (100) |
  | **Challenges** | Untouched (no knock-downs), Lone Driller (the Core alone), Full Journal (every page) |
  | **Crew** | Bring a Friend (invite a friend), Lifesaver (revive 5 crewmates), Second Wind (come back with a Revive Flare), Camp Chef (cook 50 meals) |

- **Your Stats panel:** your avatar, BEST DEPTH with its zone tag and "Only X% of explorers got this far", then sections: **The Descent** (total miles, games played, time played, fastest descent, camps reached, times at the Core, Core wins), **Survival** (nights survived, times knocked down, crew revived), **Underground** (glowstone mined, finds delved, perfect catches, meals cooked, rig repairs, threats chased off, players pushed off) and **Your Account** (notes found, journal pages, Delve Log entries, friends brought, Deepstones earned, Robux spent).
- **Favorite prompt:** the Roblox "add to favorites?" prompt the first time a player returns to camp from a run, never on the first join (the reference shows it after a return, recording).

### 14.5 Retention hooks by horizon (from the knowledge base)

| Horizon | Hook |
|---|---|
| Session | Next stop always 1–3 min away. A Waystation every 9–14 min (zone borders, plus mid-zone saves in the long zones). **End each session mid-leg**: the HUD says "Next: Waystation 3 · Crystal Hollows". |
| D1 | **The expedition is saved** at the Waystation and the camp shows "Continue: Mile 35". Rewards waiting to be claimed at camp. Opt-in notification: "Your crew's rig is waiting at Mile 35." |
| D2–7 | The class ladder (150 → 750 → 1500 Deepstones), the Journal, the Delve Log and badges, Daily Expedition Orders (3 small tasks, such as "delve 5 perfect Glowcaps"), a streak with a grace day. |
| D8–28 | A content drop every 2–4 weeks (new finds, notes, a fork, a class). Weekly events: **Quake Night** (the route reshuffles, new forks), **Glow Bloom** (double rare finds), **Hollow Moon** (harder nights, double Deepstones). Deep Mode after the first finale. |
| Social | Co-op is an "Important" Home signal (research). Invite button, Friends leaderboards, Friends Only parties on reserved servers, crew badges. |

### 14.6 Saves
- Waystations save: mile, the rig and what was built on it, and inventory, **for the party leader and each member**.
- Anyone can start a new party from their own furthest Waystation.
- Run a Resort lesson: never hand out a fresh save on a failed read; retry, then ask the player to rejoin.

---

## 15. Monetisation

Principles (owner rules and the knowledge base):
- **Free beats paid.** No Robux item out-earns the best free item.
- **No paid randomness** without shown odds, and hidden where PolicyService restricts it.
- **Skips pay what they advertise.**
- No popups in the first 3 minutes or in the 2 min after a milestone.
- Contextual prompts sit next to the problem they solve, like the reference's Turbo pill and Push Off prompt.

| Product | Type | Price (R$) | Where it shows | Notes |
|---|---|---|---|---|
| **Starter Pack**: a **Glow Mole** pet (name and colours; lights a small radius around you and fetches dropped items), a **Brass Crank** cosmetic, a head-start kit (Iron Pickaxe, 100 glowstone, 3 Cave Stews) | Gamepass | **49** | HUD button always. One popup at the **first Waystation** (Mile 10, about 9–10 min). | The reference's offer shape (popup about 15 min, bought at about 25 min, recording). Best seller in Run a Resort (live). |
| **Turbo** (crew-wide +20 MPH, 20 s) | Dev product | **25** | Pill under the speedometer (T) | Free Boost Crystals also exist. |
| **Push Off** (shove a player off the rig) | Dev product | **19** | World prompt on the target player (F) | The reference's price and placement (recording). Safeguards in 5.6. |
| **Revive** (self, on the spot) | Dev product | **19** | Down screen | 1 free Revive Flare per day through the group. |
| **Classes** | Dev product | 49 / 149 / 299 | Classes tent | Also earnable with Deepstones (the reference's model, recording). |
| **Rig skins** (Pirate Drill, Steam Mole, Crystal Beetle, Bathtub, Pizza…) | Gamepass / shop | 99–249 | Waystation and camp | Cosmetic only, still an open deck. |
| **Crank skins, Beacon skins, trails, pets** | Shop | 49–199 | Camp | Pets follow you and fetch dropped items (QoL). |
| **Big Rig** (the Wide deck from the start) | Gamepass | 199 | Camp | Convenience. The deck grows anyway. |
| **Expedition Pass** (season) | Pass | 299 | Camp | Deterministic free plus premium cosmetic tracks. No crates. |
| **Private crew server** | VIP server | 100/month | Roblox | Co-play signal. |

**Projected first purchase window (judgement):**
- First Waystation (Mile 10, about 9–10 min) and the post-first-night high (about 3–5 min, button only, no popup).
- **Target payer conversion 1.5–3%** of new players. The GameAnalytics median is 3.8% for big games (research); Run a Resort ran under 1% (live).

---

## 16. UI: 1:1 with the reference's layout, our content

**Mockup:** [ui/ui-mockup.html](ui/ui-mockup.html). Positions and sizes are measured from the 2560×1440 recordings, and every screen is a 16:9 frame. It shows the Drill Rig HUD and the Topside Camp screens (Create Party, Classes).

| Reference | Ours | Change |
|---|---|---|
| "0.2 Miles" + sun badge | "0.2 Miles Down" + glow badge (sun on the surface, a glowing crystal underground, a moon in the Dark) | Wording only |
| "Reach camp before dark!" | "Reach camp before Lights Out!" | |
| "He's hunting! Get to camp" | Same | |
| Zone-segmented route bar | Same: **6 segments sized 10/10/15/20/22/23 mi**, passed zones lit in their own colour, white rig marker, yellow Mile 100 tick. We add Waystation pips. | Pips added |
| Hunger and Health bars | Same, plus a zone stat bar only when relevant (Warmth, Heat) | |
| Speedometer + Turbo 25 R$ | Same, plus two small tread-power bars | Tread bars |
| Starter Pack pet button 49 R$ | Same position, our Glow Mole | |
| Hotbar + Bag, "Click · Paddle" hint | Same, "Click · Crank" | |
| Night bar, crew portraits, "Add wood to go faster" | Same. "Add glowstone to end the Dark". | |
| LEAVING IN / ALL ABOARD / WAITING FOR CREW | Same | |
| RAFT IS LEAVING / DON'T GET LEFT BEHIND / SWEPT AWAY | RIG IS LEAVING / DON'T GET LEFT BEHIND / LEFT BEHIND | |
| Push Off world prompt (F + 19 R$) on a player | Same, plus a "PUSHED OFF!" toast for the target | Toast added |
| Cookfire panel (recipe cards, detail, hold COOK) | Same layout as the **Cookpot**, with recipes made from delving finds | Our recipes |
| Starter Pack, Journal note, "Meet your puppy", SPAM! | Same layouts; our Glow Mole and content | |
| Lobby: Journal / Invite / Badges + currency + STATS + PLAY, party pads, Create Party (1–5, Friends Only), Classes | Same, with Deepstones, our classes and "Continue Mile X" | Continue added |

**Implementation notes:**
- Build as ScreenGuis with `UIScale` from the 2560×1440 reference. Positions use Scale, not Offset.
- Font: the reference's exact font, Comic Neue Angular Bold (`Enum.Font.Cartoon`, FontFace `rbxasset://fonts/families/ComicNeueAngular.json`), in Bold and Bold Italic. A copy is in `docs/ui/fonts/`. Use `UIStroke` 2.5–3 px black on HUD text, no stroke inside panels.
- Panels: brown wood boards with dark inner panels, a white title outside the top-left and a red X close button (the reference's panel style, recording).
- Icons match the reference's style: they come from the owner's icon pack (the one the reference uses: thick black outline, flat colours, a soft lower tone), and our own subjects are drawn in that style in `art/icons/`. `tools/build_icons.py` builds them into `assets/ui/icons/`, and Starport uploads them (see [asset-pipeline.md](asset-pipeline.md)). The older SVG drafts in `docs/ui/icons/` are superseded.
- Phone: test on a real phone. Caps: popups at 50% of screen height, safe area respected, the hotbar never covers the joystick, and the CRANK button matches the Roblox jump button.

---

## 17. Metrics and targets

| Metric | Target | Basis |
|---|---|---|
| Time to control after load | **≤ 10 s** (reference about 65 s from Play) | Bounce research |
| Time from first join to run start | **≤ 30 s** (20 s bay countdown at most) | The reference's 20 s countdown (recording) |
| Home bounce under 60 s | **≤ 15%** | Benchmark median about 14–18% (research) |
| Home bounce 61–180 s | **≤ 18%** | PRISON RP median 20.4% (research) |
| Home PTR | ≥ 3% | Band about 2.0–4.7% (research) |
| Avg playtime per Home player | **≥ 20 min** | Owner target. D1 rises until about 19–24 min sessions (research). |
| D1 | ≥ 10% (median of big games), stretch 15% | GameAnalytics 2026 (research) |
| D7 | ≥ 2.5% | |
| Reach first camp | ≥ 85% of new players | judgement |
| Reach first Waystation (Mile 10) | ≥ 70% | The reference shows 76% reaching Mile 10 (recording) |
| Parties with 2+ players | ≥ 50% | judgement; co-play signal |

**Telemetry from day one** (Run a Resort's counters that paid off):
- Per-version first-session counters: under 60 s, under 180 s, reached camp 1, reached Waystation 1.
- Time in camp before the first run, and the party size chosen.
- Mile reached and quit mile.
- Glowstone carried at each camp (target: a growing surplus; if crews run short, raise the rates) and delving finds per minute (target about 6).
- Push Off uses: who pushed whom, and whether the target quit soon after (a griefing check).
- Quit reason context: open window, in the Dark or not, thrown off or not.
- Frame rate, crew size at quit.
- The **% of explorers per mile**: the same data drives the in-game toast and the Stats panel.

---

## 18. Thumbnail and promise
- **Same verb, bigger scale.** A crew on an open Drill Rig, cranks pumping, lamps blazing with glowstone, spiralling down the sinkhole wall into a glowing cavern, the Hollow's silhouette faint on the far wall. Players do all of it in the first 90 s.
- Tile 2: the Beacon at night, the crew safe in its warm light and the Hollow's eyes outside.
- Title tile text, if any: "100 MILES DOWN".
- Upload a plain gameplay video of the first 90 s.

---

## 19. Build plan (proposal)

| Milestone | Scope | Outcome |
|---|---|---|
| **M0: Greybox descent** (1 week) | A downward route spline built from about 6 piece types, the rig with two treads, crank pumps and side-based steering, open-deck physics, thrown off and Tow Line, one fork, Push Off, HUD (distance, speed, tread bars) | The core verb feels good on a phone |
| **M1: Zone 1 vertical slice** (2 weeks) | First 3 minutes as scripted. Smashing glowstone and powering up the rig, The Drop, mining, delving and the reel, cooking, Camp Ember, Lights Out and the Beacon, the Hollow glimpse, 1 Landing, Waystation 1 save. Topside Camp with launch bays, PLAY, Journal and Badges. Full UI set. Telemetry. | **Soft launch.** Measure bounce and first-camp reach. |
| **M2: Zone 2** (2 weeks) | Glowshroom Grotto, Lantern Eels QTE, forks, Field Notes, Delve Log, classes, Starter Pack, Turbo | First monetisation read |
| M3: Zones 3–4 (15 and 20 mi) | Warmth, side caves, causeways, spores, rig builds, the Hollow's speed ramp, mid-zone saves | D1/D7 read |
| M4: Zones 5–6 (22 and 23 mi) + Core finale | The full descent | Full launch |

Engineering follows the OneWayToSpace setup: Rojo, `src/client`, `src/server`, `src/shared`. The route pieces and zone config are shared modules. The camp and the run are two places in one universe: a teleport inside the universe likely doesn't count as a bounce (creator anecdote, Run a Resort KB).

**M0 status (Nov 20, 2026): a playable greybox, in both places.**

Done:
- The Game place runs zone 1 (10 mi), from a seeded route made of Start, Straight, Bend, S, Chute and Cavern pieces, plus two set pieces: The Drop spiral at about mile 1, and a fork at mile 5 (left for glowstone, right for calm).
- The rig carries the crew on an open deck and never stops on its own. Crank Pump steering works as designed: your side's tread pushes the rig the other way, with the +15% sync bonus.
- Players can scoop glowstone, hit pillars (which cost health and can throw players off), and scrape the walls.
- Off the rig: a THROWN OFF toast, the "don't get left behind" warning with catch-up speed, the Tow Line, and the Left Behind winch.
- Push Off works free in Studio, with the safeguards (no shoves in the first minutes, a cooldown per target).
- The HUD has miles, the route bar, MPH, the tread bars, rig health and glowstone.
- The lobby has one launch bay (4 players, a 20 s countdown that drops to 5 s when full) that teleports the party into a reserved Game server.

Not in M0 yet:
- Hold-to-brake.
- Turbo.
- Rig stall at 0 HP.
- The Push Off developer product (it needs a product id).
- Real art.

**Assets and publishing go through Starport** (the uploader from the My Pet Restaurant repo). UI images, icons, sounds, animations and models are uploaded with it, and it writes their ids into our content modules. It also builds both places with Rojo and publishes them. See [asset-pipeline.md](asset-pipeline.md).

---

## 20. Decisions for the owner

**Decided:**
- The Drill Rig with two-tread crank steering.
- Crews of 1–5, default 4.
- Growing zones of 10/10/15/20/22/23 mi.
- A planned route (not player-dug).
- The reference's UI and core structure, with our own content.
- Nothing gets the rig stuck.
- Push Off shoves players (19 R$).
- The Hollow is calm at the first camps and gets faster with depth.
- Our own content: Glowstone, Delving, the Glow Mole, Deepstones, and Prospector / Delver / Lamplighter (approved Nov 19, 2026).

- "Not enclosed" means both the open rig deck and the open caverns.
- The monster is **The Hollow**.
- Progress saves at each Waystation, so a descent can span several sessions.
- The route bar is horizontal, like the reference.
- The free Revive is for joining the group only. (In the reference, the like step just asks the player to rejoin.)
- M0 prototyping has started (Nov 19, 2026), in the owner's two places, in universe 10777965719:
  - **Lobby** "100 Miles to Earth's Core": place 76938279277561. The Topside Camp, where players start.
  - **Game**: place 138151622310222. The descent, which players teleport into as a reserved server per party.

**Still open:**
1. **Push Off safeguards:** M0 uses the proposed ones: no shoves during the Dark or the first 3 minutes, and a short cooldown per target.
