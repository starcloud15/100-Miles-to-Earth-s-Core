--[[
	The Game place's save: the same profile as the lobby (shared/Data.luau).
	  - Field Notes and Journal Pages read from notice boards ("[E] Read"),
	    so the lobby's Journal shows them (and pays their claim rewards there).
	  - The run's miles (total and best), games played, creatures knocked off,
	    and the Waystation save point.
	Notes are written as they're read; the run is written when the zone is
	complete and when a player leaves.
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
		p.totalMiles += math.floor(miles * 10) / 10
		p.bestMiles = math.max(p.bestMiles, rig.s / Config.STUDS_PER_MILE)
		p.games += 1
		p.stats.knocked += player:GetAttribute("Knocked") or 0
		if state:GetAttribute("Phase") == "Complete" then
			p.save = { mile = math.floor(rig.s / Config.STUDS_PER_MILE), zone = 2 }
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
		runStart[player] = rig.s
		-- give the lobby's save a moment to land after the teleport
		task.delay(2, function()
			if player.Parent then
				Data.load(player)
			end
		end)
	end
	Players.PlayerAdded:Connect(join)
	for _, player in Players:GetPlayers() do
		join(player)
	end
	-- Data.start's lifecycle, with the run banked before the profile is released
	Players.PlayerRemoving:Connect(function(player)
		bank(player)
		Data.postAll(player)
		Data.release(player)
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			bank(player)
			Data.postAll(player)
			Data.save(player)
		end
	end)
	task.spawn(function()
		while true do
			task.wait(120)
			for _, player in Players:GetPlayers() do
				Data.save(player)
			end
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
