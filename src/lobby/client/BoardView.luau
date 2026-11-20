--[[
	The three camp leaderboards, drawn on each player's own screen (so the
	Global / Friends tabs and the pinned "You" row are theirs), onto the board
	parts the server built. Layout follows the reference's boards.
]]

local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SocialService = game:GetService("SocialService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Net = require(Shared.Net)
local Ui = require(Shared.Ui)

local BoardView = {}

local TITLES = { Fastest = "FASTEST DESCENT", Deepstones = "DEEPSTONES EARNED", Miles = "DEEPEST TOTAL" }
local TAB_ON = Color3.fromRGB(70, 190, 60)
local TAB_OFF = Color3.fromRGB(50, 90, 170)

local function fmt(board: string, v: number?): string
	v = v or 0
	if board == "Fastest" then
		if v <= 0 then
			return "None"
		end
		return string.format("%d:%02d", math.floor(v / 60), v % 60)
	elseif board == "Miles" then
		return string.format("%.1f mi", v / 10)
	end
	return tostring(v)
end

local function italic(props)
	local l = Ui.text(props)
	l.FontFace = Ui.ITALIC
	return l
end

local function build(screen: BasePart, playerGui: PlayerGui)
	local board = screen:GetAttribute("Board")
	local gui = Ui.new("SurfaceGui", { Name = "Board_" .. board, Adornee = screen, Face = Enum.NormalId.Front, CanvasSize = Vector2.new(420, 500), LightInfluence = 0.2, ResetOnSpawn = false, Parent = playerGui })
	local bg = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(100, 66, 40), Size = UDim2.fromScale(1, 1), Parent = gui }, { Ui.stroke(6, Color3.fromRGB(60, 38, 24), true) })
	italic({ Parent = bg, Text = TITLES[board], Position = UDim2.fromOffset(20, 14), Size = UDim2.new(1, -40, 0, 48), Stroke = 3 })
	local tabs = {}
	local tab = "Global"
	local list = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(56, 36, 22), Position = UDim2.fromOffset(20, 112), Size = UDim2.new(1, -40, 0, 316), Parent = bg })
	local you = Ui.new("Frame", { BackgroundColor3 = Color3.fromRGB(56, 36, 22), Position = UDim2.fromOffset(20, 436), Size = UDim2.new(1, -40, 0, 46), Parent = bg })

	local function row(parent, y: number, h: number, rank: string, name: string, value: string, userId: number?)
		local r = Ui.new("Frame", { BackgroundTransparency = 1, Position = UDim2.fromOffset(8, y), Size = UDim2.new(1, -16, 0, h), Parent = parent })
		italic({ Parent = r, Text = rank, TextColor3 = Ui.GOLD, Size = UDim2.new(0, 46, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 2 })
		local av = Ui.new("ImageLabel", { BackgroundColor3 = Color3.fromRGB(200, 200, 200), Position = UDim2.fromOffset(48, 2), Size = UDim2.fromOffset(h - 4, h - 4), Parent = r }, { Ui.corner(UDim.new(0.5, 0)) })
		if userId and userId > 0 then
			task.spawn(function()
				local ok, img = pcall(function()
					return Players:GetUserThumbnailAsync(userId, Enum.ThumbnailType.HeadShot, Enum.ThumbnailSize.Size48x48)
				end)
				if ok then
					av.Image = img
				end
			end)
		end
		Ui.text({ Parent = r, Text = name, Position = UDim2.fromOffset(52 + h, 0), Size = UDim2.new(0.6, -h - 40, 1, 0), TextXAlignment = Enum.TextXAlignment.Left, Stroke = 2 })
		italic({ Parent = r, Text = value, Position = UDim2.new(0.6, 0, 0, 0), Size = UDim2.new(0.4, 0, 1, 0), TextXAlignment = Enum.TextXAlignment.Right, Stroke = 2 })
	end

	local function load()
		for name, b in tabs do
			b.BackgroundColor3 = name == tab and TAB_ON or TAB_OFF
		end
		list:ClearAllChildren()
		you:ClearAllChildren()
		local ok, rows, me = pcall(function()
			return Net.BoardFetch:InvokeServer(board, tab)
		end)
		rows = ok and rows or {}
		if #rows == 0 and tab == "Friends" then
			Ui.text({ Parent = list, Text = "Play with friends to fill this board!", Position = UDim2.fromOffset(20, 90), Size = UDim2.new(1, -40, 0, 34), Stroke = 2 })
			local invite = Ui.button({ Parent = list, Text = "Invite Friends", Size = UDim2.fromOffset(200, 48), AnchorPoint = Vector2.new(0.5, 0), Position = UDim2.new(0.5, 0, 0, 140), Border = 3 })
			invite.Activated:Connect(function()
				pcall(function()
					SocialService:PromptGameInvite(Players.LocalPlayer)
				end)
			end)
		elseif #rows == 0 then
			Ui.text({ Parent = list, Text = "No descents yet. Be the first!", Position = UDim2.fromOffset(20, 130), Size = UDim2.new(1, -40, 0, 34), Stroke = 2 })
		end
		for i, r in rows do
			if i > 10 then
				break
			end
			row(list, 6 + (i - 1) * 30.5, 28, "#" .. r.rank, r.name, fmt(board, r.value), r.userId)
		end
		row(you, 8, 30, me and me.rank and ("#" .. me.rank) or "#-", "You", fmt(board, me and me.value), Players.LocalPlayer.UserId)
	end

	for i, name in { "Global", "Friends" } do
		local b = Ui.new("TextButton", { Text = "", BackgroundColor3 = name == tab and TAB_ON or TAB_OFF, Position = UDim2.new((i - 1) * 0.5, i == 1 and 40 or 6, 0, 68), Size = UDim2.new(0.5, -46, 0, 36), Parent = bg }, { Ui.stroke(3, Color3.new(0, 0, 0), true) })
		Ui.text({ Parent = b, Text = name, Size = UDim2.new(1, -10, 1, -8), Position = UDim2.fromOffset(5, 4), Stroke = 2 })
		b.Activated:Connect(function()
			tab = name
			load()
		end)
		tabs[name] = b
	end
	task.spawn(load)
	task.spawn(function()
		while gui.Parent do
			task.wait(60)
			load()
		end
	end)
end

function BoardView.init()
	local playerGui = Players.LocalPlayer:WaitForChild("PlayerGui")
	local camp = workspace:WaitForChild("TopsideCamp")
	for _, name in { "LeaderboardFastest", "LeaderboardDeepstones", "LeaderboardMiles" } do
		local model = camp:WaitForChild(name, 30)
		if model then
			task.spawn(build, model:WaitForChild("Screen"), playerGui)
		end
	end
end

return BoardView
