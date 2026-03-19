local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local ArenaDisplayService = {}

local displayConnections: {RBXScriptConnection} = {}

local function clearConnections()
	for _, connection in ipairs(displayConnections) do
		connection:Disconnect()
	end
	table.clear(displayConnections)
end

local function createDisplayGui(parent: BasePart, face: Enum.NormalId, pixelsPerStud: number): Frame
	local surfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "ArenaDisplayGui"
	surfaceGui.Face = face
	surfaceGui.PixelsPerStud = pixelsPerStud
	surfaceGui.AlwaysOnTop = false
	surfaceGui.LightInfluence = 0
	surfaceGui.SizingMode = Enum.SurfaceGuiSizingMode.PixelsPerStud
	surfaceGui.Parent = parent

	local frame = Instance.new("Frame")
	frame.Size = UDim2.fromScale(1, 1)
	frame.BackgroundColor3 = Color3.fromRGB(12, 16, 22)
	frame.BorderSizePixel = 0
	frame.Parent = surfaceGui

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 3
	stroke.Color = Color3.fromRGB(255, 188, 84)
	stroke.Transparency = 0.1
	stroke.Parent = frame

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 18)
	padding.PaddingRight = UDim.new(0, 18)
	padding.PaddingTop = UDim.new(0, 12)
	padding.PaddingBottom = UDim.new(0, 12)
	padding.Parent = frame

	local title = Instance.new("TextLabel")
	title.Name = "Title"
	title.BackgroundTransparency = 1
	title.Size = UDim2.new(1, 0, 0.28, 0)
	title.Font = Enum.Font.GothamBlack
	title.TextScaled = true
	title.TextColor3 = Color3.fromRGB(255, 205, 120)
	title.Text = "ROBO DISTRICT ARENA"
	title.Parent = frame

	local status = Instance.new("TextLabel")
	status.Name = "Status"
	status.BackgroundTransparency = 1
	status.Position = UDim2.fromScale(0, 0.32)
	status.Size = UDim2.new(1, 0, 0.26, 0)
	status.Font = Enum.Font.GothamBold
	status.TextScaled = true
	status.TextColor3 = Color3.fromRGB(226, 232, 242)
	status.Text = "Loading..."
	status.Parent = frame

	local detail = Instance.new("TextLabel")
	detail.Name = "Detail"
	detail.BackgroundTransparency = 1
	detail.Position = UDim2.fromScale(0, 0.60)
	detail.Size = UDim2.new(1, 0, 0.4, 0)
	detail.Font = Enum.Font.GothamSemibold
	detail.TextWrapped = true
	detail.TextScaled = true
	detail.TextColor3 = Color3.fromRGB(176, 191, 210)
	detail.Text = ""
	detail.Parent = frame

	return frame
end

local function getArenaState(): Folder?
	local arenaState = ReplicatedStorage:FindFirstChild("ArenaState")
	if arenaState and arenaState:IsA("Folder") then
		return arenaState
	end
	return nil
end

function ArenaDisplayService.Attach(arenaModel: Model)
	clearConnections()

	local marquee = arenaModel:FindFirstChild("Marquee")
	local screen = arenaModel:FindFirstChild("JumbotronScreen")
	if not (marquee and marquee:IsA("BasePart") and screen and screen:IsA("BasePart")) then
		return
	end

	local marqueeFrame = createDisplayGui(marquee, Enum.NormalId.Right, 24)
	local jumbotronFrame = createDisplayGui(screen, Enum.NormalId.Left, 32)
	local stateFolder = getArenaState()
	if not stateFolder then
		return
	end

	local function refresh()
		local phase = tostring(stateFolder:GetAttribute("Phase") or "Intermission")
		local timeRemaining = tonumber(stateFolder:GetAttribute("TimeRemaining") or 0) or 0
		local fighterAName = tostring(stateFolder:GetAttribute("FighterAName") or "Fighter A")
		local fighterBName = tostring(stateFolder:GetAttribute("FighterBName") or "Fighter B")
		local winnerName = tostring(stateFolder:GetAttribute("WinnerName") or "")
		local headline = tostring(stateFolder:GetAttribute("DisplayHeadline") or "")
		local detail = tostring(stateFolder:GetAttribute("DisplayDetail") or "")
		local cue = tostring(stateFolder:GetAttribute("EventCue") or "")
		local countdownNumber = tonumber(stateFolder:GetAttribute("CountdownNumber") or 0) or 0

		local status = headline
		local detailText = detail
		if countdownNumber > 0 then
			status = tostring(countdownNumber)
			detailText = "FIGHT STARTING"
		elseif cue == "Winner" and winnerName ~= "" then
			status = "WINNER!"
			detailText = winnerName
		elseif status == "" then
			status = ("%s  |  %ds"):format(phase:upper(), math.max(0, math.floor(timeRemaining)))
			if phase == "PredictionWindow" or phase == "FightActive" then
				detailText = ("%s VS %s"):format(fighterAName, fighterBName)
			elseif phase == "Result" and winnerName ~= "" then
				detailText = ("WINNER: %s"):format(winnerName)
			else
				detailText = "Next duel loading. Preview the matchup when predictions open."
			end
		end

		for _, frame in ipairs({marqueeFrame, jumbotronFrame}) do
			local title = frame:FindFirstChild("Title") :: TextLabel
			local statusLabel = frame:FindFirstChild("Status") :: TextLabel
			local detailLabel = frame:FindFirstChild("Detail") :: TextLabel
			title.Text = if frame == jumbotronFrame then "LIVE ARENA FEED" else "ROBO DISTRICT ARENA"
			statusLabel.Text = status
			detailLabel.Text = detailText
			statusLabel.TextColor3 = if countdownNumber > 0
				then Color3.fromRGB(255, 214, 120)
				elseif cue == "FightStart"
				then Color3.fromRGB(255, 112, 96)
				elseif cue == "Winner"
				then Color3.fromRGB(129, 227, 137)
				else Color3.fromRGB(226, 232, 242)
		end
	end

	refresh()
	for _, attr in ipairs({"Phase", "TimeRemaining", "FighterAName", "FighterBName", "WinnerName", "DisplayHeadline", "DisplayDetail", "EventCue", "CountdownNumber"}) do
		table.insert(displayConnections, stateFolder:GetAttributeChangedSignal(attr):Connect(refresh))
	end
end

function ArenaDisplayService.GetArenaModel(): Model?
	local world = Workspace:FindFirstChild("World")
	local arena = world and world:FindFirstChild("Arena")
	local venue = arena and arena:FindFirstChild("Venue")
	if venue and venue:IsA("Model") then
		return venue
	end
	return nil
end

return ArenaDisplayService
