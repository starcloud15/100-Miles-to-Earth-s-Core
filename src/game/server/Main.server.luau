--[[
	The Game place: one party's descent (M1: zone 1, Sunfall Gorge, to
	Waystation 1), matching the reference's flow (docs/match-spec.md). The
	lobby teleports a party here into a reserved server with { seed, size };
	played straight from Studio, it makes up a seed.
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
local Run = require(script.Parent.Run)
local Creatures = require(script.Parent.Creatures)
local Hollow = require(script.Parent.Hollow)
local Progress = require(script.Parent.Progress)

for _, g in { "World", "Rig", "Crew", "Barrier" } do
	PhysicsService:RegisterCollisionGroup(g)
end
PhysicsService:CollisionGroupSetCollidable("Rig", "World", false)
-- the edge walls only stop the crew
for _, g in { "World", "Rig", "Default", "Barrier" } do
	PhysicsService:CollisionGroupSetCollidable("Barrier", g, false)
end
Players.RespawnTime = 2

for _, name in { "Baseplate", "SpawnLocation" } do
	local p = workspace:FindFirstChild(name)
	if p then
		p:Destroy()
	end
end

local first = Players:GetPlayers()[1] or Players.PlayerAdded:Wait()
local seed = math.random(1, 2 ^ 30)
local zone, startMile = 1, nil
local data = first:GetJoinData().TeleportData
if type(data) == "table" then
	seed = tonumber(data.seed) or seed
	zone = tonumber(data.zone) or zone
	startMile = tonumber(data.mile)
end
if RunService:IsStudio() then
	-- playtest a later zone: set the Game place's Workspace attributes StartZone (and StartMile
	-- for a mid-zone Waystation)
	zone = workspace:GetAttribute("StartZone") or zone
	startMile = workspace:GetAttribute("StartMile") or startMile
end
zone = math.clamp(math.floor(zone), 1, Config.BUILT_ZONES)
local zoneStart = Config.zoneStart(zone)
local zoneEnd = zoneStart + Config.ZONES[zone].miles
if not startMile or startMile <= zoneStart or startMile >= zoneEnd then
	startMile = zoneStart
end

local state = Instance.new("Folder")
state.Name = "RunState"
state:SetAttribute("Seed", seed)
state:SetAttribute("Zone", zone)
state:SetAttribute("MileOffset", startMile)
state:SetAttribute("Miles", zoneEnd - startMile)
state.Parent = ReplicatedStorage

local route = Route.new(seed, zoneEnd - startMile, zone, startMile)
state:SetAttribute("RouteLength", route.length)
World.init(route)
World.update(0)

local rig
rig = Rig.new(route, function(kind, info)
	if kind == "Hit" then
		Net.Notify:FireAllClients("Hit", info.kind)
		Crew.onHazard()
	elseif kind == "Arrived" then
		Run.onArrived()
	end
end)
World.spawnVeins(route:sample(40))
Crew.init(rig, route, state, World)
Run.init(rig, route, state, World, Crew)
Creatures.init(rig, route, state, Crew)
Hollow.init(rig, route, state, Creatures)
Progress.init(rig, state, World)

-- the Beacons' feed prompts and the rig's repair prompt
local repair = Instance.new("ProximityPrompt")
repair.Name = "RepairPrompt"
repair.ActionText = "Repair Rig"
repair.ObjectText = "Glowstone"
repair.MaxActivationDistance = 14
repair.RequiresLineOfSight = false
repair.Enabled = false
repair.Parent = rig.deck
repair.Triggered:Connect(function(player)
	Run.repair(player)
end)
-- at night, once the rig is repaired, the crew may leave camp early (owner)
local leave = Instance.new("ProximityPrompt")
leave.Name = "LeavePrompt"
leave.ActionText = "Leave camp now"
leave.ObjectText = "Rig"
leave.KeyboardKeyCode = Enum.KeyCode.F
leave.HoldDuration = 1
leave.MaxActivationDistance = 14
leave.RequiresLineOfSight = false
leave.Enabled = false
leave.Parent = rig.deck
leave.Triggered:Connect(function(player)
	Run.leaveNight(player)
end)
local feedHooked = {}
local function hookBeacons()
	for _, b in World.beacons do
		local prompt = b:FindFirstChild("FeedPrompt")
		if prompt and not feedHooked[prompt] then
			feedHooked[prompt] = true
			prompt.Triggered:Connect(function(player)
				Run.feed(player)
			end)
		end
	end
end

local function publish()
	state:SetAttribute("Distance", rig.s)
	state:SetAttribute("Speed", rig.speed)
	state:SetAttribute("PowerL", rig.pL)
	state:SetAttribute("PowerR", rig.pR)
	state:SetAttribute("Synced", rig.synced)
	state:SetAttribute("Moving", rig.moving)
	state:SetAttribute("Lateral", rig.x)
	local need = state:GetAttribute("RepairNeed") or 0
	repair.Enabled = not rig.moving and need > 0
	leave.Enabled = state:GetAttribute("Phase") == "Night" and need <= 0 and not state:GetAttribute("NightLeave")
	repair.ObjectText = string.format("%d / %d", state:GetAttribute("RepairHave") or 0, need)
end

if RunService:IsStudio() then
	-- playtest handle: set RunState's DebugJump (on the server) to a distance or a piece kind
	state:GetAttributeChangedSignal("DebugJump"):Connect(function()
		local to = state:GetAttribute("DebugJump")
		for _, pc in route.pieces do
			if pc.kind == to then
				to = pc.s0 - 30
				break
			end
		end
		if type(to) == "number" then
			rig.s = math.clamp(to, 0, route.length)
			Run.retarget()
			World.update(rig.s)
			World.carve(rig.s + 14)
			task.delay(0.5, Crew.boardAll)
		end
	end)
end

local acc, lightAcc = 0, 0
local wasMoving = false
RunService.Heartbeat:Connect(function(dt)
	rig:step(dt)
	World.update(rig.s, 3)
	-- the drill breaks the rock just ahead of its bit
	local what = World.carve(rig.s + Config.Rig.DECK_L / 2 + 8)
	rig:drilling(what)
	local here = route:kindAt(rig.s)
	rig:pebbles(dt, here == "Tunnel" or here == "Chute")
	if what == "breakthrough" then
		Net.Notify:FireAllClients("Breakthrough")
	end
	Crew.step(dt)
	Run.step(dt)
	Creatures.step(dt)
	Hollow.step(dt)
	if rig.moving and not wasMoving then
		Crew.depart()
	end
	wasMoving = rig.moving
	acc += dt
	if acc > 0.1 then
		acc = 0
		publish()
		hookBeacons()
		Progress.step()
	end
	lightAcc += dt
	if lightAcc > 0.15 then
		lightAcc = 0
		World.atmosphere(rig.s, state:GetAttribute("Glow") or 1)
	end
end)

-- back to the lobby after Waystation 1
state:GetAttributeChangedSignal("Phase"):Connect(function()
	if state:GetAttribute("Phase") == "Complete" then
		task.wait(20)
		if not RunService:IsStudio() then
			local options = Instance.new("TeleportOptions")
			options:SetTeleportData({ fromRun = true })
			pcall(function()
				TeleportService:TeleportAsync(Config.LOBBY_PLACE_ID, Players:GetPlayers(), options)
			end)
		end
	end
end)
