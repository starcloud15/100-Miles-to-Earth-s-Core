--[[
	The crew: boarding the deck, the Crank Pump and Tow Line tools, falling
	off and catching up, the Left Behind winch (GDD 5.5), and Push Off
	(GDD 5.6: a paid shove, with safeguards).
]]

local MarketplaceService = game:GetService("MarketplaceService")
local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local Shared = game:GetService("ReplicatedStorage").Shared
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Art = require(Shared.Art)

local Crew = {}

local rig, route, state
local departedAt: number? = nil
local info: { [Player]: { off: boolean, s: number, lastCrank: number, lastTow: number, pushedBy: Player?, pushedAt: number, lastBehindNote: number } } = {}
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

local function notifyAll(kind: string, data: any?)
	Net.Notify:FireAllClients(kind, data)
end

-- a free spot on the deck: spread the crew over both halves
local function deckSpot(index: number): CFrame
	local slots = { Vector3.new(-5, 0, 4), Vector3.new(5, 0, 4), Vector3.new(-5, 0, -4), Vector3.new(5, 0, -4), Vector3.new(0, 0, 9) }
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

local function makeTool(name: string, icon: string, tip: string): Tool
	local tool = Instance.new("Tool")
	tool.Name = name
	tool.RequiresHandle = false
	tool.CanBeDropped = false
	tool.ToolTip = tip
	tool.TextureId = Art.icon(icon) or ""
	return tool
end

local function giveTools(player: Player)
	local backpack = player:WaitForChild("Backpack")
	for _, t in backpack:GetChildren() do
		t:Destroy()
	end
	makeTool("Crank Pump", "Crank", "Click to crank your side's tread").Parent = backpack
	makeTool("Tow Line", "DelversHook", "Click a crewmate who fell off to reel them in").Parent = backpack
end

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
	giveTools(player)
	task.defer(putOnDeck, player)
	local i = info[player]
	if i then
		i.off = false
	end
end

local function grace(): number
	return RunService:IsStudio() and Config.PushOff.GRACE_STUDIO or Config.PushOff.GRACE
end

-- shove `target` off the side of the deck, away from `from`
local function shove(target: Player, fromPos: Vector3?, kind: string)
	local root = rootOf(target)
	if not root then
		return
	end
	local deckCf = rig.deck.CFrame
	local rel = deckCf:PointToObjectSpace(root.Position)
	local side = rel.X >= 0 and 1 or -1
	if fromPos then
		local away = root.Position - fromPos
		side = deckCf.RightVector:Dot(away) >= 0 and 1 or -1
	end
	local v = deckCf.RightVector * side * 70 + Vector3.new(0, 38, 0) + rig.deck.AssemblyLinearVelocity
	local i = info[target]
	if i then
		i.pushedAt = os.clock()
	end
	Net.Shove:FireClient(target, v)
	notify(target, kind)
end

local function pushOff(pusher: Player, target: Player)
	shove(target, (rootOf(pusher) :: BasePart).Position, "PushedOff")
	pushedAt[target] = os.clock()
	notifyAll("PushOffDone", { by = pusher.DisplayName, target = target.DisplayName })
end

function Crew.init(theRig, theRoute, theState)
	rig, route, state = theRig, theRoute, theState

	local function added(player: Player)
		info[player] = { off = false, s = rig.s, lastCrank = 0, lastTow = 0, pushedAt = -10, lastBehindNote = 0 }
		player.CharacterAdded:Connect(function(char)
			onCharacter(player, char)
		end)
		if player.Character then
			onCharacter(player, player.Character)
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
		if not rel then
			return
		end
		i.lastCrank = now
		rig:crank(rel)
	end)

	Net.TowLine.OnServerEvent:Connect(function(player, target)
		local i = info[player]
		if not i or typeof(target) ~= "Instance" or not target:IsA("Player") or not info[target] then
			return
		end
		local now = os.clock()
		local root, troot = rootOf(player), rootOf(target)
		if not root or not troot or now - i.lastTow < Config.Crew.TOW_COOLDOWN then
			return
		end
		if not rig:deckPosition(root.Position) or not info[target].off then
			notify(player, "TowNo")
			return
		end
		if (troot.Position - root.Position).Magnitude > Config.Crew.TOW_RANGE then
			notify(player, "TowFar")
			return
		end
		i.lastTow = now
		-- a visible line between them, then reel them aboard
		local a0 = Instance.new("Attachment")
		a0.Parent = root
		local a1 = Instance.new("Attachment")
		a1.Parent = troot
		local beam = Instance.new("Beam")
		beam.Attachment0, beam.Attachment1 = a0, a1
		beam.Width0, beam.Width1 = 0.3, 0.3
		beam.Color = ColorSequence.new(Color3.fromRGB(196, 140, 80))
		beam.FaceCamera = true
		beam.Parent = root
		task.delay(0.6, function()
			beam:Destroy()
			a0:Destroy()
			a1:Destroy()
			putOnDeck(target)
			notify(target, "Towed", player.DisplayName)
			notify(player, "TowedOk", target.DisplayName)
		end)
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
			notify(player, "PushNo", "Push Off unlocks " .. math.ceil(grace() - (departedAt and os.clock() - departedAt or 0)) .. " s after departure")
			return
		end
		if os.clock() - (pushedAt[target] or -100) < P.TARGET_COOLDOWN then
			notify(player, "PushNo", target.DisplayName .. " was just pushed. Give them a moment!")
			return
		end
		if not rig:deckPosition(root.Position) or not rig:deckPosition(troot.Position) or (troot.Position - root.Position).Magnitude > P.RANGE + 4 then
			notify(player, "PushNo", "Get closer on the deck")
			return
		end
		if P.PRODUCT_ID ~= 0 then
			pendingPush[player] = target
			MarketplaceService:PromptProductPurchase(player, P.PRODUCT_ID)
		elseif RunService:IsStudio() then
			pushOff(player, target)
		else
			notify(player, "PushNo", "Push Off isn't on sale yet")
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
	departedAt = os.clock()
	state:SetAttribute("DepartedAt", workspace:GetServerTimeNow())
end

-- a hazard hit can throw players off the open deck
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
	if acc < 0.25 then
		return
	end
	acc = 0
	local C = Config.Crew
	for player, i in info do
		local root, hum = rootOf(player)
		if not root or not hum or hum.Health <= 0 then
			continue
		end
		if rig:deckPosition(root.Position) then
			if i.off then
				i.off = false
				notify(player, "Aboard")
			end
			hum.WalkSpeed = 16
			i.s = rig.s
			continue
		end
		local s, _, h = route:locate(root.Position, i.s, 1200)
		i.s = s
		local dist = (root.Position - rig.deck.Position).Magnitude
		if not i.off and dist > C.OFF_DISTANCE then
			i.off = true
			if os.clock() - i.pushedAt > 3 then
				notify(player, "ThrownOff")
			end
		end
		if i.off then
			hum.WalkSpeed = C.CATCHUP_WALKSPEED
			local behind = rig.s - s
			if behind > C.LEFT_BEHIND or h < -40 then
				-- the winch hauls you back; no death loop
				hum.Health = math.max(1, hum.Health - hum.MaxHealth * 0.1)
				putOnDeck(player)
				i.off = false
				notify(player, "LeftBehind")
			elseif os.clock() - i.lastBehindNote > 0.5 then
				i.lastBehindNote = os.clock()
				notify(player, "Behind", math.floor(dist / Config.STUDS_PER_METRE))
			end
		end
	end
end

function Crew.boardAll()
	for _, p in Players:GetPlayers() do
		putOnDeck(p)
	end
end

return Crew
