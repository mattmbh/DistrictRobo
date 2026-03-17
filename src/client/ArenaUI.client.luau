local ContextActionService = game:GetService("ContextActionService")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Net = require(Shared:WaitForChild("Net"))

local arenaState = ReplicatedStorage:WaitForChild("ArenaState")
local placeBetRemote = Net.GetRemoteEvent(Constants.Remotes.ArenaPlaceBet)

local gui = Instance.new("ScreenGui")
gui.Name = "NpcEventHubGui"
gui.ResetOnSpawn = false
gui.ZIndexBehavior = Enum.ZIndexBehavior.Sibling
gui.Parent = playerGui

local tabButton = Instance.new("TextButton")
tabButton.Name = "HubTab"
tabButton.AnchorPoint = Vector2.new(1, 0.5)
tabButton.Position = UDim2.new(1, -14, 0.5, -120)
tabButton.Size = UDim2.fromOffset(88, 36)
tabButton.BackgroundColor3 = Color3.fromRGB(22, 28, 38)
tabButton.TextColor3 = Color3.fromRGB(244, 214, 132)
tabButton.Text = "NPC EVENTS"
tabButton.Font = Enum.Font.GothamBold
tabButton.TextSize = 13
tabButton.BorderSizePixel = 0
tabButton.Active = true
tabButton.AutoButtonColor = true
tabButton.ZIndex = 20
tabButton.Parent = gui

local tabStroke = Instance.new("UIStroke")
tabStroke.Thickness = 1
tabStroke.Color = Color3.fromRGB(233, 184, 91)
tabStroke.Parent = tabButton

local panel = Instance.new("Frame")
panel.Name = "HubPanel"
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -14, 0, 22)
panel.Size = UDim2.fromOffset(300, 420)
panel.BackgroundColor3 = Color3.fromRGB(12, 16, 24)
panel.BackgroundTransparency = 0.08
panel.BorderSizePixel = 0
panel.Visible = false
panel.Active = false
panel.ClipsDescendants = true
panel.ZIndex = 10
panel.Parent = gui

local panelStroke = Instance.new("UIStroke")
panelStroke.Thickness = 2
panelStroke.Color = Color3.fromRGB(233, 184, 91)
panelStroke.Parent = panel

local header = Instance.new("Frame")
header.Size = UDim2.new(1, 0, 0, 42)
header.BackgroundTransparency = 1
header.ClipsDescendants = true
header.ZIndex = 11
header.Parent = panel

local headerTitle = Instance.new("TextLabel")
headerTitle.BackgroundTransparency = 1
headerTitle.Position = UDim2.fromOffset(12, 8)
headerTitle.Size = UDim2.new(1, -92, 0, 26)
headerTitle.TextXAlignment = Enum.TextXAlignment.Left
headerTitle.Font = Enum.Font.GothamBlack
headerTitle.TextSize = 20
headerTitle.TextColor3 = Color3.fromRGB(255, 212, 122)
headerTitle.Text = "NPC EVENTS"
headerTitle.ZIndex = 12
headerTitle.Parent = header

local closeButton = Instance.new("TextButton")
closeButton.Name = "CloseButton"
closeButton.AnchorPoint = Vector2.new(1, 0)
closeButton.Position = UDim2.new(1, -8, 0, 5)
closeButton.Size = UDim2.fromOffset(32, 32)
closeButton.BackgroundColor3 = Color3.fromRGB(30, 36, 46)
closeButton.TextColor3 = Color3.fromRGB(235, 239, 245)
closeButton.Font = Enum.Font.GothamBold
closeButton.TextSize = 18
closeButton.Text = "X"
closeButton.BorderSizePixel = 0
closeButton.Active = true
closeButton.AutoButtonColor = true
closeButton.Modal = false
closeButton.ZIndex = 20
closeButton.Parent = header

local closeCorner = Instance.new("UICorner")
closeCorner.CornerRadius = UDim.new(0, 4)
closeCorner.Parent = closeButton

