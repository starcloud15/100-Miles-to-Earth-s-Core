--[[
	Delving finds (GDD 9.2, 12.3): what the Delver's Hook reels up, zone by zone.
	Each find is a real item (owner): it gets its own hotbar slot with a stack
	count, you hold it to eat it, and it can be dropped and picked up again, like
	the reference's fish.

	id = the icon's slot (Assets.icons.<id>) and the item's key.
	hunger = % Hunger eating one gives back. rare = the zone's rare find.
	color / shape = how it looks in your hand (no mesh needed).
]]

local Finds = {}

local LIST = {
	-- zone 1: Sunfall Gorge and the Hollow Below
	{ id = "Puffball", name = "Puffball", zone = 1, hunger = 10, color = Color3.fromRGB(236, 226, 200), shape = "ball", desc = "A soft round puff from the quarry rock. Chewy." },
	{ id = "RootTuber", name = "Root Tuber", zone = 1, hunger = 12, color = Color3.fromRGB(176, 120, 72), shape = "tuber", desc = "A knobbly root that grows down through the gorge." },
	{ id = "GoldenTruffle", name = "Golden Truffle", zone = 1, hunger = 30, rare = true, color = Color3.fromRGB(240, 186, 50), shape = "ball", desc = "It shines in the dark. Quarrymen traded these for a week's pay." },
	-- zone 2: Glowshroom Grotto
	{ id = "Glowcap", name = "Glowcap", zone = 2, hunger = 11, color = Color3.fromRGB(70, 220, 210), shape = "mushroom", desc = "A little glowing mushroom. Your mouth glows for a minute." },
	{ id = "LanternFig", name = "Lantern Fig", zone = 2, hunger = 13, color = Color3.fromRGB(255, 150, 60), shape = "fruit", desc = "Warm and sweet, lit from inside like a lantern." },
	{ id = "MoonMorel", name = "Moon Morel", zone = 2, hunger = 30, rare = true, color = Color3.fromRGB(196, 176, 255), shape = "mushroom", desc = "Pale as moonlight. Nobody knows how it got so deep." },
	-- zone 3: Crystal Hollows and the Old Deepmine
	{ id = "FrostTruffle", name = "Frost Truffle", zone = 3, hunger = 12, color = Color3.fromRGB(170, 214, 255), shape = "ball", desc = "Cold to the touch, crunchy like snow." },
	{ id = "PrismBerry", name = "Prism Berry", zone = 3, hunger = 10, color = Color3.fromRGB(230, 120, 255), shape = "berry", desc = "Each berry splits light into a tiny rainbow." },
	{ id = "MinersCap", name = "Miner's Cap", zone = 3, hunger = 13, color = Color3.fromRGB(160, 96, 56), shape = "mushroom", desc = "Grows on old mine timbers. Tastes like smoke." },
	{ id = "IronMorel", name = "Iron Morel", zone = 3, hunger = 32, rare = true, color = Color3.fromRGB(140, 150, 164), shape = "mushroom", desc = "Heavy as a nail. Miners swore by it." },
	-- zone 4: the Fossil Sea and Sporewood Shores
	{ id = "SeaGrape", name = "Sea Grape", zone = 4, hunger = 11, color = Color3.fromRGB(80, 200, 150), shape = "berry", desc = "Salty little beads from the underground sea." },
	{ id = "FossilFern", name = "Fossil Fern", zone = 4, hunger = 10, color = Color3.fromRGB(110, 180, 80), shape = "leaf", desc = "A fern older than the dinosaurs. Still crisp." },
	{ id = "SporeMelon", name = "Spore Melon", zone = 4, hunger = 15, color = Color3.fromRGB(150, 210, 90), shape = "fruit", desc = "Striped and juicy. Don't shake it." },
	{ id = "OrchidFruit", name = "Jungle Orchid Fruit", zone = 4, hunger = 34, rare = true, color = Color3.fromRGB(255, 120, 190), shape = "fruit", desc = "Grows only where the Sporewood meets the sea." },
	-- zone 5: Emberflow and the Obsidian Rifts
	{ id = "AshPotato", name = "Ash Potato", zone = 5, hunger = 14, color = Color3.fromRGB(120, 104, 112), shape = "tuber", desc = "Roasts itself in the hot rock. Cools Heat a little." },
	{ id = "EmberPepper", name = "Ember Pepper", zone = 5, hunger = 11, color = Color3.fromRGB(240, 70, 40), shape = "pepper", desc = "Hot enough to make your ears steam." },
	{ id = "ObsidianFig", name = "Obsidian Fig", zone = 5, hunger = 34, rare = true, color = Color3.fromRGB(70, 40, 90), shape = "fruit", desc = "Glassy black skin, molten sweet inside." },
	-- zone 6: Heartstone Ruins and the Core Approach
	{ id = "SunGrain", name = "Sun Grain", zone = 6, hunger = 14, color = Color3.fromRGB(250, 210, 90), shape = "grain", desc = "The temple keepers grew it in the Core's light." },
	{ id = "CorelightPeach", name = "Corelight Peach", zone = 6, hunger = 40, rare = true, color = Color3.fromRGB(255, 170, 120), shape = "fruit", desc = "It tastes like sunrise. The last thing anyone ate before the Core." },
	-- cooked at a camp's Cookpot (GDD 12.3), never reeled up (zone 0)
	{ id = "RoastedCap", name = "Roasted Find", zone = 0, hunger = 30, cooked = true, color = Color3.fromRGB(170, 104, 56), shape = "skewer", desc = "Any find, roasted over the Cookpot. Hot, smoky and filling." },
	{ id = "CaveStew", name = "Cave Stew", zone = 0, hunger = 54, cooked = true, wellFed = 180, color = Color3.fromRGB(176, 110, 60), shape = "bowl", desc = "Three finds in one pot. Fills you right up, and you get hungry slower for 3 minutes." },
}

-- rarity tiers, coloured like the reference's tags (its Cooked Fish is a green
-- UNCOMMON): the name on the pickup card takes the tier's colour too
Finds.RARITY = {
	COMMON = Color3.fromRGB(225, 225, 225),
	UNCOMMON = Color3.fromRGB(110, 225, 100),
	RARE = Color3.fromRGB(80, 165, 255),
	LEGENDARY = Color3.fromRGB(255, 196, 40),
}
for _, f in LIST do
	-- (no cooking yet, so a raw find fills half again as much: the reference's
	-- cooked fish gives about 45%)
	f.hunger = math.floor(f.hunger * 1.5 + 0.5)
	f.rarity = f.id == "CorelightPeach" and "LEGENDARY" or ((f.rare or f.id == "CaveStew") and "RARE" or (f.hunger >= 20 and "UNCOMMON" or "COMMON"))
end

-- glowstone, the one resource, is an item too: in the Bag, held, dropped
Finds.GLOWSTONE = { id = "Glowstone", name = "Glowstone", rarity = "COMMON", desc = "Repairs the rig and feeds the Beacon. Mine it from the glowing veins at stops." }

Finds.LIST = LIST
Finds.BY_ID = {}
for _, f in LIST do
	Finds.BY_ID[f.id] = f
end

Finds.RARE_CHANCE = 0.1

-- the finds a zone can give: its own, with a small chance of its rare one
function Finds.roll(zone: number, rng: Random): any
	local common, rare = {}, nil
	for _, f in LIST do
		if f.zone == zone then
			if f.rare then
				rare = f
			else
				table.insert(common, f)
			end
		end
	end
	if rare and rng:NextNumber() < Finds.RARE_CHANCE then
		return rare
	end
	return common[rng:NextInteger(1, #common)]
end

return Finds
