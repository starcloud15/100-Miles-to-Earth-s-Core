--[[
	Creatures that get onto the rig (owner: "mobs that take the roles of the
	reference's crocodiles and snakes that fall on the raft... you have to spam
	to get them off. They can also hurt you").

	Two roles per zone, like the reference's piranhas/eels and gators:
	  Board: drops from the roof onto the deck, slows the rig and bites whoever
	         is nearest. Anyone clicks its SPAM! button: "KNOCKED OFF!".
	  Grab:  bursts from the wall and seizes one of the crew, draining Health.
	         SPAM! (the victim and crewmates both) for "BROKE FREE!", or it drags
	         the victim off the rig.

	The server keeps the state as attributes on RunState.Creatures/<id>; every
	client draws the creature itself, relative to the deck it sees (smooth, and
	nothing gets welded to the rig's assembly).
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local C = Config.Creatures
local Creatures = {}

local rig, route, state, Crew
local folder: Folder
local live = {} -- [Configuration] = { kind, mode, t, bite, target }
local nextId = 0
local rng = Random.new()
local nextBoard, nextGrab = 0, 0
local clickLog = {} -- [Player] = { t0, n }

local UNDERGROUND = { Tunnel = true, Chute = true, Cavern = true, Hall = true, HallRamp = true }

local function rootOf(player: Player): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function aboardPlayers(): { Player }
	local list = {}
	for _, p in Players:GetPlayers() do
		if Crew.isAboard(p) then
			table.insert(list, p)
		end
	end
	return list
end

local function zoneCreatures()
	return C.ZONES[math.clamp(state:GetAttribute("Zone") or 1, 1, #C.ZONES)]
end

local function spawn(kind: string, mode: string, attrs: { [string]: any })
	nextId += 1
	local f = Instance.new("Configuration")
	f.Name = tostring(nextId)
	f:SetAttribute("Kind", kind)
	f:SetAttribute("Mode", mode)
	f:SetAttribute("Need", mode == "Grab" and C.GRAB_CLICKS or C.BOARD_CLICKS)
	f:SetAttribute("Hits", 0)
	f:SetAttribute("Phase", "On")
	f:SetAttribute("Born", workspace:GetServerTimeNow())
	for k, v in attrs do
		f:SetAttribute(k, v)
	end
	live[f] = { kind = kind, mode = mode, t = 0, bite = C.BITE_EVERY * 0.8, target = attrs.Target }
	f.Parent = folder
	return f
end

-- Phase: KnockedOff / BrokeFree (SPAM! won), Dragged (the grab won), Gone (it left)
local function finish(f: Configuration, how: string)
	if not live[f] then
		return
	end
	live[f] = nil
	f:SetAttribute("Phase", how)
	f:SetAttribute("Ended", workspace:GetServerTimeNow())
	task.delay(2, function()
		f:Destroy()
	end)
end

local function boarders(): number
	local n = 0
	for _, c in live do
		if c.mode == "Board" then
			n += 1
		end
	end
	return n
end

local function spawnBoarder()
	local R = Config.Rig
	spawn(zoneCreatures().board, "Board", {
		OffX = rng:NextNumber(-R.DECK_W / 2 + 2.5, R.DECK_W / 2 - 2.5),
		OffZ = rng:NextNumber(-R.DECK_L / 2 + 3, R.DECK_L / 2 - 4),
		Yaw = rng:NextNumber(0, math.pi * 2),
	})
end

local function spawnGrabber(): boolean
	local crew = aboardPlayers()
	if #crew == 0 then
		return false
	end
	local victim = crew[rng:NextInteger(1, #crew)]
	for _, c in live do
		if c.target == victim.UserId then
			return false
		end
	end
	local root = rootOf(victim)
	local side = 1
	if root then
		side = rig.deck.CFrame:PointToObjectSpace(root.Position).X >= 0 and 1 or -1
	end
	spawn(zoneCreatures().grab, "Grab", { Target = victim.UserId, Side = side })
	return true
end

function Creatures.init(theRig, theRoute, theState, theCrew)
	rig, route, state, Crew = theRig, theRoute, theState, theCrew
	folder = Instance.new("Folder")
	folder.Name = "Creatures"
	folder.Parent = state
	local now = os.clock()
	nextBoard = now + rng:NextNumber(C.BOARD_EVERY[1], C.BOARD_EVERY[2])
	nextGrab = now + rng:NextNumber(C.GRAB_EVERY[1], C.GRAB_EVERY[2])

	Net.Spam.OnServerEvent:Connect(function(player, id)
		if type(id) ~= "string" then
			return
		end
		local f = folder:FindFirstChild(id)
		if not f or not live[f] then
			return
		end
		-- count at most CLICK_RATE clicks a second, from anyone near the rig
		local root = rootOf(player)
		if not root or (root.Position - rig.deck.Position).Magnitude > 40 then
			return
		end
		local t = os.clock()
		local log = clickLog[player]
		if not log or t - log.t0 > 1 then
			log = { t0 = t, n = 0 }
			clickLog[player] = log
		end
		log.n += 1
		if log.n > C.CLICK_RATE then
			return
		end
		local hits = f:GetAttribute("Hits") + 1
		f:SetAttribute("Hits", hits)
		if hits >= f:GetAttribute("Need") then
			f:SetAttribute("By", player.UserId)
			finish(f, f:GetAttribute("Mode") == "Grab" and "BrokeFree" or "KnockedOff")
			player:SetAttribute("Knocked", (player:GetAttribute("Knocked") or 0) + 1)
		end
	end)
	if RunService:IsStudio() then
		-- playtest handle: set RunState's DebugCreature to "Board" or "Grab"
		state:GetAttributeChangedSignal("DebugCreature"):Connect(function()
			local what = state:GetAttribute("DebugCreature")
			state:SetAttribute("DebugCreature", nil)
			if what == "Board" then
				spawnBoarder()
			elseif what == "Grab" then
				spawnGrabber()
			end
		end)
	end
	Players.PlayerRemoving:Connect(function(p)
		clickLog[p] = nil
		for f, c in live do
			if c.target == p.UserId then
				finish(f, "Gone")
			end
		end
	end)
end

function Creatures.step(dt: number)
	local now = os.clock()
	local kind = route:kindAt(rig.s)
	local active = rig.moving and UNDERGROUND[kind] and rig.s > C.FIRST_MILE * Config.STUDS_PER_MILE

	if active and #aboardPlayers() > 0 then
		if now >= nextBoard then
			nextBoard = now + rng:NextNumber(C.BOARD_EVERY[1], C.BOARD_EVERY[2])
			if boarders() < 2 then
				spawnBoarder()
			end
		end
		if now >= nextGrab then
			nextGrab = now + rng:NextNumber(C.GRAB_EVERY[1], C.GRAB_EVERY[2])
			spawnGrabber()
		end
	else
		-- at stops and on the surface the clocks wait
		nextBoard = math.max(nextBoard, now + 6)
		nextGrab = math.max(nextGrab, now + 12)
	end

	local riding = 0
	for f, c in live do
		c.t += dt
		if c.mode == "Board" then
			riding += 1
			if c.t > C.BOARD_LIFE or not rig.moving then
				finish(f, "Gone")
				continue
			end
			-- bite the nearest of the crew, once it has landed
			c.bite -= dt
			if c.t > 0.8 and c.bite <= 0 then
				c.bite = C.BITE_EVERY
				local at = rig.deck.CFrame * Vector3.new(f:GetAttribute("OffX"), 1, f:GetAttribute("OffZ"))
				local best, bestD = nil, C.BITE_RANGE
				for _, p in aboardPlayers() do
					local r = rootOf(p)
					local d = r and (r.Position - at).Magnitude or math.huge
					if d < bestD then
						best, bestD = p, d
					end
				end
				if best then
					f:SetAttribute("Bites", (f:GetAttribute("Bites") or 0) + 1)
					Crew.hurt(best, C.BITE, "Bitten")
				end
			end
		else
			local victim = Players:GetPlayerByUserId(c.target)
			if not victim or not Crew.isAboard(victim) then
				finish(f, "Gone")
				continue
			end
			if c.t > 0.5 then
				Crew.hurt(victim, C.GRAB_DPS * dt, nil)
			end
			if c.t > C.GRAB_TIME then
				finish(f, "Dragged")
				Crew.throwOff(victim)
			end
		end
	end
	rig.drag = riding > 0 and C.DRAG or 1
end

return Creatures
