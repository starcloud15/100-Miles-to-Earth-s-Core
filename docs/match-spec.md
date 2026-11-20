# Match spec: the reference, frame by frame, mapped to our descent

Nov 20, 2026. **Source:** the 1-per-second analysis of the full recording (48:13, 2,893 frames) in [research/frames/](research/frames/), segments 1–6. Each number is measured unless marked (inferred). This file replaces the earlier 5-second sampling wherever they disagree.

**Rule:** we copy the reference's UI, pacing and core structure 1:1, with our own content (owner). Each row says what the reference does, then what we do.

---

## 1. HUD while riding (centre x, y as % of screen; size as % of screen)

| Element | Reference | Ours |
|---|---|---|
| **Distance** | "5.3 Miles", (46%, 10.8%), about 19.5% × 6.6%. Heavy **italic** white with a thick black outline. Digits roll like an odometer every 0.1 mi; each whole mile turns **yellow for about 0.75 s**. "1 Mile" is singular. Off the raft or at a stop it **shrinks to about 10% wide at y 6% and goes grey and semi-transparent**. | Same, "Miles" counted down the route. |
| **Day badge** | (61%, 10.6%), about 5.5% wide. Black outer ring, a coloured progress arc that empties clockwise, and an inner disc. Day is light blue with a sun; late day is orange with a sun; night is navy with a white moon and a blue ring. Shrinks with the distance. | Same badge. Underground, "day" is the time until **Lights Out** (GDD §8): sun = glow, moon = dark. |
| **Objective line** | (50.5%, 18.6%), about 35% × 3.8%. Icon, then an italic label, then a white value. The label is white for tasks ("Punch trees for wood 0/12"); orange for "Reach camp before dark! 2.4 mi", which turns **red at about 0.2 mi**; red for "He's hunting! Get to camp". **Absent while riding after the first camp** (only the distance and route bar show). | Same states: "Mine glowstone 0/12", "Reach camp before Lights Out!", "He's hunting!". |
| **Route bar** | (50%, 23%) with an objective, (50%, 18.2%) without. 22.4% × 2.3%, black frame, 6 segments sized 10/10/15/20/22/23. Passed part brighter; a **white vertical marker** for you; a **yellow tick** at Mile 100. Hidden at stops. | Same, our zone colours. |
| **Starter Pack** | Circle at (4.4%, 32.4%), 4.5% wide, pet portrait, magenta Robux pill "49" top left. | Glow Mole portrait, "49". |
| **Hunger** | Label at (2.6%, 43.4%); bar at (6.3%, 46%), 11.7% × 2.7%. Orange fill, dark track, thick black frame. Drains right to left at **about 7.4% a minute** (about 13.5 min full to empty). Food: Cooked Fish +44–45%; Fish Stew (2 wood + 3 fish) about +40%. | Same. Food comes from Delving (GDD §11). |
| **Health** | Bar at (6.3%, 53.9%), green. **Regenerates about 1% a second.** Lost to attacks (a monster grab −47%; a gator drag −38%). | Same. **No rig health bar** (owner). |
| **Speedometer** | (92.5%, 43%), circle about 9.3% wide. Dark disc, about 40 ticks lighting **green from the lower left, clockwise**, yellow near 55–60. Big white italic number 0–60 and "MPH". **Shown only while aboard and moving.** | Same. |
| **Turbo** | (92.5%, 50%), about 8% × 4%: fireball, orange "TURBO" pill, a white "T" key cap, magenta Robux "25". | Same. |
| **Hotbar** | Roblox default backpack at the bottom centre: slot numbers, icons, stack counts, "Bag". | Same: Crank Pump, Delver's Hook, food, Bag. |
| **Action hint** | (95.5%, 96.2%): a white "Click" key cap and a bold verb (Punch, Paddle, Fish, Reel, Eat). Holding food adds "G Drop". | "Click Crank", "Click Mine", "Click Cast", "Click Reel", "Click Eat". |
| **Push Off** | A world prompt over every other crewmate: "F · Push Off · ◎19". | Same. |

## 2. Departure, falling off, stops

