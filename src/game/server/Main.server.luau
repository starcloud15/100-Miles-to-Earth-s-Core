--[[
	The Game place: one party's descent (M0: zone 1, Sunfall Gorge, to
	Waystation 1). The lobby teleports a party here into a reserved server
	with { seed, size } as teleport data; played straight from Studio, it
	makes up a seed and departs after a short countdown.
]]

local Players = game:GetService("Players")
local PhysicsService = game:GetService("PhysicsService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Route = require(Shared.Route)
local Net = require(Shared.Net)
local World = require(script.Parent.World)
local Rig = require(script.Parent.Rig)
local Crew = require(script.Parent.Crew)

-- the rig passes through the cavern (it follows the route); players collide with both
for _, g in { "World", "Rig", "Crew" } do
	PhysicsService:RegisterCollisionGroup(g)
end
PhysicsService:CollisionGroupSetCollidable("Rig", "World", false)

Players.RespawnTime = 2

-- the old template baseplate would cut across the route
for _, name in { "Baseplate", "SpawnLocation" } do
	local p = workspace:FindFirstChild(name)
	if p then
		p:Destroy()
	end
end

-- the seed comes with the party from the lobby
local first = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local seed, expected = math.random(1, 2 ^ 30), 0
local data = first:GetJoinData().TeleportData
if type(data) == "table" then
	seed = tonumber(data.seed) or seed
	expected = tonumber(data.size) or 0
end

local state = Instance.new("Folder")
state.Name = "RunState"
state:SetAttribute("Seed", seed)
state:SetAttribute("Miles", Config.PROTOTYPE_MILES)
state:SetAttribute("Phase", "Boarding")
state.Parent = ReplicatedStorage

local route = Route.new(seed, Config.PROTOTYPE_MILES)
World.init(route)
World.update(0)

local rig
rig = Rig.new(route, function(kind, data)
	if kind == "Pickup" then
		World.collect(data.id)
		Net.Notify:FireAllClients("Glowstone", data.amount)
	elseif kind == "Hit" then
		Net.Notify:FireAllClients("Hit", data.kind)
		Crew.onHazard()
	elseif kind == "Damage" and data.why == "Scrape" then
		Net.Notify:FireAllClients("Scrape")
	end
end)
state:SetAttribute("RouteLength", route.length)
Crew.init(rig, route, state)
if RunService:IsStudio() then
	-- playtest handle: set RunState's DebugJump attribute (on the server) to a
	-- distance, or to a piece name ("Drop", "Fork"), to move the rig there
	state:GetAttributeChangedSignal("DebugJump"):Connect(function()
		local to = state:GetAttribute("DebugJump")
		for _, pc in route.pieces do
			if pc.kind == to then
				to = pc.s0 + 40
				break
			end
		end
		if type(to) == "number" then
			rig.s = math.clamp(to, 0, route.length)
			task.delay(0.5, Crew.boardAll)
		end
	end)
end

local function publish()
	state:SetAttribute("Distance", rig.s)
	state:SetAttribute("Speed", rig.speed)
	state:SetAttribute("PowerL", rig.pL)
	state:SetAttribute("PowerR", rig.pR)
	state:SetAttribute("Synced", rig.synced)
	state:SetAttribute("Health", rig.health)
	state:SetAttribute("MaxHealth", Config.Rig.MAX_HEALTH)
	state:SetAttribute("Glowstone", rig.glowstone)
	state:SetAttribute("Lateral", rig.x)
end

local acc = 0
RunService.Heartbeat:Connect(function(dt)
	rig:step(dt)
	World.update(rig.s, 3)
	Crew.step(dt)
	acc += dt
	if acc > 0.1 then
		acc = 0
		publish()
	end
end)

-- boarding: depart after the countdown, sooner once the whole party is here
task.spawn(function()
	local t = Config.DEPART_COUNTDOWN
	while t > 0 do
		state:SetAttribute("Countdown", t)
		task.wait(1)
		t -= 1
		if expected > 0 and #Players:GetPlayers() >= expected and t > 5 then
			t = 5
		end
	end
	state:SetAttribute("Countdown", 0)
	state:SetAttribute("Phase", "Moving")
	rig.moving = true
	Crew.depart()
	Net.Notify:FireAllClients("Depart")

	-- the end of zone 1: Waystation 1
	while rig.s < route.length - 2 do
		task.wait(0.5)
	end
	rig.moving = false
	state:SetAttribute("Phase", "Complete")
	Net.Notify:FireAllClients("ZoneComplete", Config.ZONES[1].name)
	task.wait(20)
	if not RunService:IsStudio() then
		pcall(function()
			TeleportService:TeleportAsync(Config.LOBBY_PLACE_ID, Players:GetPlayers())
		end)
	end
end)
