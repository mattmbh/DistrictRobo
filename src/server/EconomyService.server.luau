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

local function ensureSellTerminal(): ProximityPrompt
	local zoneSafe = Workspace:FindFirstChild("Zone_Safe")
	local terminal = Workspace:FindFirstChild("SellTerminal")
	if not (terminal and terminal:IsA("BasePart")) then
		terminal = Instance.new("Part")
		terminal.Name = "SellTerminal"
		terminal.Size = Vector3.new(6, 6, 6)
		terminal.Color = Color3.fromRGB(80, 220, 120)
		terminal.Anchored = true
		terminal.Position = Vector3.new(0, 8, 20)
		terminal.Parent = Workspace
	end

	if zoneSafe and zoneSafe:IsA("BasePart") then
		local floorY = zoneSafe.Position.Y - (zoneSafe.Size.Y * 0.5) + 8
		terminal.Position = Vector3.new(zoneSafe.Position.X, floorY, zoneSafe.Position.Z + 30)
	end

	local prompt = terminal:FindFirstChildOfClass("ProximityPrompt")
	if not prompt then
		prompt = Instance.new("ProximityPrompt")
		prompt.ActionText = "Sell Materials"
		prompt.ObjectText = "Sell Terminal"
		prompt.HoldDuration = 0.3
		prompt.MaxActivationDistance = 12
		prompt.Parent = terminal
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
