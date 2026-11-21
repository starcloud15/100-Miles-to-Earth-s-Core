--[[
	The Game place client: tools (Crank Pump, Pickaxe, Delver's Hook, Food),
	the action hint, sliding when off the rig, camera shake, Push Off prompts
	over crewmates, and the server's messages.
]]

local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Config = require(Shared.Config)
local Net = require(Shared.Net)
local Ui = require(Shared.Ui)
local Hud = require(script.Parent:WaitForChild("Hud"))

local player = Players.LocalPlayer
local state = ReplicatedStorage:WaitForChild("RunState")
local camera = workspace.CurrentCamera
-- the reference frames the raft from about 12-16 studs; capping the zoom also
-- keeps the camera inside the tunnel instead of out in the rock
player.CameraMaxZoomDistance = 24

local function root(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function humanoid(): Humanoid?
	local c = player.Character
	return c and c:FindFirstChildOfClass("Humanoid")
end

local function deck(): BasePart?
	local rig = workspace:FindFirstChild("DrillRig")
	return rig and rig:FindFirstChild("Deck") :: BasePart?
end

local function onDeck(pos: Vector3): boolean
	local d = deck()
	if not d then
		return false
	end
	local rel = d.CFrame:PointToObjectSpace(pos)
	local R = Config.Rig
	return math.abs(rel.X) <= R.DECK_W / 2 + 1.5 and math.abs(rel.Z) <= R.DECK_L / 2 + 1.5 and rel.Y > -1 and rel.Y < 9
end

-- camera shake: a constant rumble that grows with speed, plus jolts --------------
local jolt = 0
local function shake(amount: number)
	jolt = math.max(jolt, amount)
end

-- tools ------------------------------------------------------------------------------
local delving = nil -- { bite = time } while the hook is in the rock
local held: string? = nil
local heldTool: Tool? = nil
local Finds = require(Shared.Finds)
local Hotbar = require(script.Parent:WaitForChild("Hotbar"))
local Sfx = require(script.Parent:WaitForChild("Sfx"))
local Pops = require(script.Parent:WaitForChild("Pops"))
Hotbar.init()
Pops.init()

local function nearestVein(): Model?
	local r = root()
	if not r then
		return nil
	end
	local mouse = player:GetMouse()
	local target = mouse.Target
	local m = target and target:FindFirstAncestorWhichIsA("Model")
	if m and m.Name == "Vein" then
		return m
	end
	local best, bestD = nil, 18
	for _, v in workspace:WaitForChild("Cavern"):GetDescendants() do
		if v:IsA("Model") and v.Name == "Vein" and v.PrimaryPart then
			local d = (v.PrimaryPart.Position - r.Position).Magnitude
			if d < bestD then
				best, bestD = v, d
			end
		end
	end
	return best
end

local playMove -- (the tool-use animations, defined below)

local function activate(tool: Tool)
	if tool.Name == "Crank Pump" then
		playMove("Crank")
		Sfx.play("Crank", 0.5)
		Net.Crank:FireServer()
		shake(0.15)
	elseif tool.Name == "Pickaxe" then
		-- every click swings, vein or not (owner)
		playMove("Swing")
		local v = nearestVein()
		if v then
			Net.Mine:FireServer(v)
			shake(0.2)
		else
			Hud.toast("Mine the glowing veins at stops", Ui.ORANGE, 1.4)
		end
	elseif tool.Name == "Delver's Hook" then
		if delving then
			playMove("Reel")
			Sfx.play("Reel", 0.6)
			Net.Delve:FireServer("reel")
		else
			playMove("Cast")
			Sfx.play("Cast", 0.6)
			-- (the hook leaves the rod as the arm comes forward)
			task.delay(0.18, function()
				Net.Delve:FireServer("cast")
			end)
		end
	elseif tool:GetAttribute("Find") == "Glowstone" then
		Hud.toast("Feed it to the Beacon, or repair the rig with it. G drops it.", Ui.ORANGE, 1.6)
	elseif tool:GetAttribute("Find") then
		-- a find: eat one
		playMove("Eat")
		Sfx.play("Eat", 0.7)
		Net.Eat:FireServer()
	end
end

local function hookTool(tool: Instance)
	if not tool:IsA("Tool") or tool:GetAttribute("Hooked") then
		return
	end
	tool:SetAttribute("Hooked", true)
	tool.Activated:Connect(function()
		activate(tool)
	end)
	tool.Equipped:Connect(function()
		held = tool.Name
		heldTool = tool
	end)
	tool.Unequipped:Connect(function()
		if held == tool.Name then
			held = nil
			heldTool = nil
		end
	end)
end

local function watchCharacter(char: Model)
	for _, c in char:GetChildren() do
		hookTool(c)
	end
	char.ChildAdded:Connect(hookTool)
	local backpack = player:WaitForChild("Backpack")
	for _, c in backpack:GetChildren() do
		hookTool(c)
	end
	backpack.ChildAdded:Connect(hookTool)
	-- the dust trail when sliding after the rig
	local r = char:WaitForChild("HumanoidRootPart")
	local att = Instance.new("Attachment")
	att.Position = Vector3.new(0, -2.8, 0)
	att.Parent = r
	local dust = Instance.new("ParticleEmitter")
	dust.Name = "SlideDust"
	dust.Texture = "rbxasset://textures/particles/smoke_main.dds"
	dust.Color = ColorSequence.new(Color3.fromRGB(200, 160, 120))
	dust.Size = NumberSequence.new(1.5, 4)
	dust.Transparency = NumberSequence.new(0.4, 1)
	dust.Lifetime = NumberRange.new(0.5, 0.9)
	dust.Speed = NumberRange.new(2, 5)
	dust.Rate = 0
	dust.Parent = att
end
player.CharacterAdded:Connect(watchCharacter)
if player.Character then
	task.spawn(watchCharacter, player.Character)
end

-- Push Off: "F · Push Off · 19" over a crewmate you're facing on the deck ------------
local pushTarget: Player? = nil
local prompts: { [Player]: BillboardGui } = {}

local function promptFor(p: Player): BillboardGui?
	local head = p.Character and p.Character:FindFirstChild("Head")
	if not head then
		return nil
	end
	local bb = prompts[p]
	if not bb or not bb.Parent then
		bb = Ui.new("BillboardGui", { Name = "PushOff", Size = UDim2.fromOffset(150, 44), StudsOffset = Vector3.new(0, 2.2, 0), AlwaysOnTop = true, Adornee = head, Parent = player.PlayerGui })
		local key = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(30, 30, 32), Size = UDim2.fromOffset(34, 34), Position = UDim2.fromOffset(0, 5), Parent = bb }, { Ui.corner(UDim.new(0.5, 0)), Ui.stroke(2, Color3.new(1, 1, 1), true) })
		Ui.new("TextLabel", { BackgroundTransparency = 1, Text = "F", FontFace = Ui.FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(0.7, 0.7), Position = UDim2.fromScale(0.15, 0.15), Parent = key })
		Ui.text({ Parent = bb, Text = "Push Off", Position = UDim2.fromOffset(40, 2), Size = UDim2.fromOffset(100, 20), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 2 })
		Ui.new("ImageLabel", { BackgroundTransparency = 1, Image = Ui.ROBUX, Position = UDim2.fromOffset(40, 23), Size = UDim2.fromOffset(16, 16), Parent = bb })
		Ui.text({ Parent = bb, Text = tostring(Config.PushOff.PRICE), Position = UDim2.fromOffset(58, 22), Size = UDim2.fromOffset(40, 18), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 2 })
		local button = Ui.new("TextButton", { BackgroundTransparency = 1, Text = "", Size = UDim2.fromScale(1, 1), Parent = bb })
		button.Activated:Connect(function()
			Net.PushOff:FireServer(p)
		end)
		bb.Active = true
		prompts[p] = bb
	end
	return bb
