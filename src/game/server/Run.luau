--[[
	The run's flow, matching the reference (docs/match-spec.md §2):
	  Spawn -> Moving -> Stop (camp: Night -> Morning; landing) -> Leaving -> Moving ... -> Complete
	  * each leg has a glow timer ("Reach camp before Lights Out!"), which drives
	    the day badge and the colour grade;
	  * the rig stops dead at named stops; glowstone is mined there, from veins;
	  * camps hold a night: the night bar runs faster with the whole crew in the
	    Beacon's ring and the Beacon fed (+0.1x per glowstone, up to 2.9x);
	  * leaving needs 3 of 4 aboard (a 30 s countdown, 3 s once everyone is on;
	    15 s at the spawn). Nobody can hold the rig hostage: it leaves anyway.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)

local Run = {}

local rig, route, state, World, Crew
local glowDuration, glowLeft = 1, 1
local nightMult, feeds, lastDecay = 1, 0, 0
local fuel = 0
local phaseStarted = os.clock()
local currentStop = nil
local leg = 1

local function set(k: string, v: any)
	state:SetAttribute(k, v)
end

local function phase(p: string)
	set("Phase", p)
	phaseStarted = os.clock()
end

local function objective(text: string?, value: string?, color: string?, icon: string?)
	set("Objective", text or "")
	set("ObjectiveValue", value or "")
	set("ObjectiveColor", color or "white")
	set("ObjectiveIcon", icon or "")
end

local function crew(): { Player }
	return Players:GetPlayers()
end

local function aboardCount(): (number, number)
	local n, on = 0, 0
	for _, p in crew() do
		n += 1
		if Crew.isAboard(p) then
			on += 1
		end
	end
	return on, n
end

local function startLeg()
	local stop = route:nextStop(rig.s)
	if not stop then
		return
	end
	-- the glow lasts a little longer than the leg takes at a crew's normal pace
	glowDuration = math.max(45, (stop.s - rig.s) / 34 * 1.2)
	glowLeft = glowDuration
	currentStop = stop
	rig:stopFor(stop.s)
	set("NextStop", stop.name)
	set("NextStopS", stop.s)
end

local function depart()
	set("NightLeave", false)
	phase("Moving")
	rig:repairAll()
	rig:showGhosts(false)
	rig.moving = true
	set("Countdown", 0)
	Net.Notify:FireAllClients("Depart")
	startLeg()
end

-- boarding: the reference's BOARD / LEAVING IN 30 / ALL ABOARD flow
local leaveAt = nil
local forceLeaveAt = nil
local function boarding(dt: number, spawn: boolean)
	local on, n = aboardCount()
	local need = math.max(1, math.ceil(n * Config.BOARD_FRACTION))
	set("Aboard", on)
	set("CrewSize", n)
	set("Need", need)
	local now = os.clock()
	if on >= n and n > 0 then
		leaveAt = math.min(leaveAt or math.huge, now + Config.LEAVE_COUNTDOWN_ALL)
		set("Boarding", "AllAboard")
	elseif on >= need or (forceLeaveAt and now >= forceLeaveAt) then
		leaveAt = leaveAt or (now + (spawn and Config.LEAVE_COUNTDOWN_SPAWN or Config.LEAVE_COUNTDOWN))
		set("Boarding", "Leaving")
	else
		leaveAt = nil
		set("Boarding", "Board")
	end
	set("Countdown", leaveAt and math.max(0, math.ceil(leaveAt - now)) or 0)
	if leaveAt and now >= leaveAt then
		leaveAt = nil
		forceLeaveAt = nil
		set("Boarding", "")
		depart()
	end
end

local function arrive()
	local stop = currentStop
	if not stop then
		return
	end
	set("StopName", stop.name)
	set("StopKind", stop.kind)
	Net.Notify:FireAllClients("StopName", stop.name)
	if stop.save then
		-- a mid-zone Waystation: the run can carry on from here next time (GDD 9.1)
		set("SavedAt", (route.mileStart or 0) + stop.s / Config.STUDS_PER_MILE)
		task.delay(2.4, function()
			Net.Notify:FireAllClients("Banner", "Progress saved at " .. stop.name)
		end)
	end
	set("RepairNeed", rig:brokenCount() * Config.Rig.REPAIR_PER_PIECE)
	set("RepairHave", 0)
	if rig:brokenCount() > 0 then
		rig:showGhosts(true)
		task.delay(2.2, function()
			Net.Notify:FireAllClients("Banner", "Repair your rig with glowstone!")
		end)
	end
	if stop.kind == "waystation" then
		phase("Complete")
		objective(stop.name .. " reached!", "", "white", "Day")
		Net.Notify:FireAllClients("ZoneComplete", Config.ZONES[route.zone or 1].name)
	elseif stop.kind == "camp" then
		phase("Night")
		set("CampsThisRun", (state:GetAttribute("CampsThisRun") or 0) + 1)
		local b = World.beacons[stop.name]
		if b then
			set("BeaconPos", b.Position)
		end
		set("NightProgress", 0)
		nightMult, feeds = 1, 0
		fuel = Config.Night.FUEL_START
		objective("He fears the light. Get inside the Beacon's glow", "", "orange", "Beacon")
	else
		phase("Stop")
		objective("Mine glowstone, then board the rig!", "", "white", "Glowstone")
		forceLeaveAt = os.clock() + 75
	end
end

function Run.init(theRig, theRoute, theState, theWorld, theCrew)
	rig, route, state, World, Crew = theRig, theRoute, theState, theWorld, theCrew
	phase("Spawn")
	objective("Mine glowstone", "0/12", "white", "Glowstone")
	set("Glow", 1)
	forceLeaveAt = os.clock() + 75
end

-- "Leave camp now" on the rig at night, once it's repaired
function Run.leaveNight(player: Player)
	if state:GetAttribute("Phase") ~= "Night" or (state:GetAttribute("RepairNeed") or 0) > 0 or state:GetAttribute("NightLeave") then
		return
	end
	set("NightLeave", true)
	Net.Notify:FireAllClients("Banner", player.DisplayName .. " wants to push on through the dark! Board the rig")
end

-- (Studio jumps: aim at whatever stop is next from here, and ride on)
function Run.retarget()
	startLeg()
	if state:GetAttribute("Phase") ~= "Moving" then
		phase("Moving")
		rig.moving = true
	end
end

function Run.onArrived()
	arrive()
end

-- feeding the Beacon: +0.1x and a few seconds of fuel per glowstone
function Run.feed(player: Player)
	if state:GetAttribute("Phase") ~= "Night" then
		return
	end
	local have = player:GetAttribute("Glowstone") or 0
	if have <= 0 then
		Net.Notify:FireClient(player, "Toast", "You need glowstone! Mine the veins")
		return
	end
	player:SetAttribute("Glowstone", have - 1)
	fuel = math.min(fuel + Config.Night.FUEL_PER_GLOWSTONE, 60)
	feeds += 1
	nightMult = math.min(Config.Night.MAX_MULT, nightMult + Config.Night.PER_FEED)
	lastDecay = os.clock()
	Net.Notify:FireAllClients("Fed", Config.Night.PER_FEED)
end

-- repairing the rig at a stop: deposit glowstone until the ghosts are paid for
function Run.repair(player: Player)
	local need = state:GetAttribute("RepairNeed") or 0
	local have = state:GetAttribute("RepairHave") or 0
	if need <= 0 or have >= need then
		return
	end
	local mine = player:GetAttribute("Glowstone") or 0
	local give = math.min(mine, need - have)
	if give <= 0 then
		Net.Notify:FireClient(player, "Toast", "You need glowstone! Mine the veins")
		return
	end
	player:SetAttribute("Glowstone", mine - give)
	have += give
	set("RepairHave", have)
	if have >= need then
		rig:repairAll()
		set("RepairNeed", 0)
		Net.Notify:FireAllClients("Banner", "Rig repaired!")
	end
end

function Run.step(dt: number)
	local p = state:GetAttribute("Phase")
	local now = os.clock()
	if p == "Spawn" then
		boarding(dt, true)
		-- the spawn objective counts your own glowstone up to 12, then says board
		local first = crew()[1]
		local g = first and first:GetAttribute("Glowstone") or 0
		if g < 12 then
			objective("Mine glowstone", math.min(g, 12) .. "/12", "white", "Glowstone")
		else
			objective("Board the rig!", "", "white", "Day")
		end
	elseif p == "Moving" then
		glowLeft = math.max(0, glowLeft - dt)
		local glow = glowLeft / glowDuration
		set("Glow", glow)
		local stop = currentStop
		local miles = stop and (stop.s - rig.s) / Config.STUDS_PER_MILE or 0
		local value = string.format("%.1f mi", math.max(0, miles))
		if glow <= 0 then
			objective("He's hunting! Get to camp", value, "red", "Night")
		elseif glow < 0.4 then
			objective(stop and stop.kind == "camp" and "Reach camp before Lights Out!" or "Lights Out soon!", value, miles < 0.2 and "red" or "orange", "Night")
		elseif leg == 1 then
			objective("Drill to " .. (stop and stop.name or "camp"), value, "white", "Crank")
		else
			objective(nil)
		end
	elseif p == "Night" then
		-- the night bar: faster with everyone in the ring and the Beacon fed
		fuel = math.max(0, fuel - dt)
		local inRing, n = 0, 0
		local beacon = World.beacons[state:GetAttribute("StopName")]
		for _, pl in crew() do
			n += 1
			local root = pl.Character and pl.Character:FindFirstChild("HumanoidRootPart")
			if beacon and root and (root.Position - beacon.Position).Magnitude <= Config.Night.RING then
				inRing += 1
			end
		end
		set("InRing", inRing)
		set("CrewSize", n)
		if now - lastDecay > Config.Night.DECAY_EVERY then
			lastDecay = now
			nightMult = math.max(1, nightMult - 0.1)
		end
		local mult = (inRing >= n and fuel > 0) and nightMult or 1
		set("NightMult", mult)
		set("BeaconFuel", fuel)
		local prog = (state:GetAttribute("NightProgress") or 0) + Config.Night.BASE_RATE * mult * dt
		set("NightProgress", math.min(100, prog))
		set("Glow", 0)
		if fuel <= 0 then
			objective("The Beacon's out! Feed it glowstone", "", "red", "Beacon")
			-- the dark hurts anyone outside the light
			for _, pl in crew() do
				local hum = pl.Character and pl.Character:FindFirstChildOfClass("Humanoid")
				if hum then
					hum.Health = math.max(1, hum.Health - hum.MaxHealth * 0.02 * dt)
				end
			end
		elseif inRing < n then
			objective("Get by the Beacon to speed up the night", (n - inRing) .. " more", "orange", "Beacon")
		else
			objective("Feed the Beacon to go faster", "", "white", "Beacon")
		end
		-- the crew can push on through the dark once the rig is repaired (owner):
		-- someone presses "Leave camp now" on the rig, then it's the usual boarding
		if state:GetAttribute("NightLeave") and (state:GetAttribute("RepairNeed") or 0) <= 0 then
			boarding(dt, false)
			if state:GetAttribute("Phase") == "Moving" then
				leg += 1
				set("Leg", leg)
				return
			end
		elseif leaveAt or state:GetAttribute("Boarding") ~= "" then
			leaveAt = nil
			set("Boarding", "")
			set("Countdown", 0)
		end
		if prog >= 100 then
			phase("Morning")
			leg += 1
			set("Glow", 1)
			forceLeaveAt = now + 60
			objective("Morning! Back on the rig", "", "white", "Day")
			Net.Notify:FireAllClients("Banner", "Morning!")
		end
	elseif p == "Morning" or p == "Stop" then
		boarding(dt, false)
	end
	set("Leg", leg)
end

return Run
