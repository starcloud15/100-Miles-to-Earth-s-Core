--[[
	The Game place's save: the same profile as the lobby (shared/Data.luau).
	  - Field Notes and Journal Pages read from notice boards ("[E] Read"),
	    so the lobby's Journal shows them (and pays their claim rewards there).
	  - The run's miles (total and best), games played, creatures knocked off,
	    and the Waystation save point.
	Notes are written as they're read; the run is written when the zone is
	complete and when a player leaves (shared/Data.luau's lifecycle).
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Data = require(Shared.Data)
local Net = require(Shared.Net)
local Story = require(Shared.Story)

local Progress = {}

local rig, state, World
local hooked = {}
local runStart = {} -- [Player] = the rig's distance when they joined the run
local banked = {} -- [Player] = true once this run's miles are in the profile

local function bank(player: Player)
	if banked[player] or not rig then
		return
	end
	banked[player] = true
	local miles = math.max(0, rig.s - (runStart[player] or 0)) / Config.STUDS_PER_MILE
	Data.update(player, function(p)
		local zone = state:GetAttribute("Zone") or 1
		local reached = (state:GetAttribute("MileOffset") or Config.zoneStart(zone)) + rig.s / Config.STUDS_PER_MILE
		p.totalMiles += math.floor(miles * 10) / 10
		p.bestMiles = math.max(p.bestMiles, reached)
		p.games += 1
		p.stats.knocked += player:GetAttribute("Knocked") or 0
		if state:GetAttribute("Phase") == "Complete" then
			if zone >= #Config.ZONES then
				-- the Core: the descent is done; the next run starts from the top again
				p.coreTimes += 1
				p.save = nil
			else
				-- saved at the Waystation: the next run starts the next zone
				p.save = { mile = Config.zoneStart(zone + 1), zone = zone + 1 }
			end
		end
	end)
end

-- a notice board: show its notes, mark the unread ones NEW! and save them
local function read(player: Player, prompt: ProximityPrompt)
	local ids = string.split(prompt:GetAttribute("Notes") or "", ",")
	local entries = {}
	local p = Data.get(player)
	local fresh = {}
	for _, id in ids do
		local kind = Story.entry(id)
		if kind then
			local list = p and (kind == "page" and p.pages or p.notes)
			local isNew = not (list and list[id])
			table.insert(entries, { id = id, new = isNew })
			if isNew then
				table.insert(fresh, { id = id, kind = kind })
			end
		end
	end
	if #fresh > 0 then
		Data.update(player, function(q)
			for _, f in fresh do
				(f.kind == "page" and q.pages or q.notes)[f.id] = true
			end
		end)
	end
	Net.Notify:FireClient(player, "Note", entries)
end

function Progress.init(theRig, theState, theWorld)
	rig, state, World = theRig, theState, theWorld
	local function join(player: Player)
		runStart[player] = runStart[player] or rig.s
	end
	Players.PlayerAdded:Connect(join)
	for _, player in Players:GetPlayers() do
		join(player)
	end
	-- the shared lifecycle (load, autosave, safe shutdown), banking the run before
	-- each final save. (Loading waits on the Lobby's session lock, so the Lobby's
	-- last save always lands first.)
	Data.start({ beforeSave = bank })
	-- a mid-zone Waystation saves where the run will carry on from
	state:GetAttributeChangedSignal("SavedAt"):Connect(function()
		local mile = state:GetAttribute("SavedAt")
		local zone = state:GetAttribute("Zone") or 1
		for _, player in Players:GetPlayers() do
			Data.update(player, function(p)
				p.save = { mile = math.floor(mile * 10 + 0.5) / 10, zone = zone }
			end)
			task.spawn(Data.save, player)
		end
	end)
	state:GetAttributeChangedSignal("Phase"):Connect(function()
		if state:GetAttribute("Phase") == "Complete" then
			for _, player in Players:GetPlayers() do
				bank(player)
				task.spawn(Data.save, player)
			end
		end
	end)
end

-- hook the boards' prompts as their stops are built
function Progress.step()
	for _, prompt in World.notePrompts do
		if not hooked[prompt] then
			hooked[prompt] = true
			prompt.Triggered:Connect(function(player)
				read(player, prompt)
			end)
		end
	end
end

return Progress
