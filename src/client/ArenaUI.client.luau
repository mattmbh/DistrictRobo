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
local predictWinnerRemote = Net.GetRemoteEvent(Constants.Remotes.ArenaPredictWinner)
local upgradeFighterRemote = Net.GetRemoteEvent(Constants.Remotes.ArenaUpgradeFighter)

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
cueBanner.Size = UDim2.fromOffset(300, 58)
cueBanner.BackgroundColor3 = Color3.fromRGB(19, 24, 33)
cueBanner.BackgroundTransparency = 0.24
cueBanner.BorderSizePixel = 0
cueBanner.Font = Enum.Font.GothamBlack
cueBanner.TextSize = 22
cueBanner.TextColor3 = Color3.fromRGB(255, 212, 122)
cueBanner.TextYAlignment = Enum.TextYAlignment.Top
cueBanner.TextStrokeTransparency = 0.5
cueBanner.TextStrokeColor3 = Color3.fromRGB(54, 34, 12)
cueBanner.Visible = false
cueBanner.ZIndex = 5
cueBanner.Parent = gui

local cueStroke = Instance.new("UIStroke")
cueStroke.Thickness = 2
cueStroke.Color = Color3.fromRGB(255, 188, 84)
cueStroke.Parent = cueBanner

local cueSecondary = Instance.new("TextLabel")
cueSecondary.Name = "Secondary"
cueSecondary.AnchorPoint = Vector2.new(0.5, 0)
cueSecondary.Position = UDim2.new(0.5, 0, 0, 32)
cueSecondary.Size = UDim2.new(1, -20, 0, 18)
cueSecondary.BackgroundTransparency = 1
cueSecondary.Font = Enum.Font.GothamBold
cueSecondary.TextSize = 16
cueSecondary.TextColor3 = Color3.fromRGB(136, 230, 144)
cueSecondary.TextStrokeTransparency = 0.35
cueSecondary.TextStrokeColor3 = Color3.fromRGB(18, 22, 28)
cueSecondary.TextWrapped = true
cueSecondary.Text = ""
cueSecondary.Visible = false
cueSecondary.ZIndex = 6
cueSecondary.Parent = cueBanner

local cueScale = Instance.new("UIScale")
cueScale.Scale = 1
cueScale.Parent = cueBanner

local lastCuePresentationKey = ""
local pulseCueBanner: (number) -> ()
local setArenaNameplateVisibility: (boolean) -> ()
local applyCueBannerPresentation: (string, Color3, string, Color3) -> ()

local personalResultBanner = Instance.new("Frame")
personalResultBanner.Name = "PersonalResultBanner"
personalResultBanner.AnchorPoint = Vector2.new(0.5, 0.5)
personalResultBanner.Position = UDim2.new(0.5, 0, 0.38, 0)
personalResultBanner.Size = UDim2.fromOffset(360, 96)
personalResultBanner.BackgroundColor3 = Color3.fromRGB(18, 24, 33)
personalResultBanner.BackgroundTransparency = 0.12
personalResultBanner.BorderSizePixel = 0
personalResultBanner.Visible = false
personalResultBanner.ZIndex = 15
personalResultBanner.Parent = gui

local personalResultStroke = Instance.new("UIStroke")
personalResultStroke.Thickness = 2
personalResultStroke.Color = Color3.fromRGB(146, 238, 152)
personalResultStroke.Parent = personalResultBanner

local personalResultTitle = Instance.new("TextLabel")
personalResultTitle.Name = "Title"
personalResultTitle.BackgroundTransparency = 1
personalResultTitle.Position = UDim2.fromOffset(14, 12)
personalResultTitle.Size = UDim2.new(1, -28, 0, 34)
personalResultTitle.Font = Enum.Font.GothamBlack
personalResultTitle.TextSize = 28
personalResultTitle.TextColor3 = Color3.fromRGB(144, 242, 152)
personalResultTitle.TextStrokeTransparency = 0.35
personalResultTitle.TextStrokeColor3 = Color3.fromRGB(14, 18, 24)
personalResultTitle.Text = ""
personalResultTitle.ZIndex = 16
personalResultTitle.Parent = personalResultBanner

local personalResultDetail = Instance.new("TextLabel")
personalResultDetail.Name = "Detail"
personalResultDetail.BackgroundTransparency = 1
personalResultDetail.Position = UDim2.fromOffset(14, 48)
personalResultDetail.Size = UDim2.new(1, -28, 0, 18)
personalResultDetail.Font = Enum.Font.GothamBold
personalResultDetail.TextSize = 14
personalResultDetail.TextColor3 = Color3.fromRGB(245, 235, 208)
personalResultDetail.TextStrokeTransparency = 0.6
personalResultDetail.TextStrokeColor3 = Color3.fromRGB(14, 18, 24)
personalResultDetail.Text = ""
personalResultDetail.ZIndex = 16
personalResultDetail.Parent = personalResultBanner

local personalResultReward = Instance.new("TextLabel")
personalResultReward.Name = "Reward"
personalResultReward.BackgroundTransparency = 1
personalResultReward.Position = UDim2.fromOffset(14, 66)
personalResultReward.Size = UDim2.new(1, -28, 0, 18)
personalResultReward.Font = Enum.Font.GothamBold
personalResultReward.TextSize = 15
personalResultReward.TextColor3 = Color3.fromRGB(255, 223, 138)
personalResultReward.TextStrokeTransparency = 0.55
personalResultReward.TextStrokeColor3 = Color3.fromRGB(14, 18, 24)
personalResultReward.Text = ""
personalResultReward.ZIndex = 16
personalResultReward.Parent = personalResultBanner

local personalResultScale = Instance.new("UIScale")
personalResultScale.Scale = 1
personalResultScale.Parent = personalResultBanner

local FIGHTER_A_ACCENT = Color3.fromRGB(161, 74, 74)
local FIGHTER_B_ACCENT = Color3.fromRGB(69, 108, 176)
local FIGHTER_A_HEADER_TEXT = Color3.fromRGB(241, 205, 205)
local FIGHTER_B_HEADER_TEXT = Color3.fromRGB(208, 223, 246)

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
local resultCueToken = 0
local arenaCueRefreshScheduled = false
local isHubOpen = false
local TOGGLE_ACTION = "ToggleNpcEventHub"
local lastToggleAt = 0
local localPredictionMarkerGui: BillboardGui? = nil
local localPredictionMarkerTarget: BasePart? = nil
local personalResultToken = 0
local lastPersonalResultRoundId = -1
local tutorialCueToken = 0
local lastTutorialCueKey = ""

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

