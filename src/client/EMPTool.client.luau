local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Net = require(Shared:WaitForChild("Net"))
local SoundLimiter = require(script.Parent:WaitForChild("SoundLimiter"))

local empFiredRemote = Net.GetRemoteEvent(Constants.Remotes.EMPFired)
local TOOL_NAME = "EMP Slingshot"

local equippedConnection: RBXScriptConnection? = nil
local unequippedConnection: RBXScriptConnection? = nil
local charging = false
local chargeStart = 0
local equipped = false

local gui = Instance.new("ScreenGui")
gui.Name = "EMPChargeGui"
gui.ResetOnSpawn = false
gui.Parent = playerGui

local barBackground = Instance.new("Frame")
barBackground.Size = UDim2.fromOffset(220, 16)
barBackground.Position = UDim2.fromScale(0.5, 0.92)
barBackground.AnchorPoint = Vector2.new(0.5, 0.5)
barBackground.BackgroundColor3 = Color3.fromRGB(30, 30, 30)
barBackground.BorderSizePixel = 0
barBackground.Visible = false
barBackground.Parent = gui

local barFill = Instance.new("Frame")
barFill.Size = UDim2.fromScale(0, 1)
barFill.BackgroundColor3 = Color3.fromRGB(70, 220, 255)
barFill.BorderSizePixel = 0
barFill.Parent = barBackground

local function findTool(): Tool?
	local backpack = player:WaitForChild("Backpack")
	local candidate = backpack:FindFirstChild(TOOL_NAME)
	if candidate and candidate:IsA("Tool") then
		return candidate
	end

	local character = player.Character
	if character then
		local equippedTool = character:FindFirstChild(TOOL_NAME)
		if equippedTool and equippedTool:IsA("Tool") then
			return equippedTool
		end
	end

	return nil
end

local function getRootPart(): BasePart?
	local character = player.Character
	if not character then
		return nil
	end
	local rootPart = character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		return rootPart
	end
	return nil
end

local function fireEMP(charge01: number)
	local rootPart = getRootPart()
	if not rootPart then
		return
	end
	local origin = rootPart.Position
	local direction = mouse.Hit.Position - origin
	if direction.Magnitude < 0.001 then
		direction = rootPart.CFrame.LookVector
	else
		direction = direction.Unit
	end

	empFiredRemote:FireServer(origin, direction, charge01)
	print(("[EMPTool] EMP Fired charge=%.2f"):format(charge01))
	if charge01 >= 0.65 then
		SoundLimiter.Play2D("EMP_BIG", "rbxasset://sounds/electronicpingshort.wav", 0.22, 0.8)
	end
end

local function bindTool(tool: Tool)
	if equippedConnection then
		equippedConnection:Disconnect()
		equippedConnection = nil
	end
	if unequippedConnection then
		unequippedConnection:Disconnect()
		unequippedConnection = nil
	end

	equippedConnection = tool.Equipped:Connect(function()
		equipped = true
		barBackground.Visible = true
		print("[EMPTool] Equipped")
	end)

	unequippedConnection = tool.Unequipped:Connect(function()
		equipped = false
		charging = false
		barBackground.Visible = false
		barFill.Size = UDim2.fromScale(0, 1)
	end)
end

UserInputService.InputBegan:Connect(function(input, gameProcessed)
	if gameProcessed or not equipped then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 then
		charging = true
		chargeStart = time()
		print("[EMPTool] Charge start")
	end
end)

UserInputService.InputEnded:Connect(function(input, gameProcessed)
	if gameProcessed or not equipped then
		return
	end
	if input.UserInputType == Enum.UserInputType.MouseButton1 and charging then
		charging = false
		local elapsed = time() - chargeStart
		local charge01 = math.clamp(elapsed / Constants.EMP.CHARGE_TIME, 0, 1)
		fireEMP(charge01)
		barFill.Size = UDim2.fromScale(0, 1)
	end
end)

RunService.RenderStepped:Connect(function()
	if charging then
		local elapsed = time() - chargeStart
		local alpha = math.clamp(elapsed / Constants.EMP.CHARGE_TIME, 0, 1)
		barFill.Size = UDim2.fromScale(alpha, 1)
	end
end)

player.CharacterAdded:Connect(function()
	task.delay(0.4, function()
		local tool = findTool()
		if tool then
			bindTool(tool)
		end
	end)
end)

local backpack = player:WaitForChild("Backpack")
backpack.ChildAdded:Connect(function(child)
	if child:IsA("Tool") and child.Name == TOOL_NAME then
		bindTool(child)
	end
end)

local initialTool = findTool()
if initialTool then
	bindTool(initialTool)
end

print("[EMPTool] Ready")
