local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Net = require(Shared:WaitForChild("Net"))

local arenaState = ReplicatedStorage:WaitForChild("ArenaState")
local placeBetRemote = Net.GetRemoteEvent(Constants.Remotes.ArenaPlaceBet)

local gui = Instance.new("ScreenGui")
gui.Name = "ArenaUi"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.AnchorPoint = Vector2.new(1, 0)
panel.Position = UDim2.new(1, -22, 0, 20)
panel.Size = UDim2.fromOffset(340, 250)
panel.BackgroundColor3 = Color3.fromRGB(14, 18, 26)
panel.BackgroundTransparency = 0.1
panel.BorderSizePixel = 0
panel.Visible = false
panel.Parent = gui

local stroke = Instance.new("UIStroke")
stroke.Thickness = 2
stroke.Color = Color3.fromRGB(243, 186, 87)
stroke.Parent = panel

local pad = Instance.new("UIPadding")
pad.PaddingLeft = UDim.new(0, 14)
pad.PaddingRight = UDim.new(0, 14)
pad.PaddingTop = UDim.new(0, 12)
pad.PaddingBottom = UDim.new(0, 12)
pad.Parent = panel

local layout = Instance.new("UIListLayout")
layout.Padding = UDim.new(0, 8)
layout.Parent = panel

local function makeLabel(height: number, font: Enum.Font, size: number, color: Color3): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, 0, 0, height)
	label.BackgroundTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.Font = font
	label.TextSize = size
	label.TextColor3 = color
	label.Parent = panel
	return label
end

local titleLabel = makeLabel(26, Enum.Font.GothamBlack, 22, Color3.fromRGB(255, 208, 116))
local phaseLabel = makeLabel(22, Enum.Font.GothamBold, 18, Color3.fromRGB(231, 236, 244))
local creditsLabel = makeLabel(20, Enum.Font.GothamSemibold, 16, Color3.fromRGB(184, 198, 214))
local fighterALabel = makeLabel(20, Enum.Font.GothamBold, 18, Color3.fromRGB(244, 139, 129))
local fighterBLabel = makeLabel(20, Enum.Font.GothamBold, 18, Color3.fromRGB(134, 180, 255))
local statusLabel = makeLabel(36, Enum.Font.GothamSemibold, 16, Color3.fromRGB(214, 219, 228))
statusLabel.TextWrapped = true

local buttonRow = Instance.new("Frame")
buttonRow.Size = UDim2.new(1, 0, 0, 54)
buttonRow.BackgroundTransparency = 1
buttonRow.Parent = panel

local grid = Instance.new("UIGridLayout")
grid.CellSize = UDim2.new(0.48, 0, 1, 0)
grid.CellPadding = UDim2.new(0.04, 0, 0, 0)
grid.Parent = buttonRow

local function makeButton(text: string, color: Color3): TextButton
	local button = Instance.new("TextButton")
	button.AutoButtonColor = true
	button.Text = text
	button.Font = Enum.Font.GothamBold
	button.TextSize = 17
	button.TextColor3 = Color3.fromRGB(255, 255, 255)
	button.BackgroundColor3 = color
	button.BorderSizePixel = 0
	button.Parent = buttonRow
	return button
end

local betAButton = makeButton("Bet On A", Color3.fromRGB(170, 78, 78))
local betBButton = makeButton("Bet On B", Color3.fromRGB(73, 112, 186))

local function getCreditsValue(): IntValue?
	local leaderstats = player:FindFirstChild("leaderstats")
	local credits = leaderstats and leaderstats:FindFirstChild("Credits")
	if credits and credits:IsA("IntValue") then
		return credits
	end
	return nil
end

local function getPlayerBetRoundId(): number
	return tonumber(player:GetAttribute("ArenaBetRoundId") or -1) or -1
end

local function getPlayerBetSlot(): string
	return tostring(player:GetAttribute("ArenaBetSlot") or "")
end

local function getOutcomeText(currentRoundId: number): string
	local outcomeRoundId = tonumber(player:GetAttribute("ArenaOutcomeRoundId") or -1) or -1
	if outcomeRoundId ~= currentRoundId then
		return ""
	end

	local outcome = tostring(player:GetAttribute("ArenaOutcome") or "")
	if outcome == "Won" then
		return "You won your bet."
	elseif outcome == "Lost" then
		return "You lost this round."
	elseif outcome == "Refunded" then
		return "Bet refunded on draw."
	end
	return ""
