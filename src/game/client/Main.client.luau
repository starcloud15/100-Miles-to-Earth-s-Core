--[[
	The Game place client: HUD updates, the Crank Pump and Tow Line tools,
	Push Off, and being shoved.
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

local function root(): BasePart?
	local c = player.Character
	return c and c:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function deck(): BasePart?
	local rig = workspace:FindFirstChild("DrillRig")
	return rig and rig:FindFirstChild("Deck") :: BasePart?
end

local function deckRel(pos: Vector3): Vector3?
	local d = deck()
	if not d then
		return nil
	end
	local rel = d.CFrame:PointToObjectSpace(pos)
	local R = Config.Rig
	if math.abs(rel.X) <= R.DECK_W / 2 + 1.5 and math.abs(rel.Z) <= R.DECK_L / 2 + 1.5 and rel.Y > -1 and rel.Y < 9 then
		return rel
	end
	return nil
end

-- tools ---------------------------------------------------------------------
local function nearestOffRig(hit: Vector3): Player?
	local best, bestD = nil, 24
	for _, p in Players:GetPlayers() do
		if p ~= player and p.Character then
			local r = p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if r and not deckRel(r.Position) then
				local d = (r.Position - hit).Magnitude
				if d < bestD then
					best, bestD = p, d
				end
			end
		end
	end
	return best
end

local function hookTool(tool: Instance)
	if not tool:IsA("Tool") or tool:GetAttribute("Hooked") then
		return
	end
	tool:SetAttribute("Hooked", true)
	if tool.Name == "Crank Pump" then
		tool.Activated:Connect(function()
			Net.Crank:FireServer()
		end)
	elseif tool.Name == "Tow Line" then
		tool.Activated:Connect(function()
			local mouse = player:GetMouse()
			local target = nearestOffRig(mouse.Hit.Position)
			if target then
				Net.TowLine:FireServer(target)
			else
				Hud.toast("Aim at a crewmate who fell off", Ui.ORANGE, 1.5)
			end
		end)
	end
end

local function watchCharacter(char: Model)
	for _, c in char:GetChildren() do
		hookTool(c)
	end
	char.ChildAdded:Connect(hookTool)
	-- start holding the Crank Pump, like the reference's paddle
	task.delay(1, function()
		local backpack = player:FindFirstChild("Backpack")
		local hum = char:FindFirstChildOfClass("Humanoid")
		local crank = backpack and backpack:FindFirstChild("Crank Pump")
		if hum and crank and not char:FindFirstChildOfClass("Tool") then
			hum:EquipTool(crank :: Tool)
		end
	end)
end
player.CharacterAdded:Connect(watchCharacter)
if player.Character then
	watchCharacter(player.Character)
end

-- Push Off: the crewmate you're facing, close by on the deck ----------------
local pushTarget: Player? = nil

local function findPushTarget(): Player?
	local r = root()
	if not r or not deckRel(r.Position) then
		return nil
	end
	local look = workspace.CurrentCamera.CFrame.LookVector
	local best, bestScore = nil, -1
	for _, p in Players:GetPlayers() do
		if p ~= player and p.Character then
			local pr = p.Character:FindFirstChild("HumanoidRootPart") :: BasePart?
			if pr and deckRel(pr.Position) then
				local d = pr.Position - r.Position
				if d.Magnitude <= Config.PushOff.RANGE then
					local score = look:Dot(d.Unit)
					if score > 0.5 and score > bestScore then
						best, bestScore = p, score
					end
				end
			end
		end
	end
	return best
end

local function doPush()
	if pushTarget then
		Net.PushOff:FireServer(pushTarget)
	end
end
ContextActionService:BindAction("PushOff", function(_, inputState)
	if inputState == Enum.UserInputState.Begin then
		doPush()
	end
	return Enum.ContextActionResult.Pass
end, false, Enum.KeyCode.F)
Hud.pushButton().Activated:Connect(doPush)

-- server messages -----------------------------------------------------------
Net.Shove.OnClientEvent:Connect(function(velocity: Vector3)
	local r = root()
	local hum = player.Character and player.Character:FindFirstChildOfClass("Humanoid")
	if r and hum then
		-- a knockback: free the character from walking control for a moment so
		-- air control can't cancel the shove
		hum.PlatformStand = true
		r.AssemblyLinearVelocity = velocity
		task.delay(0.7, function()
			hum.PlatformStand = false
			hum:ChangeState(Enum.HumanoidStateType.GettingUp)
		end)
	end
end)

local MESSAGES = {
	ThrownOff = { "THROWN OFF!", Ui.RED },
	PushedOff = { "PUSHED OFF!", Ui.RED },
	LeftBehind = { "LEFT BEHIND: the winch hauled you back", Ui.ORANGE },
	Aboard = { "Back aboard!", Ui.GREEN },
	Depart = { "The rig is leaving!", Ui.ORANGE },
	Hit = { "CRASH!", Ui.RED },
	Scrape = { "SCRAPING THE WALL!", Ui.ORANGE },
	TowNo = { "You can only tow from the deck, to someone who fell off", Ui.ORANGE },
	TowFar = { "Too far for the Tow Line", Ui.ORANGE },
}

Net.Notify.OnClientEvent:Connect(function(kind: string, data: any)
	if kind == "Behind" then
		Hud.behind(data)
	elseif kind == "Glowstone" then
		Hud.toast("+" .. tostring(data) .. " glowstone", Color3.fromRGB(255, 210, 80), 1)
	elseif kind == "Towed" then
		Hud.behind(nil)
		Hud.toast(tostring(data) .. " reeled you in!", Ui.GREEN)
	elseif kind == "TowedOk" then
		Hud.toast("You reeled in " .. tostring(data) .. "!", Ui.GREEN)
	elseif kind == "PushNo" then
		Hud.toast(tostring(data), Ui.ORANGE, 2)
	elseif kind == "PushOffDone" then
		if data.target ~= player.DisplayName then
			Hud.toast(data.by .. " pushed " .. data.target .. " off!", Ui.PURPLE, 2)
		end
	elseif kind == "ZoneComplete" then
		Hud.banner("ZONE COMPLETE: " .. tostring(data) .. "!")
	else
		local m = MESSAGES[kind]
		if m then
			if kind == "LeftBehind" or kind == "Aboard" then
				Hud.behind(nil)
			end
			Hud.toast(m[1], m[2])
		end
	end
end)

-- every frame ---------------------------------------------------------------
local acc = 0
RunService.RenderStepped:Connect(function(dt)
	acc += dt
	if acc < 0.05 then
		return
	end
	acc = 0
	Hud.update(state)
	local r = root()
	local rel = r and deckRel(r.Position)
	Hud.setSide(rel and (rel.X < 0 and "L" or "R") or nil)
	pushTarget = findPushTarget()
	Hud.pushTarget(pushTarget and pushTarget.DisplayName or nil)
	local phase = state:GetAttribute("Phase")
	if phase == "Boarding" then
		Hud.banner("BOARDING  " .. tostring(state:GetAttribute("Countdown") or ""))
	elseif phase == "Moving" then
		Hud.banner("")
	end
end)
