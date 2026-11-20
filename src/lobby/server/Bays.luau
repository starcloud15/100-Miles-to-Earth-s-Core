--[[
	Party bays (GDD 14.1, the reference's party pads):
	  * step into an empty bay -> the Create Party panel: 1-5 players (4 by
	    default) and Friends Only;
	  * a taken bay glows green: "N/M PLAYERS / Starting in Xs / leader";
	  * the countdown starts at 20 s, never resets when people join, and drops
	    to 5 s when the party is full; a party that isn't full starts anyway;
	  * "STARTING! / Teleporting..." -> the party's own reserved Game server;
	  * the big PLAY button joins the fullest open public party, or starts one.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Data = require(Shared.Data)

local Bays = {}

local GREEN = Color3.fromRGB(70, 230, 60)
local bays = {}
local friendCache: { [string]: boolean } = {}

local function isFriend(a: Player, b: Player): boolean
	if a == b then
		return true
	end
	local k = math.min(a.UserId, b.UserId) .. ":" .. math.max(a.UserId, b.UserId)
	if friendCache[k] == nil then
		local ok, res = pcall(function()
			return a:IsFriendsWith(b.UserId)
		end)
		friendCache[k] = ok and res or false
	end
	return friendCache[k]
end

local function rootOf(p: Player): BasePart?
	local c = p.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function inside(bay, p: Player): boolean
	local r = rootOf(p)
	if not r then
		return false
	end
	local rel = bay.cf:PointToObjectSpace(r.Position)
	return math.abs(rel.X) <= 7 and math.abs(rel.Z) <= 7 and rel.Y > -1 and rel.Y < 9
end

local function setLines(bay, a: string, b: string, c: string?, d: string?, bColor: Color3?)
	local board = bay.board
	board.Line1.Text = a
	board.Line2.Text = b
	board.Line2.TextColor3 = bColor or Color3.new(1, 1, 1)
	board.Line3.Text = c or ""
	board.Line4.Text = d or ""
end

local function setGlow(bay, on: boolean)
	for _, p in bay.model:GetChildren() do
		if p.Name == "Edge" then
			p.Color = on and GREEN or Color3.new(1, 1, 1)
		elseif p.Name == "Wall" then
			p.Color = on and Color3.fromRGB(120, 255, 110) or Color3.fromRGB(220, 240, 255)
			p.Transparency = on and 0.72 or 0.82
		end
	end
end

local function refresh(bay)
	local party = bay.party
	if bay.starting then
		setLines(bay, "STARTING!", "Teleporting...", party and party.leader.DisplayName or "", party and party.friendsOnly and "Friends only" or "", GREEN)
	elseif party then
		setLines(bay, #party.members .. "/" .. party.size .. " PLAYERS", "Starting in " .. math.max(0, math.ceil(party.countdown)) .. "s", party.leader.DisplayName, party.friendsOnly and "Friends only" or "", GREEN)
	else
		setLines(bay, "PLAY", "Step In to make a party")
	end
	setGlow(bay, party ~= nil)
	local ids = {}
	for _, m in party and party.members or {} do
		table.insert(ids, tostring(m.UserId))
	end
	bay.model:SetAttribute("Members", table.concat(ids, ","))
	bay.model:SetAttribute("Open", party ~= nil and not party.friendsOnly and #party.members < party.size)
end

local function launch(bay)
	local party = bay.party
	bay.starting = true
	refresh(bay)
	local members = table.clone(party.members)
	-- friends who start together count as "brought"
	for _, m in members do
		for _, o in members do
			if o ~= m and isFriend(m, o) then
				Data.update(m, function(p)
					p.friendsBrought += 1
				end)
				break
			end
		end
	end
	if RunService:IsStudio() then
		for _, m in members do
			Net.Notify:FireClient(m, "Toast", "Teleports only work in a live server: playtest the Game place in Studio")
		end
		task.wait(4)
	else
		for _, m in members do
			Data.save(m) -- save first, so the Game place loads the latest
		end
		local data = { seed = math.random(1, 2 ^ 30), size = #members, leader = party.leader.UserId, friendsOnly = party.friendsOnly }
		local ok, err
		for attempt = 1, 3 do
			ok, err = pcall(function()
				local options = Instance.new("TeleportOptions")
				options.ReservedServerAccessCode = TeleportService:ReserveServer(Config.GAME_PLACE_ID)
				options:SetTeleportData(data)
				TeleportService:TeleportAsync(Config.GAME_PLACE_ID, members, options)
			end)
			if ok then
				break
			end
			task.wait(attempt)
		end
		if not ok then
			warn("Launch failed: " .. tostring(err))
			for _, m in members do
				Net.Notify:FireClient(m, "Toast", "Couldn't start the descent. Try again!")
			end
		end
		task.wait(6)
	end
	bay.party = nil
	bay.starting = false
	refresh(bay)
end

local function createParty(bay, leader: Player, size: number, friendsOnly: boolean)
	bay.pending = nil
	bay.party = {
		leader = leader,
		size = math.clamp(math.floor(size), 1, Config.PARTY_MAX),
		friendsOnly = friendsOnly,
		countdown = Config.BAY_COUNTDOWN,
		members = { leader },
	}
	refresh(bay)
end

local function moveInto(bay, p: Player)
	local r = rootOf(p)
	if r then
		r.CFrame = bay.cf * CFrame.new(math.random(-3, 3), 4, math.random(-3, 3))
	end
end

function Bays.init(list)
	bays = list
	for _, bay in bays do
		refresh(bay)
	end

	Net.PartyCreate.OnServerEvent:Connect(function(player, size, friendsOnly)
		for _, bay in bays do
			if bay.pending == player and not bay.party and inside(bay, player) then
				createParty(bay, player, tonumber(size) or Config.PARTY_DEFAULT, friendsOnly == true)
				return
			end
		end
	end)
	Net.PartyCancel.OnServerEvent:Connect(function(player)
		for _, bay in bays do
			if bay.pending == player then
				bay.declined = player -- don't ask again until they step out
				bay.pending = nil
			end
		end
	end)
	Net.QuickPlay.OnServerEvent:Connect(function(player)
		local best, bestN = nil, -1
		for _, bay in bays do
			local party = bay.party
			if party and not bay.starting and not party.friendsOnly and #party.members < party.size and #party.members > bestN then
				best, bestN = bay, #party.members
			end
		end
		if best then
			moveInto(best, player)
			return
		end
		for _, bay in bays do
			if not bay.party and not bay.pending and not bay.starting then
				moveInto(bay, player)
				createParty(bay, player, Config.PARTY_DEFAULT, false)
				return
			end
		end
		Net.Notify:FireClient(player, "Toast", "Every bay is busy, try again in a moment!")
	end)

	local last = os.clock()
	task.spawn(function()
		while true do
			task.wait(0.25)
			local now = os.clock()
			local dt = now - last
			last = now
			local claimed: { [Player]: boolean } = {}
			for _, bay in bays do
				if bay.starting then
					continue
				end
				local party = bay.party
				local here = {}
				for _, p in Players:GetPlayers() do
					if inside(bay, p) then
						table.insert(here, p)
					end
				end
				if bay.declined and not table.find(here, bay.declined) then
					bay.declined = nil
				end
				if not party then
					if bay.pending and not table.find(here, bay.pending) then
						Net.Notify:FireClient(bay.pending, "PartyPromptClose")
						bay.pending = nil
					end
					if not bay.pending then
						for _, p in here do
							if p ~= bay.declined and not claimed[p] then
								bay.pending = p
								Net.PartyPrompt:FireClient(p, bay.model.Name)
								break
							end
						end
					end
					if bay.pending then
						claimed[bay.pending] = true
					end
				else
					-- members who stepped out leave; new arrivals join if allowed
					local kept = {}
					for _, m in party.members do
						if m.Parent and table.find(here, m) then
							table.insert(kept, m)
						end
					end
					for _, p in here do
						if not table.find(kept, p) and #kept < party.size and not claimed[p] then
							if not party.friendsOnly or isFriend(p, party.leader) then
								table.insert(kept, p)
							end
						end
					end
					party.members = kept
					if #kept == 0 then
						bay.party = nil
					else
						if not table.find(kept, party.leader) then
							party.leader = kept[1]
						end
						for _, m in kept do
							claimed[m] = true
						end
						party.countdown -= dt
						if #kept >= party.size then
							party.countdown = math.min(party.countdown, Config.BAY_COUNTDOWN_FULL)
						end
						if party.countdown <= 0 then
							task.spawn(launch, bay)
						end
					end
				end
				refresh(bay)
			end
		end
	end)
end

return Bays
