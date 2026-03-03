local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local StarterPack = game:GetService("StarterPack")

local TOOL_NAME = "EMP Slingshot"
local ASSET_MODEL_NAME = "EmpSlingshot"

local FRAME_COLOR = Color3.fromRGB(28, 32, 38)
local GLOW_COLOR = Color3.fromRGB(0, 229, 255)

local function configureWeaponPart(part: BasePart)
	part.CanCollide = false
	part.CanTouch = false
	part.CanQuery = false
	part.Massless = true
	part.Anchored = false
end

local function makePart(name: string, size: Vector3, cframe: CFrame, material: Enum.Material, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Material = material
	part.Color = color
	configureWeaponPart(part)
	return part
end

local function weldToHandle(handle: BasePart, part: BasePart)
	if part == handle then
		return
	end

	local weld = Instance.new("WeldConstraint")
	weld.Name = "WeaponWeld"
	weld.Part0 = handle
	weld.Part1 = part
	weld.Parent = part
end

local function createPowerNode(name: string, cframe: CFrame, parent: Instance): Part
	local node = makePart(name, Vector3.new(0.24, 0.24, 0.24), cframe, Enum.Material.Neon, GLOW_COLOR)
	local light = Instance.new("PointLight")
	light.Name = "NodeLight"
	light.Color = GLOW_COLOR
	light.Range = 6
	light.Brightness = 1.5
	light.Shadows = false
	light.Parent = node
	node.Parent = parent
	return node
end

local function ensureEmpSlingshotAssetModel(): Model
	local assets = ReplicatedStorage:FindFirstChild("Assets")
	if not assets then
		assets = Instance.new("Folder")
		assets.Name = "Assets"
		assets.Parent = ReplicatedStorage
	end

	local weapons = assets:FindFirstChild("Weapons")
	if not weapons then
		weapons = Instance.new("Folder")
		weapons.Name = "Weapons"
		weapons.Parent = assets
	end

	local slingshotFolder = weapons:FindFirstChild("EmpSlingshot")
	if not slingshotFolder then
		slingshotFolder = Instance.new("Folder")
		slingshotFolder.Name = "EmpSlingshot"
		slingshotFolder.Parent = weapons
	end

	local existing = slingshotFolder:FindFirstChild(ASSET_MODEL_NAME)
	if existing and existing:IsA("Model") then
		local existingHandle = existing:FindFirstChild("Handle")
		if existingHandle and existingHandle:IsA("BasePart") then
			existing.PrimaryPart = existingHandle
			return existing
		end
		existing:Destroy()
	end

	local model = Instance.new("Model")
	model.Name = ASSET_MODEL_NAME
	model.Parent = slingshotFolder

	local handle = makePart(
		"Handle",
		Vector3.new(0.28, 1.1, 0.28),
		CFrame.new(0, -0.05, 0),
		Enum.Material.Metal,
		FRAME_COLOR
	)
	handle.Parent = model
	model.PrimaryPart = handle

	local spine = makePart("FrameSpine", Vector3.new(0.22, 1.45, 0.22), CFrame.new(0, 0.45, 0), Enum.Material.Metal, FRAME_COLOR)
	spine.Parent = model

	local forkStem = makePart("ForkStem", Vector3.new(0.2, 0.5, 0.2), CFrame.new(0, 1.05, 0), Enum.Material.Metal, FRAME_COLOR)
	forkStem.Parent = model

	local leftFork = makePart(
		"ForkLeft",
		Vector3.new(0.18, 0.95, 0.18),
		CFrame.new(-0.38, 1.45, 0),
		Enum.Material.Metal,
		FRAME_COLOR
	)
	leftFork.Parent = model

	local rightFork = makePart(
		"ForkRight",
		Vector3.new(0.18, 0.95, 0.18),
		CFrame.new(0.38, 1.45, 0),
		Enum.Material.Metal,
		FRAME_COLOR
	)
	rightFork.Parent = model

	local bridge = makePart("ForkBridge", Vector3.new(0.8, 0.16, 0.16), CFrame.new(0, 1.03, 0), Enum.Material.Metal, FRAME_COLOR)
	bridge.Parent = model

	local glowStrip1 = makePart(
		"GlowStripFront",
		Vector3.new(0.08, 1.1, 0.08),
		CFrame.new(0, 0.45, -0.16),
		Enum.Material.Neon,
		GLOW_COLOR
	)
	glowStrip1.Parent = model

	local glowStrip2 = makePart(
		"GlowStripBack",
		Vector3.new(0.08, 1.1, 0.08),
		CFrame.new(0, 0.45, 0.16),
		Enum.Material.Neon,
		GLOW_COLOR
	)
	glowStrip2.Parent = model

	createPowerNode("PowerNodeA", CFrame.new(-0.28, 0.95, 0), model)
	createPowerNode("PowerNodeB", CFrame.new(0.28, 0.95, 0), model)
	createPowerNode("PowerNodeC", CFrame.new(0, 0.15, -0.2), model)

	local stringA = Instance.new("Attachment")
	stringA.Name = "StringA"
	stringA.Position = Vector3.new(0, 0.42, 0)
	stringA.Parent = leftFork

	local stringB = Instance.new("Attachment")
	stringB.Name = "StringB"
	stringB.Position = Vector3.new(0, 0.42, 0)
	stringB.Parent = rightFork

	local energyString = Instance.new("Beam")
	energyString.Name = "EnergyString"
	energyString.Attachment0 = stringA
	energyString.Attachment1 = stringB
	energyString.Width0 = 0.08
	energyString.Width1 = 0.08
	energyString.FaceCamera = true
	energyString.LightEmission = 1
	energyString.LightInfluence = 0
	energyString.Color = ColorSequence.new(GLOW_COLOR)
	energyString.Parent = model

	for _, part in ipairs(model:GetDescendants()) do
		if part:IsA("BasePart") then
			weldToHandle(handle, part)
		end
	end

	return model
end

local function createHandle(): Part
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 1)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Anchored = false
	handle.Massless = true
	return handle
end

local function createTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = "Click to fire EMP pulse"

	local handle = createHandle()
	handle.Parent = tool
	return tool
end

local function ensureToolInContainer(container: Instance)
	local existing = container:FindFirstChild(TOOL_NAME)
	if existing and existing:IsA("Tool") then
		local hasHandle = existing:FindFirstChild("Handle")
		if hasHandle and hasHandle:IsA("BasePart") then
			existing.CanBeDropped = false
			existing.RequiresHandle = true
			return
		end
		existing:Destroy()
	end

	local tool = createTool()
	tool.Parent = container
end

ensureEmpSlingshotAssetModel()
ensureToolInContainer(StarterPack)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		local backpack = player:WaitForChild("Backpack")
		ensureToolInContainer(backpack)
	end)
end)

print("[EMPToolService] EMP Slingshot provisioned")