end

-- Push Off is a paid product: until it has a product id it only works in Studio
local pushOffSold = Config.PushOff.PRODUCT_ID ~= 0 or RunService:IsStudio()

local function updatePushPrompts()
	local r = root()
	pushTarget = nil
	if not pushOffSold then
		return
	end
	local look = camera.CFrame.LookVector
	local bestScore = 0.4
	for _, p in Players:GetPlayers() do
		if p ~= player then
			local pr = p.Character and p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			local ok = r and pr and onDeck(r.Position) and onDeck(pr.Position) and (pr.Position - r.Position).Magnitude <= Config.PushOff.RANGE
			local bb = promptFor(p)
			if bb then
				bb.Enabled = ok == true
			end
			if ok then
				local score = look:Dot(((pr :: BasePart).Position - (r :: BasePart).Position).Unit)
				if score > bestScore then
					pushTarget, bestScore = p, score
				end
			end
		end
	end
end

ContextActionService:BindAction("PushOff", function(_, inputState)
	if inputState == Enum.UserInputState.Begin and pushTarget then
		Net.PushOff:FireServer(pushTarget)
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.F)

-- server messages ---------------------------------------------------------------------
Net.Shove.OnClientEvent:Connect(function(velocity: Vector3)
	local r, hum = root(), humanoid()
	if r and hum then
		hum.PlatformStand = true
		r.AssemblyLinearVelocity = velocity
		shake(0.8)
		task.delay(0.7, function()
			hum.PlatformStand = false
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end)
	end
end)

