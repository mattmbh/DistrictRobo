local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local UserInputService = game:GetService("UserInputService")
local Workspace = game:GetService("Workspace")

local player = Players.LocalPlayer
local mouse = player:GetMouse()
local playerGui = player:WaitForChild("PlayerGui")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Net = require(Shared:WaitForChild("Net"))
local SoundLimiter = require(script.Parent:WaitForChild("SoundLimiter"))

local empFiredRemote = Net.GetRemoteEvent(Constants.Remotes.EMPFired)
local TOOL_NAME = "EMP Slingshot"
local WEAPON_ASSET_PATH = {"Assets", "Weapons", "EmpSlingshot", "EmpSlingshot"}
local WEAPON_GRIP_OFFSET = CFrame.new(0.05, -1.05, -0.65) * CFrame.Angles(math.rad(360), math.rad(90), math.rad(0))

local equippedConnection: RBXScriptConnection? = nil
local unequippedConnection: RBXScriptConnection? = nil
local charging = false
local chargeStart = 0
local equipped = false
local equippedVisualModel: Model? = nil

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
	local origin = rootPart.Position + Vector3.new(0, 1.5, 0)
	local direction = mouse.UnitRay.Direction
	if direction.Magnitude < 0.001 then
		direction = rootPart.CFrame.LookVector
	end
	local aimRay = {
		origin = origin,
		direction = direction.Unit,
		timestamp = Workspace:GetServerTimeNow(),
	}

	empFiredRemote:FireServer(aimRay, charge01)
	print(("[EMPTool] EMP Fired charge=%.2f"):format(charge01))
	if charge01 >= 0.65 then
		SoundLimiter.Play2D("EMP_BIG", "rbxasset://sounds/electronicpingshort.wav", 0.22, 0.8)
	end
end

local function getWeaponAssetModel(): Model?
	local cursor: Instance = ReplicatedStorage
	for _, childName in ipairs(WEAPON_ASSET_PATH) do
		local nextNode = cursor:FindFirstChild(childName)
		if not nextNode then
			return nil
		end
		cursor = nextNode
	end

	if cursor:IsA("Model") then
		return cursor
	end
	return nil
end

local function cleanupEquippedVisual()
	if equippedVisualModel then
		equippedVisualModel:Destroy()
		equippedVisualModel = nil
	end
end

local function getEquipLimb(character: Model): BasePart?
	local rightHand = character:FindFirstChild("RightHand")
	if rightHand and rightHand:IsA("BasePart") then
		return rightHand
	end

	local rightArm = character:FindFirstChild("Right Arm")
	if rightArm and rightArm:IsA("BasePart") then
		return rightArm
	end

	return nil
end

local function attachWeaponVisual(tool: Tool)
	cleanupEquippedVisual()

	local assetModel = getWeaponAssetModel()
	if not assetModel then
		return
	end

	local character = player.Character
	if not character then
		return
	end

	local limb = getEquipLimb(character)
	if not limb then
		return
	end

	local modelClone = assetModel:Clone()
	local handle = modelClone:FindFirstChild("Handle")
	if not handle or not handle:IsA("BasePart") then
		modelClone:Destroy()
		return
	end
	modelClone.PrimaryPart = handle

	for _, descendant in ipairs(modelClone:GetDescendants()) do
		if descendant:IsA("BasePart") then
			descendant.CanCollide = false
			descendant.CanTouch = false
			descendant.CanQuery = false
			descendant.Massless = true
			descendant.Anchored = false
		end
	end

	modelClone:PivotTo(limb.CFrame * WEAPON_GRIP_OFFSET)
	modelClone.Parent = character

	local weld = Instance.new("WeldConstraint")
	weld.Name = "EmpSlingshotHandWeld"
	weld.Part0 = limb
	weld.Part1 = handle
	weld.Parent = handle

	equippedVisualModel = modelClone
	tool.Destroying:Once(function()
		cleanupEquippedVisual()
	end)
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
		attachWeaponVisual(tool)
		barBackground.Visible = true
		print("[EMPTool] Equipped")
	end)

	unequippedConnection = tool.Unequipped:Connect(function()
		equipped = false
		charging = false
		cleanupEquippedVisual()
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
	cleanupEquippedVisual()
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
