--[[
	Items (owner; the reference's fish and logs): every find you reel up, and your
	glowstone, are items in your Bag. Finds also take hotbar slots with a stack
	count; glowstone stays in the Bag until you take it out. Hold an item and
	click to use it (finds: eat one), press G to drop one, and walk up to a
	dropped one for its card ([E] name, rarity, what it is) to pick it up.

	The find inventory lives here (it survives respawns); each item shows as a
	Tool in the Backpack with attributes Find (its id) and Count. Glowstone is the
	player's "Glowstone" attribute, mirrored by a Bag-only Glowstone tool. In your
	hand (and when dropped) it's the item's own model: tools/blender/items.py via
	Starport to Models/Tools/<Id>, painted by piece name, or a stand-in until then.
]]

local Players = game:GetService("Players")

local Shared = game:GetService("ReplicatedStorage").Shared
local Finds = require(Shared.Finds)

local Items = {}

local inv: { [Player]: { order: { string }, count: { [string]: number } } } = {}
local makeTool, registerModel, notify
local rig
local DROP_LIFE = 180
local GLOW = Color3.fromRGB(255, 170, 30)

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

local function itemTools(player: Player): { [string]: Tool }
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

local function standIn(tool: Tool, color: Color3, glowy: boolean)
	-- (until the item's model is uploaded: a simple shape in its colour)
	local h = Instance.new("Part")
	h.Name = "Handle"
	h.Shape = Enum.PartType.Ball
	h.Size = Vector3.new(1, 1, 1)
	h.Color = color
	h.Material = glowy and Enum.Material.Neon or Enum.Material.SmoothPlastic
	h.CanCollide = false
	h.Massless = true
	h.Parent = tool
	tool.RequiresHandle = true
	tool.Grip = CFrame.new(0, 0, -0.2)
end

local function buildTool(id: string): Tool
	if id == "Glowstone" then
		local g = Finds.GLOWSTONE
		local tool = makeTool(g.name, "Glowstone", g.desc)
		tool:SetAttribute("Find", "Glowstone")
		tool:SetAttribute("BagOnly", true) -- (in the Bag, not a hotbar slot, unless you hold it)
		if not tool:FindFirstChild("Handle") then
			standIn(tool, GLOW, true)
		end
		return tool
	end
	local f = Finds.BY_ID[id]
	local tool = makeTool(f.name, f.id, f.desc)
	tool:SetAttribute("Find", f.id)
	if not tool:FindFirstChild("Handle") then
		standIn(tool, f.color, false)
	end
	return tool
end

-- make the Backpack match the inventory (counts, new and used-up items)
local function sync(player: Player)
	local data = inv[player]
	local backpack = player:FindFirstChild("Backpack")
	if not data or not backpack then
		return
	end
	local tools = itemTools(player)
	local glow = player:GetAttribute("Glowstone") or 0
	for id, t in tools do
		local n = id == "Glowstone" and glow or (data.count[id] or 0)
		if n <= 0 then
			t:Destroy()
			tools[id] = nil
		end
	end
	for _, id in data.order do
		local n = data.count[id] or 0
		if n > 0 then
			local t = tools[id]
			if not t then
				t = buildTool(id)
				t.Parent = backpack
			end
			t:SetAttribute("Count", n)
		end
	end
	if glow > 0 then
		local t = tools.Glowstone
		if not t then
			t = buildTool("Glowstone")
			t.Parent = backpack
		end
		t:SetAttribute("Count", glow)
	end
end

function Items.init(opts)
	makeTool, registerModel, notify, rig = opts.makeTool, opts.registerModel, opts.notify, opts.rig
	for _, f in Finds.LIST do
		registerModel(f.name, { file = f.id, grip = CFrame.new(0, -0.45, -0.15), paint = paintFor(f) })
	end
	registerModel("Glowstone", { file = "GlowstoneChunk", grip = CFrame.new(0, -0.4, -0.15), paint = { Handle = { GLOW, Enum.Material.Neon }, Glow = { GLOW, Enum.Material.Neon }, Rock = { Color3.fromRGB(94, 70, 58), Enum.Material.Slate } } })
	local function added(p: Player)
		inv[p] = inv[p] or { order = {}, count = {} }
		p:GetAttributeChangedSignal("Glowstone"):Connect(function()
			sync(p)
		end)
	end
	Players.PlayerAdded:Connect(added)
	for _, p in Players:GetPlayers() do
		added(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		inv[p] = nil
	end)
end

-- (after the Backpack is reset on respawn)
Items.sync = sync

function Items.give(player: Player, id: string, n: number?)
	if id == "Glowstone" then
		player:SetAttribute("Glowstone", (player:GetAttribute("Glowstone") or 0) + (n or 1))
		return
	end
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
	if id == "Glowstone" then
		local g = player:GetAttribute("Glowstone") or 0
		if g <= 0 then
			return false
		end
		player:SetAttribute("Glowstone", g - 1)
		return true
	end
	local data = inv[player]
	if not data or (data.count[id] or 0) <= 0 then
		return false
	end
	data.count[id] -= 1
	sync(player)
	return true
end

local function heldTool(player: Player): Tool?
	local char = player.Character
	local tool = char and char:FindFirstChildOfClass("Tool")
	return tool and tool:GetAttribute("Find") and tool or nil
end

-- take n raw finds (not cooked dishes), from the biggest stacks first
function Items.takeRaw(player: Player, n: number): boolean
	local data = inv[player]
	if not data then
		return false
	end
	local have = 0
	for id, c in data.count do
		local f = Finds.BY_ID[id]
		if f and not f.cooked then
			have += c
		end
	end
	if have < n then
		return false
	end
	for _ = 1, n do
		local best, bestN = nil, 0
		for id, c in data.count do
			local f = Finds.BY_ID[id]
			if f and not f.cooked and c > bestN then
				best, bestN = id, c
			end
		end
		data.count[best] -= 1
	end
	sync(player)
	return true
end

-- the find in your hand (not glowstone: that isn't food)
function Items.held(player: Player): any
	local t = heldTool(player)
	local id = t and t:GetAttribute("Find")
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

-- drop one of what you're holding: the item itself floats there in a soft green
-- glow until someone walks up and picks it up (the reference's dropped fish)
function Items.drop(player: Player)
	local tool = heldTool(player)
	local id = tool and tool:GetAttribute("Find")
	local char = player.Character
	local root = char and char:FindFirstChild("HumanoidRootPart") :: BasePart?
	if not tool or not id or not root or not Items.take(player, id) then
		return
	end
	local at = (root.CFrame * CFrame.new(0, -1.2, -3.5)).Position
	local item = Instance.new("Model")
	item.Name = "DroppedItem"
	item:SetAttribute("Find", id)
	-- the item's own model, copied from the tool in your hand
	local anchor = Instance.new("Part")
	anchor.Name = "Anchor"
	anchor.Size = Vector3.new(0.5, 0.5, 0.5)
	anchor.Transparency = 1
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.CanQuery = false
	anchor.CanTouch = false
	anchor.CFrame = CFrame.new(at)
	anchor.Parent = item
	item.PrimaryPart = anchor
	local handle = tool:FindFirstChild("Handle") :: BasePart?
	for _, p in tool:GetChildren() do
		if p:IsA("BasePart") and handle then
			local c = p:Clone()
			c:ClearAllChildren()
			c.Anchored = true
			c.CanCollide = false
			c.CanQuery = false
			c.CanTouch = false
			c.Massless = true
			-- upright, the way the item was modelled
			c.CFrame = CFrame.new(at) * handle.CFrame:ToObjectSpace(p.CFrame)
			c.Parent = item
		end
	end
	local light = Instance.new("PointLight")
	light.Color = Color3.fromRGB(90, 255, 110)
	light.Range = 9
	light.Brightness = 2
	light.Parent = anchor
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "PickUp"
	prompt.ActionText = "Pick up"
	prompt.ObjectText = id
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 0
	prompt.MaxActivationDistance = 9
	prompt.RequiresLineOfSight = false
	prompt.Style = Enum.ProximityPromptStyle.Custom -- (the client draws the reference's card beside it)
	prompt:SetAttribute("Find", id)
	prompt.Parent = anchor
	-- on the moving rig it rides along; on the ground it stays put
	local onRig = rig and rig:deckPosition(root.Position) ~= nil
	item:SetAttribute("OnRig", onRig)
	if onRig then
		item:SetAttribute("DeckOffset", rig.deck.CFrame:PointToObjectSpace(at))
	end
	item.Parent = workspace
	prompt.Triggered:Connect(function(by)
		if item.Parent then
			item:Destroy()
			Items.give(by, id)
			notify(by, "PickedUp", id)
		end
	end)
	task.delay(DROP_LIFE, function()
		if item.Parent then
			item:Destroy()
		end
	end)
end

return Items
