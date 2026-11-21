--[[
	Meta content shared by both places (GDD section 14): badges, classes,
	the Journal's layout and the Stats panel. Rewards are paid in
	Deepstones, claimed at Topside Camp.
]]

local Config = require(script.Parent.Config)

local Content = {}

Content.GROUP_ID = 606354866 -- Joyshare Studios: joining it earns the free Revive Flare

-- Badges (13): rewards follow the reference's curve (25 / 25 / 75 / 200, challenges 200)
Content.BADGES = {
	{ id = "BreakingGround", group = "Distance", name = "Breaking Ground", desc = "Start a descent", icon = "Pickaxe", reward = 25, check = function(p) return p.games >= 1 end },
	{ id = "TenMiles", group = "Distance", name = "Ten Miles Down", desc = "Reach Mile 10", icon = "Beacon", reward = 25, check = function(p) return p.bestMiles >= 10 end },
	{ id = "QuarterWay", group = "Distance", name = "Quarter Way", desc = "Reach Mile 25", icon = "GlowstoneVein", reward = 75, check = function(p) return p.bestMiles >= 25 end },
	{ id = "Halfway", group = "Distance", name = "Halfway There", desc = "Reach Mile 50", icon = "BoostCrystal", reward = 200, check = function(p) return p.bestMiles >= 50 end },
	{ id = "AlmostThere", group = "Distance", name = "Almost There", desc = "Reach Mile 75", icon = "Turbo", reward = 200, check = function(p) return p.bestMiles >= 75 end },
	{ id = "TheCore", group = "Distance", name = "The Core", desc = "Reach Mile 100", icon = "Glowstone", reward = 200, check = function(p) return p.bestMiles >= 100 end },
	{ id = "Untouched", group = "Challenges", name = "Untouched", desc = "Finish a zone without being knocked off", icon = "Health", reward = 200, check = function(p) return p.flags.untouched == true end },
	{ id = "LoneDriller", group = "Challenges", name = "Lone Driller", desc = "Reach the Core alone", icon = "Crank", reward = 200, check = function(p) return p.flags.loneCore == true end },
	{ id = "FullJournal", group = "Challenges", name = "Full Journal", desc = "Find every Journal page", icon = "Journal", reward = 200, check = function(p) return Content.count(p.pages) >= Content.TOTAL_PAGES end },
	{ id = "BringAFriend", group = "Crew", name = "Bring a Friend", desc = "Play with a friend you invited", icon = "Invite", reward = 75, check = function(p) return p.friendsBrought >= 1 end },
	{ id = "Lifesaver", group = "Crew", name = "Lifesaver", desc = "Revive 5 crewmates", icon = "Revive", reward = 75, check = function(p) return p.stats.revived >= 5 end },
	{ id = "SecondWind", group = "Crew", name = "Second Wind", desc = "Come back with a Revive Flare", icon = "Lantern", reward = 75, check = function(p) return p.flags.secondWind == true end },
	{ id = "CampChef", group = "Crew", name = "Camp Chef", desc = "Cook 50 meals", icon = "CaveStew", reward = 75, check = function(p) return (p.stats.cooked or 0) >= 50 end },
}

-- Classes (GDD 14.3): the reference's price ladder, our own roles
Content.CLASSES = {
	{ id = "Prospector", name = "Prospector", icon = "Pickaxe", deepstones = 150, robux = 49, perk = "+1 glowstone with every swing at a vein" },
	{ id = "Delver", name = "Delver", icon = "DelversHook", deepstones = 750, robux = 149, perk = "Bites come 20% faster when delving, and food fills you 15% more" },
	{ id = "Lamplighter", name = "Lamplighter", icon = "Lantern", deepstones = 1500, robux = 299, perk = "Carries a hand lantern, and the Beacon burns 15% slower with you in the crew" },
}
-- developer product ids for buying a class with Robux (0 = not on sale yet)
Content.CLASS_PRODUCTS = { Prospector = 0, Delver = 0, Lamplighter = 0 }

-- the Journal: 6 Field Notes and 2 pages per zone; the Core holds the 13th page
Content.NOTES_PER_ZONE = 6
Content.PAGES_PER_ZONE = 2
Content.TOTAL_NOTES = 6 * #Config.ZONES
Content.TOTAL_PAGES = 2 * #Config.ZONES + 1
Content.NOTE_REWARD = 10
Content.PAGE_REWARD = 25
Content.DELVE_REWARD = 5 -- each new find in the Delve Log
-- the expeditions who left the notes (their text is in Story.luau; docs/story.md)
Content.NOTE_AUTHORS = { "the Quarrymen", "the Lamp Keepers", "the Ice Survey", "the Deep Fleet", "the Ember Watch", "the Heart Keepers" }

-- Your Stats panel sections (GDD 14.4); `key` reads the profile
Content.STATS = {
	{ title = "THE DESCENT", rows = {
		{ "Total Miles", "totalMiles", "miles" },
		{ "Games Played", "games" },
		{ "Time Played", "timePlayed", "time" },
		{ "Fastest Descent", "fastest", "time" },
		{ "Camps Reached", "camps" },
		{ "Times at the Core", "coreTimes" },
	} },
	{ title = "SURVIVAL", rows = {
		{ "Nights Survived", "stats.nights" },
		{ "Times Knocked Off", "stats.knocked" },
		{ "Crew Revived", "stats.revived" },
	} },
	{ title = "UNDERGROUND", rows = {
		{ "Glowstone Scooped", "stats.glowstone" },
		{ "Finds Delved", "stats.finds" },
		{ "Meals Cooked", "stats.meals" },
		{ "Rig Repairs", "stats.repairs" },
		{ "Players Pushed Off", "stats.pushed" },
	} },
	{ title = "YOUR ACCOUNT", rows = {
		{ "Field Notes", "notes", "notes" },
		{ "Journal Pages", "pages", "pages" },
		{ "Friends Brought", "friendsBrought" },
		{ "Deepstones Earned", "deepstonesEarned" },
	} },
}

function Content.count(t: { [any]: any }?): number
	local n = 0
	for _ in t or {} do
		n += 1
	end
	return n
end

function Content.zoneAt(miles: number): (number, string)
	local acc = 0
	for i, z in Config.ZONES do
		acc += z.miles
		if miles < acc then
			return i, z.name
		end
	end
	return #Config.ZONES, Config.ZONES[#Config.ZONES].name
end

-- what's waiting to be claimed at camp, in Deepstones
function Content.pendingJournal(p): number
	local n = 0
	for id in p.notes do
		if not p.claimed.notes[id] then
			n += Content.NOTE_REWARD
		end
	end
	for id in p.pages do
		if not p.claimed.pages[id] then
			n += Content.PAGE_REWARD
		end
	end
	for id in p.delveLog or {} do
		if not (p.claimed.delveLog or {})[id] then
			n += Content.DELVE_REWARD
		end
	end
	return n
end

function Content.pendingBadges(p): (number, number)
	local n, count = 0, 0
	for _, b in Content.BADGES do
		if b.check(p) and not p.claimed.badges[b.id] then
			n += b.reward
			count += 1
		end
	end
	return n, count
end

return Content
