local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local HeatMath = require(Shared:WaitForChild("HeatMath"))
local Net = require(Shared:WaitForChild("Net"))

local runtimeFolder = ServerScriptService:FindFirstChild("ServerRuntime")
if not runtimeFolder then
	runtimeFolder = Instance.new("Folder")
	runtimeFolder.Name = "ServerRuntime"
	runtimeFolder.Parent = ServerScriptService
end

local function ensureBindableEvent(name: string): BindableEvent
	local existing = runtimeFolder:FindFirstChild(name)
	if existing and existing:IsA("BindableEvent") then
		return existing
	end

	local bindable = Instance.new("BindableEvent")
	bindable.Name = name
	bindable.Parent = runtimeFolder
	return bindable
end

local function ensureBindableFunction(name: string): BindableFunction
	local existing = runtimeFolder:FindFirstChild(name)
	if existing and existing:IsA("BindableFunction") then
		return existing
	end

	local bindable = Instance.new("BindableFunction")
	bindable.Name = name
	bindable.Parent = runtimeFolder
	return bindable
end

for _, remoteName in pairs(Constants.Remotes) do
	Net.GetOrCreateRemoteEvent(remoteName)
end

local heatUpdatedRemote = Net.GetRemoteEvent(Constants.Remotes.HeatUpdated)
local toastRemote = Net.GetRemoteEvent(Constants.Remotes.Toast)

local addHeatBindable = ensureBindableEvent(Constants.Bindables.AddHeat)
local getHeatBindable = ensureBindableFunction(Constants.Bindables.GetHeat)

local playerHeat: {[number]: number} = {}
local districtHeat = 0
local lastThreatLevel = 0
local clusterAccumulator = 0
local broadcastAccumulator = 0

local function recomputeDistrictHeat()
	local dangerOnlyHeat: {[number]: number} = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("InDangerZone") then
			dangerOnlyHeat[player.UserId] = playerHeat[player.UserId] or 0
		end
	end

	districtHeat = HeatMath.ComputeDistrictHeat(dangerOnlyHeat)
	Workspace:SetAttribute("DistrictHeat", districtHeat)
	Workspace:SetAttribute("ThreatLevel", HeatMath.GetThreatLevel(districtHeat))
end

local function getHeat(player: Player): number
	return playerHeat[player.UserId] or 0
end

local function addHeat(player: Player, amount: number, reason: string?)
	if amount <= 0 then
		return
	end

	local userId = player.UserId
	local current = playerHeat[userId] or 0
	local nextHeat = math.clamp(current + amount, 0, Constants.Heat.MaxPlayerHeat)
	playerHeat[userId] = nextHeat

	recomputeDistrictHeat()
	print(("[HeatService] %s +%.2f (%s) -> %.2f | district=%.2f"):format(
		player.Name,
		amount,
		reason or "unknown",
		nextHeat,
		districtHeat
	))
end

getHeatBindable.OnInvoke = function(player: Player)
	return getHeat(player)
end

addHeatBindable.Event:Connect(function(player: Player, amount: number, reason: string)
	if typeof(player) ~= "Instance" or not player:IsA("Player") then
		return
	end
	if typeof(amount) ~= "number" then
		return
	end
	addHeat(player, amount, reason)
end)

Players.PlayerAdded:Connect(function(player)
	playerHeat[player.UserId] = 0
	player:SetAttribute("DistrictId", Constants.Districts.SAFE)
	player:SetAttribute("InDangerZone", false)
end)

Players.PlayerRemoving:Connect(function(player)
	playerHeat[player.UserId] = nil
	recomputeDistrictHeat()
end)

task.spawn(function()
	while true do
		local deltaTime = task.wait(0.1)
		clusterAccumulator += deltaTime
		broadcastAccumulator += deltaTime

		for _, player in ipairs(Players:GetPlayers()) do
			local heatValue = playerHeat[player.UserId] or 0
			if heatValue > 0 then
				local inDanger = player:GetAttribute("InDangerZone") == true
				playerHeat[player.UserId] = HeatMath.ApplyDecay(heatValue, deltaTime, inDanger)
			end
		end

		if clusterAccumulator >= 1 then
			clusterAccumulator = 0
			local dangerPlayers = {}
			for _, player in ipairs(Players:GetPlayers()) do
				if player:GetAttribute("InDangerZone") then
					table.insert(dangerPlayers, player)
				end
			end

			for _, player in ipairs(dangerPlayers) do
				local character = player.Character
				local rootPart = character and character:FindFirstChild("HumanoidRootPart")
				if rootPart and rootPart:IsA("BasePart") then
					local nearby = 0
					for _, other in ipairs(dangerPlayers) do
						if other ~= player then
							local otherChar = other.Character
							local otherRoot = otherChar and otherChar:FindFirstChild("HumanoidRootPart")
							if otherRoot and otherRoot:IsA("BasePart") then
								if (otherRoot.Position - rootPart.Position).Magnitude <= Constants.ZoneCheck.ClusterRadius then
									nearby += 1
								end
							end
						end
					end
					if nearby > Constants.ZoneCheck.ClusterMinNearbyPlayers then
						local clusteredBeyondThreshold = nearby - Constants.ZoneCheck.ClusterMinNearbyPlayers
						local clusterHeat = clusteredBeyondThreshold * Constants.Heat.HEAT_CLUSTER_PER_SECOND
						addHeat(player, clusterHeat, "cluster")
					end
				end
			end
		end

		recomputeDistrictHeat()
		local threatLevel = HeatMath.GetThreatLevel(districtHeat)
		if threatLevel > lastThreatLevel then
			for _, player in ipairs(Players:GetPlayers()) do
				toastRemote:FireClient(player, ("THREAT LEVEL %d"):format(threatLevel))
			end
		end
		lastThreatLevel = threatLevel

		if broadcastAccumulator >= Constants.Heat.BroadcastRate then
			broadcastAccumulator = 0
			for _, player in ipairs(Players:GetPlayers()) do
				heatUpdatedRemote:FireClient(player, {
					playerHeat = getHeat(player),
					districtHeat = districtHeat,
					threatLevel = threatLevel,
				})
			end
		end
	end
end)

print("[HeatService] Initialized")
