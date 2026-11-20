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
	SURFACE_MILES = 0.9, -- open gorge before The Drop; enclosed after

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
}

return Config