print(("[EventHubUI] closeButton=%s size=%s pos=%s"):format(
	closeButton:GetFullName(),
	tostring(closeButton.Size),
	tostring(closeButton.Position)
))

local listHolder = Instance.new("ScrollingFrame")
listHolder.Name = "SectionList"
listHolder.Position = UDim2.fromOffset(0, 48)
listHolder.Size = UDim2.new(1, 0, 1, -48)
listHolder.CanvasSize = UDim2.fromOffset(0, 0)
listHolder.ScrollBarThickness = 5
listHolder.BackgroundTransparency = 1
listHolder.BorderSizePixel = 0
listHolder.AutomaticCanvasSize = Enum.AutomaticSize.Y
listHolder.Active = true
listHolder.ZIndex = 10
listHolder.Parent = panel

local listPadding = Instance.new("UIPadding")
listPadding.PaddingLeft = UDim.new(0, 10)
listPadding.PaddingRight = UDim.new(0, 10)
listPadding.PaddingTop = UDim.new(0, 6)
listPadding.PaddingBottom = UDim.new(0, 10)
listPadding.Parent = listHolder

local listLayout = Instance.new("UIListLayout")
listLayout.Padding = UDim.new(0, 8)
listLayout.Parent = listHolder

local cueBanner = Instance.new("TextLabel")
cueBanner.AnchorPoint = Vector2.new(0.5, 0)
cueBanner.Position = UDim2.new(0.5, 0, 0, 92)
cueBanner.Size = UDim2.fromOffset(300, 42)
cueBanner.BackgroundColor3 = Color3.fromRGB(19, 24, 33)
cueBanner.BackgroundTransparency = 0.24
cueBanner.BorderSizePixel = 0
cueBanner.Font = Enum.Font.GothamBlack
cueBanner.TextSize = 22
cueBanner.TextColor3 = Color3.fromRGB(255, 212, 122)
cueBanner.Visible = false
cueBanner.ZIndex = 5
cueBanner.Parent = gui

local cueStroke = Instance.new("UIStroke")
cueStroke.Thickness = 2
cueStroke.Color = Color3.fromRGB(255, 188, 84)
cueStroke.Parent = cueBanner

type EventSectionDefinition = {
	id: string,
	title: string,
	buildBody: (body: Frame) -> {[string]: any},
	refresh: (views: any) -> (),
}

type EventSectionViews = {
	container: Frame,
	body: Frame,
	arrow: TextLabel,
	definition: EventSectionDefinition,
	[string]: any,
}

local expandedSections: {[string]: boolean} = {
	arena = true,
	foot_races = false,
	car_chaos = false,
	drone_gauntlet = false,
}

local sectionViewsById: {[string]: EventSectionViews} = {}
local betResultToken = 0
local arenaCueRefreshScheduled = false
local isHubOpen = false
local TOGGLE_ACTION = "ToggleNpcEventHub"
local lastToggleAt = 0

local function connectButtonClick(button: TextButton, callback: () -> ())
	button.MouseButton1Click:Connect(callback)
end

local function isNearArena(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local arenaPosition = arenaState:GetAttribute("ArenaPosition")
	if not (root and root:IsA("BasePart") and typeof(arenaPosition) == "Vector3") then
		return false
	end
	return (root.Position - arenaPosition).Magnitude <= Constants.Arena.SpectateDistance
end

local function isSpectating(): boolean
	return playerGui:GetAttribute("ArenaSpectating") == true
end

local function shouldShowArenaCueBanner(): boolean
	return isNearArena() or isSpectating()
end

local function showCueBanner(text: string, color: Color3, duration: number)
	betResultToken += 1
	local current = betResultToken
	cueBanner.Text = text
	cueBanner.TextColor3 = color
	cueBanner.BackgroundTransparency = 0.24
	cueBanner.Visible = true

	local fade = TweenService:Create(cueBanner, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.92,
	})
	task.delay(duration, function()
		if current == betResultToken then
			fade:Play()
		end
	end)
	task.delay(duration + 0.12, function()
		if current == betResultToken then
			cueBanner.Visible = false
		end
	end)
