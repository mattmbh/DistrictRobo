local Lighting = game:GetService("Lighting")
local Players = game:GetService("Players")

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")

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

local sunRays = Lighting:FindFirstChildOfClass("SunRaysEffect")

local function enforceDaySky()
	for _, child in ipairs(Lighting:GetChildren()) do
		if child:IsA("Sky") then
			child:Destroy()
		end
	end
end

local function applyBaseLighting()
	Lighting.ClockTime = 13.5
	Lighting.Brightness = 2.1
	Lighting.ExposureCompensation = 0.08
	Lighting.GlobalShadows = true
	Lighting.Ambient = Color3.fromRGB(120, 120, 125)
	Lighting.OutdoorAmbient = Color3.fromRGB(150, 150, 155)

	colorCorrection.TintColor = Color3.fromRGB(255, 255, 255)
	colorCorrection.Saturation = -0.03
	colorCorrection.Contrast = 0.02
	colorCorrection.Brightness = 0

	bloom.Intensity = 0.02
	bloom.Size = 10

	atmosphere.Density = 0.18
	atmosphere.Offset = 0
	atmosphere.Color = Color3.fromRGB(210, 205, 195)
	atmosphere.Decay = Color3.fromRGB(235, 215, 190)
	atmosphere.Glare = 0.05
	atmosphere.Haze = 0.45

	-- Safety clamp: keep post FX subtle so highlights/avatars do not bloom or wash out.
	bloom.Intensity = math.min(bloom.Intensity, 0.02)
	bloom.Size = math.min(bloom.Size, 10)
	colorCorrection.Contrast = math.clamp(colorCorrection.Contrast, -0.05, 0.05)
	colorCorrection.Brightness = math.clamp(colorCorrection.Brightness, -0.02, 0.02)
	if sunRays then
		sunRays.Intensity = math.min(sunRays.Intensity, 0.04)
	end
	print("[DistrictVibe] Post FX clamp applied for highlight safety")
end

local function applyDangerLighting(inDanger: boolean)
	if inDanger then
		colorCorrection.TintColor = Color3.fromRGB(255, 232, 232)
		colorCorrection.Saturation = -0.06
		colorCorrection.Contrast = 0.05
		colorCorrection.Brightness = -0.005
		atmosphere.Color = Color3.fromRGB(205, 190, 190)
		atmosphere.Decay = Color3.fromRGB(220, 188, 188)
	else
		colorCorrection.TintColor = Color3.fromRGB(255, 255, 255)
		colorCorrection.Saturation = -0.03
		colorCorrection.Contrast = 0.02
		colorCorrection.Brightness = 0
		atmosphere.Color = Color3.fromRGB(210, 205, 195)
		atmosphere.Decay = Color3.fromRGB(235, 215, 190)
	end

	bloom.Intensity = math.min(bloom.Intensity, 0.02)
	bloom.Size = math.min(bloom.Size, 10)
end

local function refreshDistrictVibe()
	local districtName = tostring(player:GetAttribute("DistrictId") or "SAFE DISTRICT")
	local inDanger = player:GetAttribute("InDangerDistrict") == true
	label.Text = districtName:upper()
	label.TextColor3 = inDanger and Color3.fromRGB(236, 156, 156) or Color3.fromRGB(230, 255, 235)
	applyDangerLighting(inDanger)
end

label.Text = "SAFE DISTRICT"
label.TextColor3 = Color3.fromRGB(230, 255, 235)
enforceDaySky()
applyBaseLighting()
refreshDistrictVibe()
player:GetAttributeChangedSignal("DistrictId"):Connect(refreshDistrictVibe)
player:GetAttributeChangedSignal("InDangerDistrict"):Connect(refreshDistrictVibe)
print("[DistrictVibe] Ready")
