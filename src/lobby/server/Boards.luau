--[[
	Leaderboard data (GDD 14.1): Fastest Descent, Deepstones Earned and
	Deepest Total (lifetime miles), each with Global and Friends tabs and a
	pinned "You" row. Clients draw the boards; this answers BoardFetch.
]]

local DataStoreService = game:GetService("DataStoreService")
local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Net = require(Shared.Net)
local Data = require(Shared.Data)

local Boards = {}

local GLOBAL_TTL = 60
local FRIENDS_TTL = 300
local globalCache: { [string]: { at: number, rows: { any } } } = {}
local friendsCache: { [string]: { at: number, rows: { any } } } = {}
local names: { [number]: string } = {}

local function nameOf(userId: number): string
	if not names[userId] then
		local ok, n = pcall(function()
			return Players:GetNameFromUserIdAsync(userId)
		end)
		names[userId] = ok and n or "?"
	end
	return names[userId]
end

local function storeOf(board: string)
	local def = Data.BOARDS[board]
	return def and DataStoreService:GetOrderedDataStore(def.store), def
end

local function global(board: string)
	local c = globalCache[board]
	if c and os.clock() - c.at < GLOBAL_TTL then
		return c.rows
	end
	local rows = {}
	local ok = pcall(function()
		local store, def = storeOf(board)
		local page = store:GetSortedAsync(def.ascending, 10, def.ascending and 1 or nil):GetCurrentPage()
		for i, e in page do
			local id = tonumber(e.key) or 0
			table.insert(rows, { rank = i, userId = id, name = nameOf(id), value = e.value })
		end
	end)
	if ok then
		globalCache[board] = { at = os.clock(), rows = rows }
	end
	return rows
end

local function friends(board: string, player: Player)
	local k = board .. ":" .. player.UserId
	local c = friendsCache[k]
	if c and os.clock() - c.at < FRIENDS_TTL then
		return c.rows
	end
	local rows = {}
	pcall(function()
		local store = storeOf(board)
		local pages = Players:GetFriendsAsync(player.UserId)
		local n = 0
		for _, f in pages:GetCurrentPage() do
			n += 1
			if n > 25 then
				break
			end
			local v = store:GetAsync(tostring(f.Id))
			if v and v > 0 then
				table.insert(rows, { userId = f.Id, name = f.Username, value = v })
			end
		end
		local def = Data.BOARDS[board]
		table.sort(rows, function(a, b)
			if def.ascending then
				return a.value < b.value
			end
			return a.value > b.value
		end)
		for i, r in rows do
			r.rank = i
		end
	end)
	friendsCache[k] = { at = os.clock(), rows = rows }
	return rows
end

local function mine(board: string, player: Player): number
	local p = Data.get(player)
	if not p then
		return 0
	end
	if board == "Fastest" then
		return p.fastest
	elseif board == "Deepstones" then
		return p.deepstonesEarned
	end
	return math.floor(p.totalMiles * 10)
end

function Boards.init()
	Net.BoardFetch.OnServerInvoke = function(player, board, tab)
		if not Data.BOARDS[board] then
			return {}, nil
		end
		local rows = tab == "Friends" and friends(board, player) or global(board)
		local you = { name = "You", value = mine(board, player), rank = nil }
		for _, r in rows do
			if r.userId == player.UserId then
				you.rank = r.rank
			end
		end
		return rows, you
	end
end

return Boards
