local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local player = Players.LocalPlayer
local playerGui = player:WaitForChild("PlayerGui")
local camera = Workspace.CurrentCamera
local arenaState = ReplicatedStorage:WaitForChild("ArenaState")

local gui = Instance.new("ScreenGui")
gui.Name = "ArenaSpectateGui"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local button = Instance.new("TextButton")
button.AnchorPoint = Vector2.new(0.5, 1)
button.Position = UDim2.new(0.5, 0, 1, -44)
button.Size = UDim2.fromOffset(180, 40)
button.BackgroundColor3 = Color3.fromRGB(34, 42, 58)
button.TextColor3 = Color3.fromRGB(244, 246, 249)
button.Font = Enum.Font.GothamBold
button.TextSize = 18
button.BorderSizePixel = 0
button.Visible = false
button.Parent = gui

local watching = false
local renderConnection: RBXScriptConnection? = nil

local function isNearArena(): boolean
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	local arenaPosition = arenaState:GetAttribute("ArenaPosition")
	if not (root and root:IsA("BasePart") and typeof(arenaPosition) == "Vector3") then
		return false
	end

	return (root.Position - arenaPosition).Magnitude <= Constants.Arena.SpectateDistance
end

local function stopSpectating()
	watching = false
	button.Text = "Watch Fight"
	if renderConnection then
		renderConnection:Disconnect()
		renderConnection = nil
	end
	camera.CameraType = Enum.CameraType.Custom
end

local function startSpectating()
	watching = true
	button.Text = "Return To Player"
	camera.CameraType = Enum.CameraType.Scriptable

	if renderConnection then
		renderConnection:Disconnect()
	end

	renderConnection = RunService.RenderStepped:Connect(function()
		local anchorPosition = arenaState:GetAttribute("CameraAnchorPosition")
		local focusPosition = arenaState:GetAttribute("FightCenter")
		if typeof(focusPosition) ~= "Vector3" then
			focusPosition = arenaState:GetAttribute("FocusPosition")
		end
		if typeof(anchorPosition) ~= "Vector3" or typeof(focusPosition) ~= "Vector3" then
			return
		end
		camera.CFrame = CFrame.lookAt(anchorPosition, focusPosition)
	end)
end

local function refresh()
	local phase = tostring(arenaState:GetAttribute("Phase") or "")
	local active = arenaState:GetAttribute("IsArenaActive") == true
	local canWatch = active and phase == "FightActive" and isNearArena()
	button.Visible = canWatch or watching
	if not canWatch and watching then
		stopSpectating()
	end
	if not watching then
		button.Text = "Watch Fight"
	end
end

button.Activated:Connect(function()
	if watching then
		stopSpectating()
	else
		startSpectating()
	end
	refresh()
end)

player.CharacterAdded:Connect(function()
	task.defer(refresh)
	stopSpectating()
end)

for _, attr in ipairs({"Phase", "IsArenaActive", "ArenaPosition", "CameraAnchorPosition", "FightCenter"}) do
	arenaState:GetAttributeChangedSignal(attr):Connect(refresh)
end

task.spawn(function()
	while true do
		task.wait(0.25)
		refresh()
	end
end)

refresh()
