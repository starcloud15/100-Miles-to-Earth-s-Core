--[[
	Claims at camp (GDD 14.2), classes (14.3) and the free Revive Flare for
	joining the group. Everything pays or costs Deepstones.
]]

local Shared = game:GetService("ReplicatedStorage").Shared
local Content = require(Shared.Content)
local Net = require(Shared.Net)
local Data = require(Shared.Data)

local Rewards = {}

local function pay(player: Player, amount: number)
	Data.update(player, function(p)
		p.deepstones += amount
		p.deepstonesEarned += amount
	end)
	Data.postScore("Deepstones", player, (Data.get(player) or {}).deepstonesEarned or 0)
	Net.Notify:FireClient(player, "Deepstones", amount)
end

local function classOf(id: string)
	for _, c in Content.CLASSES do
		if c.id == id then
			return c
		end
	end
	return nil
end

function Rewards.init()
	Net.Claim.OnServerEvent:Connect(function(player, what)
		local p = Data.get(player)
		if not p or p.failed then
			return
		end
		if what == "journal" then
			local amount = Content.pendingJournal(p)
			if amount > 0 then
				Data.update(player, function(q)
					for id in q.notes do
						q.claimed.notes[id] = true
					end
					for id in q.pages do
						q.claimed.pages[id] = true
					end
					for id in q.delveLog do
						q.claimed.delveLog[id] = true
					end
				end)
				pay(player, amount)
			end
		elseif what == "badges" then
			local amount = Content.pendingBadges(p)
			if amount > 0 then
				Data.update(player, function(q)
					for _, b in Content.BADGES do
						if b.check(q) then
							q.claimed.badges[b.id] = true
						end
					end
				end)
				pay(player, amount)
			end
		elseif what == "favorite" then
			Data.update(player, function(q)
				q.favPrompted = true
			end)
		end
	end)

	Net.BuyClass.OnServerEvent:Connect(function(player, id, currency)
		local c = classOf(id)
		local p = Data.get(player)
		if not c or not p or p.failed or p.classes[c.id] then
			return
		end
		if currency == "deepstones" then
			if p.deepstones >= c.deepstones then
				Data.update(player, function(q)
					q.deepstones -= c.deepstones
					q.classes[c.id] = true
					q.class = c.id
				end)
				Net.Notify:FireClient(player, "Toast", c.name .. " unlocked!")
			end
		else
			-- Robux needs a developer product id per class (Content.CLASS_PRODUCTS)
			Net.Notify:FireClient(player, "Toast", "Robux purchases aren't on sale yet")
		end
	end)

	Net.EquipClass.OnServerEvent:Connect(function(player, id)
		local p = Data.get(player)
		if p and (id == "" or p.classes[id]) then
			Data.update(player, function(q)
				q.class = id
			end)
		end
	end)

	Net.FreeRevive.OnServerEvent:Connect(function(player)
		local p = Data.get(player)
		if not p or p.failed or p.freeRevive then
			return
		end
		local ok, member = pcall(function()
			return player:IsInGroupAsync(Content.GROUP_ID)
		end)
		if ok and member then
			Data.update(player, function(q)
				q.freeRevive = true
				q.reviveFlares += 1
			end)
			Net.Notify:FireClient(player, "Toast", "+1 Revive Flare! It's in your pack for the next descent")
		else
			Net.Notify:FireClient(player, "Toast", "Join the group first!")
		end
	end)

	Net.GetProfile.OnServerInvoke = function(player)
		local p = Data.get(player) or Data.load(player)
		return p and Data.snapshot(p) or nil
	end
	Data.Changed:Connect(function(player, p)
		if player.Parent then
			Net.Profile:FireClient(player, Data.snapshot(p))
		end
	end)
	-- (loading on join is Data.start's job)
end

return Rewards
