local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Net = require(Shared:WaitForChild("Net"))

local runtimeFolder = ServerScriptService:FindFirstChild("ServerRuntime")
if not runtimeFolder then
	runtimeFolder = Instance.new("Folder")
	runtimeFolder.Name = "ServerRuntime"
	runtimeFolder.Parent = ServerScriptService
end

local addMaterialsBindable = runtimeFolder:FindFirstChild(Constants.Bindables.AddMaterials)
if not (addMaterialsBindable and addMaterialsBindable:IsA("BindableFunction")) then
	if addMaterialsBindable then
		addMaterialsBindable:Destroy()
	end
	addMaterialsBindable = Instance.new("BindableFunction")
	addMaterialsBindable.Name = Constants.Bindables.AddMaterials
	addMaterialsBindable.Parent = runtimeFolder
end

local toastRemote = Net.GetOrCreateRemoteEvent(Constants.Remotes.Toast)

local function getOrCreateLeaderstats(player: Player): Folder
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats and leaderstats:IsA("Folder") then
		return leaderstats
	end

	leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player

	return leaderstats
end

local function getOrCreateIntValue(parent: Instance, name: string, defaultValue: number): IntValue
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("IntValue") then
		return existing
	end

	local value = Instance.new("IntValue")
	value.Name = name
	value.Value = defaultValue
	value.Parent = parent
	return value
end

local function getPlayerStats(player: Player): (IntValue, IntValue)
	local leaderstats = getOrCreateLeaderstats(player)
	local credits = getOrCreateIntValue(leaderstats, "Credits", Constants.GameSettings.StartingCoins)
	local materials = getOrCreateIntValue(leaderstats, "Materials", Constants.GameSettings.StartingMaterials)
	return credits, materials
end

(addMaterialsBindable :: BindableFunction).OnInvoke = function(player: Player, amount: number, reason: string)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return false
	end
	if typeof(amount) ~= "number" then
		return false
	end

	local _, materials = getPlayerStats(player)
	materials.Value += math.max(1, math.floor(amount))
	print(("[EconomyService] +%d materials to %s (%s)"):format(amount, player.Name, reason or "unknown"))
	return true
end

-- Sell terminal visual swap notes:
-- 1) Import the Sci-ATM model to ReplicatedStorage/Assets/Terminals/SciATM (or ServerStorage equivalent).
-- 2) The terminal keeps gameplay logic on SellTerminal.Root + ProximityPrompt; visuals live under SellTerminal.Visual.
-- 3) Call ReplaceVisual(newModel) to swap visuals safely, or rely on auto-swap if SciATM exists.
local function ensureRootPart(terminalModel: Model, fallbackPosition: Vector3): BasePart
	local root = terminalModel:FindFirstChild("Root")
	if root and root:IsA("BasePart") then
		root.Anchored = true
		root.CanCollide = false
		root.Transparency = 1
		return root
	end

	local createdRoot = Instance.new("Part")
	createdRoot.Name = "Root"
	createdRoot.Size = Vector3.new(2, 2, 2)
	createdRoot.Anchored = true
	createdRoot.CanCollide = false
	createdRoot.Transparency = 1
	createdRoot.Position = fallbackPosition
	createdRoot.Parent = terminalModel
	return createdRoot
end

local function ensureVisualContainer(terminalModel: Model): Instance
	local visual = terminalModel:FindFirstChild("Visual")
	if visual and (visual:IsA("Folder") or visual:IsA("Model")) then
		return visual
	end
	visual = Instance.new("Folder")
	visual.Name = "Visual"
	visual.Parent = terminalModel
	return visual
end

local function getModelCenterPosition(model: Model): Vector3?
	local sum = Vector3.zero
	local count = 0
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			sum += descendant.Position
			count += 1
		end
	end
	if count == 0 then
		return nil
	end
	return sum / count
end

local function alignRootToVisual(rootPart: BasePart, visualContainer: Instance)
	if visualContainer:IsA("Model") then
		local center = getModelCenterPosition(visualContainer)
		if center then
			rootPart.CFrame = CFrame.new(center)
			return
		end
	end

	local samplePart: BasePart? = nil
	for _, child in ipairs(visualContainer:GetChildren()) do
		if child:IsA("BasePart") then
			samplePart = child
			break
		elseif child:IsA("Model") then
			local center = getModelCenterPosition(child)
			if center then
				rootPart.CFrame = CFrame.new(center)
				return
			end
		end
	end

	if samplePart then
		rootPart.CFrame = CFrame.new(samplePart.Position)
	end
