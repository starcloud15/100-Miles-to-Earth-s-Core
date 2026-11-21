--[[
	Pop-outs, like the reference's logs: when you mine a vein (or reel up a find)
	the resource's icon bursts out of it, arcs, bounces on the ground with a
	little spin, then gets pulled into you and lands in the Bag (or its hotbar
	slot). They're flat icons that move like objects, not 3D models (owner).
	Purely visual: the server has already counted them.
]]

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage"):WaitForChild("Shared")
local Art = require(Shared.Art)

local Pops = {}

local player = Players.LocalPlayer
local GRAVITY = 70
local live = {}
local folder: Folder

local params = RaycastParams.new()
params.FilterType = Enum.RaycastFilterType.Exclude

local function groundBelow(pos: Vector3): number
	local ignore = { folder }
	if player.Character then
		table.insert(ignore, player.Character)
	end
	local rig = workspace:FindFirstChild("DrillRig")
	params.FilterDescendantsInstances = ignore
	local hit = workspace:Raycast(pos + Vector3.new(0, 2, 0), Vector3.new(0, -30, 0), params)
	local y = hit and hit.Position.Y or (pos.Y - 3)
	local _ = rig
	return y + 0.7
end

-- n icons out of `from`, flying out then into you; `arrive(kind)` for each one
function Pops.burst(kind: string, from: Vector3, n: number, arrive: ((string) -> ())?)
	local image = Art.icon(kind) or ""
	local floor = groundBelow(from)
	for i = 1, n do
		local p = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.CanQuery = false
		p.CanTouch = false
		p.Transparency = 1
		p.Size = Vector3.new(0.2, 0.2, 0.2)
		p.CFrame = CFrame.new(from)
		local gui = Instance.new("BillboardGui")
		gui.Size = UDim2.fromScale(1.5, 1.5)
		gui.LightInfluence = 0
		gui.AlwaysOnTop = false
		gui.Parent = p
		local img = Instance.new("ImageLabel")
		img.BackgroundTransparency = 1
		img.Size = UDim2.fromScale(1, 1)
		img.Image = image
		img.Parent = gui
		p.Parent = folder
		local a = math.random() * math.pi * 2
		local out = 6 + math.random() * 6
		table.insert(live, {
			part = p,
			img = img,
			pos = from,
			vel = Vector3.new(math.cos(a) * out, 16 + math.random() * 8, math.sin(a) * out),
			spin = (math.random() - 0.5) * 720,
			floor = floor,
			bounces = 0,
			t = 0,
			-- (staggered, so a pile comes in one after another)
			pullAt = 0.75 + i * 0.07,
			kind = kind,
			arrive = arrive,
		})
	end
end

local function step(dt: number)
	local root = player.Character and player.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
	for i = #live, 1, -1 do
		local o = live[i]
		o.t += dt
		if o.t < o.pullAt or not root then
			-- flying out and bouncing
			o.vel -= Vector3.new(0, GRAVITY * dt, 0)
			o.pos += o.vel * dt
			if o.pos.Y < o.floor then
				o.pos = Vector3.new(o.pos.X, o.floor, o.pos.Z)
				if o.bounces < 2 then
					o.bounces += 1
					o.vel = Vector3.new(o.vel.X * 0.55, -o.vel.Y * 0.45, o.vel.Z * 0.55)
				else
					o.vel = Vector3.new(o.vel.X * 0.6, 0, o.vel.Z * 0.6)
				end
				o.spin *= 0.6
			end
			o.img.Rotation += o.spin * dt
		else
			-- pulled in to you, faster and faster, shrinking as it arrives
			local to = (root :: BasePart).Position + Vector3.new(0, 1, 0)
			local k = math.clamp((o.t - o.pullAt) / 0.28, 0, 1)
			o.pos = o.pos:Lerp(to, math.min(1, dt * (8 + k * 30)))
			o.img.Size = UDim2.fromScale(1 - k * 0.5, 1 - k * 0.5)
			if k >= 1 or (o.pos - to).Magnitude < 1 then
				o.part:Destroy()
				table.remove(live, i)
				if o.arrive then
					o.arrive(o.kind)
				end
				continue
			end
		end
		o.part.CFrame = CFrame.new(o.pos)
	end
end

function Pops.init()
	folder = Instance.new("Folder")
	folder.Name = "Pops"
	folder.Parent = workspace
	RunService.RenderStepped:Connect(step)
end

return Pops