end

local function scheduleArenaCueRefresh()
	if arenaCueRefreshScheduled then
		return
	end
	arenaCueRefreshScheduled = true
	task.spawn(function()
		while arenaCueRefreshScheduled do
			task.wait(0.35)
			if not cueBanner.Visible and not shouldShowArenaCueBanner() then
				arenaCueRefreshScheduled = false
				break
			end
			local winnerName = tostring(arenaState:GetAttribute("WinnerName") or "")
			local eventCue = tostring(arenaState:GetAttribute("EventCue") or "")
			local countdownNumber = tonumber(arenaState:GetAttribute("CountdownNumber") or 0) or 0
			local eventType = tostring(arenaState:GetAttribute("EventType") or "ArenaDuel")

			if not shouldShowArenaCueBanner() then
				cueBanner.Visible = false
			elseif countdownNumber > 0 then
				cueBanner.Visible = true
				cueBanner.Text = tostring(countdownNumber)
				cueBanner.TextColor3 = Color3.fromRGB(255, 212, 122)
				cueBanner.BackgroundTransparency = 0.22
			elseif eventCue == "FightStart" then
				cueBanner.Visible = true
				cueBanner.Text = ("%s  |  FIGHT!"):format(eventType == "ArenaDuel" and "ARENA" or "EVENT")
				cueBanner.TextColor3 = Color3.fromRGB(255, 110, 92)
				cueBanner.BackgroundTransparency = 0.22
			elseif eventCue == "Winner" and winnerName ~= "" then
				cueBanner.Visible = true
				cueBanner.Text = ("%s WINS"):format(winnerName)
				cueBanner.TextColor3 = Color3.fromRGB(136, 230, 144)
				cueBanner.BackgroundTransparency = 0.22
			elseif eventCue == "Introductions" then
				cueBanner.Visible = true
				cueBanner.Text = "MAIN EVENT"
				cueBanner.TextColor3 = Color3.fromRGB(255, 212, 122)
				cueBanner.BackgroundTransparency = 0.22
			else
				cueBanner.Visible = false
			end
		end
	end)
end

local function getArenaOutcomeText(currentRoundId: number): string
	local outcomeRoundId = tonumber(player:GetAttribute("ArenaOutcomeRoundId") or -1) or -1
	if outcomeRoundId ~= currentRoundId then
		return ""
	end

	local outcome = tostring(player:GetAttribute("ArenaOutcome") or "")
	if outcome == "Won" then
		return "Bet Won"
	elseif outcome == "Lost" then
		return "Bet Lost"
	end
	return ""
end

local function makeSectionLabel(parent: Instance, height: number, textSize: number, color: Color3, font: Enum.Font): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, height)
	label.BackgroundTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextWrapped = true
	label.Font = font
	label.TextSize = textSize
	label.TextColor3 = color
	label.Parent = parent
	return label
end

local function makeActionButton(parent: Instance, text: string, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, 30)
	button.BackgroundColor3 = color
	button.TextColor3 = Color3.fromRGB(245, 247, 250)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.Text = text
	button.BorderSizePixel = 0
	button.Parent = parent
	return button
end