local setCueSecondary: (string, Color3) -> ()

local function getPredictedFighterNameForCurrentRound(): string
	local predictedSlot = tostring(player:GetAttribute("ArenaPredictionSlot") or "")
	if predictedSlot == "A" then
		local fighterName = tostring(arenaState:GetAttribute("FighterAName") or "")
		local trimmed = string.gsub(fighterName, "^%s*(.-)%s*$", "%1")
		return if trimmed ~= "" then trimmed else "Fighter A"
	elseif predictedSlot == "B" then
		local fighterName = tostring(arenaState:GetAttribute("FighterBName") or "")
		local trimmed = string.gsub(fighterName, "^%s*(.-)%s*$", "%1")
		return if trimmed ~= "" then trimmed else "Fighter B"
	end
	return ""
end

local function hidePersonalResultBanner()
	personalResultToken += 1
	personalResultBanner.Visible = false
	setArenaNameplateVisibility(true)
	personalResultBanner.BackgroundTransparency = 0.12
	personalResultTitle.TextTransparency = 0
	personalResultTitle.TextStrokeTransparency = 0.35
	personalResultDetail.TextTransparency = 0
	personalResultDetail.TextStrokeTransparency = 0.6
	personalResultReward.TextTransparency = 0
	personalResultReward.TextStrokeTransparency = 0.55
	personalResultDetail.Text = ""
	personalResultReward.Text = ""
	personalResultScale.Scale = 1
end

