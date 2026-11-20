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
	local best, bestD = nil, 16
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

local function activate(tool: Tool)
	if tool.Name == "Crank Pump" then
		Net.Crank:FireServer()
		shake(0.15)
	elseif tool.Name == "Pickaxe" then
		local v = nearestVein()
		if v then
			Net.Mine:FireServer(v)
			shake(0.2)
		else
			Hud.toast("Mine the glowing veins at stops", Ui.ORANGE, 1.4)
		end
	elseif tool.Name == "Delver's Hook" then
		if delving then
			Net.Delve:FireServer("reel")
		else
			Net.Delve:FireServer("cast")
		end
	elseif tool.Name == "Food" then
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
	end)
	tool.Unequipped:Connect(function()
		if held == tool.Name then
			held = nil
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

local function updatePushPrompts()
	local r = root()
	pushTarget = nil
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
	elseif kind == "Banner" then
		task.delay(0.1, function()
			Hud.toast(tostring(data), Color3.new(1, 1, 1), 2.4)
		end)
	elseif kind == "Toast" then
		Hud.toast(tostring(data), Ui.ORANGE, 2)
	elseif kind == "Mined" then
		Hud.toast("+" .. tostring(data) .. " glowstone", Color3.fromRGB(255, 210, 80), 0.6)
	elseif kind == "Fed" then
		Hud.toast("+0.1x", Color3.fromRGB(255, 214, 40), 0.6)
	elseif kind == "Cast" then
		delving = { bite = os.clock() + (tonumber(data) or 3) }
		Hud.toast("...", Color3.new(1, 1, 1), tonumber(data) or 3)
		task.delay(tonumber(data) or 3, function()
			if delving then
				Hud.toast("! CLICK", Color3.fromRGB(255, 214, 40), 1.2)
				shake(0.25)
			end
		end)
	elseif kind == "DelveResult" then
		delving = nil
		if data == "catch" then
			Hud.toast("You dug up a find!", Ui.GREEN, 1.4)
		elseif data == "early" then
			Hud.toast("Too early", Color3.new(1, 1, 1), 1)
		else
			Hud.toast("It slipped away", Color3.new(1, 1, 1), 1)
		end
	elseif kind == "Ate" then
		Hud.toast("+" .. tostring(data) .. "% Hunger", Ui.GREEN, 1)
	elseif kind == "Breakthrough" then
		shake(1)
		Hud.toast("BREAKTHROUGH!", Color3.fromRGB(255, 214, 40), 1.2)
	elseif kind == "ZoneComplete" then
		Hud.stopName("ZONE COMPLETE!")
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
			end
		end
	end
end)

-- every frame -------------------------------------------------------------------------
local acc = 0
local rumbleT = 0
RunService.RenderStepped:Connect(function(dt)
	local r, hum = root(), humanoid()
	local aboard = r ~= nil and onDeck(r.Position)
	local d = deck()

	-- camera shake through the humanoid's camera offset
	local speed = state:GetAttribute("Speed") or 0
	local moving = state:GetAttribute("Moving") == true
	rumbleT += dt
	jolt = math.max(0, jolt - dt * 2.5)
	local amount = (aboard and moving and math.clamp(speed / 100, 0, 1) * 0.22 or 0) + jolt * 0.6
	if hum then
		hum.CameraOffset = Vector3.new(math.noise(rumbleT * 18, 1) * amount, math.noise(rumbleT * 18, 7) * amount, 0)
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
	-- the action hint follows the tool in your hand
	local verbs = { ["Crank Pump"] = "Crank", Pickaxe = "Mine", ["Delver's Hook"] = delving and "Reel" or "Cast", Food = "Eat" }
	Hud.setHint(held and verbs[held] or nil)
	updatePushPrompts()
end)