local function buildArenaBody(body: Frame): {[string]: any}
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.Parent = body

	local status = makeSectionLabel(body, 18, 14, Color3.fromRGB(229, 233, 240), Enum.Font.GothamSemibold)
	local winner = makeSectionLabel(body, 18, 14, Color3.fromRGB(183, 198, 214), Enum.Font.GothamSemibold)
	local matchup = makeSectionLabel(body, 34, 14, Color3.fromRGB(214, 219, 228), Enum.Font.GothamSemibold)
	local timer = makeSectionLabel(body, 18, 14, Color3.fromRGB(183, 198, 214), Enum.Font.GothamSemibold)
	local result = makeSectionLabel(body, 18, 14, Color3.fromRGB(129, 227, 137), Enum.Font.GothamBold)

	local buttonRow = Instance.new("Frame")
	buttonRow.Size = UDim2.new(1, 0, 0, 100)
	buttonRow.BackgroundTransparency = 1
	buttonRow.Parent = body

	local buttonLayout = Instance.new("UIListLayout")
	buttonLayout.Padding = UDim.new(0, 5)
	buttonLayout.Parent = buttonRow

	local betA = makeActionButton(buttonRow, "Bet A", Color3.fromRGB(161, 74, 74))
	local betB = makeActionButton(buttonRow, "Bet B", Color3.fromRGB(69, 108, 176))
	local spectate = makeActionButton(buttonRow, "Spectate Fight", Color3.fromRGB(56, 71, 99))

	return {
		status = status,
		winner = winner,
		matchup = matchup,
		timer = timer,
		result = result,
		betA = betA,
		betB = betB,
		spectate = spectate,
	}
end

local function buildPlaceholderBody(body: Frame, message: string): {[string]: any}
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 5)
	layout.Parent = body

	local description = makeSectionLabel(body, 40, 14, Color3.fromRGB(183, 198, 214), Enum.Font.GothamSemibold)
	description.Text = message

	return {
		description = description,
	}
end

local eventSections: {EventSectionDefinition} = {
	{
		id = "arena",
		title = "Arena Fights",
		buildBody = buildArenaBody,
		refresh = function(views)
			local phase = tostring(arenaState:GetAttribute("Phase") or "Intermission")
			local roundId = tonumber(arenaState:GetAttribute("RoundId") or 0) or 0
			local fighterAName = tostring(arenaState:GetAttribute("FighterAName") or "Fighter A")
			local fighterBName = tostring(arenaState:GetAttribute("FighterBName") or "Fighter B")
			local fighterAStyle = tostring(arenaState:GetAttribute("FighterAStyle") or "")
			local fighterBStyle = tostring(arenaState:GetAttribute("FighterBStyle") or "")
			local winnerName = tostring(arenaState:GetAttribute("LastResult") or "")
			local timeRemaining = tonumber(arenaState:GetAttribute("TimeRemaining") or 0) or 0
			local bettingOpen = arenaState:GetAttribute("BettingOpen") == true
			local currentBetRoundId = tonumber(player:GetAttribute("ArenaBetRoundId") or -1) or -1
			local currentBetSlot = tostring(player:GetAttribute("ArenaBetSlot") or "")
			local alreadyBet = currentBetRoundId == roundId and currentBetSlot ~= ""
			local statusLabel = views.status :: TextLabel
			local winnerLabel = views.winner :: TextLabel
			local matchupLabel = views.matchup :: TextLabel
			local timerLabel = views.timer :: TextLabel
			local resultLabel = views.result :: TextLabel

			statusLabel.Text = ("Status: %s"):format(phase)
			winnerLabel.Text = ("Last Winner: %s"):format(winnerName ~= "" and winnerName or "--")
			matchupLabel.Text = ("Match: %s [%s] vs %s [%s]"):format(fighterAName, fighterAStyle, fighterBName, fighterBStyle)
			timerLabel.Text = ("Time Remaining: %ds"):format(math.max(0, math.floor(timeRemaining)))
			resultLabel.Text = getArenaOutcomeText(roundId)

			local betA = views.betA :: TextButton
			local betB = views.betB :: TextButton
			local spectate = views.spectate :: TextButton
			local canBet = bettingOpen and not alreadyBet

			betA.Active = canBet
			betB.Active = canBet
			betA.AutoButtonColor = canBet
			betB.AutoButtonColor = canBet
			betA.BackgroundTransparency = if canBet then 0 else 0.45
			betB.BackgroundTransparency = if canBet then 0 else 0.45
			betA.Text = if alreadyBet and currentBetSlot == "A" then "Bet Locked On A" else "Bet A"
			betB.Text = if alreadyBet and currentBetSlot == "B" then "Bet Locked On B" else "Bet B"
			spectate.Text = if isSpectating() then "Return To Player" else "Spectate Fight"
		end,
	},
	{
		id = "foot_races",
		title = "Foot Races",
		buildBody = function(body)
			return buildPlaceholderBody(body, "No race feed active yet. This slot is ready for future NPC race events.")
		end,
		refresh = function() end,
	},
	{
		id = "car_chaos",
		title = "Car Chaos",
		buildBody = function(body)
			return buildPlaceholderBody(body, "No car chaos feed active yet. Future vehicle spectacle bets can plug in here.")
		end,
		refresh = function() end,
	},
	{
		id = "drone_gauntlet",
		title = "Drone Gauntlet",
		buildBody = function(body)
			return buildPlaceholderBody(body, "No drone gauntlet feed active yet. Future drone-run bets can plug in here.")
		end,
		refresh = function() end,
	},
}

