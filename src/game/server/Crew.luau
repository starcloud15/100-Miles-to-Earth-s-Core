--[[
	The crew (docs/match-spec.md): tools, mining at stops, Delving for food,
	Hunger and Health, falling off and getting back, and Push Off.

	  * Off the rig you SLIDE down the loose slope, faster than running (our
	    answer to the reference's swimming). The crew stops cranking to let you
	    catch up.
	  * Past about 60 m the "DON'T GET LEFT BEHIND!" bar fills with the distance
	    from 60 m to 125 m (owner). When it's full you're PULLED BACK onto the
	    rig.
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Art = require(Shared.Art)
local Pulses = require(script.Parent.Pulses)
local Items = require(script.Parent.Items)
local Data = require(Shared.Data)
local Finds = require(Shared.Finds)

local Crew = {}

local rig, route, state, World
local departedAt: number? = nil
local info = {}
local pushedAt: { [Player]: number } = {}
local pendingPush: { [Player]: Player } = {}

local function rootOf(player: Player): (BasePart?, Humanoid?)
	local char = player.Character
	if not char then
		return nil, nil
	end
	return char:FindFirstChild("HumanoidRootPart") :: BasePart?, char:FindFirstChildOfClass("Humanoid")
end

local function notify(player: Player, kind: string, data: any?)
	Net.Notify:FireClient(player, kind, data)
end

function Crew.isAboard(player: Player): boolean
	local root = rootOf(player)
	return root ~= nil and rig:deckPosition(root.Position) ~= nil
end

local function deckSpot(index: number): CFrame
	local slots = { Vector3.new(-3.5, 0, 2), Vector3.new(3.5, 0, 2), Vector3.new(-3.5, 0, -3), Vector3.new(3.5, 0, -3), Vector3.new(0, 0, 0) }
	local v = slots[(index - 1) % #slots + 1]
	return rig.deck.CFrame * CFrame.new(v.X, 4, v.Z)
end

local function putOnDeck(player: Player)
	local root = rootOf(player)
	if not root then
		return
	end
	local index = table.find(Players:GetPlayers(), player) or 1
	root.AssemblyLinearVelocity = rig.deck.AssemblyLinearVelocity
	root.CFrame = deckSpot(index)
end
Crew.putOnDeck = putOnDeck

-- at the spawn, players start on the ground beside the rig, by the first veins
local function spawnSpot(player: Player): CFrame
	local index = table.find(Players:GetPlayers(), player) or 1
	return rig.deck.CFrame * CFrame.new(-14 + index * 4, 3, 16)
end

-- the tool models from Blender (tools/blender/tools.py), once Starport has
-- uploaded them to src/shared/Models/Tools; the FBX colours don't survive the
-- import, so each piece is painted by name
local WOOD, WOOD_DARK = { Color3.fromRGB(150, 96, 54), Enum.Material.Wood }, { Color3.fromRGB(104, 64, 36), Enum.Material.Wood }
local STEEL, STEEL_DARK = { Color3.fromRGB(176, 184, 196), Enum.Material.Metal }, { Color3.fromRGB(84, 90, 100), Enum.Material.Metal }
local BRASS = { Color3.fromRGB(226, 168, 54), Enum.Material.Metal }
local ROPE, CLOTH = { Color3.fromRGB(120, 84, 50), Enum.Material.Fabric }, { Color3.fromRGB(196, 150, 98), Enum.Material.Fabric }
local GLOW = { Color3.fromRGB(255, 186, 70), Enum.Material.Neon }
-- tools are modelled with the handle along Y and their working end (pick, gear,
-- hook) spread along X; FACE turns that end to point forward from the fist.
-- The Delver's Hook also leans forward like a fishing rod.
local FACE = CFrame.Angles(0, math.rad(90), 0)
local TOOL_MODELS = {
	["Crank Pump"] = { file = "CrankPump", grip = CFrame.new(0, -0.3, 0) * FACE, paint = { Handle = WOOD_DARK, Arm = BRASS, Elbow = BRASS, Gear = STEEL, Hub = STEEL_DARK } },
	Pickaxe = { file = "Pickaxe", grip = CFrame.new(0, -1.4, 0) * FACE, paint = { Handle = WOOD, Grip = WOOD_DARK, Head = STEEL, Binding = BRASS } },
	["Delver's Hook"] = { file = "DelversHook", grip = CFrame.new(0, -1.2, 0) * FACE * CFrame.Angles(math.rad(40), 0, 0), paint = { Handle = WOOD, Grip = ROPE, Reel = BRASS, Tip = BRASS, TipArm = BRASS, Line = ROPE, Hook = STEEL, Barb = STEEL, Glow = GLOW } },
}

local function toolModel(file: string): Model?
	local models = Shared:FindFirstChild("Models")
	local folder = models and models:FindFirstChild("Tools")
	return folder and folder:FindFirstChild(file) :: Model?
end

local function makeTool(name: string, icon: string, tip: string): Tool
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool.ToolTip = tip
	tool.TextureId = Art.icon(icon) or ""
	local def = TOOL_MODELS[name]
	local m = def and toolModel(def.file)
	local src = m and m:FindFirstChild("Handle", true) :: BasePart?
	if def and m and src then
		local base = src.CFrame
		local handle
		for _, p in m:GetDescendants() do
			if p:IsA("BasePart") then
				local c = p:Clone()
				c:ClearAllChildren()
				c.CFrame = base:ToObjectSpace(p.CFrame) -- relative to the handle, placed below
				c.CanCollide = false
				c.Massless = true
				local look = def.paint[p.Name]
				if look then
					c.Color = look[1]
					c.Material = look[2]
				end
				if p == src then
					handle = c
				end
				c:SetAttribute("Rel", c.CFrame)
				c.Parent = tool
			end
		end
		handle.Name = "Handle"
		handle.CFrame = CFrame.new()
		for _, c in tool:GetChildren() do
			if c:IsA("BasePart") and c ~= handle then
				c.CFrame = handle.CFrame * c:GetAttribute("Rel")
				local w = Instance.new("WeldConstraint")
				w.Part0 = handle
				w.Part1 = c
				w.Parent = c
			end
		end
		tool.RequiresHandle = true
		tool.Grip = def.grip
	end
	return tool
end

local function giveTools(player: Player)
	local backpack = player:WaitForChild("Backpack")
	for _, t in backpack:GetChildren() do
		t:Destroy()
	end
	makeTool("Crank Pump", "Crank", "Click to crank your side's tread").Parent = backpack
	makeTool("Pickaxe", "Pickaxe", "Click a glowstone vein to mine it").Parent = backpack
	makeTool("Delver's Hook", "DelversHook", "Click to cast into the rock, then reel at the tug").Parent = backpack
	-- (your finds come back with you: Items keeps them)
	Items.sync(player)
end

-- the Lamplighter's hand lantern: a warm light that goes everywhere with them
function Crew.classLook(player: Player, char: Model)
	local root = char:FindFirstChild("HumanoidRootPart")
	local old = root and root:FindFirstChild("HandLantern")
	if old then
		old:Destroy()
	end
	if root and player:GetAttribute("Class") == "Lamplighter" then
		local l = Instance.new("PointLight")
		l.Name = "HandLantern"
		l.Color = Color3.fromRGB(255, 196, 110)
		l.Range = 22
		l.Brightness = 1.6
		l.Parent = root
	end
end

-- (downed players: defined with Crew.down below)
local downed: { [Player]: { prompt: ProximityPrompt?, ends: number } } = {}
local getUp: (Player, number, CFrame?) -> ()

local function onCharacter(player: Player, char: Model)
	local hum = char:WaitForChild("Humanoid") :: Humanoid
	char:WaitForChild("HumanoidRootPart")
	for _, p in char:GetDescendants() do
		if p:IsA("BasePart") then
			p.CollisionGroup = "Crew"
		end
	end
	char.DescendantAdded:Connect(function(p)
		if p:IsA("BasePart") then
			p.CollisionGroup = "Crew"
		end
	end)
	hum.WalkSpeed = 16
	hum.MaxHealth = 100
	hum.Health = 100
	giveTools(player)
	task.defer(Crew.classLook, player, char)
	if downed[player] then
		getUp(player, 1)
	end
	local i = info[player]
	if i then
		i.off = false
	end
	task.defer(function()
		local root = rootOf(player)
		if not root then
			return
		end
		if state:GetAttribute("Phase") == "Spawn" then
			root.CFrame = spawnSpot(player)
		else
			putOnDeck(player)
		end
	end)
end

local function grace(): number
	return RunService:IsStudio() and Config.PushOff.GRACE_STUDIO or Config.PushOff.GRACE
end

local function shove(target: Player, fromPos: Vector3?, kind: string)
	local root = rootOf(target)
	if not root then
		return
	end
	local deckCf = rig.deck.CFrame
	local rel = deckCf:PointToObjectSpace(root.Position)
	local side = rel.X >= 0 and 1 or -1
	if fromPos then
		side = deckCf.RightVector:Dot(root.Position - fromPos) >= 0 and 1 or -1
	end
	local v = deckCf.RightVector * side * 60 + Vector3.new(0, 34, 0) + rig.deck.AssemblyLinearVelocity
	local i = info[target]
	if i then
		i.pushedAt = os.clock()
	end
	Net.Shove:FireClient(target, v)
	notify(target, kind)
end

local function pushOff(pusher: Player, target: Player)
	shove(target, (rootOf(pusher) :: BasePart).Position, "PushedOff")
	pusher:SetAttribute("RunPushed", (pusher:GetAttribute("RunPushed") or 0) + 1)
	pushedAt[target] = os.clock()
	Net.Notify:FireAllClients("PushOffDone", { by = pusher.DisplayName, target = target.DisplayName })
end

local function addHunger(player: Player, amount: number)
	player:SetAttribute("Hunger", math.clamp((player:GetAttribute("Hunger") or 100) + amount, 0, 100))
end

function Crew.init(theRig, theRoute, theState, theWorld)
	rig, route, state, World = theRig, theRoute, theState, theWorld
	Items.init({
		makeTool = makeTool,
		registerModel = function(name, def)
			TOOL_MODELS[name] = def
		end,
		notify = notify,
		rig = rig,
	})
	Net.Drop.OnServerEvent:Connect(function(player)
		Items.drop(player)
	end)
	-- the camps' Cookpots: Roast the find in your hand, or stew any three
	local hookedPots = {}
	task.spawn(function()
		while true do
			for _, pot in World.cookPots do
				if not hookedPots[pot] and pot.Parent then
					hookedPots[pot] = true
					pot:FindFirstChild("Roast").Triggered:Connect(function(player)
						local f = Items.held(player)
						if not f or f.cooked then
							notify(player, "Toast", "Hold a find from your hotbar to roast it")
							return
						end
						if Items.take(player, f.id) then
							Items.give(player, "RoastedCap")
							player:SetAttribute("RunCooked", (player:GetAttribute("RunCooked") or 0) + 1)
							notify(player, "Cooked", "RoastedCap")
						end
					end)
					pot:FindFirstChild("Stew").Triggered:Connect(function(player)
						if Items.takeRaw(player, 3) then
							Items.give(player, "CaveStew")
							player:SetAttribute("RunCooked", (player:GetAttribute("RunCooked") or 0) + 1)
							notify(player, "Cooked", "CaveStew")
						else
							notify(player, "Toast", "Cave Stew needs 3 finds: go delving!")
						end
					end)
				end
			end
			task.wait(1)
		end
	end)

	Net.UseFlare.OnServerEvent:Connect(function(player)
		if not downed[player] then
			return
		end
		local p = Data.get(player)
		if not p or (p.reviveFlares or 0) <= 0 then
			return
		end
		Data.update(player, function(q)
			q.reviveFlares -= 1
			q.flags.secondWind = true -- (the Second Wind badge)
		end)
		getUp(player, 1)
		notify(player, "Revived", "your Revive Flare")
	end)
	Players.PlayerRemoving:Connect(function(p)
		downed[p] = nil
	end)
	-- the class each player equipped at camp (their save), for its perks
	Data.Changed:Connect(function(player, p)
		-- (how many runs they've done: the client only coaches newer players)
		player:SetAttribute("Games", p.games or 0)
		if player:GetAttribute("Class") ~= (p.class or "") then
			player:SetAttribute("Class", p.class or "")
			if player.Character then
				Crew.classLook(player, player.Character)
			end
		end
	end)

	local function added(player: Player)
		info[player] = { off = false, s = rig.s, lastCrank = 0, lastMine = 0, pushedAt = -10, cast = nil }
		player:SetAttribute("Glowstone", 0)
		player:SetAttribute("Hunger", 100)
		player:SetAttribute("Behind", -1)
		player.CharacterAdded:Connect(function(char)
			onCharacter(player, char)
		end)
		if player.Character then
			task.spawn(onCharacter, player, player.Character)
		end
	end
	Players.PlayerAdded:Connect(added)
	for _, p in Players:GetPlayers() do
		added(p)
	end
	Players.PlayerRemoving:Connect(function(p)
		info[p] = nil
		pushedAt[p] = nil
		pendingPush[p] = nil
	end)

	Net.Crank.OnServerEvent:Connect(function(player)
		local i = info[player]
		local root = rootOf(player)
		if not i or not root or not rig.moving then
			return
		end
		local now = os.clock()
		if now - i.lastCrank < Config.Rig.PUMP_COOLDOWN then
			return
		end
		local rel = rig:deckPosition(root.Position)
		if rel then
			i.lastCrank = now
			rig:crank(rel)
		end
	end)

	-- mining a vein: +2 glowstone a hit; a vein holds 12 ("+12" like a tree)
	Net.Mine.OnServerEvent:Connect(function(player, vein)
		local i = info[player]
		local root = rootOf(player)
		if not i or not root or typeof(vein) ~= "Instance" or not table.find(World.veins, vein) then
			return
		end
		local now = os.clock()
		local pp = vein.PrimaryPart
		if now - i.lastMine < 0.3 or not pp or (pp.Position - root.Position).Magnitude > 20 then
			return
		end
		i.lastMine = now
		local hp = (vein:GetAttribute("HP") or 12) - 2
		-- Prospector: +1 glowstone per hit
		local n = player:GetAttribute("Class") == "Prospector" and 3 or 2
		player:SetAttribute("Glowstone", (player:GetAttribute("Glowstone") or 0) + n)
		player:SetAttribute("RunGlowstone", (player:GetAttribute("RunGlowstone") or 0) + n)
		notify(player, "Mined", { n = n, at = pp.Position })
		if hp <= 0 then
			World.removeVein(vein)
		else
			vein:SetAttribute("HP", hp)
		end
	end)

	-- Delving (GDD 11): cast into the rock, wait for the tug, reel in time
	Net.Delve.OnServerEvent:Connect(function(player, action)
		local i = info[player]
		if not i then
			return
		end
		local now = os.clock()
		if action == "cast" and not i.cast then
			local root = rootOf(player)
			if not root then
				return
			end
			-- Delver: bites come 20% faster
			local bite = now + math.random(20, 60) / 10 * (player:GetAttribute("Class") == "Delver" and 0.8 or 1)
			local c = { bite = bite }
			i.cast = c
			-- the hook really flies out: it lands on the ground about 16 studs in front
			-- (short of any wall), and every client draws it there on its line with
			-- "..." over it, then "!" at the tug (client/Hook.luau)
			local fwd = Vector3.new(root.CFrame.LookVector.X, 0, root.CFrame.LookVector.Z)
			fwd = fwd.Magnitude > 0.01 and fwd.Unit or Vector3.new(0, 0, -1)
			local aboard = Crew.isAboard(player)
			local params = RaycastParams.new()
			params.FilterType = Enum.RaycastFilterType.Exclude
			local ignore = {}
			for _, p in Players:GetPlayers() do
				if p.Character then
					table.insert(ignore, p.Character)
				end
			end
			-- (from the deck it flies over the rig's rails; from the ground it stops at the rig)
			params.FilterDescendantsInstances = aboard and { rig.model, table.unpack(ignore) } or ignore
			params.CollisionGroup = "Default" -- (passes through the edge barriers)
			local dist = 16
			local wall = workspace:Raycast(root.Position, fwd * dist, params)
			if wall then
				dist = math.max(4, (wall.Position - root.Position).Magnitude - 1.5)
			end
			local over = root.Position + fwd * dist
			table.insert(ignore, rig.model)
			params.FilterDescendantsInstances = ignore
			local down = workspace:Raycast(over + Vector3.new(0, 3, 0), Vector3.new(0, -40, 0), params)
			local at = down and (down.Position + Vector3.new(0, 0.4, 0)) or (over - Vector3.new(0, 2.8, 0))
			player:SetAttribute("HookRig", aboard)
			player:SetAttribute("HookAt", aboard and rig.deck.CFrame:PointToObjectSpace(at) or at)
			player:SetAttribute("HookTime", workspace:GetServerTimeNow())
			player:SetAttribute("HookState", "Cast")
			task.delay(bite - now, function()
				if i.cast == c then
					player:SetAttribute("HookState", "Bite")
				end
			end)
			task.delay(bite - now + 1.25, function()
				if i.cast == c then
					-- never reeled: it slips away
					i.cast = nil
					player:SetAttribute("HookState", "")
					notify(player, "DelveResult", "late")
				end
			end)
			notify(player, "Cast", bite - now)
		elseif action == "reel" and i.cast then
			local c = i.cast
			i.cast = nil
			player:SetAttribute("HookState", "")
			if now < c.bite then
				notify(player, "DelveResult", "early")
			elseif now > c.bite + 1.2 then
				notify(player, "DelveResult", "late")
			else
				-- a find of this zone (sometimes its rare one), into your inventory
				local f = Finds.roll(state:GetAttribute("Zone") or 1, Random.new())
				Items.give(player, f.id)
				player:SetAttribute("RunFinds", (player:GetAttribute("RunFinds") or 0) + 1)
				local prof = Data.get(player)
				if prof and not prof.delveLog[f.id] then
					Data.update(player, function(q)
						q.delveLog[f.id] = true
					end)
					task.delay(1.6, function()
						notify(player, "Toast", "NEW in your Delve Log: " .. f.name .. "!")
					end)
				end
				local at = player:GetAttribute("HookAt")
				if typeof(at) == "Vector3" and player:GetAttribute("HookRig") then
					at = rig.deck.CFrame:PointToWorldSpace(at)
				end
				notify(player, "DelveResult", { result = "catch", find = f.id, at = typeof(at) == "Vector3" and at or nil })
			end
		end
	end)

	-- eat one of the find in your hand
	Net.Eat.OnServerEvent:Connect(function(player)
		local f = Items.held(player)
		if f and Items.take(player, f.id) then
			-- Delver: food fills 15% more
			local fill = math.floor(f.hunger * (player:GetAttribute("Class") == "Delver" and 1.15 or 1) + 0.5)
			addHunger(player, fill)
			if f.wellFed then
				player:SetAttribute("WellFed", workspace:GetServerTimeNow() + f.wellFed)
			end
			player:SetAttribute("RunMeals", (player:GetAttribute("RunMeals") or 0) + 1)
			player:SetAttribute("Exposure", math.max(0, (player:GetAttribute("Exposure") or 0) - Config.Temperature.EAT))
			notify(player, "Ate", { hunger = fill, find = f.id })
		elseif Items.total(player) == 0 then
			notify(player, "Toast", "No food! Cast your Delver's Hook into the rock")
		end
	end)

	Net.PushOff.OnServerEvent:Connect(function(player, target)
		if typeof(target) ~= "Instance" or not target:IsA("Player") or target == player or not info[target] then
			return
		end
		local root, troot = rootOf(player), rootOf(target)
		if not root or not troot then
			return
		end
		local P = Config.PushOff
		if not departedAt or os.clock() - departedAt < grace() then
			notify(player, "Toast", "Push Off unlocks " .. math.ceil(grace() - (departedAt and os.clock() - departedAt or 0)) .. " s after departure")
			return
		end
		if os.clock() - (pushedAt[target] or -100) < P.TARGET_COOLDOWN then
			notify(player, "Toast", target.DisplayName .. " was just pushed. Give them a moment!")
			return
		end
		if not rig:deckPosition(root.Position) or not rig:deckPosition(troot.Position) or (troot.Position - root.Position).Magnitude > P.RANGE + 4 then
			return
		end
		if P.PRODUCT_ID ~= 0 then
			pendingPush[player] = target
			MarketplaceService:PromptProductPurchase(player, P.PRODUCT_ID)
		elseif RunService:IsStudio() then
			pushOff(player, target)
		else
			notify(player, "Toast", "Push Off isn't on sale yet")
		end
	end)
	if Config.PushOff.PRODUCT_ID ~= 0 then
		MarketplaceService.ProcessReceipt = function(receipt)
			local buyer = Players:GetPlayerByUserId(receipt.PlayerId)
			if receipt.ProductId == Config.PushOff.PRODUCT_ID and buyer then
				local target = pendingPush[buyer]
				pendingPush[buyer] = nil
				if target and target.Parent then
					pushOff(buyer, target)
				end
				return Enum.ProductPurchaseDecision.PurchaseGranted
			end
			return Enum.ProductPurchaseDecision.NotProcessedYet
		end
	end
end

function Crew.depart()
	if not departedAt then
		departedAt = os.clock()
	end
end

function Crew.onHazard()
	for player, i in info do
		local root = rootOf(player)
		if root and not i.off and rig:deckPosition(root.Position) and math.random() < Config.Rig.THROW_CHANCE then
			shove(player, nil, "ThrownOff")
		end
	end
end

local acc = 0
function Crew.step(dt: number)
	acc += dt
	if acc < 0.2 then
		return
	end
	local stepDt = acc
	acc = 0
	local C = Config.Crew
	local S = Config.Survival
	local riding = rig.moving
	for player, i in info do
		local root, hum = rootOf(player)
		if not root or not hum or hum.Health <= 0 then
			continue
		end
		-- (starving, the cold, the dark and bites all bottom out at 1 Health: that downs you)
		if hum.Health <= 1.01 and not downed[player] then
			Crew.down(player)
		end
		if downed[player] then
			continue
		end
		-- Hunger drains steadily; Health comes back while fed, drains while starving
		-- (Cave Stew: hunger drains at half the rate while you're well fed)
		local fed = (player:GetAttribute("WellFed") or 0) > workspace:GetServerTimeNow()
		local hunger = math.max(0, (player:GetAttribute("Hunger") or 100) - S.HUNGER_PER_MIN / 60 * stepDt * (fed and 0.5 or 1))
		player:SetAttribute("Hunger", hunger)
		if hunger > 0 then
			hum.Health = math.min(hum.MaxHealth, hum.Health + S.REGEN_PER_SEC * stepDt)
		else
			hum.Health = math.max(1, hum.Health - S.STARVE_PER_SEC * stepDt)
		end

		-- Cold (zone 3) and Heat (zone 5): builds while riding, eases at stops and by the Beacon
		local TC = Config.Temperature
		local temp = TC[state:GetAttribute("Zone") or 1]
		if temp and temp.pulses then
			-- zone 6, Pulses: the dark fills the meter unless you're in light
			local P = Config.Pulses
			local e = player:GetAttribute("Exposure") or 0
			if Pulses.lit(root.Position, rig) then
				e -= (state:GetAttribute("Pulse") == "Dark" and TC.BEACON_FALL or P.LIGHT_FALL) * stepDt
			else
				e += P.DARK_RISE * stepDt
			end
			e = math.clamp(e, 0, 100)
			player:SetAttribute("Exposure", e)
			if e >= 100 then
				hum.Health = math.max(1, hum.Health - TC.HURT_PER_SEC * 3 * stepDt)
			end
		elseif temp then
			local e = player:GetAttribute("Exposure") or 0
			if riding then
				e += temp.RISE * stepDt
			else
				e -= TC.FALL * stepDt
				local beacon = state:GetAttribute("BeaconPos")
				if beacon and (root.Position - beacon).Magnitude <= Config.Night.RING * 1.5 then
					e -= TC.BEACON_FALL * stepDt
				end
			end
			e = math.clamp(e, 0, 100)
			player:SetAttribute("Exposure", e)
			if e >= 100 then
				hum.Health = math.max(1, hum.Health - TC.HURT_PER_SEC * stepDt)
			end
		end

		local aboard = rig:deckPosition(root.Position) ~= nil
		player:SetAttribute("Aboard", aboard)
		if aboard then
			if i.off then
				i.off = false
				player:SetAttribute("OffRig", false)
				player:SetAttribute("Behind", -1)
				notify(player, "Aboard")
			end
			i.s = rig.s
			continue
		end
		-- off the rig while it's riding: slide, warn, and pull back when too far
		local dist = (root.Position - rig.deck.Position).Magnitude
		local s, _, h = route:locate(root.Position, i.s, 900)
		i.s = s
		if riding and dist > 12 then
			if not i.off then
				i.off = true
				player:SetAttribute("OffRig", true)
				player:SetAttribute("EverOff", true) -- (no Untouched badge this zone)
				if os.clock() - i.pushedAt > 3 then
					notify(player, "ThrownOff")
				end
			end
		elseif not riding and i.off then
			i.off = false
			player:SetAttribute("OffRig", false)
			player:SetAttribute("Behind", -1)
		end
		if i.off then
			local fill = (dist - C.WARN_STUDS) / C.PULL_STUDS
			player:SetAttribute("Behind", dist > C.WARN_STUDS and math.clamp(fill, 0, 1) or -1)
			player:SetAttribute("RigDistance", math.floor(dist / Config.STUDS_PER_METRE))
			if fill >= 1 or h < -60 then
				-- PULLED BACK: a 3 s screen, then onto the rig (no death loop)
				i.off = false
				player:SetAttribute("Behind", -1)
				notify(player, "PulledBack")
				task.delay(2.6, function()
					putOnDeck(player)
					player:SetAttribute("OffRig", false)
				end)
			end
		end
	end
end

function Crew.boardAll()
	for _, p in Players:GetPlayers() do
		putOnDeck(p)
	end
end

-- taken by the Hollow: back at the Beacon (or the rig) on half health (GDD 10.1)
function Crew.taken(player: Player)
	local root, hum = rootOf(player)
	if not root or not hum then
		return
	end
	local beacon = state:GetAttribute("BeaconPos")
	local at = beacon and CFrame.new(beacon + Vector3.new(4, 4, 4)) or rig.deck.CFrame * CFrame.new(0, 4, 0)
	root.CFrame = at
	root.AssemblyLinearVelocity = Vector3.zero
	hum.Health = math.min(hum.Health, hum.MaxHealth * 0.5)
	notify(player, "Taken")
end

-- DOWNED (GDD 12: "come back on the spot when downed"): at the last point of
-- Health you drop where you are. A crewmate holding E beside you, or your own
-- Revive Flare, brings you back on the spot; otherwise after DOWN_TIME you wake on
-- the rig, weak, having dropped half your glowstone.
local DOWN_TIME = 12

function getUp(player: Player, health: number, where: CFrame?)
	local d = downed[player]
	if not d then
		return
	end
	downed[player] = nil
	if d.prompt then
		d.prompt:Destroy()
	end
	player:SetAttribute("Downed", nil)
	local root, hum = rootOf(player)
	if hum then
		hum.WalkSpeed = 16
		hum.JumpPower = 50
		hum.PlatformStand = false
		hum.Health = math.max(hum.Health, hum.MaxHealth * health)
		hum:ChangeState(Enum.HumanoidStateType.GettingUp)
	end
	if root and where then
		root.CFrame = where
		root.AssemblyLinearVelocity = Vector3.zero
	end
end

function Crew.down(player: Player)
	if downed[player] then
		return
	end
	local root, hum = rootOf(player)
	if not root or not hum then
		return
	end
	local ends = workspace:GetServerTimeNow() + DOWN_TIME
	downed[player] = { ends = ends }
	player:SetAttribute("Downed", ends)
	hum.WalkSpeed = 0
	hum.JumpPower = 0
	hum.PlatformStand = true -- (collapsed on the ground)
	local p = Data.get(player)
	player:SetAttribute("Flares", p and p.reviveFlares or 0)
	notify(player, "Downed")
	-- a crewmate can bring you back: hold E beside you
	local prompt = Instance.new("ProximityPrompt")
	prompt.Name = "ReviveCrew"
	prompt.ActionText = "Revive"
	prompt.ObjectText = player.DisplayName
	prompt.KeyboardKeyCode = Enum.KeyCode.E
	prompt.HoldDuration = 2.5
	prompt.MaxActivationDistance = 10
	prompt.RequiresLineOfSight = false
	prompt.Parent = root
	downed[player].prompt = prompt
	prompt.Triggered:Connect(function(by)
		if by == player or not downed[player] then
			return
		end
		getUp(player, 0.5)
		Data.update(by, function(q)
			q.stats.revived += 1
		end)
		notify(player, "Revived", by.DisplayName)
		Net.Notify:FireAllClients("Toast", by.DisplayName .. " revived " .. player.DisplayName .. "!")
	end)
	task.delay(DOWN_TIME, function()
		if downed[player] and downed[player].ends == ends then
			-- nobody came: wake on the rig, weak, half your glowstone left behind
			local g = player:GetAttribute("Glowstone") or 0
			player:SetAttribute("Glowstone", math.ceil(g / 2))
			getUp(player, 0.35, rig.deck.CFrame * CFrame.new(0, 4, 0))
			notify(player, "WokeOnRig")
		end
	end)
end

function Crew.isDowned(player: Player): boolean
	return downed[player] ~= nil
end

-- the rig hit a boulder: each player aboard has `chance` of being thrown off
function Crew.crashJolt(chance: number)
	for _, p in Players:GetPlayers() do
		if Crew.isAboard(p) and not downed[p] and math.random() < chance then
			shove(p, nil, "ThrownOff")
		end
	end
end

-- a creature dragged this player off the rig
function Crew.throwOff(player: Player)
	shove(player, nil, "Dragged")
end

-- creature damage: never kills outright; the last point of Health downs you
function Crew.hurt(player: Player, amount: number, kind: string?)
	local _, hum = rootOf(player)
	if hum and hum.Health > 0 and not downed[player] then
		hum.Health = math.max(1, hum.Health - amount)
		if kind then
			notify(player, kind)
		end
	end
end

return Crew