local MESSAGES = {
	ThrownOff = { "THROWN OFF!", Ui.RED },
	PushedOff = { "PUSHED OFF!", Ui.RED },
	Aboard = { "Back aboard!", Ui.GREEN },
	Hit = { "CRASH!", Ui.RED },
}

Net.Notify.OnClientEvent:Connect(function(kind: string, data: any)
	if kind == "PulledBack" then
		Hud.pulledBack()
	elseif kind == "StopName" then
		Hud.stopName(tostring(data))
		Sfx.play("Fanfare", 0.6)
	elseif kind == "Banner" then
		task.delay(0.1, function()
			Hud.toast(tostring(data), Color3.new(1, 1, 1), 2.4)
		end)
	elseif kind == "Toast" then
		Hud.toast(tostring(data), Ui.ORANGE, 2)
	elseif kind == "Mined" then
		-- glowstone bursts out of the vein, bounces, and flies into your Bag
		if type(data) == "table" and typeof(data.at) == "Vector3" then
			Sfx.play("Mine", 0.8, data.at)
			Pops.burst("Glowstone", data.at, data.n or 1, function()
				Hotbar.bagPop("Glowstone", 1)
				Sfx.play("Collect", 0.35)
			end)
		end
	elseif kind == "Fed" then
		Hud.toast("+0.1x", Color3.fromRGB(255, 214, 40), 0.6)
	elseif kind == "Cast" then
		-- ("..." and "!" are drawn on the hook itself: client/Hook.luau)
		local d = { bite = os.clock() + (tonumber(data) or 3) }
		delving = d
		task.delay(tonumber(data) or 3, function()
			if delving == d then
				shake(0.25)
			end
		end)
	elseif kind == "DelveResult" then
		delving = nil
		if type(data) == "table" and data.result == "catch" then
			-- the find pops off the hook and flies into its hotbar slot
			local f = Finds.BY_ID[data.find]
			local r = root()
			local from = typeof(data.at) == "Vector3" and data.at or (r and r.Position + r.CFrame.LookVector * 6)
			if f and from then
				Sfx.play("Pop", 0.7)
				Pops.burst(f.id, from, 1, function()
					Hotbar.bump(f.id)
					Sfx.play("Collect", 0.5)
				end)
				Hud.toast((f.rare and "RARE! " or "") .. "You reeled up a " .. f.name .. "!", f.rare and Color3.fromRGB(255, 214, 40) or Ui.GREEN, 1.6)
			end
		elseif data == "early" then
			Hud.toast("Too early", Color3.new(1, 1, 1), 1)
		else
			Hud.toast("It slipped away", Color3.new(1, 1, 1), 1)
		end
	elseif kind == "Ate" then
		local n = type(data) == "table" and data.hunger or data
		Hud.toast("+" .. tostring(n) .. "% Hunger", Ui.GREEN, 1)
	elseif kind == "Revived" then
		Hud.toast("Revived by " .. tostring(data) .. "!", Ui.GREEN, 2)
	elseif kind == "WokeOnRig" then
		Hud.toast("You came to on the rig. Half your glowstone was left behind", Ui.ORANGE, 2.5)
	elseif kind == "Downed" then
		shake(1)
		Sfx.play("Downed", 0.8)
	elseif kind == "PickedUp" then
		Sfx.play("Collect", 0.6)
		local f = Finds.BY_ID[data]
		Hotbar.bump(data)
		Hud.toast("Picked up " .. (f and f.name or "a find"), Ui.GREEN, 1)
	elseif kind == "Pulse" then
		-- zone 6: the Core's light comes in beats
		if data == "Fading" then
			Hud.toast("The light is fading! Get to the rig's lamp or the Beacon!", Ui.ORANGE, 2)
		elseif data == "Light" then
			Hud.toast("PULSE!", Color3.fromRGB(255, 214, 40), 0.8)
			shake(0.3)
		end
	elseif kind == "Breakthrough" then
		shake(1)
		Hud.toast("BREAKTHROUGH!", Color3.fromRGB(255, 214, 40), 1.2)
	elseif kind == "ZoneComplete" then
		if (state:GetAttribute("Zone") or 1) >= #Config.ZONES then
			-- the finale: 100 miles down
			Hud.stopName("YOU REACHED THE CORE!")
			shake(1.5)
			task.delay(3, function()
				Hud.toast("100 miles down! Your next descent starts from the surface.", Color3.fromRGB(255, 214, 40), 5)
			end)
		else
			Hud.stopName("ZONE COMPLETE!")
		end
	elseif kind == "PushOffDone" then
		if data.target ~= player.DisplayName then
			Hud.toast(data.by .. " pushed " .. data.target .. " off!", Ui.PURPLE, 2)
		end
	else
		local m = MESSAGES[kind]
		if m then
			Hud.toast(m[1], m[2])
			if kind == "Hit" then
				shake(1.2)
				Sfx.play("Hit", 0.9)
			end
		end
	end
end)

