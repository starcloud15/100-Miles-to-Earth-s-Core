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
		stats = { nights = 0, knocked = 0, revived = 0, glowstone = 0, finds = 0, meals = 0, cooked = 0, repairs = 0, pushed = 0 },
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

-- Session lock (live-server audit): a profile is written only by the server that
-- holds its lock, so the Lobby can't load a stale copy while the Game place is
-- still writing the run (or the other way round) and then overwrite it. A lock
-- is refreshed by every save; one older than LOCK_STALE belongs to a server that
-- died, and is taken over.
local LOCK_STALE = 150
local LOCK_WAIT = 25 -- seconds to wait for the other server's last save to land
local loading: { [Player]: boolean } = {}
local pending = 0 -- saves in flight (BindToClose waits for them)

local function lockedByOther(old): boolean
	local lock = old and old._lock
	return lock ~= nil and lock.job ~= game.JobId and os.time() - (lock.t or 0) < LOCK_STALE
end

function Data.load(player: Player)
	if profiles[player] then
		return profiles[player]
	end
	if loading[player] then
		-- (someone else is already loading it: wait for that instead of racing it)
		while loading[player] and player.Parent do
			task.wait(0.1)
		end
		return profiles[player]
	end
	loading[player] = true
	local profile, err
	if store then
		local started = os.clock()
		local attempt = 0
		while player.Parent do
			attempt += 1
			local waiting = false
			local okGet, result = pcall(function()
				return store:UpdateAsync(key(player), function(old)
					if lockedByOther(old) and os.clock() - started < LOCK_WAIT then
						waiting = true
						return nil -- leave it alone, and try again shortly
					end
					old = old or default()
					old._lock = { job = game.JobId, t = os.time() }
					return old
				end)
			end)
			if okGet and not waiting then
				profile = reconcile(result or default(), default())
				err = nil
				break
			end
			if not okGet then
				err = result
				if string.find(tostring(result), "StudioAccessToApisNotAllowed", 1, true) or attempt >= 4 then
					break -- (Studio without API access, or the DataStore is down)
				end
				task.wait(attempt)
			else
				task.wait(1.5) -- the other server is still saving this player
			end
		end
	else
		err = "no DataStore"
	end
	loading[player] = nil
	if not player.Parent then
		-- they left while it loaded: let the lock go without changing anything
		if profile and store then
			pcall(function()
				store:UpdateAsync(key(player), function(old)
					if old and old._lock and old._lock.job == game.JobId then
						old._lock = nil
						return old
					end
					return nil
				end)
			end)
		end
		return nil
	end
	if not profile then
		profile = default()
		if RunService:IsStudio() then
			profile.offline = true -- Studio without API access: play, but never save
		else
			profile.failed = true
			warn("Couldn't load " .. player.Name .. "'s save: " .. tostring(err))
			-- never play on a blank save that could later look like theirs
			player:Kick("Couldn't load your save. Please rejoin in a moment.")
		end
	end
	profile._lock = nil
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

-- write the profile (only while this server holds its lock); `release` also
-- lets the lock go, for the next server the player joins
function Data.save(player: Player, release: boolean?)
	local p = profiles[player]
	if not p or p.failed or p.offline or not store then
		return false
	end
	local now = os.time()
	p.timePlayed += now - (p.joinedAt or now)
	p.joinedAt = now
	local copy = table.clone(p)
	copy.joinedAt = nil
	copy._lock = not release and { job = game.JobId, t = now } or nil
	pending += 1
	local okSet, err, lost = false, nil, false
	for attempt = 1, 3 do
		okSet, err = pcall(function()
			store:UpdateAsync(key(player), function(old)
				if lockedByOther(old) then
					lost = true -- another server took this player over: don't clobber it
					return nil
				end
				return copy
			end, { player.UserId })
		end)
		if okSet then
			break
		end
		task.wait(attempt * 1.5)
	end
	pending -= 1
	if not okSet then
		warn("Couldn't save " .. player.Name .. ": " .. tostring(err))
	elseif lost then
		warn(player.Name .. "'s save is held by another server; not overwriting it")
		okSet = false
	end
	return okSet
end

function Data.release(player: Player)
	Data.save(player, true)
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

-- the profile lifecycle: load on join, autosave, and on leave / shutdown write the
-- profile first, then the leaderboards. `beforeSave(player)` lets a place fold
-- its own state in first (the Game place banks the run). Shutdown waits for every
-- save still in flight, so a solo player quitting doesn't lose the run.
function Data.start(opts: { beforeSave: ((Player) -> ())?, loadDelay: number? }?)
	opts = opts or {}
	local function join(player: Player)
		if opts.loadDelay then
			task.wait(opts.loadDelay)
		end
		if player.Parent then
			Data.load(player)
		end
	end
	Players.PlayerAdded:Connect(join)
	for _, player in Players:GetPlayers() do
		task.spawn(join, player)
	end
	local leaving = 0
	local left: { [Player]: boolean } = {}
	local function leave(player: Player)
		if left[player] then
			return
		end
		left[player] = true
		leaving += 1
		pcall(function()
			if opts.beforeSave then
				opts.beforeSave(player)
			end
			Data.save(player, true) -- (lets the session lock go)
			Data.postAll(player)
		end)
		profiles[player] = nil
		left[player] = nil
		leaving -= 1
	end
	Players.PlayerRemoving:Connect(leave)
	game:BindToClose(function()
		for _, player in Players:GetPlayers() do
			task.spawn(leave, player)
		end
		local deadline = os.clock() + 25
		while (leaving > 0 or pending > 0) and os.clock() < deadline do
			task.wait()
		end
	end)
	task.spawn(function()
		while true do
			task.wait(60) -- (also keeps each player's session lock fresh)
			for _, player in Players:GetPlayers() do
				task.spawn(Data.save, player)
			end
		end
	end)
end

return Data
