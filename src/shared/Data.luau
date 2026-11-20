--[[
	Player save data, shared by the Lobby and the Game place (one universe, one
	DataStore). Server only.

	Rule from Run a Resort: never hand out a fresh save on a failed read. If
	loading fails, the profile is marked `failed`, is never saved, and the
	player is asked to rejoin. In Studio without API access the profile is an
	offline copy that's never saved.
]]

local DataStoreService = game:GetService("DataStoreService")
local HttpService = game:GetService("HttpService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Data = {}

local STORE = "Profiles_v1"
local profiles: { [Player]: any } = {}
local changed = Instance.new("BindableEvent")
Data.Changed = changed.Event -- (player, profile)

local function default()
	return {
		deepstones = 0,
		deepstonesEarned = 0,
		totalMiles = 0,
		bestMiles = 0,
		games = 0,
		timePlayed = 0,
		fastest = 0, -- seconds to the Core; 0 = none yet
		camps = 0,
		coreTimes = 0,
		stats = { nights = 0, knocked = 0, revived = 0, glowstone = 0, finds = 0, meals = 0, repairs = 0, pushed = 0 },
		flags = {},
		notes = {},
		pages = {},
		claimed = { notes = {}, pages = {}, badges = {} },
		classes = {},
		class = "",
		reviveFlares = 0,
		freeRevive = false,
		friendsBrought = 0,
		favPrompted = false,
		save = nil, -- { mile, zone } at the last Waystation
	}
end

-- fill in anything added to the default since this profile was saved
local function reconcile(p, d)
	for k, v in d do
		if p[k] == nil then
			p[k] = v
		elseif type(v) == "table" and type(p[k]) == "table" and next(v) ~= nil then
			reconcile(p[k], v)
		end
	end
	return p
end

local store
local ok = pcall(function()
	store = DataStoreService:GetDataStore(STORE)
end)
if not ok then
	store = nil
end

local function key(player: Player): string
	return "p_" .. player.UserId
end

function Data.load(player: Player)
	if profiles[player] then
		return profiles[player]
	end
	local profile, err
	if store then
		for attempt = 1, 3 do
			local okGet, result = pcall(function()
				return store:GetAsync(key(player))
			end)
			if okGet then
				profile = reconcile(result or default(), default())
				err = nil
				break
			end
			err = result
			if string.find(tostring(result), "StudioAccessToApisNotAllowed", 1, true) then
				break -- Studio without API access: retrying won't help
			end
			task.wait(attempt)
		end
	else
		err = "no DataStore"
	end
	if not profile then
		profile = default()
		if RunService:IsStudio() then
			profile.offline = true -- Studio without API access: play, but never save
		else
			profile.failed = true
			warn("Couldn't load " .. player.Name .. "'s save: " .. tostring(err))
		end
	end
	profile.joinedAt = os.time()
	profiles[player] = profile
	changed:Fire(player, profile)
	return profile
end

function Data.get(player: Player)
	return profiles[player]
end

-- change a profile and tell everyone listening (the HUD sync, leaderstats)
function Data.update(player: Player, fn: (any) -> ())
	local p = profiles[player]
	if not p or p.failed then
		return nil
	end
	fn(p)
	changed:Fire(player, p)
	return p
end

function Data.save(player: Player)
	local p = profiles[player]
	if not p or p.failed or p.offline or not store then
		return false
	end
	local now = os.time()
	p.timePlayed += now - (p.joinedAt or now)
	p.joinedAt = now
	local copy = table.clone(p)
	copy.joinedAt = nil
	local okSet, err = pcall(function()
		store:SetAsync(key(player), copy, { player.UserId })
	end)
	if not okSet then
		warn("Couldn't save " .. player.Name .. ": " .. tostring(err))
	end
	return okSet
end

function Data.release(player: Player)
	Data.save(player)
	profiles[player] = nil
end

-- a snapshot safe to send to the client
function Data.snapshot(p)
	return HttpService:JSONDecode(HttpService:JSONEncode(p))
end

-- leaderboards: OrderedDataStores; Fastest is ascending seconds
Data.BOARDS = {
	Fastest = { store = "Board_Fastest_v1", ascending = true },
	Deepstones = { store = "Board_Deepstones_v1", ascending = false },
	Miles = { store = "Board_Miles_v1", ascending = false },
}

function Data.postScore(board: string, player: Player, value: number)
	local def = Data.BOARDS[board]
	if not def or value <= 0 then
		return
	end
	pcall(function()
		DataStoreService:GetOrderedDataStore(def.store):SetAsync(tostring(player.UserId), math.floor(value))
	end)
end

function Data.postAll(player: Player)
	local p = profiles[player]
	if not p or p.failed or p.offline then
		return
	end
	Data.postScore("Miles", player, p.totalMiles * 10) -- tenths of a mile
	Data.postScore("Deepstones", player, p.deepstonesEarned)
	if p.fastest > 0 then
		Data.postScore("Fastest", player, p.fastest)
	end
end

function Data.start()
	Players.PlayerRemoving:Connect(function(player)
		Data.postAll(player)
		Data.release(player)
	end)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
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
end

return Data