-- sliding after the rig: a real slide animation instead of fast walking ----------------
-- (uploaded through Starport as animations/Character/Slide; until then, Studio
-- previews it from the same pose data in Shared.Poses)
local Art = require(Shared.Art)
local Poses = require(Shared.Poses)
local slideTrack: AnimationTrack? = nil
local slideChar: Model? = nil

-- load one of Shared.Poses' animations on a humanoid: the uploaded one, or in
-- Studio, the same pose data registered on the fly
local function loadPose(hum: Humanoid, name: string): AnimationTrack?
	local id = Art.get("animations", "Character/" .. name)
	if not id and RunService:IsStudio() then
		local ok, res = pcall(function()
			local kfs = Poses.build(Poses[name], Instance, CFrame, Enum)
			return game:GetService("KeyframeSequenceProvider"):RegisterKeyframeSequence(kfs)
		end)
		id = ok and res or nil
	end
	local animator = hum:FindFirstChildOfClass("Animator")
	if not id or not animator then
		return nil
	end
	local anim = Instance.new("Animation")
	anim.AnimationId = id
	local track = animator:LoadAnimation(anim)
	track.Looped = Poses[name].looped == true
	track.Priority = Enum.AnimationPriority.Action4
	return track
end

local function getSlideTrack(hum: Humanoid): AnimationTrack?
	if slideTrack and slideChar == hum.Parent then
		return slideTrack
	end
	slideTrack = loadPose(hum, "Slide")
	slideChar = slideTrack and hum.Parent or nil
	return slideTrack
end

