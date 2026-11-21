--[[
	Zone 6's rule, Pulses (GDD 9.1: "the light comes in beats, so move between
	them"; 10.1: "the Hollow hunts every pulse").

	The Core breathes: a beat of golden light, a moment of fading, then a gap of
	dark. RunState's "Pulse" is "Light", "Fading" or "Dark".
	  * In the dark, the Dark meter (the zone's stat bar) fills unless you're in
	    light: the middle of the rig, by its furnace lamp, or the Beacon's ring.
	  * At camp the Hollow only hunts in the dark gaps (Hollow.luau).
	  * The lighting swells and drops with the beat (World.atmosphere).
]]

local Net = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Net)
local Config = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Config)

local Pulses = {}

local state
local phase, left = "Light", 0

local function set(p: string, t: number)
	phase, left = p, t
	state:SetAttribute("Pulse", p)
	state:SetAttribute("PulseEnds", workspace:GetServerTimeNow() + t)
	Net.Notify:FireAllClients("Pulse", p)
end

function Pulses.init(theState)
	state = theState
	if (state:GetAttribute("Zone") or 1) ~= 6 then
		return
	end
	set("Light", Config.Pulses.LIGHT)
end

function Pulses.step(dt: number)
	if not state or (state:GetAttribute("Zone") or 1) ~= 6 then
		return
	end
	local P = Config.Pulses
	left -= dt
	if left > 0 then
		return
	end
	if phase == "Light" then
		set("Fading", P.FADE)
	elseif phase == "Fading" then
		set("Dark", P.DARK)
	else
		set("Light", P.LIGHT)
	end
end

-- is this spot lit (safe from the dark)?
function Pulses.lit(pos: Vector3, rig): boolean
	if state:GetAttribute("Pulse") ~= "Dark" then
		return true
	end
	if rig and rig.deck and (pos - rig.deck.Position).Magnitude <= Config.Pulses.SAFE then
		return true
	end
	local beacon = state:GetAttribute("BeaconPos")
	return beacon ~= nil and (pos - beacon).Magnitude <= Config.Night.RING
end

return Pulses