| Moment | Reference | Ours |
|---|---|---|
| **Boarding** | "BOARD THE RAFT!" at (50%, 10%), with crew portraits (green with a tick when aboard) and "0/4 aboard · **3 more** to leave". Leaving needs **3 of 4**. | "BOARD THE RIG!" |
| **Countdown** | "LEAVING IN 30" (yellow number, red at 1) once enough are aboard; "**ALL ABOARD!**" in green, "Leaving in 3", once all are. 15 s at the spawn. | Same. |
| **Left on the bank** | "RAFT IS LEAVING" in orange with a draining bar and "Get back to the raft". A **RAFT world marker** (yellow tag, distance, red seconds box) clamps to the screen edge. | "RIG IS LEAVING", "RIG" marker. |
| **Fell off** | The HUD shrinks: the distance goes small and grey, and the speedometer and route bar hide. The player **swims**. At **about 60 m** from the raft, "**DON'T GET LEFT BEHIND!**" appears in red, with a red bar (50%, 16.9%, 25% × 3.2%) filling left to right and a red radial vignette. **Fill ≈ (distance − 60 m) / 630 m.** Past 80% the line reads "The river will take you!". When full, a 3 s **SWEPT AWAY** screen, then a wave wipe. | Same bar and thresholds (studs: 215 / 2250). When full: a 3 s "**PULLED BACK**" screen, then **back on the rig** (owner: "tps you back"). |
| **Catching up** | Swimming is slower than the raft in calm water, but the current carries the swimmer almost at raft speed in rapids. The crew stops paddling (about 5 MPH) to let them catch up. Most falls were recovered in 1–8 s. | **Sliding:** off the rig you slide and skid down the loose slope at about the rig's idle-plus speed, faster than running. The crew stops cranking to let you catch up. Same co-op beat. |
| **Stops** | Named, every **2.5–3.5 mi**. A small label grows into the big stop name ("Fishing Camp"), then "Repair your raft with wood!". The raft docks itself and **stops dead from full speed**. **Camps** hold the night (the night bar plus fire); **landings** are short daytime stops. | Named chambers dug off the route, the same spacing and flow. |
| **Harvesting** | **Only at stops**: punch the cube trees around the clearing (2–3 logs a hit, "+12" per tree), even at night. **Nothing is ever picked up from the river.** Fishing works from the bank and from the moving raft. | **Glowstone veins and crystal clusters in the chamber walls, only at stops.** Delving works anywhere, including the moving rig. |
| **Night** | The night bar (moon, then bar, then sun) fills at 0.56%/s at 1× (about 3 min). With the **whole crew** in the fire ring it speeds up: +0.1× per log, capped at 2.9×, decaying about 0.1× every 3 s. The fire has a fuel panel (8 segments, a timer). "Fire's out! He's coming." | Same with the Beacon and glowstone. |
| **Rig damage** | No health bar. Hits break planks off the model. At the next stop the missing ones show as **white ghost planks** with a "Repair Raft 0/N · E" prompt; N grows with damage (0/2 to 0/15). | Same with rig pieces (the `Break*` meshes): they break off, then show as ghosts with "Repair Rig 0/N". |

## 3. Speed, pace and camera

- **Displayed MPH is not real speed.** Game miles per minute ≈ **MPH ÷ 12.8**.
- **Typical MPH:** 18–29 on calm stretches with paddling; 30–45 on faster water; 50–60 in rapids and on drops (the gauge maxes at 60; one chute read 172). It falls to 0–9 against rocks.
- **Pace:** about 1.8 mi/min while moving; about 1 mi/min including stops.
- **Ours:** the rig moves at **real stud speeds that feel fast**, and the gauge and mile count follow the reference's ratios:

  | Rig state | Studs/s | Gauge |
  |---|---|---|
  | Idle | 17 | 10 MPH |
  | Cranking | 45 | 27 MPH |
  | Chutes | 75–100 | 45–60 MPH |

  Displayed MPH = studs/s × 0.6. **1 game mile = 1,290 studs.**
- **Camera:** Roblox's default third-person camera, behind and above at a 40–50° pitch, with the raft filling 25–35% of the screen width (about 12–16 studs away).
- **Effects:**
  - lens droplets in rapids;
  - a white spray wash on drops;
  - blur and shake when grabbed;
  - a red vignette when left behind.
  
  **Ours adds:** constant low drill rumble, stronger shake on drops and when breaking rock, and debris.

## 4. The route

- **Reference:** a gentle, frequent bend every **10–20 s**, at 4–6 raft-widths wide.
  - Cliff walls are hugged at times; wide pools open at others.
  - Rapids and drops come about every 1–2 min, each signposted 11–30 s ahead with a **yellow diamond sign**.
  - Rocks and sandbars sit in the water.
- **Ours:**
  - A **steep downhill dig**: a −15 to −25% slope, with chutes of −40% or more.
  - Bends every 10–20 s.
  - The same diamond signs before drops, rock bands and creature attacks.
  - **Open at the surface, enclosed underground** (owner). The tunnel is carved live by the drill in voxel terrain (prototype tested: carving costs about 0 ms).

## 5. Rig size

- **Reference:** the raft is about 10–12 studs square (about 2 character heights). Four players fill it.
- **Ours:** the rig model is 14 × 18 studs (`tools/blender/drill_rig.py`).
