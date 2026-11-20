# Proposal: the map's look, atmosphere and the lobby backdrop

Nov 20, 2026. **Status: approved by the owner on Nov 20, 2026, with lobby backdrop A.** Built from the frame analysis ([research/frames/](research/frames/)): what makes the reference look rich, applied to a descent.

## Why ours looks plain now
- Flat grey blocks in a straight, wide trench, with one colour and no fog or grading.
- Nothing in the distance, nothing moving, no light sources.
- Walls the same height everywhere and no props.

## What makes the reference look rich (measured)
The reference's shapes are very simple and low-poly. The richness comes from layering:
1. **Strong colour grading** through day, dusk and night. Salmon, then crimson, then purple, then navy, then a warm gold before dawn. The whole frame is tinted to match.
2. **Thick coloured fog**, a different colour for each stretch: turquoise, red, grey-green, teal, milky green.
3. **Constant small motion:** animated water caustics, foam, spray, snow gusts and floating debris.
4. **Dense silhouettes:** cube trees on every cliff top, faceted cliffs on both banks, rocks and sandbars in the water.
5. **A themed prop cluster at every stop:** a dock, fire pit, cookfire, drying rack, notice board, stilt hut and NPCs.
6. **Light sources:** lanterns, searchlight beams at night, and glowing set pieces like an ice cave with purple crystals.
7. **Yellow diamond signs** before every hazard.

## Proposal for zone 1, Sunfall Gorge (what M1 builds)

**Surface, mile 0 to about 1 (open, sunny):**
- A red-rock gorge dropping steeply toward the sinkhole.
- Faceted terracotta cliffs (low-poly, like the reference's) topped with cube pines.
- A dusty track with tread ruts, scattered boulders, old fence posts and expedition signage ("DIG SITE, KEEP OUT").
- Warm haze and sun rays.

**The Drop, about mile 1:**
- The rig spirals down the inside of the giant sinkhole while sunlight shafts fall from the opening above.
- At the bottom, the drill **bites into the rock face**: dust bursts, the camera shakes, and the screen goes dark for a beat.
- Then the headlight and lanterns take over. From here on the route is **enclosed**.

**Tunnels, miles 1 to 10:**
- **Walls:** carved live in voxel terrain, with **banded strata**: warm sandstone, then slate, then a dark basalt band. They have irregular, noisy edges, not straight lines.
- **Glowstone veins:** amber glowing lines and clusters in the walls. They're the main light (soft point lights) and a preview of what you mine at stops.
- **Detail:**
  - stalactites, hanging roots near the surface, and crystal clusters;
  - fallen-rock rubble on the floor;
  - old mine timbers and rails in "old dig" sections.
- **Caverns every 1–2 min,** to break up the enclosure: a big open chamber with a glowing pool, mushrooms or crystal spires, and a rope bridge over a chasm. These play the role of the reference's wide pools.
- **Speed and feel:**
  - drill dust and sparks at the bit;
  - falling pebbles from the ceiling, and dust motes in the lantern light;
  - camera shake, which grows on chutes and when breaking hard rock bands;
  - the walls rushing past close by. Underground, that sells the speed better than the reference's open water.
- **Atmosphere:** Roblox `Atmosphere`, `ColorCorrection` and `Bloom`, with Future lighting:
  - each stretch gets its own haze colour: amber dust in tunnels, teal mist in caverns, a red glow near deep seams;
  - the glow cycle grades the whole frame like the reference's day: **warm gold, then crimson ("Lights Out soon"), then deep blue (Lights Out), then golden pre-dawn**.
- **Stops:** named chambers dug off the route, each with a prop cluster:
  - "Quarry Camp": tents, the Beacon in a ring of stones, a cookpot, crates and lantern poles;
  - glowing veins in the walls to mine;
  - a notice board for Field Notes;
  - an NPC prospector.
- **Signs:** yellow diamond signs on posts before chutes, rock bands, cave-ins and creature attacks.

**Art pipeline:**
- Cliffs, props, rock chunks and signs are made in Blender in the reference's low-poly faceted style.
- Rock textures are flat-colour with soft noise.
- Everything goes up through Starport.
- The tunnel itself is voxel terrain with Roblox materials (custom MaterialVariants later, also through Starport).

## Lobby backdrop: three options

**A. Topside Camp at the Dig (recommended).**
- The expedition's camp on a sunny red-rock plateau at the rim of the giant sinkhole.
- The hole glows amber from below, right behind the party bays, so the first thing you see is where you're going.
- A big steel **headframe crane** stands over the hole, lowering a drill rig on cables.
- Around it:
  - mesas and cube-pine woods;
  - rope bridges and tents with flags and string lights;
  - crates of glowstone and a parked rig you can stand on.
- It matches zone 1's colours, so leaving the lobby feels continuous.

**B. Boomtown main street.**
- A wooden frontier mining town, with the boards and the Classes hut as storefronts.
- A headframe and ore carts sit at the end of the street.
- It's cosier and busier, but the hole is less visible.

**C. Crater rim at dusk.**
- A volcanic crater at sunset, with the Core's light rising as a beam far below.
- It's dramatic, but it's a zone 6 mood and tells nothing about the first descent.

## Build order once approved
1. The tunnel kit: terrain carving, strata bands, glowstone veins, caverns, signs. Plus lighting and grading.
2. The surface gorge and The Drop, using Blender cliffs and props.
3. Stop chambers and their prop clusters.
4. The lobby backdrop.
