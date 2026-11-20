--[[
	The story's text (docs/story.md): the intro captions, and every zone's 6
	Field Notes and 2 Journal Pages (the Core holds a 13th page). Ids are
	"z<zone>n<i>" and "z<zone>p<i>", as the save data and the Journal use.
]]

local Story = {}

Story.INTRO = {
	"Every night for a hundred years, a light has risen from the Sunfall sinkhole.",
	"The old folks call it the Corelight. The heart of the world, breathing far below.",
	"Crews have dug down to find it. Their lanterns went out, one by one.",
	"Something down there eats the light.",
	"One hundred miles to the Earth's Core.",
	"Will your crew be the first to bring the light back?",
}

Story.ZONES = {
	{
		author = "the Quarrymen",
		notes = {
			"The light came up again last night. Gold, like a lamp left on at the bottom of the world.",
			"Rock here glows when you crack it. The kids call it glowstone. We call it pay.",
			"Rig's ready. Two treads, one drill, four fools. We go down at sunrise.",
			"Lantern went out on its own today. No wind down here. No wind at all.",
			"Saw something tall on the ledge above us. Thought it was a pillar. Pillars don't turn their heads.",
			"Keep the lights burning. Whatever it is, it won't walk into the glow.",
		},
		pages = {
			{ by = "Mara Quill, quarry foreman", text = "We dug for coal and found light. The deeper the seam, the brighter the stone, as if something below is pouring it up. Old Ned says it's breathing. I've watched the glow in the walls rise and fall, slow, like a sleeper's chest." },
			{ by = "Mara Quill", text = "Three crews went past the Drop. One came back, and they won't say what they saw. Only that it was tall, and patient, and put out every lamp it could reach. I'm taking the next rig down." },
		},
	},
	{
		author = "the Lamp Keepers",
		notes = {
			"Mushrooms the size of houses, glowing teal. You could read by them. We do.",
			"Spores fall like snow. Don't breathe them in. Bram did. Bram is very cheerful now.",
			"The glow dims every few hours, all at once, like someone pinching the lamps. We call it Lights Out.",
			"In the dark it comes closer. In the light it waits. Mind the light.",
			"Found Quarrymen tracks. They kept going down. So do we.",
			"Feed the fire and the night goes faster. The light down here does what it likes.",
		},
		pages = {
			{ by = "Oren Vale, lamplighter", text = "Every Lights Out, the mushrooms fade together, then brighten together: the same rhythm as the glow in Sunfall's quarry walls. Whatever is breathing light up through the rock, its breath reaches this far." },
			{ by = "Oren Vale", text = "We lost two lamps tonight. Not broken: emptied, the glowstone dull and grey, as if something drank it. 'Hollow, Hollow, hungry and slow, drink up the lamplight, down you go.' I used to think it was for children." },
		},
	},
	{
		author = "the Ice Survey",
		notes = {
			"Crystals ring when the drill passes, a note I can't name. Temperature: freezing. Morale: also freezing.",
			"Light enters the crystal and doesn't come out for a long time. They hold the Core's breath.",
			"Carvings in the ice: a figure holding a lantern up to a great light. Not ours. Very old.",
			"The old Deepmine is here. Somebody dug this far before Sunfall had a name.",
			"The lift cage still works. Whoever left it wanted someone to follow.",
			"The light breathes once every 3 hours and 11 minutes. The Hollow comes in the gap.",
		},
		pages = {
			{ by = "Dr. Ilsa Brandt, Ice Survey", text = "The carvings repeat: a lantern-bearer, a great light, people bowing. Then one panel scratched over: the lantern-bearer turning away from the light, his lantern dark. I don't know what it means. I don't like it." },
			{ by = "Dr. Ilsa Brandt", text = "The Deepmine's builders painted one word on every beam: KEEP. My assistant says it's a name. 'Keepers.' He says they were here first. He says they're still here, in a way." },
		},
	},
	{
		author = "the Deep Fleet",
		notes = {
			"A sea. Under the world. With a horizon. I'm a sailor and I still don't believe it.",
			"Something enormous died here once. We sail between its ribs.",
			"The geode overhead glows like a moon. Our compass spins. We steer by the light.",
			"Keep to the middle of the causeway. The edges remember the sea and want to go back.",
			"The jungle on the far shore breathes spores. Mask up, and sing loud so we can find each other.",
			"Saw the Hollow walk across the water toward us. It stopped where our lantern light began.",
		},
		pages = {
			{ by = "Captain Teodor Reyes, the Deep Fleet", text = "A shrine on an island: a cold stone lantern, a keeper kneeling to the Core, and words in Sunfall's oldest script: 'He who carries the light must never keep it.' Nobody's joking about it now." },
			{ by = "Captain Teodor Reyes", text = "Half the fleet turned back today. The Hollow followed our wakes all night. It has no face. Just the shape of someone holding up a lantern that isn't there." },
		},
	},
	{
		author = "the Ember Watch",
		notes = {
			"The rock runs like honey down here, red and slow. Don't touch it. Don't even think about it.",
			"Heat climbs fast away from cool stone. Eat the frost-fruit, drink the cold water, keep moving.",
			"Obsidian walls, glass-smooth. You see yourself in them. Sometimes you see someone behind you.",
			"The Hollow hunts faster here. The Core's breath is strong, and the gaps hurt it.",
			"A Keeper's lantern melted into the glass. Still warm. Hundreds of years, and still warm.",
			"Don't run from it. Run to the light. It's the only place it can't follow.",
		},
		pages = {
			{ by = "Sefa Okoro, the Ember Watch", text = "The melted lantern read: 'The Keepers carry the Corelight up to the world, and give it all away.' Scratched under it: 'Why should we give it away?' I think we know his name now. We've been calling it the Hollow." },
			{ by = "Sefa Okoro", text = "He tried to steal the light, and the dark between the breaths took him: a Keeper with no light, forever hungry for it. I almost pity him. Almost. He took Jonah tonight." },
		},
	},
	{
		author = "the Heart Keepers",
		notes = {
			"Temples of gold stone, built by people who carried light for a living. Their doors still open for a lantern.",
			"Statues of Keepers line the road. Their lanterns are lit. Who lights them?",
			"The light comes in beats now. Move between them. Hold still in the dark and you'll be found.",
			"Carved at every gate: 'Carry it up. Give it all. Keep nothing.'",
			"The rock is turning to light. My hands glow when I touch the walls.",
			"The Core Beacon stands cold at the bottom. It's waiting for someone to light it.",
		},
		pages = {
			{ by = "Keeper Ashavel (translated)", text = "Each day we carry the Core's breath up through the stone, so the world above stays warm and lit. One of us has grown tired of giving. I told him that is the whole point of light." },
			{ by = "Keeper Ashavel (translated)", text = "He put out his lantern and went into the dark between the breaths, to keep the light for himself. The dark kept him instead. Light the Beacon, if you come after us. Give him back his light." },
			{ by = "Your crew", text = "We lit the Beacon. The Core breathed out, and the light went up through a hundred miles of rock. And the tall shadow on the ledge lifted its lantern, full at last, and was gone." },
		},
	},
}

