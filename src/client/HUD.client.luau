local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local TweenService = game:GetService("TweenService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Net = require(Shared:WaitForChild("Net"))
local SoundLimiter = require(script.Parent:WaitForChild("SoundLimiter"))

local heatUpdatedRemote = Net.GetRemoteEvent(Constants.Remotes.HeatUpdated)
local toastRemote = Net.GetRemoteEvent(Constants.Remotes.Toast)
local rewardUpgradeRemote = Net.GetRemoteEvent(Constants.Remotes.ArenaUpgradeRewardMultiplier)

local gui = Instance.new("ScreenGui")
gui.Name = "MainHudGui"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local panel = Instance.new("Frame")
panel.Size = UDim2.fromOffset(290, 258)
panel.Position = UDim2.fromOffset(18, 18)
panel.BackgroundColor3 = Color3.fromRGB(20, 20, 26)
panel.BackgroundTransparency = 0.12
panel.BorderSizePixel = 0
panel.Parent = gui

local panelStroke = Instance.new("UIStroke")
panelStroke.Thickness = 2
panelStroke.Color = Color3.fromRGB(233, 184, 91)
panelStroke.Parent = panel

local uiList = Instance.new("UIListLayout")
uiList.Padding = UDim.new(0, 6)
uiList.Parent = panel

local uiPadding = Instance.new("UIPadding")
uiPadding.PaddingLeft = UDim.new(0, 10)
uiPadding.PaddingTop = UDim.new(0, 10)
uiPadding.PaddingRight = UDim.new(0, 10)
uiPadding.PaddingBottom = UDim.new(0, 10)
uiPadding.Parent = panel

local function makeLabel(initialText: string): TextLabel
	local label = Instance.new("TextLabel")
	label.Size = UDim2.new(1, -20, 0, 24)
	label.BackgroundTransparency = 1
	label.TextXAlignment = Enum.TextXAlignment.Left
	label.TextColor3 = Color3.fromRGB(228, 235, 243)
	label.Font = Enum.Font.GothamBold
	label.TextSize = 16
	label.Text = initialText
	label.Parent = panel
	return label
end

local creditsLabel = makeLabel("Credits: 0")
local materialsLabel = makeLabel("Materials: 0")
local multiplierLabel = makeLabel("Rewards: x1.0")
multiplierLabel.TextColor3 = Color3.fromRGB(220, 228, 236)

local nextRewardLabel = makeLabel("Next: x1.1")
nextRewardLabel.TextColor3 = Color3.fromRGB(188, 201, 214)
nextRewardLabel.Font = Enum.Font.GothamSemibold
nextRewardLabel.TextSize = 14

local rewardUpgradeButton = Instance.new("TextButton")
rewardUpgradeButton.Size = UDim2.new(1, -20, 0, 24)
rewardUpgradeButton.BackgroundColor3 = Color3.fromRGB(110, 122, 82)
rewardUpgradeButton.BackgroundTransparency = 0.04
rewardUpgradeButton.BorderSizePixel = 0
rewardUpgradeButton.TextColor3 = Color3.fromRGB(240, 244, 236)
rewardUpgradeButton.Font = Enum.Font.GothamBold
rewardUpgradeButton.TextSize = 14
rewardUpgradeButton.Text = "Upgrade Rewards"
rewardUpgradeButton.Parent = panel

local rewardUpgradeStroke = Instance.new("UIStroke")
rewardUpgradeStroke.Thickness = 1
rewardUpgradeStroke.Color = Color3.fromRGB(246, 220, 150)
rewardUpgradeStroke.Transparency = 0.2
rewardUpgradeStroke.Parent = rewardUpgradeButton

local heatLabel = makeLabel("Heat: 0")
local districtHeatLabel = makeLabel("District Heat: 0")
local threatLabel = makeLabel("Threat: 0")

local toastLabel = Instance.new("TextLabel")
toastLabel.Size = UDim2.fromOffset(360, 38)
toastLabel.Position = UDim2.fromScale(0.5, 0.18)
toastLabel.AnchorPoint = Vector2.new(0.5, 0.5)
toastLabel.BackgroundColor3 = Color3.fromRGB(25, 35, 25)
toastLabel.BackgroundTransparency = 0.25
toastLabel.TextColor3 = Color3.fromRGB(210, 255, 210)
toastLabel.Font = Enum.Font.GothamBold
toastLabel.TextScaled = true
toastLabel.Visible = false
toastLabel.Parent = gui

local pulseOverlay = Instance.new("Frame")
pulseOverlay.Size = UDim2.fromScale(1, 1)
pulseOverlay.BackgroundColor3 = Color3.fromRGB(220, 40, 40)
pulseOverlay.BackgroundTransparency = 1
pulseOverlay.BorderSizePixel = 0
pulseOverlay.ZIndex = 10
pulseOverlay.Parent = gui

local pickupPopLabel = Instance.new("TextLabel")
pickupPopLabel.Size = UDim2.fromOffset(220, 28)
pickupPopLabel.Position = UDim2.fromOffset(20, 120)
pickupPopLabel.BackgroundTransparency = 1
pickupPopLabel.TextXAlignment = Enum.TextXAlignment.Left
pickupPopLabel.Font = Enum.Font.GothamBold
pickupPopLabel.TextColor3 = Color3.fromRGB(130, 250, 190)
pickupPopLabel.TextSize = 24
pickupPopLabel.Text = ""
pickupPopLabel.Visible = false
pickupPopLabel.Parent = gui

local lastThreatLevel = 0
local pickupPopToken = 0

local function pulseScreen()
	if not Constants.Accessibility.ENABLE_SCREEN_PULSE then
		return
	end

	local fadeIn = TweenService:Create(pulseOverlay, TweenInfo.new(0.09, Enum.EasingStyle.Sine, Enum.EasingDirection.Out), {
		BackgroundTransparency = 0.92,
	})
	local fadeOut = TweenService:Create(pulseOverlay, TweenInfo.new(0.16, Enum.EasingStyle.Sine, Enum.EasingDirection.In), {
		BackgroundTransparency = 1,
	})
	fadeIn:Play()
	fadeIn.Completed:Connect(function()
		fadeOut:Play()
	end)
end

local function showPickupPop(amount: number)
	pickupPopToken += 1
	local current = pickupPopToken
	pickupPopLabel.Text = ("+%d Materials"):format(amount)
	pickupPopLabel.Visible = true
	task.delay(0.8, function()
		if current == pickupPopToken then
			pickupPopLabel.Visible = false
		end
	end)
end

local function wireLeaderstats()
	local leaderstats = player:WaitForChild("leaderstats")
	local credits = leaderstats:WaitForChild("Credits") :: IntValue
	local materials = leaderstats:WaitForChild("Materials") :: IntValue
	local lastMaterials = materials.Value

	local function refreshEconomy()
		creditsLabel.Text = ("Credits: %d"):format(credits.Value)
		materialsLabel.Text = ("Materials: %d"):format(materials.Value)

		if materials.Value > lastMaterials then
			local gained = materials.Value - lastMaterials
			showPickupPop(gained)
			SoundLimiter.Play2D("PICKUP", "rbxasset://sounds/action_get.wav", 0.18, 1.15)
		end
		lastMaterials = materials.Value
	end

	credits:GetPropertyChangedSignal("Value"):Connect(refreshEconomy)
	materials:GetPropertyChangedSignal("Value"):Connect(refreshEconomy)
	refreshEconomy()
end

wireLeaderstats()

local function refreshMultiplier()
	local level = math.max(0, math.floor(tonumber(player:GetAttribute("RewardUpgradeLevel") or 0) or 0))
	local multiplier = tonumber(player:GetAttribute("RewardMultiplier") or 1) or 1
	local nextCost = tonumber(player:GetAttribute("RewardUpgradeNextCost") or 0) or 0
	local nextMultiplier = Constants.Arena.RewardMultiplierByLevel[level + 1]
	multiplierLabel.Text = ("Rewards: x%.1f"):format(multiplier)
	if nextCost > 0 then
		nextRewardLabel.Text = ("Next: x%.1f"):format(nextMultiplier or multiplier)
		rewardUpgradeButton.Text = "Upgrade Rewards"
		rewardUpgradeButton.Active = true
		rewardUpgradeButton.AutoButtonColor = true
		rewardUpgradeButton.BackgroundTransparency = 0.04
		rewardUpgradeStroke.Transparency = 0.2
	else
		nextRewardLabel.Text = "Next: MAX"
		rewardUpgradeButton.Text = "Upgrade Rewards"
		rewardUpgradeButton.Active = false
		rewardUpgradeButton.AutoButtonColor = false
		rewardUpgradeButton.BackgroundTransparency = 0.26
		rewardUpgradeStroke.Transparency = 0.58
	end
end

player:GetAttributeChangedSignal("RewardMultiplier"):Connect(refreshMultiplier)
player:GetAttributeChangedSignal("RewardUpgradeLevel"):Connect(refreshMultiplier)
player:GetAttributeChangedSignal("RewardUpgradeNextCost"):Connect(refreshMultiplier)
rewardUpgradeButton.MouseButton1Click:Connect(function()
	rewardUpgradeRemote:FireServer()
end)
refreshMultiplier()

heatUpdatedRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end
	local playerHeat = math.clamp(payload.playerHeat or 0, 0, Constants.Heat.MaxPlayerHeat)
	local districtHeat = payload.districtHeat or 0
	local threatLevel = math.clamp(payload.threatLevel or 0, 0, Constants.Threat.MaxLevel)

	heatLabel.Text = ("Heat: %.1f"):format(playerHeat)
	districtHeatLabel.Text = ("District Heat: %.1f"):format(districtHeat)
	threatLabel.Text = ("Threat: %d"):format(threatLevel)

	if threatLevel > lastThreatLevel then
		pulseScreen()
		SoundLimiter.Play2D("THREAT_UP", "rbxasset://sounds/electronicpingshort.wav", 0.24, 0.92)
	end
	lastThreatLevel = threatLevel
end)

local toastToken = 0
toastRemote.OnClientEvent:Connect(function(message: string)
	toastToken += 1
	local current = toastToken
	toastLabel.Text = message
	toastLabel.Visible = true
	task.delay(2, function()
		if current == toastToken then
			toastLabel.Visible = false
		end
	end)
end)

print("[HUD] Ready")