local function getArrowText(isExpanded: boolean): string
	return if isExpanded then "v" else ">"
end

local function buildSection(definition: EventSectionDefinition)
	local container = Instance.new("Frame")
	container.Name = definition.id
	container.Size = UDim2.new(1, 0, 0, 40)
	container.AutomaticSize = Enum.AutomaticSize.Y
	container.BackgroundColor3 = Color3.fromRGB(18, 23, 32)
	container.BorderSizePixel = 0
	container.ZIndex = 10
	container.Parent = listHolder

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(55, 67, 84)
	stroke.Parent = container

	local containerLayout = Instance.new("UIListLayout")
	containerLayout.FillDirection = Enum.FillDirection.Vertical
	containerLayout.SortOrder = Enum.SortOrder.LayoutOrder
	containerLayout.Padding = UDim.new(0, 0)
	containerLayout.Parent = container

	local headerButton = Instance.new("TextButton")
	headerButton.Name = "Header"
	headerButton.Size = UDim2.new(1, 0, 0, 38)
	headerButton.LayoutOrder = 1
	headerButton.BackgroundTransparency = 1
	headerButton.Text = ""
	headerButton.Active = true
	headerButton.AutoButtonColor = true
	headerButton.ZIndex = 11
	headerButton.Parent = container

	local arrowLabel = Instance.new("TextLabel")
	arrowLabel.Name = "Arrow"
	arrowLabel.BackgroundTransparency = 1
	arrowLabel.Position = UDim2.fromOffset(10, 8)
	arrowLabel.Size = UDim2.fromOffset(18, 20)
	arrowLabel.Font = Enum.Font.GothamBold
	arrowLabel.TextSize = 18
	arrowLabel.TextColor3 = Color3.fromRGB(229, 233, 240)
	arrowLabel.ZIndex = 12
	arrowLabel.Parent = headerButton

	local titleLabel = Instance.new("TextLabel")
	titleLabel.BackgroundTransparency = 1
	titleLabel.Position = UDim2.fromOffset(34, 8)
	titleLabel.Size = UDim2.new(1, -44, 0, 20)
	titleLabel.TextXAlignment = Enum.TextXAlignment.Left
	titleLabel.Font = Enum.Font.GothamBold
	titleLabel.TextSize = 16
	titleLabel.TextColor3 = Color3.fromRGB(243, 246, 250)
	titleLabel.Text = definition.title
	titleLabel.ZIndex = 12
	titleLabel.Parent = headerButton

	local body = Instance.new("Frame")
	body.Name = "Body"
	body.AutomaticSize = Enum.AutomaticSize.Y
	body.Size = UDim2.new(1, 0, 0, 0)
	body.LayoutOrder = 2
	body.BackgroundTransparency = 1
	body.Visible = expandedSections[definition.id] == true
	body.ZIndex = 10
	body.Parent = container

	local bodyPadding = Instance.new("UIPadding")
	bodyPadding.PaddingLeft = UDim.new(0, 14)
	bodyPadding.PaddingRight = UDim.new(0, 14)
	bodyPadding.PaddingTop = UDim.new(0, 8)
	bodyPadding.PaddingBottom = UDim.new(0, 10)
	bodyPadding.Parent = body

	local builtViews = definition.buildBody(body)
	local views: EventSectionViews = builtViews :: any
	views.container = container
	views.body = body
	views.arrow = arrowLabel
	views.definition = definition
	sectionViewsById[definition.id] = views

	connectButtonClick(headerButton, function()
		expandedSections[definition.id] = not (expandedSections[definition.id] == true)
		body.Visible = expandedSections[definition.id] == true
		arrowLabel.Text = getArrowText(body.Visible)
	end)

	arrowLabel.Text = getArrowText(body.Visible)