function Story.note(zone: number, i: number): string?
	local z = Story.ZONES[zone]
	return z and z.notes[i]
end

function Story.page(zone: number, i: number)
	local z = Story.ZONES[zone]
	return z and z.pages[i]
end

-- which notes a stop's notice board holds: the zone's 6 Field Notes spread over its
-- stops, Journal Page 1 at the middle stop, Page 2 at the Waystation (the last stop)
function Story.boardEntries(zone: number, stopIndex: number, stopCount: number): { string }
	local ids = {}
	local camps = math.max(1, stopCount - 1)
	if stopIndex < stopCount then
		local a = math.floor((stopIndex - 1) * 6 / camps) + 1
		local b = math.floor(stopIndex * 6 / camps)
		for i = a, b do
			table.insert(ids, ("z%dn%d"):format(zone, i))
		end
		if stopIndex == math.ceil(camps / 2) then
			table.insert(ids, ("z%dp1"):format(zone))
		end
	else
		table.insert(ids, ("z%dp2"):format(zone))
	end
	return ids
end

-- the text of a note or page id: (kind, text, signature)
function Story.entry(id: string): (string?, string?, string?)
	local z, kind, i = id:match("^z(%d+)([np])(%d+)$")
	local zone = Story.ZONES[tonumber(z) or 0]
	if not zone then
		return nil
	end
	if kind == "n" then
		local text = zone.notes[tonumber(i)]
		return text and "note", text, zone.author
	end
	local page = zone.pages[tonumber(i)]
	return page and "page", page and page.text, page and page.by
end

return Story
