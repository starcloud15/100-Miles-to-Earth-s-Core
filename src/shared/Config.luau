--[[
	Tuning for both places. Every number follows docs/match-spec.md (the
	reference measured frame by frame) translated to our descent. M1 builds
	zone 1, Sunfall Gorge.
]]

local Config = {
	LOBBY_PLACE_ID = 76938279277561,
	GAME_PLACE_ID = 138151622310222,

	-- distance and speed: the gauge reads like the reference's (18-29 calm,
	-- 30-45 fast, 50-60 chutes) while the rig really moves fast underground
	STUDS_PER_MILE = 1290,
	MPH_PER_STUD = 0.6, -- studs per second -> displayed MPH
	STUDS_PER_METRE = 3.57,

	-- the zone ladder (GDD section 9): six zones that get longer
	ZONES = {
		{ name = "Sunfall Gorge", miles = 10, color = Color3.fromRGB(122, 196, 92) },
		{ name = "Glowshroom Grotto", miles = 10, color = Color3.fromRGB(70, 196, 196) },
		{ name = "Crystal Hollows", miles = 15, color = Color3.fromRGB(150, 205, 255) },
		{ name = "Fossil Sea", miles = 20, color = Color3.fromRGB(64, 132, 204) },
		{ name = "Emberflow", miles = 22, color = Color3.fromRGB(236, 112, 52) },
		{ name = "Heartstone Ruins", miles = 23, color = Color3.fromRGB(246, 198, 76) },
	},
	PROTOTYPE_MILES = 10, -- M1: zone 1, ending at Waystation 1

	-- zone 1's stops, like the reference's (named, every 2.5-3.5 mi; camps
	-- hold the night, landings are short daytime stops)
	STOPS = {
		{ mile = 2.6, name = "Lantern Hollow", kind = "camp" },
		{ mile = 5.4, name = "Old Shaft Landing", kind = "landing" },
		{ mile = 7.9, name = "Rootcellar Camp", kind = "camp" },
		{ mile = 10.0, name = "Waystation 1", kind = "waystation" },
	},
	-- every zone's stops (miles down from the surface) and its giant cavern (GDD 9.0,
	-- 9.1): the cavern runs to `untilMile`, then a short dig out to the Waystation
	ZONE_STOPS = {
		nil, -- zone 1 uses STOPS (below)
		{
			{ mile = 12.7, name = "Glowcap Hollow", kind = "camp" },
			{ mile = 15.3, name = "Spore Bridge Landing", kind = "landing" },
			{ mile = 17.9, name = "Mirror Pool Camp", kind = "camp" },
			{ mile = 20.0, name = "Waystation 2", kind = "waystation" },
		},
		{
			{ mile = 22.8, name = "Frostlight Camp", kind = "camp" },
			{ mile = 25.4, name = "Prism Bridge Landing", kind = "landing" },
			{ mile = 29.4, name = "Lift Cage Landing", kind = "landing" },
			{ mile = 31.8, name = "Pithead Camp", kind = "camp" },
			{ mile = 33.6, name = "Old Pumphouse Landing", kind = "landing" },
			{ mile = 35.0, name = "Waystation 3", kind = "waystation" },
		},
		{
			{ mile = 37.0, name = "Tidewrack Camp", kind = "camp" },
			{ mile = 39.6, name = "Rib Island Landing", kind = "landing" },
			{ mile = 42.2, name = "Lighthouse Camp", kind = "camp" },
			{ mile = 45.0, name = "Midsea Waystation", kind = "landing" }, -- (GDD 9.1: the mid-zone save; for now a landing)
			{ mile = 47.8, name = "Sporewood Landing", kind = "landing" },
			{ mile = 50.6, name = "Canopy Camp", kind = "camp" },
			{ mile = 53.2, name = "Rootfall Landing", kind = "landing" },
			{ mile = 55.0, name = "Waystation 4", kind = "waystation" },
		},
		{
			{ mile = 57.4, name = "Cinder Camp", kind = "camp" },
			{ mile = 60.0, name = "Basalt Steps Landing", kind = "landing" },
			{ mile = 62.8, name = "Geyser Camp", kind = "camp" },
			{ mile = 66.0, name = "Ashfall Waystation", kind = "landing" }, -- (the mid-zone save; for now a landing)
			{ mile = 69.0, name = "Glass Rift Landing", kind = "landing" },
			{ mile = 71.6, name = "Ember Watch Camp", kind = "camp" },
			{ mile = 74.3, name = "Redglass Camp", kind = "camp" },
			{ mile = 77.0, name = "Waystation 5", kind = "waystation" },
		},
		{
			{ mile = 79.4, name = "Gatehouse Camp", kind = "camp" },
			{ mile = 82.0, name = "Statue Road Landing", kind = "landing" },
			{ mile = 84.8, name = "Sunstone Camp", kind = "camp" },
			{ mile = 88.0, name = "Heartstone Waystation", kind = "landing" }, -- (the mid-zone save; for now a landing)
			{ mile = 90.8, name = "Lantern Gate Landing", kind = "landing" },
			{ mile = 93.4, name = "Last Light Camp", kind = "camp" },
			{ mile = 96.6, name = "Corelight Camp", kind = "camp" },
			{ mile = 100.0, name = "The Core", kind = "waystation" },
		},
	},
	ZONE_HALL = {
		{ untilMile = 9.5, WIDTH = 380, FLOOR = 150, CEILING = 120, theme = "Hollow" },
		{ untilMile = 19.5, WIDTH = 420, FLOOR = 170, CEILING = 150, theme = "Grotto" },
		-- zone 3 has two caverns: the Crystal Hollows, then the Old Deepmine from mile 28
		{ untilMile = 34.5, WIDTH = 400, FLOOR = 160, CEILING = 170, theme = "Crystal", split = { mile = 28, theme = "Deepmine" } },
		-- zone 4: the Fossil Sea, then the Sporewood Shores from mile 46
		{ untilMile = 54.5, WIDTH = 600, FLOOR = 160, CEILING = 140, theme = "FossilSea", split = { mile = 46, theme = "Sporewood" } },
		-- zone 5: Emberflow, then the Obsidian Rifts from mile 66
		{ untilMile = 76.5, WIDTH = 420, FLOOR = 150, CEILING = 150, theme = "Emberflow", split = { mile = 66, theme = "Obsidian" } },
		-- zone 6: the Heartstone Ruins, then the Core Approach from mile 90
		{ untilMile = 99.5, WIDTH = 440, FLOOR = 160, CEILING = 160, theme = "Heartstone", split = { mile = 90, theme = "CoreApproach" } },
	},
	SURFACE_MILES = 0.9, -- open gorge before The Drop
	DIG_IN = 700, -- studs of dig after The Drop before the zone's cavern (GDD 9.0)
	HALL_UNTIL_MILE = 9.5, -- the cavern runs to here; then a short dig out to the Waystation
	HALL = { WIDTH = 380, FLOOR = 150, CEILING = 120 }, -- the cavern's size around the route

	PARTY_MAX = 5,
	PARTY_DEFAULT = 4,
	BAY_COUNTDOWN = 20, -- lobby: drops to BAY_COUNTDOWN_FULL when full
	BAY_COUNTDOWN_FULL = 5,

	-- boarding (reference: 3 of 4 aboard starts "LEAVING IN 30"; all aboard -> 3 s; 15 s at the spawn)
	BOARD_FRACTION = 0.75,
	LEAVE_COUNTDOWN = 30,
	LEAVE_COUNTDOWN_SPAWN = 15,
	LEAVE_COUNTDOWN_ALL = 3,

	Rig = {
		DECK_W = 14,
		DECK_L = 18,
		HEIGHT = 3.2, -- deck centre above the route floor
		IDLE_SPEED = 26, -- studs/s with nobody cranking (16 MPH): it never stops on its own
		CRANK_SPEED = 55, -- both treads at full power (33 MPH)
		CHUTE_BONUS = 160, -- extra speed per unit of slope steeper than CHUTE_SLOPE
		CHUTE_SLOPE = 0.22,
		MAX_SPEED = 100, -- 60 MPH, the gauge's top
		PUMP = 0.22,
		DECAY = 0.32,
		PUMP_COOLDOWN = 0.18,
		SYNC_WINDOW = 0.4,
		SYNC_BONUS = 1.15,
		LAT_SPEED = 16,
		BRAKE = 45, -- studs/s^2 when stopping at a stop
		THROW_CHANCE = 0.3,
		REPAIR_PER_PIECE = 3, -- glowstone per broken piece
	},

	Tunnel = {
		WIDTH = 44, -- lane width underground
		HEIGHT = 30,
		SHELL = 26, -- rock around the bore
	},

	Crew = {
		WARN_STUDS = 215, -- about 60 m: "DON'T GET LEFT BEHIND!"
		PULL_STUDS = 2250, -- the bar fills over this much more (reference: 630 m)
		SLIDE_SPEED = 38, -- off the rig you slide down the slope faster than you run
		TOW_RANGE = 160,
		TOW_COOLDOWN = 3,
	},

	Survival = {
		HUNGER_PER_MIN = 7.4, -- % (reference: full to empty in about 13.5 min)
		REGEN_PER_SEC = 1, -- % health while fed
		STARVE_PER_SEC = 1,
		RAW_FIND = 15, -- % hunger from eating a raw find
		COOKED_FIND = 45,
	},

	Night = {
		BASE_RATE = 0.56, -- % of the night bar per second at 1x (about 3 min)
		PER_FEED = 0.1,
		MAX_MULT = 2.9,
		DECAY_EVERY = 3,
		FUEL_START = 45, -- seconds of Beacon fuel
		FUEL_PER_GLOWSTONE = 6,
		RING = 26, -- studs: safe in the Beacon's light
	},

	PushOff = {
		PRODUCT_ID = 0, -- the 19 R$ developer product; 0 = free in Studio, off in live servers
		PRICE = 19,
		GRACE = 180,
		GRACE_STUDIO = 15,
		TARGET_COOLDOWN = 30,
		RANGE = 12,
	},

	-- creatures that get onto the rig (the reference's piranhas/eels and gators):
	-- a boarder drops onto the deck and bites; a grabber seizes one of the crew.
	-- SPAM! to knock them off (docs/research/frames seg-2, seg-5, seg-6)
	Creatures = {
		FIRST_MILE = 1.2,
		BOARD_EVERY = { 20, 38 }, -- seconds between boarders, underground and moving
		GRAB_EVERY = { 45, 75 },
		BOARD_CLICKS = 7, -- the reference's ring fills in about 2 s of clicking
		GRAB_CLICKS = 10,
		BITE = 6, -- a boarder bites the nearest of the crew
		BITE_EVERY = 2.2,
		BITE_RANGE = 7,
		BOARD_LIFE = 20, -- it leaves on its own after this
		GRAB_DPS = 14, -- the gator grab took about 38% in a couple of seconds
		GRAB_TIME = 3.5, -- then it drags you off the rig
		DRAG = 0.7, -- the rig's speed while something rides the deck
		CLICK_RATE = 14, -- clicks a second the server counts, per player
		-- the creatures of each zone (docs/story.md): { boarder, grabber }
		ZONES = {
			{ board = "Cragskitter", grab = "Burrowmaw" },
			{ board = "Puffcap", grab = "LanternEel" },
			{ board = "Shardback", grab = "TunnelMole" },
			{ board = "BoneCrab", grab = "Snapjaw" },
			{ board = "CinderImp", grab = "MagmaSalamander" },
			{ board = "Ashwisp", grab = "TempleGuardian" },
		},
	},
}

Config.ZONE_STOPS[1] = Config.STOPS

-- the mile a zone starts at (zone 2 starts at 10, zone 3 at 20...)
function Config.zoneStart(zone: number): number
	local m = 0
	for i = 1, zone - 1 do
		m += Config.ZONES[i].miles
	end
	return m
end

-- the highest zone that's built so far
Config.BUILT_ZONES = #Config.ZONE_HALL

return Config
