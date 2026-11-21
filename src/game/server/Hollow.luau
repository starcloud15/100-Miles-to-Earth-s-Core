--[[
	The Hollow (GDD 10.1, docs/story.md): the fallen Heart Keeper that eats light.

	Zone 1 teaches the rules safely: it never attacks (GDD: "Camps 1-3: not
	aggressive. It watches from the edge of the light"). What it does here:
	  Glimpse: once about 1:20 into the run (instead of a cutscene) and again
	           while the glow dims, it stands far down the route for a moment,
	           then vanishes in a flash of crystal light.
	  Watch:   on a camp night it stands at the edge of the light (a tunnel
	           mouth, or out on the causeway at a cavern stop), turning to
	           follow the crew.
	  Reach:   if the Beacon goes out it steps in closer. (From zone 3 this is
	           where it would grab: the same SPAM! QTE as the creatures.)

	The server only decides where it stands: RunState attributes HollowMode
	("Hidden" / "Glimpse" / "Watch" / "Reach") and HollowCF. Each client draws
	and animates it (client/Creatures.luau).
]]

local Hollow = {}

local rig, route, state
local rng = Random.new()
local started = os.clock()
local firstGlimpse = false
local nextGlimpse = math.huge
local glimpseUntil = 0
local watchSide, watchSwap = 1, 0

-- GDD 10.1: zones 1-2 never grab; zone 3 hunts at camp, slowly; faster each zone after
local HUNT_SPEED = { 0, 0, 9, 13, 17, 24 }
local hunting = nil -- { player, cf } while it stalks someone outside the light
local huntRest = 0
local Creatures -- set by init (avoids a require loop)
local Players = game:GetService("Players")
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config)

local GLIMPSE_AT = 80 -- seconds into the run (GDD 7: "glimpsed from the rig at 1:20")
local GLIMPSE_FOR = 3.5

local function set(mode: string, cf: CFrame?)
	if state:GetAttribute("HollowMode") ~= mode then
		state:SetAttribute("HollowMode", mode)
	end
	if cf then
		state:SetAttribute("HollowCF", cf)
	end
end

-- standing on the route floor at distance s, offset sideways, facing back up the route
local function standAt(s: number, side: number): CFrame
	local cf, w = route:sample(s)
	local kind = route:kindAt(s)
	local x = kind == "Gorge" and (w / 2 + 6) or w * 0.32
	local p = (cf * CFrame.new(side * x, 0, 0)).Position
	local back = (route:sample(s - 40)).Position
	return CFrame.lookAt(p, Vector3.new(back.X, p.Y, back.Z))
end

local function stopHere()
	for _, st in route.stops do
		if math.abs(st.s - rig.s) < 40 then
			return st
		end
	end
	return nil
end

function Hollow.init(theRig, theRoute, theState, theCreatures)
	rig, route, state, Creatures = theRig, theRoute, theState, theCreatures
	set("Hidden")
end

-- someone outside the Beacon's light (anyone, once the Beacon is out)
local function prey(beacon: Vector3, from: Vector3, out: boolean): (Player?, BasePart?)
	local best, bestRoot, bestD = nil, nil, 140
	for _, p in Players:GetPlayers() do
		local c = p.Character
		local root = c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
		local hum = c and c:FindFirstChildOfClass("Humanoid")
		if root and hum and hum.Health > 0 then
			local outside = (root.Position - beacon).Magnitude > Config.Night.RING
			local d = (root.Position - from).Magnitude
			if (outside or out) and d < bestD then
				best, bestRoot, bestD = p, root, d
			end
		end
	end
	return best, bestRoot
end

function Hollow.step(dt: number)
	local now = os.clock()
	local phase = state:GetAttribute("Phase")

	if phase == "Night" then
		local st = stopHere()
		if not st then
			set("Hidden")
			return
		end
		local zone = state:GetAttribute("Zone") or 1
		local speed = HUNT_SPEED[math.clamp(zone, 1, #HUNT_SPEED)] * (1 + 0.08 * ((state:GetAttribute("CampsThisRun") or 0)))
		local beacon = state:GetAttribute("BeaconPos")
		local out = (state:GetAttribute("BeaconFuel") or 1) <= 0
		-- zone 6: it hunts in the dark gaps between the Core's pulses
		local gap = zone ~= 6 or state:GetAttribute("Pulse") == "Dark"
		if speed > 0 and beacon and now > huntRest and gap then
			local from = hunting and hunting.cf.Position or (state:GetAttribute("HollowCF") or CFrame.new(beacon)).Position
			local p, root = prey(beacon, from, out and zone >= 4)
			if p and root then
				-- stalk them across the ground, then reach
				local cur = hunting and hunting.cf or (state:GetAttribute("HollowCF") or CFrame.new(from))
				local to = Vector3.new(root.Position.X, cur.Position.Y, root.Position.Z)
				local step = to - cur.Position
				local pos = cur.Position + (step.Magnitude > 0.01 and step.Unit * math.min(step.Magnitude, speed * dt) or Vector3.zero)
				hunting = { player = p, cf = CFrame.lookAt(pos, to) }
				set("Hunt", hunting.cf)
				if step.Magnitude < 9 then
					if Creatures and Creatures.hollowGrab(p) then
						huntRest = now + 14
						hunting = nil
					end
				end
				return
			end
		end
		hunting = nil
		-- at the edge of the light: a tunnel mouth (or the causeway at a cavern
		-- stop), changing ends now and then
		if now > watchSwap then
			watchSwap = now + rng:NextNumber(22, 34)
			watchSide = -watchSide
		end
		local out = (state:GetAttribute("BeaconFuel") or 1) <= 0
		local z = (out and 58 or 96) * watchSide
		local cf = route:sample(st.s)
		local p = (cf * CFrame.new(out and -10 or 0, 0, z)).Position
		local beacon = state:GetAttribute("BeaconPos") or cf.Position
		set(out and "Reach" or "Watch", CFrame.lookAt(p, Vector3.new(beacon.X, p.Y, beacon.Z)))
		return
	end

	if phase ~= "Moving" then
		set("Hidden")
		return
	end

	if now < glimpseUntil then
		return
	end
	if state:GetAttribute("HollowMode") == "Glimpse" then
		set("Hidden")
	end
	local glow = state:GetAttribute("Glow") or 1
	local want = false
	if not firstGlimpse and now - started > GLIMPSE_AT then
		firstGlimpse = true
		want = true
	elseif glow < 0.45 then
		if nextGlimpse == math.huge then
			nextGlimpse = now + rng:NextNumber(8, 16)
		elseif now > nextGlimpse then
			nextGlimpse = now + rng:NextNumber(35, 55)
			want = true
		end
	else
		nextGlimpse = math.huge
	end
	if want then
		local ahead = rig.s + rng:NextNumber(150, 220)
		if ahead < route.length - 50 then
			glimpseUntil = now + GLIMPSE_FOR
			set("Glimpse", standAt(ahead, rng:NextNumber() < 0.5 and -1 or 1))
		end
	end
end

return Hollow