local function showPersonalResultBanner(titleText: string, titleColor: Color3, detailText: string, rewardText: string, duration: number, scaleFrom: number)
	personalResultToken += 1
	local current = personalResultToken

	personalResultTitle.Text = titleText
	personalResultTitle.TextColor3 = titleColor
	personalResultDetail.Text = detailText
	personalResultDetail.Visible = detailText ~= ""
	personalResultReward.Text = rewardText
	personalResultReward.Visible = rewardText ~= ""
	personalResultStroke.Color = titleColor
	personalResultBanner.BackgroundTransparency = if titleText == "PREDICTION CORRECT" then 0.1 else 0.18
	personalResultTitle.TextTransparency = 0
	personalResultTitle.TextStrokeTransparency = 0.35
	personalResultDetail.TextTransparency = 0
	personalResultDetail.TextStrokeTransparency = 0.6
	personalResultReward.TextTransparency = 0
	personalResultReward.TextStrokeTransparency = 0.55
	personalResultBanner.Visible = true
	setArenaNameplateVisibility(false)
	personalResultScale.Scale = scaleFrom

	local settle = TweenService:Create(personalResultScale, TweenInfo.new(0.18, Enum.EasingStyle.Back, Enum.EasingDirection.Out), {
		Scale = 1,
	})
	settle:Play()

	task.delay(duration, function()
		if current ~= personalResultToken then
			return
		end

		TweenService:Create(personalResultBanner, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		}):Play()
		TweenService:Create(personalResultTitle, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		TweenService:Create(personalResultDetail, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		TweenService:Create(personalResultReward, TweenInfo.new(0.22, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			TextTransparency = 1,
			TextStrokeTransparency = 1,
		}):Play()
		task.delay(0.24, function()
			if current == personalResultToken then
				personalResultBanner.Visible = false
			end
		end)
	end)
end

local function refreshPersonalResultBanner()
	local phase = tostring(arenaState:GetAttribute("Phase") or "")
	local roundId = tonumber(arenaState:GetAttribute("RoundId") or -1) or -1
	local outcomeRoundId = tonumber(player:GetAttribute("ArenaOutcomeRoundId") or -1) or -1
	local outcome = tostring(player:GetAttribute("ArenaOutcome") or "")
	local outcomeReward = tonumber(player:GetAttribute("ArenaOutcomeReward") or 0) or 0

	if phase ~= "Result" then
		hidePersonalResultBanner()
		if phase == "PredictionWindow" or phase == "Intermission" or phase == "Introductions" then
			lastPersonalResultRoundId = -1
		end
		return
	end

	if outcomeRoundId ~= roundId or outcome == "" or lastPersonalResultRoundId == roundId then
		return
	end

	local predictedName = getPredictedFighterNameForCurrentRound()
	local detailText = predictedName ~= "" and ("You predicted: %s"):format(predictedName) or ""

	if outcome == "Correct" then
		showPersonalResultBanner(
			"PREDICTION CORRECT",
			Color3.fromRGB(144, 242, 152),
			detailText,
			if outcomeReward > 0 then ("+%d Credits"):format(outcomeReward) else "",
			1.8,
			1.08
		)
	elseif outcome == "Missed" then
		showPersonalResultBanner(
			"PREDICTION MISSED",
			Color3.fromRGB(239, 126, 96),
			detailText,
			"",
			1.6,
			1.04
		)
	else
		return
	end

	lastPersonalResultRoundId = roundId
end

local function showCueBanner(text: string, color: Color3, duration: number)
	resultCueToken += 1
	local current = resultCueToken
	cueBanner.Text = text
	cueBanner.TextColor3 = color
	cueBanner.TextSize = 22
	cueBanner.BackgroundTransparency = 0.24
	cueStroke.Color = Color3.fromRGB(255, 188, 84)
	setCueSecondary("", cueSecondary.TextColor3)
	cueBanner.Visible = true
	pulseCueBanner(0.96)

	local fade = TweenService:Create(cueBanner, TweenInfo.new(duration, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.92,
	})
	task.delay(duration, function()
		if current == resultCueToken then
			fade:Play()
		end
	end)
	task.delay(duration + 0.12, function()
		if current == resultCueToken then
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
				setCueSecondary("", cueSecondary.TextColor3)
				lastCuePresentationKey = ""
			elseif personalResultBanner.Visible and eventCue == "Winner" then
				cueBanner.Visible = false
				setCueSecondary("", cueSecondary.TextColor3)
			elseif countdownNumber > 0 then
				cueBanner.Visible = true
				applyCueBannerPresentation(tostring(countdownNumber), Color3.fromRGB(255, 212, 122), "", cueSecondary.TextColor3)
			elseif eventCue == "FightStart" then
				cueBanner.Visible = true
				applyCueBannerPresentation(
					("%s  |  FIGHT!"):format(eventType == "ArenaDuel" and "ARENA" or "EVENT"),
					Color3.fromRGB(255, 110, 92),
					"",
					cueSecondary.TextColor3
				)
			elseif eventCue == "Winner" and winnerName ~= "" then
				cueBanner.Visible = true
				applyCueBannerPresentation(("%s WINS"):format(winnerName), Color3.fromRGB(255, 212, 122), "", cueSecondary.TextColor3)
			elseif eventCue == "Introductions" then
				cueBanner.Visible = true
				applyCueBannerPresentation("MAIN EVENT", Color3.fromRGB(255, 212, 122), "", cueSecondary.TextColor3)
			else
				cueBanner.Visible = false
				setCueSecondary("", cueSecondary.TextColor3)
				lastCuePresentationKey = ""
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
	if outcome == "Correct" then
		return "Prediction Correct"
	elseif outcome == "Missed" then
		return "Prediction Missed"
	end
	return ""
end

setCueSecondary = function(text: string, color: Color3)
	local hasSecondary = text ~= ""
	cueSecondary.Text = text
	cueSecondary.TextColor3 = color
	cueSecondary.Visible = hasSecondary
	cueBanner.Size = if hasSecondary then UDim2.fromOffset(300, 60) else UDim2.fromOffset(300, 42)
end

local function getArenaOutcomeBannerText(currentRoundId: number): string
	local outcomeText = getArenaOutcomeText(currentRoundId)
	if outcomeText == "Prediction Correct" then
		return "PREDICTION CORRECT"
	elseif outcomeText == "Prediction Missed" then
		return "PREDICTION MISSED"
	end
	return ""
end

local function getArenaOutcomeBannerColor(currentRoundId: number): Color3
	local outcomeText = getArenaOutcomeText(currentRoundId)
	if outcomeText == "Prediction Correct" then
		return Color3.fromRGB(144, 242, 152)
	elseif outcomeText == "Prediction Missed" then
		return Color3.fromRGB(239, 126, 96)
	end
	return Color3.fromRGB(220, 228, 238)
end

pulseCueBanner = function(scaleFrom: number)
	cueScale.Scale = scaleFrom
	local pop = TweenService:Create(cueScale, TweenInfo.new(0.16, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
		Scale = 1,
	})
	pop:Play()
end

applyCueBannerPresentation = function(primaryText: string, primaryColor: Color3, secondaryText: string, secondaryColor: Color3)
	local key = table.concat({primaryText, secondaryText}, "::")
	local isOutcomeFocus = secondaryText ~= "" and (primaryText == "PREDICTION CORRECT" or primaryText == "PREDICTION MISSED")

	cueBanner.Text = primaryText
	cueBanner.TextColor3 = primaryColor
	cueBanner.TextSize = if isOutcomeFocus then 26 else 22
	cueBanner.BackgroundTransparency = if isOutcomeFocus then 0.12 else 0.22
	cueSecondary.TextSize = if isOutcomeFocus then 14 else 16
	cueStroke.Color = if primaryText == "PREDICTION CORRECT"
		then Color3.fromRGB(146, 238, 152)
		elseif primaryText == "PREDICTION MISSED"
		then Color3.fromRGB(239, 126, 96)
		else Color3.fromRGB(255, 188, 84)

	setCueSecondary(secondaryText, secondaryColor)

	if key ~= lastCuePresentationKey then
		pulseCueBanner(if isOutcomeFocus then 0.91 else 0.96)
		lastCuePresentationKey = key
	end
end

local function getArenaWinnerInfoText(phase: string, lastWinnerName: string, currentWinnerName: string, fighterAName: string, fighterBName: string): string
	local displayFighterA = string.gsub(fighterAName, "^%s*(.-)%s*$", "%1")
	local displayFighterB = string.gsub(fighterBName, "^%s*(.-)%s*$", "%1")
	if displayFighterA == "" then
		displayFighterA = "Fighter A"
	end
	if displayFighterB == "" then
		displayFighterB = "Fighter B"
	end

	if phase == "FightActive" then
		return ("Live Fight: %s vs %s"):format(displayFighterA, displayFighterB)
	elseif phase == "Result" and currentWinnerName ~= "" then
		return ("Winner: %s"):format(currentWinnerName)
	elseif lastWinnerName ~= "" then
		return ("Last Winner: %s"):format(lastWinnerName)
	end
	return "Last Winner: --"
end

local function getArenaWinnerInfoColor(phase: string): Color3
	if phase == "FightActive" then
		return Color3.fromRGB(226, 192, 106)
	elseif phase == "Result" then
		return Color3.fromRGB(136, 230, 144)
	end
	return Color3.fromRGB(168, 181, 196)
end

local function getPhaseDisplayText(phase: string): string
	if phase == "Intermission" then
		return "Next Round Preparing"
	elseif phase == "Introductions" then
		return "Upcoming Fight"
	elseif phase == "PredictionWindow" then
		return "Upcoming Fight / Prediction Open"
	elseif phase == "FightActive" then
		return "Fight Active / Prediction Locked"
	elseif phase == "Result" then
		return "Fight Complete / Result Shown"
	end
	return phase
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

local function setInfoLine(label: TextLabel, prefix: string, valueText: string)
	label.Text = ("%s %s"):format(prefix, valueText)
end

local function getPlayerScrap(): number
	local leaderstats = player:FindFirstChild("leaderstats")
	local scrapValue = leaderstats and (leaderstats:FindFirstChild("Materials") or leaderstats:FindFirstChild("Scrap"))
	if scrapValue and scrapValue:IsA("IntValue") then
		return scrapValue.Value
	end
	return 0
end

local function makeActionButton(parent: Instance, text: string, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(1, 0, 0, 30)
	button.BackgroundColor3 = color
	button.TextColor3 = Color3.fromRGB(245, 247, 250)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 14
	button.TextTruncate = Enum.TextTruncate.AtEnd
	button.Text = text
	button.BorderSizePixel = 0
	button.Parent = parent

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(250, 212, 120)
	stroke.Transparency = 0.9
	stroke.Parent = button

	return button
end

local function makeCompactRowButton(parent: Instance, width: number, text: string, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.Size = UDim2.new(0, width, 0, 30)
	button.BackgroundColor3 = color
	button.TextColor3 = Color3.fromRGB(245, 247, 250)
	button.Font = Enum.Font.GothamBold
	button.TextSize = 13
	button.TextTruncate = Enum.TextTruncate.AtEnd
	button.Text = text
	button.BorderSizePixel = 0
	button.Parent = parent

	local stroke = Instance.new("UIStroke")
	stroke.Name = "Stroke"
	stroke.Thickness = 1
	stroke.Color = Color3.fromRGB(250, 212, 120)
	stroke.Transparency = 0.9
	stroke.Parent = button

	return button
end

local function setCompactUpgradeButtonState(
	button: TextButton,
	fighterId: string,
	cost: number,
	materials: number,
	isAvailable: boolean
)
	local stroke = button:FindFirstChild("Stroke") :: UIStroke?
	local canUpgrade = fighterId ~= "" and cost > 0 and materials >= cost and isAvailable

	button.Active = canUpgrade
	button.AutoButtonColor = canUpgrade
	button.Text = "+ Upgrade"
	button.TextColor3 = if canUpgrade then Color3.fromRGB(255, 241, 205) else Color3.fromRGB(206, 214, 224)
	button.BackgroundTransparency = if canUpgrade then 0.12 else 0.42
	if stroke then
		stroke.Transparency = if canUpgrade then 0.22 else 0.72
	end

	button:SetAttribute("FighterId", fighterId)
	button:SetAttribute("UpgradeCost", cost)
end

local function showTutorialCue(stepText: string, step: number, stepCount: number)
	tutorialCueToken += 1
	local current = tutorialCueToken

	applyCueBannerPresentation(
		stepText:upper(),
		Color3.fromRGB(164, 227, 255),
		("Step %d/%d"):format(math.max(1, step), math.max(1, stepCount)),
		Color3.fromRGB(216, 236, 248)
	)
	cueBanner.Visible = true
	pulseCueBanner(0.98)

	task.delay(1.85, function()
		if current ~= tutorialCueToken then
			return
		end

		TweenService:Create(cueBanner, TweenInfo.new(0.2, Enum.EasingStyle.Quad, Enum.EasingDirection.Out), {
			BackgroundTransparency = 1,
		}):Play()
		task.delay(0.22, function()
			if current == tutorialCueToken then
				cueBanner.Visible = false
				setCueSecondary("", cueSecondary.TextColor3)
				lastCuePresentationKey = ""
				scheduleArenaCueRefresh()
			end
		end)
	end)
end

local function refreshTutorialCue()
	local tutorialActive = player:GetAttribute("TutorialActive") == true
	local tutorialCompleted = player:GetAttribute("TutorialCompleted") == true
	local step = tonumber(player:GetAttribute("TutorialStep") or 1) or 1
	local stepCount = tonumber(player:GetAttribute("TutorialStepCount") or 5) or 5
	local stepText = tostring(player:GetAttribute("TutorialStepText") or "")

	if not tutorialActive or tutorialCompleted or stepText == "" then
		lastTutorialCueKey = ""
		return
	end

	local cueKey = ("%d:%s"):format(step, stepText)
	if cueKey == lastTutorialCueKey then
		return
	end

	lastTutorialCueKey = cueKey
	showTutorialCue(stepText, step, stepCount)
end

local function getChoiceDisplayName(choiceName: string, fallbackName: string): string
	local trimmed = string.gsub(choiceName, "^%s*(.-)%s*$", "%1")
	if trimmed == "" then
		return fallbackName
	end
	return trimmed
end

local function getPredictionButtonColor(slot: string, variant: string): Color3
	if slot == "A" then
		if variant == "selected" then
			return Color3.fromRGB(186, 88, 88)
		end
		return Color3.fromRGB(161, 74, 74)
	end

	if variant == "selected" then
		return Color3.fromRGB(82, 124, 196)
	end
	return Color3.fromRGB(69, 108, 176)
end

local function setPredictionButtonState(
	button: TextButton,
	slot: string,
	choiceName: string,
	fallbackName: string,
	state: string
)
	local stroke = button:FindFirstChild("Stroke") :: UIStroke?
	local displayName = getChoiceDisplayName(choiceName, fallbackName)

	button.Active = state == "available"
	button.AutoButtonColor = state == "available"
	button.BackgroundColor3 = getPredictionButtonColor(slot, if state == "selected" then "selected" else "base")
	button.TextColor3 = Color3.fromRGB(245, 247, 250)
	button.BackgroundTransparency = 0
	if stroke then
		stroke.Transparency = 0.9
	end

	if state == "available" then
		button.Text = ("Predict: %s"):format(displayName)
	elseif state == "selected" then
		button.Text = ("Selected: %s"):format(displayName)
		button.TextColor3 = Color3.fromRGB(255, 242, 205)
		if stroke then
			stroke.Transparency = 0.18
		end
	elseif state == "submitted_other" then
		button.Text = "Prediction Submitted"
		button.BackgroundTransparency = 0.32
		button.TextColor3 = Color3.fromRGB(227, 233, 241)
	elseif state == "locked_selected" then
		button.Text = ("Locked: %s"):format(displayName)
		button.BackgroundTransparency = 0.14
		button.TextColor3 = Color3.fromRGB(255, 239, 198)
		if stroke then
			stroke.Transparency = 0.24
		end
	elseif state == "opens_soon" then
		button.Text = "Prediction Opening Soon"
		button.BackgroundTransparency = 0.42
		button.TextColor3 = Color3.fromRGB(225, 232, 241)
	elseif state == "result_selected" then
		button.Text = ("Your Pick: %s"):format(displayName)
		button.BackgroundTransparency = 0.22
		button.TextColor3 = Color3.fromRGB(250, 239, 204)
	elseif state == "result" then
		button.Text = "Next Round Soon"
		button.BackgroundTransparency = 0.44
		button.TextColor3 = Color3.fromRGB(218, 226, 236)
	else
		button.Text = "Prediction Locked"
		button.BackgroundTransparency = 0.52
		button.TextColor3 = Color3.fromRGB(209, 217, 227)
	end
end

local function getStatFillColor(value: number): Color3
	local clampedValue = math.clamp(math.floor(value + 0.5), 0, 10)
	if clampedValue <= 2 then
		return Color3.fromRGB(210, 84, 84)
	elseif clampedValue <= 5 then
		return Color3.fromRGB(224, 142, 74)
	elseif clampedValue <= 7 then
		return Color3.fromRGB(230, 198, 82)
	end
	return Color3.fromRGB(104, 201, 116)
end

local function setStatBar(row: Frame, labelText: string, value: number)
	local clampedValue = math.clamp(value, 0, 10)
	local label = row:FindFirstChild("Label") :: TextLabel
	local barBackground = row:FindFirstChild("BarBackground") :: Frame
	local barFill = barBackground:FindFirstChild("BarFill") :: Frame

	label.Text = labelText
	barFill.Size = UDim2.fromScale(clampedValue / 10, 1)
	barFill.BackgroundColor3 = getStatFillColor(clampedValue)
end

local function getFighterStatHeaderLabel(card: Frame): TextLabel?
	local headerFrame = card:FindFirstChild("HeaderFrame")
	if headerFrame and headerFrame:IsA("Frame") then
		local header = headerFrame:FindFirstChild("Header")
		if header and header:IsA("TextLabel") then
			return header
		end
	end
	return nil
end

local function makeStatRow(parent: Instance, labelText: string): Frame
	local row = Instance.new("Frame")
	row.Name = "StatRow"
	row.Size = UDim2.new(1, 0, 0, 16)
	row.BackgroundTransparency = 1
	row.Parent = parent

	local label = Instance.new("TextLabel")
	label.Name = "Label"
	label.BackgroundTransparency = 1
	label.Size = UDim2.fromOffset(78, 16)
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = Enum.Font.GothamBold
	label.TextSize = 13
	label.TextColor3 = Color3.fromRGB(232, 238, 245)
	label.Text = labelText
	label.Parent = row

	local barBackground = Instance.new("Frame")
	barBackground.Name = "BarBackground"
	barBackground.Position = UDim2.fromOffset(90, 3)
	barBackground.Size = UDim2.new(1, -90, 0, 10)
	barBackground.BackgroundColor3 = Color3.fromRGB(34, 42, 56)
	barBackground.BackgroundTransparency = 0.22
	barBackground.BorderSizePixel = 0
	barBackground.Parent = row

	local barFill = Instance.new("Frame")
	barFill.Name = "BarFill"
	barFill.Size = UDim2.fromScale(0, 1)
	barFill.BackgroundColor3 = Color3.fromRGB(230, 198, 82)
	barFill.BorderSizePixel = 0
	barFill.Parent = barBackground

	return row
end

local function makeFighterStatCard(parent: Instance, accentColor: Color3, headerTextColor: Color3): Frame
	local card = Instance.new("Frame")
	card.Size = UDim2.new(1, 0, 0, 74)
	card.BackgroundColor3 = Color3.fromRGB(18, 24, 34)
	card.BackgroundTransparency = 0.18
	card.BorderSizePixel = 0
	card.Parent = parent

	local padding = Instance.new("UIPadding")
	padding.PaddingLeft = UDim.new(0, 8)
	padding.PaddingRight = UDim.new(0, 8)
	padding.PaddingTop = UDim.new(0, 5)
	padding.PaddingBottom = UDim.new(0, 5)
	padding.Parent = card

	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 3)
	layout.Parent = card

	local headerFrame = Instance.new("Frame")
	headerFrame.Name = "HeaderFrame"
	headerFrame.Size = UDim2.new(1, 0, 0, 18)
	headerFrame.BackgroundColor3 = accentColor
	headerFrame.BackgroundTransparency = 0.82
	headerFrame.BorderSizePixel = 0
	headerFrame.Parent = card

	local headerAccent = Instance.new("Frame")
	headerAccent.Name = "HeaderAccent"
	headerAccent.Size = UDim2.fromOffset(4, 18)
	headerAccent.BackgroundColor3 = accentColor
	headerAccent.BorderSizePixel = 0
	headerAccent.Parent = headerFrame

	local header = Instance.new("TextLabel")
	header.Name = "Header"
	header.BackgroundTransparency = 1
	header.Position = UDim2.fromOffset(10, 0)
	header.Size = UDim2.new(1, 0, 1, 0)
	header.TextXAlignment = Enum.TextXAlignment.Left
	header.Font = Enum.Font.GothamBlack
	header.TextSize = 13
	header.TextColor3 = headerTextColor
	header.TextTruncate = Enum.TextTruncate.AtEnd
	header.Text = ""
	header.Parent = headerFrame

	local powerRow = makeStatRow(card, "Power")
	powerRow.Name = "PowerRow"

	local speedRow = makeStatRow(card, "Speed")
	speedRow.Name = "SpeedRow"

	local toughnessRow = makeStatRow(card, "Toughness")
	toughnessRow.Name = "ToughnessRow"

	return card
end

local function setFighterStatCard(
	card: Frame,
	choiceName: string,
	fallbackName: string,
	style: string,
	record: string,
	winChance: number,
	power: number,
	speed: number,
	toughness: number
)
	local displayName = getChoiceDisplayName(choiceName, fallbackName)
	local displayStyle = style ~= "" and style or "Unknown"
	local displayRecord = record ~= "" and record or "0-0"
	local displayWinChance = math.clamp(math.floor(winChance + 0.5), 0, 100)
	local header = getFighterStatHeaderLabel(card)

	if header then
		header.Text = ("%s | %s | REC %s | %d%%"):format(displayName, displayStyle, displayRecord, displayWinChance)
	end
	setStatBar(card:FindFirstChild("PowerRow") :: Frame, "Power", power)
	setStatBar(card:FindFirstChild("SpeedRow") :: Frame, "Speed", speed)
	setStatBar(card:FindFirstChild("ToughnessRow") :: Frame, "Toughness", toughness)
end

local function buildArenaBody(body: Frame): {[string]: any}
	local layout = Instance.new("UIListLayout")
	layout.Padding = UDim.new(0, 3)
	layout.Parent = body

	local status = makeSectionLabel(body, 18, 13, Color3.fromRGB(228, 235, 243), Enum.Font.GothamBold)
	local timer = makeSectionLabel(body, 18, 13, Color3.fromRGB(220, 228, 238), Enum.Font.GothamBold)
	local fighterAStats = makeFighterStatCard(body, FIGHTER_A_ACCENT, FIGHTER_A_HEADER_TEXT)
	local fighterBStats = makeFighterStatCard(body, FIGHTER_B_ACCENT, FIGHTER_B_HEADER_TEXT)
	local winner = makeSectionLabel(body, 16, 13, Color3.fromRGB(213, 221, 232), Enum.Font.GothamBold)
	local result = makeSectionLabel(body, 18, 13, Color3.fromRGB(136, 230, 144), Enum.Font.GothamBold)

	local buttonRow = Instance.new("Frame")
	buttonRow.AutomaticSize = Enum.AutomaticSize.Y
	buttonRow.Size = UDim2.new(1, 0, 0, 0)
	buttonRow.BackgroundTransparency = 1
	buttonRow.Parent = body

	local buttonPadding = Instance.new("UIPadding")
	buttonPadding.PaddingTop = UDim.new(0, 4)
	buttonPadding.PaddingBottom = UDim.new(0, 8)
	buttonPadding.Parent = buttonRow

	local buttonLayout = Instance.new("UIListLayout")
	buttonLayout.Padding = UDim.new(0, 6)
	buttonLayout.Parent = buttonRow

	local spectate = makeActionButton(buttonRow, "Watch Fight", Color3.fromRGB(56, 71, 99))

	local sectionSpacer = Instance.new("Frame")
	sectionSpacer.Name = "SectionSpacer"
	sectionSpacer.Size = UDim2.new(1, 0, 0, 18)
	sectionSpacer.BackgroundTransparency = 1
	sectionSpacer.Parent = buttonRow

	local actionRowA = Instance.new("Frame")
	actionRowA.Name = "ActionRowA"
	actionRowA.Size = UDim2.new(1, 0, 0, 30)
	actionRowA.BackgroundTransparency = 1
	actionRowA.Parent = buttonRow

	local actionRowALayout = Instance.new("UIListLayout")
	actionRowALayout.FillDirection = Enum.FillDirection.Horizontal
	actionRowALayout.VerticalAlignment = Enum.VerticalAlignment.Center
	actionRowALayout.Padding = UDim.new(0, 6)
	actionRowALayout.Parent = actionRowA

	local predictA = makeActionButton(actionRowA, "Predict A", Color3.fromRGB(161, 74, 74))
	predictA.Size = UDim2.new(1, -92, 0, 30)
	local upgradeA = makeCompactRowButton(actionRowA, 86, "+ Upgrade", Color3.fromRGB(116, 92, 58))

	local actionRowB = Instance.new("Frame")
	actionRowB.Name = "ActionRowB"
	actionRowB.Size = UDim2.new(1, 0, 0, 30)
	actionRowB.BackgroundTransparency = 1
	actionRowB.Parent = buttonRow

	local actionRowBLayout = Instance.new("UIListLayout")
	actionRowBLayout.FillDirection = Enum.FillDirection.Horizontal
	actionRowBLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	actionRowBLayout.Padding = UDim.new(0, 6)
	actionRowBLayout.Parent = actionRowB

	local predictB = makeActionButton(actionRowB, "Predict B", Color3.fromRGB(69, 108, 176))
	predictB.Size = UDim2.new(1, -92, 0, 30)
	local upgradeB = makeCompactRowButton(actionRowB, 86, "+ Upgrade", Color3.fromRGB(116, 92, 58))

	return {
		status = status,
		timer = timer,
		fighterAStats = fighterAStats,
		fighterBStats = fighterBStats,
		winner = winner,
		result = result,
		upgradeA = upgradeA,
		upgradeB = upgradeB,
		predictA = predictA,
		predictB = predictB,
		spectate = spectate,
	}
end

local function findArenaRuntimeFolder(): Folder?
	local world = workspace:FindFirstChild("World")
	local arena = world and world:FindFirstChild("Arena")
	local venue = arena and arena:FindFirstChild("Venue")
	local runtime = venue and venue:FindFirstChild("Runtime")
	if runtime and runtime:IsA("Folder") then
		return runtime
	end
	return nil
end

local function findArenaFighterPartForSlot(slot: string): BasePart?
	local runtime = findArenaRuntimeFolder()
	if not runtime then
		return nil
	end

	for _, child in ipairs(runtime:GetChildren()) do
		if child:IsA("Model") and tostring(child:GetAttribute("ArenaSlot") or "") == slot then
			local head = child:FindFirstChild("Head")
			if head and head:IsA("BasePart") then
				return head
			end
			local primaryPart = child.PrimaryPart
			if primaryPart then
				return primaryPart
			end
		end
	end

	return nil
end

setArenaNameplateVisibility = function(visible: boolean)
	local runtime = findArenaRuntimeFolder()
	if not runtime then
		return
	end

	for _, child in ipairs(runtime:GetChildren()) do
		if child:IsA("Model") then
			for _, descendant in ipairs(child:GetDescendants()) do
				if descendant:IsA("BillboardGui") and descendant.Name == "ArenaNameplate" then
					descendant.Enabled = visible
				end
			end
		end
	end
end

local function ensureLocalPredictionMarker(): BillboardGui
	if localPredictionMarkerGui and localPredictionMarkerGui.Parent then
		return localPredictionMarkerGui
	end

	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ArenaLocalPredictionMarker"
	billboard.Size = UDim2.fromOffset(30, 22)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 5.85, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = Constants.Arena.NameplateMaxDistance
	billboard.Enabled = false

	local arrow = Instance.new("TextLabel")
	arrow.Name = "Arrow"
	arrow.BackgroundTransparency = 1
	arrow.Size = UDim2.fromScale(1, 1)
	arrow.Font = Enum.Font.GothamBlack
	arrow.TextScaled = true
	arrow.Text = "v"
	arrow.TextColor3 = FIGHTER_A_HEADER_TEXT
	arrow.TextStrokeTransparency = 0.45
	arrow.TextStrokeColor3 = Color3.fromRGB(12, 16, 22)
	arrow.Parent = billboard

	localPredictionMarkerGui = billboard
	return billboard
end

local function refreshLocalPredictionMarker()
	local currentRoundId = tonumber(player:GetAttribute("ArenaPredictionRoundId") or -1) or -1
	local currentPredictionSlot = tostring(player:GetAttribute("ArenaPredictionSlot") or "")
	local arenaRoundId = tonumber(arenaState:GetAttribute("RoundId") or -1) or -1
	local hasActivePredictionMarker = currentPredictionSlot ~= "" and currentRoundId == arenaRoundId
	local marker = ensureLocalPredictionMarker()

	if not hasActivePredictionMarker then
		marker.Enabled = false
		marker.Parent = nil
		localPredictionMarkerTarget = nil
		return
	end

	local targetPart = findArenaFighterPartForSlot(currentPredictionSlot)
	if not targetPart then
		marker.Enabled = false
		marker.Parent = nil
		localPredictionMarkerTarget = nil
		return
	end

	if localPredictionMarkerTarget ~= targetPart then
		marker.Parent = targetPart
		localPredictionMarkerTarget = targetPart
	end

	local arrow = marker:FindFirstChild("Arrow") :: TextLabel
	if currentPredictionSlot == "A" then
		arrow.TextColor3 = FIGHTER_A_HEADER_TEXT
	else
		arrow.TextColor3 = FIGHTER_B_HEADER_TEXT
	end
	marker.Enabled = true
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
			local fighterAId = tostring(arenaState:GetAttribute("FighterAId") or "")
			local fighterBId = tostring(arenaState:GetAttribute("FighterBId") or "")
			local fighterAPower = tonumber(arenaState:GetAttribute("FighterAPower") or 0) or 0
			local fighterASpeed = tonumber(arenaState:GetAttribute("FighterASpeed") or 0) or 0
			local fighterAToughness = tonumber(arenaState:GetAttribute("FighterAToughness") or 0) or 0
			local fighterARecord = tostring(arenaState:GetAttribute("FighterARecord") or "0-0")
			local fighterAWinChance = tonumber(arenaState:GetAttribute("FighterAWinChance") or 50) or 50
			local fighterAPowerUpgradeCost = tonumber(arenaState:GetAttribute("FighterAPowerUpgradeCost") or 0) or 0
			local fighterBPower = tonumber(arenaState:GetAttribute("FighterBPower") or 0) or 0
			local fighterBSpeed = tonumber(arenaState:GetAttribute("FighterBSpeed") or 0) or 0
			local fighterBToughness = tonumber(arenaState:GetAttribute("FighterBToughness") or 0) or 0
			local fighterBRecord = tostring(arenaState:GetAttribute("FighterBRecord") or "0-0")
			local fighterBWinChance = tonumber(arenaState:GetAttribute("FighterBWinChance") or 50) or 50
			local fighterBPowerUpgradeCost = tonumber(arenaState:GetAttribute("FighterBPowerUpgradeCost") or 0) or 0
			local winnerName = tostring(arenaState:GetAttribute("LastResult") or "")
			local currentWinnerName = tostring(arenaState:GetAttribute("WinnerName") or "")
			local timeRemaining = tonumber(arenaState:GetAttribute("TimeRemaining") or 0) or 0
			local predictionOpen = arenaState:GetAttribute("PredictionOpen") == true
			local scrap = getPlayerScrap()
			local currentPredictionRoundId = tonumber(player:GetAttribute("ArenaPredictionRoundId") or -1) or -1
			local currentPredictionSlot = tostring(player:GetAttribute("ArenaPredictionSlot") or "")
			local alreadyPredicted = currentPredictionRoundId == roundId and currentPredictionSlot ~= ""
			local predictionLocked = player:GetAttribute("ArenaPredictionLocked") == true and currentPredictionRoundId == roundId
			local statusLabel = views.status :: TextLabel
			local timerLabel = views.timer :: TextLabel
			local fighterAStatsCard = views.fighterAStats :: Frame
			local fighterBStatsCard = views.fighterBStats :: Frame
			local winnerLabel = views.winner :: TextLabel
			local resultLabel = views.result :: TextLabel

			setInfoLine(statusLabel, "Status:", getPhaseDisplayText(phase))
			setInfoLine(timerLabel, "Time Remaining:", ("%ds"):format(math.max(0, math.floor(timeRemaining))))
			setFighterStatCard(
				fighterAStatsCard,
				fighterAName,
				"Fighter A",
				fighterAStyle,
				fighterARecord,
				fighterAWinChance,
				fighterAPower,
				fighterASpeed,
				fighterAToughness
			)
			setFighterStatCard(
				fighterBStatsCard,
				fighterBName,
				"Fighter B",
				fighterBStyle,
				fighterBRecord,
				fighterBWinChance,
				fighterBPower,
				fighterBSpeed,
				fighterBToughness
			)
			local winnerInfoText = getArenaWinnerInfoText(phase, winnerName, currentWinnerName, fighterAName, fighterBName)
			winnerLabel.Text = winnerInfoText
			winnerLabel.TextColor3 = getArenaWinnerInfoColor(phase)
			resultLabel.Text = ""
			resultLabel.Visible = false
			local upgradeA = views.upgradeA :: TextButton
			local upgradeB = views.upgradeB :: TextButton
			local predictA = views.predictA :: TextButton
			local predictB = views.predictB :: TextButton
			local spectate = views.spectate :: TextButton
			local isFightLocked = phase == "FightActive" or phase == "Result" or predictionLocked
			local upgradesAvailable = phase ~= "FightActive" and phase ~= "Result"

			setCompactUpgradeButtonState(
				upgradeA,
				fighterAId,
				fighterAPowerUpgradeCost,
				scrap,
				upgradesAvailable
			)
			setCompactUpgradeButtonState(
				upgradeB,
				fighterBId,
				fighterBPowerUpgradeCost,
				scrap,
				upgradesAvailable
			)

			if phase == "Intermission" or phase == "Introductions" then
				setPredictionButtonState(predictA, "A", fighterAName, "Fighter A", "opens_soon")
				setPredictionButtonState(predictB, "B", fighterBName, "Fighter B", "opens_soon")
			elseif predictionOpen and not alreadyPredicted then
				setPredictionButtonState(predictA, "A", fighterAName, "Fighter A", "available")
				setPredictionButtonState(predictB, "B", fighterBName, "Fighter B", "available")
			elseif alreadyPredicted and not isFightLocked then
				setPredictionButtonState(
					predictA,
					"A",
					fighterAName,
					"Fighter A",
					if currentPredictionSlot == "A" then "selected" else "submitted_other"
				)
				setPredictionButtonState(
					predictB,
					"B",
					fighterBName,
					"Fighter B",
					if currentPredictionSlot == "B" then "selected" else "submitted_other"
				)
			elseif phase == "Result" then
				setPredictionButtonState(
					predictA,
					"A",
					fighterAName,
					"Fighter A",
					if alreadyPredicted and currentPredictionSlot == "A" then "result_selected" else "result"
				)
				setPredictionButtonState(
					predictB,
					"B",
					fighterBName,
					"Fighter B",
					if alreadyPredicted and currentPredictionSlot == "B" then "result_selected" else "result"
				)
			else
				setPredictionButtonState(
					predictA,
					"A",
					fighterAName,
					"Fighter A",
					if alreadyPredicted and currentPredictionSlot == "A" then "locked_selected" else "locked"
				)
				setPredictionButtonState(
					predictB,
					"B",
					fighterBName,
					"Fighter B",
					if alreadyPredicted and currentPredictionSlot == "B" then "locked_selected" else "locked"
				)
			end

			spectate.Text = if isSpectating() then "Return To Player" else "Watch Fight"
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
			return buildPlaceholderBody(body, "No car chaos feed active yet. Future vehicle spectacle predictions can plug in here.")
		end,
		refresh = function() end,
	},
	{
		id = "drone_gauntlet",
		title = "Drone Gauntlet",
		buildBody = function(body)
			return buildPlaceholderBody(body, "No drone gauntlet feed active yet. Future drone-run predictions can plug in here.")
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
	bodyPadding.PaddingTop = UDim.new(0, 2)
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
		setCueSecondary("", cueSecondary.TextColor3)
		lastCuePresentationKey = ""
	elseif personalResultBanner.Visible and eventCue == "Winner" then
		cueBanner.Visible = false
		setCueSecondary("", cueSecondary.TextColor3)
	elseif countdownNumber > 0 then
		cueBanner.Visible = true
		applyCueBannerPresentation(tostring(countdownNumber), Color3.fromRGB(255, 212, 122), "", cueSecondary.TextColor3)
	elseif eventCue == "FightStart" then
		cueBanner.Visible = true
		applyCueBannerPresentation(
			("%s  |  FIGHT!"):format(eventType == "ArenaDuel" and "ARENA" or "EVENT"),
			Color3.fromRGB(255, 110, 92),
			"",
			cueSecondary.TextColor3
		)
	elseif eventCue == "Winner" and winnerName ~= "" then
		cueBanner.Visible = true
		applyCueBannerPresentation(("%s WINS"):format(winnerName), Color3.fromRGB(255, 212, 122), "", cueSecondary.TextColor3)
	elseif eventCue == "Introductions" then
		cueBanner.Visible = true
		applyCueBannerPresentation("MAIN EVENT", Color3.fromRGB(255, 212, 122), "", cueSecondary.TextColor3)
	else
		cueBanner.Visible = false
		setCueSecondary("", cueSecondary.TextColor3)
		lastCuePresentationKey = ""
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
	refreshPersonalResultBanner()
	refreshLocalPredictionMarker()
	refreshTutorialCue()
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
	local arenaUpgradeAButton = arenaViews.upgradeA :: TextButton
	local arenaUpgradeBButton = arenaViews.upgradeB :: TextButton
	local arenaPredictAButton = arenaViews.predictA :: TextButton
	local arenaPredictBButton = arenaViews.predictB :: TextButton
	local arenaSpectateButton = arenaViews.spectate :: TextButton

	connectButtonClick(arenaUpgradeAButton, function()
		local fighterId = tostring(arenaUpgradeAButton:GetAttribute("FighterId") or "")
		if fighterId ~= "" then
			upgradeFighterRemote:FireServer(fighterId, Constants.Arena.UpgradeStatKey)
		end
	end)

	connectButtonClick(arenaUpgradeBButton, function()
		local fighterId = tostring(arenaUpgradeBButton:GetAttribute("FighterId") or "")
		if fighterId ~= "" then
			upgradeFighterRemote:FireServer(fighterId, Constants.Arena.UpgradeStatKey)
		end
	end)

	connectButtonClick(arenaPredictAButton, function()
		predictWinnerRemote:FireServer("A")
	end)

	connectButtonClick(arenaPredictBButton, function()
		predictWinnerRemote:FireServer("B")
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
	"FighterAId",
	"FighterBId",
	"FighterAPower",
	"FighterASpeed",
	"FighterAToughness",
	"FighterARecord",
	"FighterAWinChance",
	"FighterAPowerUpgradeCost",
	"FighterBPower",
	"FighterBSpeed",
	"FighterBToughness",
	"FighterBRecord",
	"FighterBWinChance",
	"FighterBPowerUpgradeCost",
	"TimeRemaining",
	"WinnerName",
	"LastResult",
	"PredictionOpen",
	"DisplayHeadline",
	"DisplayDetail",
	"EventCue",
	"CountdownNumber",
	"EventType",
}) do
	arenaState:GetAttributeChangedSignal(attr):Connect(refreshAll)
end

for _, attr in ipairs({
	"ArenaPredictionRoundId",
	"ArenaPredictionSlot",
	"ArenaPredictionLocked",
	"ArenaPredictionRewardGranted",
	"ArenaOutcome",
	"ArenaOutcomeRoundId",
	"ArenaOutcomeReward",
	"TutorialActive",
	"TutorialCompleted",
	"TutorialStep",
	"TutorialStepCount",
	"TutorialStepText",
}) do
	player:GetAttributeChangedSignal(attr):Connect(refreshAll)
end

playerGui:GetAttributeChangedSignal("ArenaSpectating"):Connect(refreshAll)
playerGui:GetAttributeChangedSignal("ArenaSpectateRequested"):Connect(refreshAll)

player:GetAttributeChangedSignal("ArenaOutcome"):Connect(function()
	refreshAll()
end)

local function bindCreditsRefresh()
	local leaderstats = player:FindFirstChild("leaderstats")
	local credits = leaderstats and leaderstats:FindFirstChild("Credits")
	if credits and credits:IsA("IntValue") then
		credits:GetPropertyChangedSignal("Value"):Connect(refreshAll)
	end
	local materials = leaderstats and (leaderstats:FindFirstChild("Materials") or leaderstats:FindFirstChild("Scrap"))
	if materials and materials:IsA("IntValue") then
		materials:GetPropertyChangedSignal("Value"):Connect(refreshAll)
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