-- tool use: Swing (Pickaxe), Crank, Cast and Reel (Delver's Hook), Eat
local moveTracks: { [string]: AnimationTrack } = {}
local moveChar: Model? = nil
playMove = function(name: string)
	local hum = humanoid()
	if not hum then
		return
	end
	if moveChar ~= hum.Parent then
		moveTracks = {}
		moveChar = hum.Parent
	end
	local track = moveTracks[name]
	if not track then
		track = loadPose(hum, name)
		if not track then
			return
		end
		moveTracks[name] = track
	end
	track:Play(0.05)
	track.TimePosition = 0
end

RunService.Heartbeat:Connect(function()
	local hum = humanoid()
	if not hum then
		return
	end
	local off = player:GetAttribute("OffRig") == true
	local grounded = hum.FloorMaterial ~= Enum.Material.Air and not hum.PlatformStand
	local want = off and grounded and hum.MoveDirection.Magnitude > 0.1
	local track = (want or (slideTrack and slideTrack.IsPlaying)) and getSlideTrack(hum)
	if track then
		if want and not track.IsPlaying then
			track:Play(0.15)
		elseif not want and track.IsPlaying then
			track:Stop(0.2)
		end
	end
end)

-- riding the rig like a train: jump on it and you land on the same spot ---------------
-- Standing on the deck, Roblox carries you with it. In the air you'd keep the
-- speed you jumped with while the rig turns and dives downhill under you, so
-- you'd drift off. While you're in the air above the deck, you move with the
-- rig's frame instead (its turns and drops carry you), and your own jump and
-- movement stay relative to the deck. Leave the deck's footprint and you get
-- the rig's speed back and fall off naturally; a shove (PlatformStand) is never carried.
local lastDeckCF: CFrame? = nil
local carrying = false

local function overDeck(d: BasePart, pos: Vector3): boolean
	local rel = d.CFrame:PointToObjectSpace(pos)
	local R = Config.Rig
	return math.abs(rel.X) <= R.DECK_W / 2 + 1 and math.abs(rel.Z) <= R.DECK_L / 2 + 1 and rel.Y > -1 and rel.Y < 30
end

RunService.Heartbeat:Connect(function()
	local d, r, hum = deck(), root(), humanoid()
	if not d or not r or not hum then
		lastDeckCF = nil
		carrying = false
		return
	end
	local deckCF = d.CFrame
	local state = hum:GetState()
	local airborne = state == Enum.HumanoidStateType.Jumping or state == Enum.HumanoidStateType.Freefall
	local want = airborne and not hum.PlatformStand and overDeck(d, r.Position)
	if want and not carrying then
		-- take the rig's own motion out of your velocity: the deck's frame carries that now
		r.AssemblyLinearVelocity -= d.AssemblyLinearVelocity
		carrying = true
	elseif carrying and not want then
		if airborne and not hum.PlatformStand then
			-- jumped off the edge: you leave with the rig's speed, like stepping off a train
			r.AssemblyLinearVelocity += d.AssemblyLinearVelocity
		end
		carrying = false
	end
	if carrying and lastDeckCF then
		r.CFrame = deckCF * lastDeckCF:ToObjectSpace(r.CFrame)
		-- your sideways speed is only your own input; the rig's motion is the frame's
		local v = r.AssemblyLinearVelocity
		local md = hum.MoveDirection * hum.WalkSpeed
		r.AssemblyLinearVelocity = Vector3.new(md.X, v.Y, md.Z)
	end
	lastDeckCF = deckCF
	player:SetAttribute("Carrying", carrying) -- (local only: for playtests)
end)

-- the drill bit spins and the crank levers rock, drawn here on each client:
-- Motor6D transforms don't replicate, and this costs one CFrame per part a frame
local bitAngle = 0
local leverAt = { L = -10, R = -10 }
local watchedDeck: BasePart? = nil
RunService.RenderStepped:Connect(function(dt)
	local d = deck()
	if not d then
		return
	end
	if d ~= watchedDeck then
		watchedDeck = d
		for _, side in { "L", "R" } do
			d:GetAttributeChangedSignal("Pump" .. side):Connect(function()
				leverAt[side] = os.clock()
			end)
		end
	end
	local bitMotor = d:FindFirstChild("BitMotor") :: Motor6D?
	if bitMotor then
		bitAngle = (bitAngle + (state:GetAttribute("Speed") or 0) * dt * 0.5) % (math.pi * 2)
		bitMotor.Transform = CFrame.Angles(0, 0, bitAngle)
	end
	for side, t in leverAt do
		local motor = d:FindFirstChild("CrankMotor" .. side) :: Motor6D?
		if motor then
			local k = (os.clock() - t) / 0.28
			motor.Transform = k < 1 and CFrame.Angles(math.sin(k * math.pi * 2) * math.rad(24), 0, 0) or CFrame.new()
		end
	end
end)

-- every frame -------------------------------------------------------------------------
local acc = 0
local rumbleT = 0
local liftY = 0
RunService.RenderStepped:Connect(function(dt)
	local r, hum = root(), humanoid()
	local aboard = r ~= nil and onDeck(r.Position)
	local d = deck()

	-- aboard, the camera stays pulled back and up, over the rig's engine, so you
	-- see the crew and the route ahead (the reference's high raft camera)
	local wantZoom = aboard and 17 or 0.5
	if player.CameraMinZoomDistance ~= wantZoom then
		player.CameraMinZoomDistance = wantZoom
	end

	-- camera shake through the humanoid's camera offset
	local speed = state:GetAttribute("Speed") or 0
	local moving = state:GetAttribute("Moving") == true
	rumbleT += dt
	jolt = math.max(0, jolt - dt * 2.5)
	local amount = (aboard and moving and math.clamp(speed / 100, 0, 1) * 0.22 or 0) + jolt * 0.6
	-- aboard, the camera's focus rises above the engine's stacks, so it looks down
	-- on the deck and the route like the reference's raft camera
	liftY += ((aboard and 7 or 0) - liftY) * math.min(1, dt * 4)
	if hum then
		hum.CameraOffset = Vector3.new(math.noise(rumbleT * 18, 1) * amount, liftY + math.noise(rumbleT * 18, 7) * amount, 0)
	end

	-- off the rig: slide down the slope faster than you can run
	local off = player:GetAttribute("OffRig") == true
	if hum then
		hum.WalkSpeed = off and Config.Crew.SLIDE_SPEED or 16
	end
	local dust = r and r:FindFirstChild("SlideDust", true) :: ParticleEmitter?
	if dust then
		dust.Rate = (off and hum and hum.MoveDirection.Magnitude > 0.1) and 30 or 0
	end

	acc += dt
	if acc < 0.05 then
		return
	end
	acc = 0
	local rigScreen, onScreen = nil, false
	if d then
		local v, vis = camera:WorldToViewportPoint(d.Position + Vector3.new(0, 6, 0))
		if v.Z < 0 then
			v = Vector3.new(camera.ViewportSize.X - v.X, camera.ViewportSize.Y * 0.85, v.Z)
			vis = false
		end
		rigScreen, onScreen = v, vis
	end
	Hud.update(state, {
		aboard = aboard,
		behind = player:GetAttribute("Behind") or -1,
		rigDistance = player:GetAttribute("RigDistance") or 0,
		rigScreen = rigScreen,
		onScreen = onScreen,
	})
	-- (the RIG marker itself moves every frame: below)
	-- the action hint follows the tool in your hand
	local verbs = { ["Crank Pump"] = "Crank", Pickaxe = "Mine", ["Delver's Hook"] = delving and "Reel" or "Cast" }
	local holdingItem = heldTool ~= nil and heldTool.Parent ~= nil and heldTool:GetAttribute("Find") ~= nil
	local isGlow = holdingItem and heldTool:GetAttribute("Find") == "Glowstone"
	Hud.setHint(holdingItem and (isGlow and "Use" or "Eat") or (held and verbs[held] or nil), holdingItem)
	updatePushPrompts()
end)

-- creatures on the rig and their SPAM! buttons
require(script.Parent:WaitForChild("Creatures")).init({ deck = deck, shake = shake, toast = Hud.toast })

-- the RIG marker: placed every frame after the camera moves, with the distance
-- measured here (the server's figure only updates a few times a second: it lagged)
RunService:BindToRenderStep("RigMarker", Enum.RenderPriority.Camera.Value + 1, function(dt)
	local d = deck()
	local r = root()
	if not d or not r then
		Hud.marker(nil, false, 0)
		return
	end
	local v, vis = camera:WorldToViewportPoint(d.Position + Vector3.new(0, 6, 0))
	if v.Z < 0 then
		v = Vector3.new(camera.ViewportSize.X - v.X, camera.ViewportSize.Y * 0.85, v.Z)
		vis = false
	end
	local studs = (r.Position - d.Position).Magnitude
	Hud.marker(v, vis, math.floor(studs / Config.STUDS_PER_METRE), studs, dt)
end)

-- G drops one of the find in your hand (on phones: a Drop button while holding one)
ContextActionService:BindAction("DropFind", function(_, st)
	if st == Enum.UserInputState.Begin and heldTool and heldTool.Parent == player.Character and heldTool:GetAttribute("Find") then
		Net.Drop:FireServer()
		return Enum.ContextActionResult.Sink
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.G)

-- a dropped item: its model floats there, turning slowly in a soft green glow;
-- walk up and its card appears beside it, like the reference's: [E], the name in
-- its rarity colour, the rarity tag, and what it is
do
	local ProximityPromptService = game:GetService("ProximityPromptService")
	-- (a screen card that follows the item every frame: crisp at any distance)
	local card = Ui.new("ScreenGui", { Name = "PickupCard", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 6, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
	local holder = Ui.new("Frame", { BackgroundTransparency = 1, AnchorPoint = Vector2.new(0, 1), Size = UDim2.fromOffset(420, 70), Parent = card })
	local back = Ui.new("TextButton", { Text = "", AutoButtonColor = false, BackgroundColor3 = Color3.fromRGB(14, 14, 16), BackgroundTransparency = 0.08, Position = UDim2.fromOffset(22, 0), Size = UDim2.new(1, -22, 1, 0), Parent = holder }, { Ui.corner(UDim.new(0, 14)) })
	local key = Ui.new("Frame", { BackgroundColor3 = Color3.new(0, 0, 0), Position = UDim2.fromOffset(0, 12), Size = UDim2.fromOffset(46, 46), Parent = holder }, { Ui.corner(UDim.new(0.5, 0)), Ui.stroke(3, Color3.new(1, 1, 1), true) })
	local keyText = Ui.new("TextLabel", { BackgroundTransparency = 1, Text = "E", FontFace = Ui.FONT, TextScaled = true, TextColor3 = Color3.new(1, 1, 1), Size = UDim2.fromScale(0.6, 0.6), Position = UDim2.fromScale(0.2, 0.2), Parent = key })
	local name = Ui.new("TextLabel", { BackgroundTransparency = 1, FontFace = Ui.FONT, TextScaled = true, TextColor3 = Color3.fromRGB(140, 255, 120), Position = UDim2.fromOffset(34, 7), Size = UDim2.new(1, -150, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, Parent = back })
	local rare = Ui.new("TextLabel", { FontFace = Ui.FONT, TextScaled = true, TextColor3 = Color3.new(0, 0, 0), AnchorPoint = Vector2.new(1, 0), Position = UDim2.new(1, -10, 0, 9), Size = UDim2.fromOffset(100, 20), Parent = back }, { Ui.corner(UDim.new(0.3, 0)), Ui.stroke(2, Color3.new(0, 0, 0), true) })
	local desc = Ui.new("TextLabel", { BackgroundTransparency = 1, FontFace = Ui.FONT, TextScaled = true, TextWrapped = true, TextColor3 = Color3.new(1, 1, 1), Position = UDim2.fromOffset(34, 36), Size = UDim2.new(1, -44, 0, 26), TextXAlignment = Enum.TextXAlignment.Left, Parent = back })
	local UIS = game:GetService("UserInputService")
	local current: ProximityPrompt? = nil
	ProximityPromptService.PromptShown:Connect(function(prompt)
		local id = prompt:GetAttribute("Find")
		local f = id == "Glowstone" and Finds.GLOWSTONE or Finds.BY_ID[id or ""]
		if not f then
			return
		end
		current = prompt
		local color = Finds.RARITY[f.rarity] or Color3.new(1, 1, 1)
		name.Text = f.name
		name.TextColor3 = color
		rare.Text = f.rarity
		rare.BackgroundColor3 = color
		desc.Text = f.desc
		keyText.Text = (UIS.TouchEnabled and not UIS.KeyboardEnabled) and "TAP" or "E"
		card.Enabled = true
	end)
	ProximityPromptService.PromptHidden:Connect(function(prompt)
		if prompt == current then
			current = nil
			card.Enabled = false
		end
	end)
	-- (on a phone, tap the card)
	back.Activated:Connect(function()
		if current then
			current:InputHoldBegin()
			task.wait()
			if current then
				current:InputHoldEnd()
			end
		end
	end)
	Ui.fit(card)
	-- dropped items turn and bob in their glow (and ride along on the rig)
	local spun = {}
	RunService.RenderStepped:Connect(function()
		-- the card sits up and to the right of the item, like the reference's
		local at = current and current.Parent and (current.Parent :: BasePart).Position
		if at then
			local v, onScreen = camera:WorldToViewportPoint(at + Vector3.new(0, 1.2, 0))
			holder.Visible = onScreen
			holder.Position = UDim2.fromOffset(v.X + 30, v.Y - 10)
		end
		local t = os.clock()
		local d = deck()
		for _, m in workspace:GetChildren() do
			if m.Name == "DroppedItem" and m:IsA("Model") and m.PrimaryPart then
				local s = spun[m]
				if not s then
					-- remember each piece relative to the anchor, and add the glow
					s = { base = m.PrimaryPart.CFrame, parts = {} }
					for _, p in m:GetChildren() do
						if p:IsA("BasePart") and p ~= m.PrimaryPart then
							s.parts[p] = m.PrimaryPart.CFrame:ToObjectSpace(p.CFrame)
						end
					end
					local glow = Ui.new("BillboardGui", { Name = "Glow", Size = UDim2.fromScale(4, 4), LightInfluence = 0, Parent = m.PrimaryPart })
					for i, a in { 0.92, 0.86, 0.78, 0.7 } do
						local k = 1 - (i - 1) * 0.22
						Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(90, 255, 110), BackgroundTransparency = a, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.5), Size = UDim2.fromScale(k, k), BorderSizePixel = 0, Parent = glow }, { Ui.corner(UDim.new(0.5, 0)) })
					end
					spun[m] = s
				end
				local base = s.base
				if m:GetAttribute("OnRig") and d then
					local off = m:GetAttribute("DeckOffset")
					if typeof(off) == "Vector3" then
						base = CFrame.new(d.CFrame:PointToWorldSpace(off))
					end
				end
				local cf = base * CFrame.new(0, 0.6 + math.sin(t * 2.2) * 0.18, 0) * CFrame.Angles(0, t * 1.4, 0)
				-- (the prompt's own part stays put unless the rig carries it: moving it
				-- every frame made the pickup card flicker)
				if m:GetAttribute("OnRig") and (m.PrimaryPart.Position - base.Position).Magnitude > 0.5 then
					m.PrimaryPart.CFrame = base
				end
				for p, rel in s.parts do
					p.CFrame = cf * rel
				end
			end
		end
		for m in spun do
			if not m.Parent then
				spun[m] = nil
			end
		end
	end)
end

-- DOWNED: the screen greys, a countdown to waking on the rig, and your Revive
-- Flare if you have one (crewmates hold E beside you to bring you back)
do
	local dgui = Ui.new("ScreenGui", { Name = "Downed", ResetOnSpawn = false, IgnoreGuiInset = true, DisplayOrder = 8, Enabled = false, Parent = player:WaitForChild("PlayerGui") })
	Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(40, 0, 0), BackgroundTransparency = 0.45, BorderSizePixel = 0, Size = UDim2.fromScale(1, 1), Parent = dgui })
	local title = Ui.text({ Parent = dgui, Text = "DOWNED!", TextColor3 = Ui.RED, AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.32), Size = UDim2.fromScale(0.4, 0.11), Stroke = 5 })
	title.FontFace = Ui.ITALIC
	local sub = Ui.text({ Parent = dgui, Text = "", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.42), Size = UDim2.fromScale(0.5, 0.045), Stroke = 3 })
	local help = Ui.text({ Parent = dgui, Text = "A crewmate can hold E beside you to revive you", TextColor3 = Color3.fromRGB(230, 230, 230), AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.48), Size = UDim2.fromScale(0.5, 0.032), Stroke = 2 })
	local flare = Ui.button({ Parent = dgui, Text = "Use Revive Flare", AnchorPoint = Vector2.new(0.5, 0.5), Position = UDim2.fromScale(0.5, 0.6), Size = UDim2.fromOffset(360, 84) })
	flare.Activated:Connect(function()
		Net.UseFlare:FireServer()
	end)
	local _ = help
	RunService.RenderStepped:Connect(function()
		local ends = player:GetAttribute("Downed")
		dgui.Enabled = type(ends) == "number"
		if dgui.Enabled then
			local left = math.max(0, math.ceil(ends - workspace:GetServerTimeNow()))
			sub.Text = "Back on the rig in " .. left .. "s"
			local n = player:GetAttribute("Flares") or 0
			flare.Visible = n > 0
			local label = flare:FindFirstChild("Label") :: TextLabel?
			if label then
				label.Text = "Use Revive Flare (x" .. n .. ")"
			end
		end
	end)
