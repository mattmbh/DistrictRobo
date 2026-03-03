local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

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
label.Size = UDim2.fromOffset(240, 30)
label.Position = UDim2.fromScale(0.5, 0.03)
label.AnchorPoint = Vector2.new(0.5, 0.5)
label.BackgroundColor3 = Color3.fromRGB(20, 20, 20)
label.BackgroundTransparency = 0.5
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

local function enforceDaySky()
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Sky") then
			child:Destroy()
		end
	end
end

local function applyBaseLighting()
	Lighting.ClockTime = 13.5
	Lighting.Brightness = 2.5
	Lighting.ExposureCompensation = 0.3
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(120, 120, 125)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 155)

	colorCorrection.TintColor = Color3.fromRGB(255, 255, 255)
	colorCorrection.Saturation = -0.05
	colorCorrection.Contrast = 0.05
	colorCorrection.Brightness = 0.02

	bloom.Intensity = 0.12
	bloom.Size = 14

	atmosphere.Density = 0.18
	atmosphere.Offset = 0
	atmosphere.Color = Color3.fromRGB(210, 205, 195)
	atmosphere.Decay = Color3.fromRGB(235, 215, 190)
	atmosphere.Glare = 0.05
	atmosphere.Haze = 0.45
end

districtChangedRemote.OnClientEvent:Connect(function(newDistrict: string)
	print(("[DistrictVibe] District changed -> %s"):format(newDistrict))
	if newDistrict == Constants.Districts.DANGEROUS then
		label.Text = "DANGEROUS DISTRICT"
		label.TextColor3 = Color3.fromRGB(255, 130, 130)
	else
		label.Text = "SAFE DISTRICT"
		label.TextColor3 = Color3.fromRGB(230, 255, 235)
	end
	applyBaseLighting()
end)

label.Text = "SAFE DISTRICT"
label.TextColor3 = Color3.fromRGB(230, 255, 235)
enforceDaySky()
applyBaseLighting()
print("[DistrictVibe] Ready")