end

for _, definition in ipairs(eventSections) do
	buildSection(definition)
end

local function refreshCueBanner()
	local winnerName = tostring(arenaState:GetAttribute("WinnerName") or "")
	local eventCue = tostring(arenaState:GetAttribute("EventCue") or "")
	local countdownNumber = tonumber(arenaState:GetAttribute("CountdownNumber") or 0) or 0
	local eventType = tostring(arenaState:GetAttribute("EventType") or "ArenaDuel")

	if not shouldShowArenaCueBanner() then
		cueBanner.Visible = false
	elseif countdownNumber > 0 then
		cueBanner.Visible = true
		cueBanner.Text = tostring(countdownNumber)
		cueBanner.TextColor3 = Color3.fromRGB(255, 212, 122)
		cueBanner.BackgroundTransparency = 0.22
	elseif eventCue == "FightStart" then
		cueBanner.Visible = true
		cueBanner.Text = ("%s  |  FIGHT!"):format(eventType == "ArenaDuel" and "ARENA" or "EVENT")
		cueBanner.TextColor3 = Color3.fromRGB(255, 110, 92)
		cueBanner.BackgroundTransparency = 0.22
	elseif eventCue == "Winner" and winnerName ~= "" then
		cueBanner.Visible = true
		cueBanner.Text = ("%s WINS"):format(winnerName)
		cueBanner.TextColor3 = Color3.fromRGB(136, 230, 144)
		cueBanner.BackgroundTransparency = 0.22
	elseif eventCue == "Introductions" then
		cueBanner.Visible = true
		cueBanner.Text = "MAIN EVENT"
		cueBanner.TextColor3 = Color3.fromRGB(255, 212, 122)
		cueBanner.BackgroundTransparency = 0.22
	else
		cueBanner.Visible = false
	end

	if cueBanner.Visible then
		scheduleArenaCueRefresh()
	end
end

local function refreshSections()
	for _, views in pairs(sectionViewsById) do
		local definition = views.definition
		local body = views.body
		local arrow = views.arrow
		body.Visible = expandedSections[definition.id] == true
		arrow.Text = getArrowText(body.Visible)
		definition.refresh(views)
	end
end

local function refreshAll()
	refreshSections()
	refreshCueBanner()
end

local function setHubOpen(open: boolean)
	isHubOpen = open
	print(("[EventHubUI] setOpen(%s)"):format(tostring(open)))
	panel.Visible = open
	panel.Active = open
	listHolder.Active = open
	tabButton.Visible = not open
	tabButton.Active = not open
end

local function toggleHub()
	local now = os.clock()
	if now - lastToggleAt < 0.08 then
		return Enum.ContextActionResult.Pass
	end
	lastToggleAt = now
	print("[EventHubUI] X key toggle")
	setHubOpen(not isHubOpen)
	return Enum.ContextActionResult.Sink
end