end

-- the rig's drill, louder and faster with speed; the caves' ambience; Lights Out
do
	local drillSound: Sound? = nil
	local cave = Sfx.loop("Cave", workspace.CurrentCamera, 0.25)
	local lastPhase = state:GetAttribute("Phase")
	RunService.Heartbeat:Connect(function()
		local d = deck()
		if d and not drillSound then
			drillSound = Sfx.loop("Drill", d, 0)
		end
		if drillSound then
			local speed = state:GetAttribute("Speed") or 0
			local moving = state:GetAttribute("Moving") == true
			local want = moving and math.clamp(0.25 + speed / 120, 0, 0.7) or 0
			drillSound.Volume += (want - drillSound.Volume) * 0.08
			drillSound.PlaybackSpeed = 0.85 + math.clamp(speed / 100, 0, 1) * 0.35
		end
		if cave then
			-- (the cave air only underground: quiet on the surface gorge)
			local miles = (state:GetAttribute("MileOffset") or 0) + (state:GetAttribute("Distance") or 0) / Config.STUDS_PER_MILE
			cave.Volume = miles < 1 and 0.05 or 0.25
		end
		local phase = state:GetAttribute("Phase")
		if phase ~= lastPhase then
			if phase == "Night" then
				Sfx.play("Night", 0.7)
			end
			lastPhase = phase
		end
	end)