end

local function ensureSellTerminal(): ProximityPrompt
	local zoneSafe = Workspace:FindFirstChild("Zone_Safe")
	local existing = Workspace:FindFirstChild("SellTerminal")

	local fallbackPosition = Vector3.new(0, 8, 20)
	if zoneSafe and zoneSafe:IsA("BasePart") then
		local floorY = zoneSafe.Position.Y - (zoneSafe.Size.Y * 0.5) + 8
		fallbackPosition = Vector3.new(zoneSafe.Position.X, floorY, zoneSafe.Position.Z + 30)
	end

	local terminalModel: Model
	if existing and existing:IsA("Model") then
		terminalModel = existing
	elseif existing and existing:IsA("BasePart") then
		terminalModel = Instance.new("Model")
		terminalModel.Name = "SellTerminal"
		terminalModel.Parent = Workspace
	else
		terminalModel = Instance.new("Model")
		terminalModel.Name = "SellTerminal"
		terminalModel.Parent = Workspace
	end

	local rootPart = ensureRootPart(terminalModel, fallbackPosition)
	local visualContainer = ensureVisualContainer(terminalModel)

	if existing and existing:IsA("BasePart") and existing ~= rootPart then
		existing.Parent = visualContainer
		existing.Anchored = true
		if existing:IsA("Part") then
			existing.Color = Color3.fromRGB(80, 220, 120)
		end
	end

	for _, child in ipairs(terminalModel:GetChildren()) do
		if child ~= rootPart and child ~= visualContainer and not child:IsA("ProximityPrompt") and not child:IsA("Script") and not child:IsA("LocalScript") and not child:IsA("ModuleScript") then
			if child:IsA("BasePart") or child:IsA("Model") then
				child.Parent = visualContainer
			end
		end
	end

	terminalModel.PrimaryPart = rootPart

	local function ReplaceVisual(newModel: Model)
		for _, child in ipairs(visualContainer:GetChildren()) do
			child:Destroy()
		end

		newModel.Parent = visualContainer
		newModel:PivotTo(rootPart.CFrame)
		for _, descendant in ipairs(newModel:GetDescendants()) do
			if descendant:IsA("BasePart") then
				descendant.Anchored = true
			end
		end
		print("[SellTerminal] Visual swapped:", newModel.Name)
	end

	alignRootToVisual(rootPart, visualContainer)
	rootPart.CFrame = CFrame.new(-10, rootPart.Position.Y, rootPart.Position.Z)
	print("[SellTerminal] Prompt root aligned at", rootPart.Position)

	local prompt = terminalModel:FindFirstChildWhichIsA("ProximityPrompt", true)
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Sell Materials"
		prompt.ObjectText = "Sell Terminal"
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 12
		prompt.Parent = rootPart
	else
		prompt.Parent = rootPart
	end

	local assets = ReplicatedStorage:FindFirstChild("Assets")
	local terminals = assets and assets:FindFirstChild("Terminals")
	local sciATM = terminals and terminals:FindFirstChild("SciATM")
	if sciATM and sciATM:IsA("Model") then
		ReplaceVisual(sciATM:Clone())
	elseif #visualContainer:GetChildren() == 0 then
		local placeholder = Instance.new("Part")
		placeholder.Name = "TerminalBody"
		placeholder.Size = Vector3.new(6, 6, 6)
		placeholder.Color = Color3.fromRGB(80, 220, 120)
		placeholder.Anchored = true
		placeholder.CFrame = rootPart.CFrame
		placeholder.Parent = visualContainer
	end

	return prompt
end

local sellPrompt = ensureSellTerminal()

sellPrompt.Triggered:Connect(function(player: Player)
	local credits, materials = getPlayerStats(player)
	if materials.Value <= 0 then
		toastRemote:FireClient(player, "No materials to sell.")
		return
	end

	local soldMaterials = materials.Value
	local creditsEarned = soldMaterials * Constants.GameSettings.SellPricePerMaterial
	materials.Value = 0
	credits.Value += creditsEarned
	print(("[EconomyService] %s sold %d materials for %d credits"):format(player.Name, soldMaterials, creditsEarned))
	toastRemote:FireClient(player, ("Sold %d materials for %d credits"):format(soldMaterials, creditsEarned))
end)

Players.PlayerAdded:Connect(function(player)
	getPlayerStats(player)
end)

print("[EconomyService] Initialized")
