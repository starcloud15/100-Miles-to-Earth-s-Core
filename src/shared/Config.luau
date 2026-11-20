--[[
	Tuning for both places. Numbers follow the GDD (docs/GameDesignDocument.md);
	the M0 prototype builds zone 1 only.
]]

local Config = {
	LOBBY_PLACE_ID = 76938279277561,
	GAME_PLACE_ID = 138151622310222,

	-- distance and speed: the HUD shows miles and MPH like the reference
	STUDS_PER_MILE = 1000,
	MPH_PER_STUD = 1.2, -- studs per second -> displayed MPH
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
	PROTOTYPE_MILES = 10, -- M0: zone 1 only, ending at Waystation 1

	PARTY_MAX = 5,
	PARTY_DEFAULT = 4,
	BAY_COUNTDOWN = 20, -- lobby launch bay; drops to BAY_COUNTDOWN_FULL when the bay is full
	BAY_COUNTDOWN_FULL = 5,
	DEPART_COUNTDOWN = 10, -- in the Game place, before the rig sets off

	Rig = {
		DECK_W = 20, -- 3 x 4 plates
		DECK_L = 28,
		HEIGHT = 4, -- deck centre above the route
		MAX_HEALTH = 200,
		IDLE_SPEED = 9, -- studs/s with nobody cranking (about 11 MPH): it never stops
		CRANK_SPEED = 30, -- studs/s with both treads at full power (about 36 MPH)
		CHUTE_BONUS = 40, -- extra speed per unit of downhill slope
		PUMP = 0.2, -- tread power added by one crank
		DECAY = 0.3, -- tread power lost per second
		PUMP_COOLDOWN = 0.18,
		SYNC_WINDOW = 0.4, -- cranks on both sides within this many seconds...
		SYNC_BONUS = 1.15, -- ...give +15% speed
		LAT_SPEED = 14, -- sideways studs/s at full one-sided power
		LANE_FRACTION = 0.45, -- the rig can drift +-45% of the lane width
		HAZARD_DAMAGE = 12,
		SCRAPE_DAMAGE = 3, -- per second against a wall
		THROW_CHANCE = 0.3, -- chance a hazard hit throws each player off
	},

	Crew = {
		OFF_DISTANCE = 26, -- studs from the deck before you count as off the rig
		LEFT_BEHIND = 780, -- about 220 m: the winch hauls you back
		CATCHUP_WALKSPEED = 24,
		TOW_RANGE = 160,
		TOW_COOLDOWN = 3,
	},

	PushOff = {
		PRODUCT_ID = 0, -- the 19 R$ developer product; 0 = free in Studio, off in live servers
		PRICE = 19,
		GRACE = 180, -- no shoves in the first 3 minutes
		GRACE_STUDIO = 15,
		TARGET_COOLDOWN = 30,
		RANGE = 12,
	},
}

return Config