end

-- every player's Delver's Hook, cast out on its line
require(script.Parent:WaitForChild("Hook")).init(deck)

-- zone 6's Pulses: while the light fades and in the dark, a lit circle round the
-- middle of the rig shows where the furnace lamp keeps you safe
do
	local ring: BasePart? = nil
	RunService.RenderStepped:Connect(function()
		local pulse = state:GetAttribute("Pulse")
		local d = deck()
		local show = (pulse == "Fading" or pulse == "Dark") and d ~= nil
		if show and not ring then
			local r = Instance.new("Part")
			r.Name = "PulseSafe"
			r.Shape = Enum.PartType.Cylinder
			r.Anchored = true
			r.CanCollide = false
			r.CanQuery = false
			r.CanTouch = false
			r.CastShadow = false
			r.Material = Enum.Material.Neon
			r.Color = Color3.fromRGB(255, 214, 90)
			r.Size = Vector3.new(0.15, Config.Pulses.SAFE * 2, Config.Pulses.SAFE * 2)
			local l = Instance.new("PointLight")
			l.Color = Color3.fromRGB(255, 200, 110)
			l.Range = Config.Pulses.SAFE * 2.5
			l.Brightness = 2
			l.Parent = r
			r.Parent = workspace
			ring = r
		elseif not show and ring then
			ring:Destroy()
			ring = nil
		end
		if ring and d then
			ring.CFrame = d.CFrame * CFrame.new(0, d.Size.Y / 2 + 0.1, 0) * CFrame.Angles(0, 0, math.rad(90))
			ring.Transparency = pulse == "Dark" and 0.72 or (0.72 + math.sin(os.clock() * 12) * 0.15)
		end
	end)
end

-- notice boards: "[E] Read" opens the Journal note card
local Journal = require(script.Parent:WaitForChild("Journal"))
Journal.init()
Net.Notify.OnClientEvent:Connect(function(kind, data)
	if kind == "Note" and type(data) == "table" then
		Journal.open(data)
	end
end)
