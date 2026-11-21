--[[
	Sound effects (tools/build_sfx.py makes them; Starport uploads them to
	Assets.sounds). Sfx.play("Mine") plays one; Sfx.play("Mine", 0.8, somePosition)
	plays it out in the world. Sfx.loop(name) returns a looping Sound to drive.
]]

local SoundService = game:GetService("SoundService")

local Art = require(game:GetService("ReplicatedStorage"):WaitForChild("Shared").Art)

local Sfx = {}

local folder = Instance.new("Folder")
folder.Name = "Sfx"
folder.Parent = workspace

local function make(name: string, volume: number?): Sound?
	local id = Art.sound(name)
	if not id then
		return nil
	end
	local s = Instance.new("Sound")
	s.Name = name
	s.SoundId = id
	s.Volume = volume or 0.6
	return s
end

function Sfx.play(name: string, volume: number?, at: Vector3?, pitch: number?)
	local s = make(name, volume)
	if not s then
		return
	end
	s.PlaybackSpeed = pitch or (0.94 + math.random() * 0.12) -- (a little variety)
	if at then
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(0.2, 0.2, 0.2)
		p.CFrame = CFrame.new(at)
		p.Parent = folder
		s.RollOffMinDistance = 12
		s.RollOffMaxDistance = 160
		s.Parent = p
		s.Ended:Connect(function()
			p:Destroy()
		end)
		s:Play()
	else
		SoundService:PlayLocalSound(s)
	end
end

function Sfx.loop(name: string, parent: Instance, volume: number?): Sound?
	local s = make(name, volume)
	if not s then
		return nil
	end
	s.Looped = true
	s.RollOffMinDistance = 14
	s.RollOffMaxDistance = 220
	s.Parent = parent
	s:Play()
	return s
end

return Sfx