end

local function refresh()
	local phase = tostring(arenaState:GetAttribute("Phase") or "Intermission")
	local roundId = tonumber(arenaState:GetAttribute("RoundId") or 0) or 0
	local fighterAName = tostring(arenaState:GetAttribute("FighterAName") or "Fighter A")
	local fighterBName = tostring(arenaState:GetAttribute("FighterBName") or "Fighter B")
	local fighterAStyle = tostring(arenaState:GetAttribute("FighterAStyle") or "")
	local fighterBStyle = tostring(arenaState:GetAttribute("FighterBStyle") or "")
	local countdown = tonumber(arenaState:GetAttribute("TimeRemaining") or 0) or 0
	local winnerName = tostring(arenaState:GetAttribute("WinnerName") or "")
	local bettingOpen = arenaState:GetAttribute("BettingOpen") == true
	local credits = getCreditsValue()
	local playerBetRoundId = getPlayerBetRoundId()
	local playerBetSlot = getPlayerBetSlot()
	local alreadyBet = playerBetRoundId == roundId and playerBetSlot ~= ""
	local show = phase == "BetWindow" or phase == "FightActive" or phase == "Result"

	panel.Visible = show
	if not show then
		return
	end

	titleLabel.Text = "ROBO DISTRICT ARENA"
	phaseLabel.Text = ("%s  |  %ds"):format(phase:upper(), math.max(0, math.floor(countdown)))
	creditsLabel.Text = ("Credits: %d  |  Bet Size: %d"):format(if credits then credits.Value else 0, Constants.Arena.DefaultBetAmount)
	fighterALabel.Text = ("A  %s  [%s]"):format(fighterAName, fighterAStyle)
	fighterBLabel.Text = ("B  %s  [%s]"):format(fighterBName, fighterBStyle)

	if phase == "BetWindow" then
		statusLabel.Text = if alreadyBet
			then ("Bet locked: Fighter %s"):format(playerBetSlot)
			else "Choose one fighter before the window closes."
	elseif phase == "FightActive" then
		statusLabel.Text = if alreadyBet
			then ("Bet placed on Fighter %s. Fight live now."):format(playerBetSlot)
			else "Fight in progress. Betting is closed."
	else
		local outcomeText = getOutcomeText(roundId)
		statusLabel.Text = if outcomeText ~= ""
			then ("%s Winner: %s"):format(outcomeText, winnerName)
			else ("Winner: %s"):format(winnerName ~= "" and winnerName or "Pending")
	end

	local buttonsEnabled = bettingOpen and not alreadyBet
	betAButton.Active = buttonsEnabled
	betBButton.Active = buttonsEnabled
	betAButton.AutoButtonColor = buttonsEnabled
	betBButton.AutoButtonColor = buttonsEnabled
	betAButton.BackgroundTransparency = if buttonsEnabled then 0 else 0.45
	betBButton.BackgroundTransparency = if buttonsEnabled then 0 else 0.45
	betAButton.Text = if alreadyBet and playerBetSlot == "A" then "Bet Locked On A" else "Bet On A"
	betBButton.Text = if alreadyBet and playerBetSlot == "B" then "Bet Locked On B" else "Bet On B"
end

betAButton.Activated:Connect(function()
	placeBetRemote:FireServer("A", Constants.Arena.DefaultBetAmount)
end)

betBButton.Activated:Connect(function()
	placeBetRemote:FireServer("B", Constants.Arena.DefaultBetAmount)
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
	"BettingOpen",
}) do
	arenaState:GetAttributeChangedSignal(attr):Connect(refresh)
end

for _, attr in ipairs({"ArenaBetRoundId", "ArenaBetSlot", "ArenaOutcome", "ArenaOutcomeRoundId"}) do
	player:GetAttributeChangedSignal(attr):Connect(refresh)
end

local creditsValue = getCreditsValue()
if creditsValue then
	creditsValue:GetPropertyChangedSignal("Value"):Connect(refresh)
else
	player.ChildAdded:Connect(function(child)
		if child.Name == "leaderstats" then
			task.defer(refresh)
		end
	end)
end

refresh()