local arenaViews = sectionViewsById.arena
if arenaViews then
	local arenaBetAButton = arenaViews.betA :: TextButton
	local arenaBetBButton = arenaViews.betB :: TextButton
	local arenaSpectateButton = arenaViews.spectate :: TextButton

	connectButtonClick(arenaBetAButton, function()
		placeBetRemote:FireServer("A", Constants.Arena.DefaultBetAmount)
	end)

	connectButtonClick(arenaBetBButton, function()
		placeBetRemote:FireServer("B", Constants.Arena.DefaultBetAmount)
	end)

	connectButtonClick(arenaSpectateButton, function()
		playerGui:SetAttribute("ArenaSpectateRequested", if isSpectating() then "Stop" else "Start")
	end)
end

connectButtonClick(tabButton, function()
	print("[EventHubUI] Tab clicked")
	setHubOpen(true)
end)

connectButtonClick(closeButton, function()
	print("[EventHubUI] X clicked")
	setHubOpen(false)
end)

local function onToggleHubAction(_actionName, inputState)
	if inputState ~= Enum.UserInputState.Begin then
		return Enum.ContextActionResult.Pass
	end
	if UserInputService:GetFocusedTextBox() then
		return Enum.ContextActionResult.Pass
	end
	return toggleHub()
end

ContextActionService:UnbindAction(TOGGLE_ACTION)
ContextActionService:BindAction(TOGGLE_ACTION, onToggleHubAction, false, Enum.KeyCode.X)

UserInputService.InputBegan:Connect(function(inputObject, gameProcessed)
	if gameProcessed then
		return
	end
	if inputObject.KeyCode == Enum.KeyCode.X then
		if UserInputService:GetFocusedTextBox() then
			return
		end
		toggleHub()
	end
end)

for _, attr in ipairs({
	"Phase",
	"RoundId",
	"FighterAName",
	"FighterBName",
	"FighterAStyle",
	"FighterBStyle",
	"TimeRemaining",
	"WinnerName",
	"LastResult",
	"BettingOpen",
	"DisplayHeadline",
	"DisplayDetail",
	"EventCue",
	"CountdownNumber",
	"EventType",
}) do
	arenaState:GetAttributeChangedSignal(attr):Connect(refreshAll)
end

for _, attr in ipairs({"ArenaBetRoundId", "ArenaBetSlot", "ArenaOutcome", "ArenaOutcomeRoundId"}) do
	player:GetAttributeChangedSignal(attr):Connect(refreshAll)
end

playerGui:GetAttributeChangedSignal("ArenaSpectating"):Connect(refreshAll)
playerGui:GetAttributeChangedSignal("ArenaSpectateRequested"):Connect(refreshAll)

player:GetAttributeChangedSignal("ArenaOutcome"):Connect(function()
	if not shouldShowArenaCueBanner() then
		return
	end
	local outcome = tostring(player:GetAttribute("ArenaOutcome") or "")
	if outcome == "Won" then
		showCueBanner("BET WON", Color3.fromRGB(129, 227, 137), 1.2)
	elseif outcome == "Lost" then
		showCueBanner("BET LOST", Color3.fromRGB(255, 128, 115), 1.2)
	end
	refreshAll()
end)

local function bindCreditsRefresh()
	local leaderstats = player:FindFirstChild("leaderstats")
	local credits = leaderstats and leaderstats:FindFirstChild("Credits")
	if credits and credits:IsA("IntValue") then
		credits:GetPropertyChangedSignal("Value"):Connect(refreshAll)
	end
end

bindCreditsRefresh()

player.ChildAdded:Connect(function(child)
	if child.Name == "leaderstats" then
		task.defer(function()
			bindCreditsRefresh()
			refreshAll()
		end)
	end
end)

player.CharacterAdded:Connect(function()
	task.defer(refreshAll)
	scheduleArenaCueRefresh()
end)

refreshAll()
setHubOpen(false)
