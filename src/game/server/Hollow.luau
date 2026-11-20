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

function Hollow.init(theRig, theRoute, theState)
	rig, route, state = theRig, theRoute, theState
	set("Hidden")
end

function Hollow.step(_dt: number)
	local now = os.clock()
	local phase = state:GetAttribute("Phase")

	if phase == "Night" then
		local st = stopHere()
		if not st then
			set("Hidden")
			return
		end
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
