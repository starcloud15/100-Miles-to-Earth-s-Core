--[[
	Finds as real items (owner; the reference's fish): each find you reel up goes
	into your inventory and gets its own hotbar slot with a stack count. Hold it
	and click to eat one, press G to drop one, and walk up to a dropped one to
	pick it up again ("E" card at the top of the screen, like the reference).

	The inventory lives here (it survives respawns); each find is shown as a Tool
	in the Backpack with attributes Find (its id) and Count. In your hand it's the
	find's own model (tools/blender/items.py, via Starport to Models/Tools/<Id>),
	painted by piece name, or a simple stand-in until that's uploaded.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Finds = require(Shared.Finds)
local Art = require(Shared.Art)

local Items = {}

local inv: { [Player]: { order: { string }, count: { [string]: number } } } = {}
local makeTool, registerModel, notify
local rig
local DROP_LIFE = 180

-- the pieces of a find's model, painted by name
local function paintFor(f)
	local c = f.color
	local body = { c, Enum.Material.SmoothPlastic }
	return {
		Handle = body,
		Body = body,
		Dark = { Color3.new(c.R * 0.6, c.G * 0.6, c.B * 0.6), Enum.Material.SmoothPlastic },
		Stem = { Color3.fromRGB(236, 226, 204), Enum.Material.SmoothPlastic },
		Twig = { Color3.fromRGB(108, 68, 36), Enum.Material.Wood },
		Leaf = { Color3.fromRGB(78, 168, 58), Enum.Material.SmoothPlastic },
		Spot = { Color3.fromRGB(246, 242, 232), Enum.Material.SmoothPlastic },
		Glow = { c, Enum.Material.Neon },
	}
end

local function toolFor(player: Player): { [string]: Tool }
	local found = {}
	for _, where in { player:FindFirstChild("Backpack"), player.Character } do
		if where then
			for _, t in where:GetChildren() do
				if t:IsA("Tool") and t:GetAttribute("Find") then
					found[t:GetAttribute("Find")] = t
				end
			end
		end
	end
	return found
end

local function buildTool(f): Tool
	local tool = makeTool(f.name, f.id, f.desc)
	tool:SetAttribute("Find", f.id)
	tool:SetAttribute("Rare", f.rare == true)
	if not tool:FindFirstChild("Handle") then
		-- (until its model is uploaded: a simple stand-in in the find's colour)
		local h = Instance.new("Part")
		h.Name = "Handle"
		h.Shape = Enum.PartType.Ball
		h.Size = Vector3.new(1, 1, 1)
		h.Color = f.color
		h.Material = Enum.Material.SmoothPlastic
		h.CanCollide = false
		h.Massless = true
		h.Parent = tool
		tool.RequiresHandle = true
		tool.Grip = CFrame.new(0, 0, -0.2)
	end
	return tool
end

-- make the Backpack match the inventory (counts, new and used-up finds)
local function sync(player: Player)
	local data = inv[player]
	local backpack = player:FindFirstChild("Backpack")
	if not data or not backpack then
		return
	end
	local tools = toolFor(player)
	for id, t in tools do
		if (data.count[id] or 0) <= 0 then
			t:Destroy()
		end
	end
	for _, id in data.order do
		local n = data.count[id] or 0
		if n > 0 then
			local t = tools[id]
			if not t then
				t = buildTool(Finds.BY_ID[id])
				t.Parent = backpack
			end
			t:SetAttribute("Count", n)
		end
	end
end

function Items.init(opts)
	makeTool, registerModel, notify, rig = opts.makeTool, opts.registerModel, opts.notify, opts.rig
	for _, f in Finds.LIST do
		registerModel(f.name, { file = f.id, grip = CFrame.new(0, -0.45, -0.15), paint = paintFor(f) })
	end
	Players.PlayerAdded:Connect(function(p)
		inv[p] = { order = {}, count = {} }
	end)
	for _, p in Players:GetPlayers() do
		inv[p] = inv[p] or { order = {}, count = {} }
	end
	Players.PlayerRemoving:Connect(function(p)
		inv[p] = nil
	end)
end

-- (after the Backpack is reset on respawn)
Items.sync = sync

function Items.give(player: Player, id: string, n: number?)
	local data = inv[player]
	if not data or not Finds.BY_ID[id] then
		return
	end
	if not data.count[id] or data.count[id] <= 0 then
		-- (a find you didn't have goes to the end of the hotbar)
		local i = table.find(data.order, id)
		if i then
			table.remove(data.order, i)
		end
		table.insert(data.order, id)
	end
	data.count[id] = (data.count[id] or 0) + (n or 1)
	sync(player)
end

function Items.take(player: Player, id: string): boolean
	local data = inv[player]
	if not data or (data.count[id] or 0) <= 0 then
		return false
	end
	data.count[id] -= 1
	sync(player)
	return true
end

function Items.held(player: Player): any
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	local id = tool and tool:GetAttribute("Find")
	return id and Finds.BY_ID[id] or nil
end

function Items.total(player: Player): number
	local data = inv[player]
	local n = 0
	for _, c in data and data.count or {} do
		n += c
	end
	return n
end

-- drop one of the held find at your feet: it glows on the ground until someone
-- picks it up (the reference's dropped fish)
function Items.drop(player: Player)
	local f = Items.held(player)
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not f or not root or not Items.take(player, f.id) then
		return
	end
	local at = root.CFrame * CFrame.new(0, -2.4, -3)
	local item = Instance.new("Part")
	item.Name = "DroppedFind"
	item.Size = Vector3.new(1.4, 1.4, 1.4)
	item.Transparency = 1
	item.CanCollide = false
	item.CanQuery = false
	item.CanTouch = false
	item.CFrame = CFrame.new(at.Position)
	item:SetAttribute("Find", f.id)
	-- the find itself, floating and bobbing, over a soft green glow (client spins it)
	local gui = Instance.new("BillboardGui")
	gui.Name = "Icon"
	gui.Size = UDim2.fromScale(2.2, 2.2)
	gui.StudsOffset = Vector3.new(0, 1.1, 0)
	gui.LightInfluence = 0
	gui.MaxDistance = 90
	gui.Parent = item
	local img = Instance.new("ImageLabel")
	img.BackgroundTransparency = 1
	img.Size = UDim2.fromScale(1, 1)
	img.Image = Art.icon(f.id) or ""
	img.Parent = gui
	local glow = Instance.new("Part")
	glow.Name = "Glow"
	glow.Shape = Enum.PartType.Cylinder
	glow.Size = Vector3.new(0.1, 3, 3)
	glow.Material = Enum.Material.Neon
	glow.Color = f.rare and Color3.fromRGB(255, 200, 60) or Color3.fromRGB(90, 255, 110)
	glow.Transparency = 0.55
	glow.CanCollide = false
	glow.CanQuery = false
	glow.CanTouch = false
	glow.CastShadow = false
	glow.CFrame = item.CFrame * CFrame.new(0, -0.6, 0) * CFrame.Angles(0, 0, math.rad(90))
	glow.Parent = item
	local light = Instance.new("PointLight")
	light.Color = glow.Color
	light.Range = 8
	light.Brightness = 1.4
	light.Parent = item
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickUp"
	prompt.ActionText = "Pick up"
	prompt.ObjectText = f.name
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom -- (the client draws the reference's card)
	prompt:SetAttribute("Find", f.id)
	prompt.Parent = item
	-- on the moving rig it rides along; on the ground it stays put
	if rig and rig:deckPosition(root.Position) then
		item.Anchored = false
		item.Massless = true
		glow.Anchored = false
		local w = Instance.new("WeldConstraint")
		w.Part0 = rig.deck
		w.Part1 = item
		w.Parent = item
		local w2 = Instance.new("WeldConstraint")
		w2.Part0 = item
		w2.Part1 = glow
		w2.Parent = glow
	else
		item.Anchored = true
		glow.Anchored = true
	end
	item.Parent = workspace
	prompt.Triggered:Connect(function(by)
		if item.Parent then
			item:Destroy()
			Items.give(by, f.id)
			notify(by, "PickedUp", f.id)
		end
	end)
	task.delay(DROP_LIFE, function()
		if item.Parent then
			item:Destroy()
		end
	end)
end

return Items
