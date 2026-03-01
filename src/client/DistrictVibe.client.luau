local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Net = require(Shared:WaitForChild("Net"))

local districtChangedRemote = Net.GetRemoteEvent(Constants.Remotes.DistrictChanged)

local gui = Instance.new("ScreenGui")
gui.Name = "DistrictVibeGui"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local label = Instance.new("TextLabel")
label.Size = UDim2.fromOffset(300, 44)
label.Position = UDim2.fromScale(0.5, 0.08)
label.AnchorPoint = Vector2.new(0.5, 0.5)
label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
label.BackgroundTransparency = 0.35
label.TextColor3 = Color3.fromRGB(240, 240, 240)
label.TextScaled = true
label.Font = Enum.Font.GothamBold
label.Text = "SAFE DISTRICT"
label.Parent = gui

local colorCorrection = Lighting:FindFirstChild("DistrictColorCorrection")
if not (colorCorrection and colorCorrection:IsA("ColorCorrectionEffect")) then
	colorCorrection = Instance.new("ColorCorrectionEffect")
	colorCorrection.Name = "DistrictColorCorrection"
	colorCorrection.Parent = Lighting
end

local bloom = Lighting:FindFirstChild("DistrictBloom")
if not (bloom and bloom:IsA("BloomEffect")) then
	bloom = Instance.new("BloomEffect")
	bloom.Name = "DistrictBloom"
	bloom.Parent = Lighting
end

local atmosphere = Lighting:FindFirstChild("DistrictAtmosphere")
if not (atmosphere and atmosphere:IsA("Atmosphere")) then
	atmosphere = Instance.new("Atmosphere")
	atmosphere.Name = "DistrictAtmosphere"
	atmosphere.Parent = Lighting
end

local currentDistrict = Constants.Districts.SAFE
local sirenTime = 0

local function applySafeVibe()
	currentDistrict = Constants.Districts.SAFE
	label.Text = "SAFE DISTRICT"
	label.TextColor3 = Color3.fromRGB(230, 255, 235)
	colorCorrection.TintColor = Color3.fromRGB(255, 255, 255)
	colorCorrection.Saturation = 0
	colorCorrection.Contrast = 0
	bloom.Intensity = 0.2
	bloom.Size = 18
	atmosphere.Density = 0.2
	atmosphere.Color = Color3.fromRGB(199, 214, 255)
end

local function applyDangerVibe()
	currentDistrict = Constants.Districts.DANGEROUS
	label.Text = "DANGEROUS DISTRICT"
	label.TextColor3 = Color3.fromRGB(255, 130, 130)
	colorCorrection.Saturation = -0.15
	colorCorrection.Contrast = 0.08
	bloom.Intensity = 0.55
	bloom.Size = 26
	atmosphere.Density = 0.45
	atmosphere.Color = Color3.fromRGB(150, 80, 80)
end

districtChangedRemote.OnClientEvent:Connect(function(newDistrict: string)
	print(("[DistrictVibe] District changed -> %s"):format(newDistrict))
	if newDistrict == Constants.Districts.DANGEROUS then
		applyDangerVibe()
	else
		applySafeVibe()
	end
end)

RunService.RenderStepped:Connect(function(deltaTime)
	if currentDistrict == Constants.Districts.DANGEROUS then
		sirenTime += deltaTime
		local pulse = (math.sin(sirenTime * 2.5) + 1) * 0.5
		colorCorrection.TintColor = Color3.fromRGB(
			255,
			math.floor(130 - (pulse * 50)),
			math.floor(130 - (pulse * 50))
		)
	end
end)

applySafeVibe()
print("[DistrictVibe] Ready")
