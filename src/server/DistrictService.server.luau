local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Net = require(Shared:WaitForChild("Net"))

local districtChangedRemote = Net.GetOrCreateRemoteEvent(Constants.Remotes.DistrictChanged)

local function ensureFolder(parent: Instance, name: string): Folder
	local folder = parent:FindFirstChild(name)
	if folder and folder:IsA("Folder") then
		return folder
	end
	local created = Instance.new("Folder")
	created.Name = name
	created.Parent = parent
	return created
end

local function ensureZonePart(name: string, position: Vector3): BasePart
	local existing = Workspace:FindFirstChild(name)
	if existing and existing:IsA("BasePart") then
		return existing
	end
	local zone = Instance.new("Part")
	zone.Name = name
	zone.Anchored = true
	zone.CanCollide = false
	zone.Transparency = 1
	zone.Size = Vector3.new(220, 30, 220)
	zone.Position = position
	zone.Parent = Workspace
	return zone
end

local worldFolder = ensureFolder(Workspace, "World")
local districtsFolder = ensureFolder(worldFolder, "Districts")
ensureZonePart("Zone_Safe", Vector3.new(0, 15, 0))
ensureZonePart("Zone_Danger", Vector3.new(320, 15, 0))

local splitLegacyValue = worldFolder:FindFirstChild("SplitX")
if splitLegacyValue and splitLegacyValue:IsA("NumberValue") then
	warn("[District] Legacy SplitX NumberValue found; syncing with World attribute")
else
	splitLegacyValue = nil
end

local districtById: {[string]: Folder} = {}
local splitX = 0
local minX = -560
local maxX = 560
local minZ = -560
local maxZ = 560
local missingRootWarnAt: {[number]: number} = {}

local function isValidNumber(value: any): boolean
	return typeof(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge
end

local function publishSplitX(value: number)
	local finalValue = value
	if not isValidNumber(finalValue) then
		warn(("[District] Invalid splitX '%s'; forcing fallback splitX=0"):format(tostring(finalValue)))
		finalValue = 0
	end
	splitX = finalValue
	local world = Workspace:FindFirstChild("World")
	if not (world and world:IsA("Folder")) then
		world = Instance.new("Folder")
		world.Name = "World"
		world.Parent = Workspace
	end
	world:SetAttribute("SplitX", splitX)
	if splitLegacyValue and splitLegacyValue.Parent == worldFolder then
		splitLegacyValue.Value = splitX
	end
	print(("[District] publish SplitX=%.2f typeof=%s"):format(splitX, typeof(splitX)))
	print("[DistrictService] SplitX published =", splitX)
end

local function getFallbackBounds(): (number, number, number, number)
	local cityLayout = Constants.CityLayout or {}
	local half = cityLayout.WorldHalfSizeXZ
	local center = cityLayout.WorldCenter
	if typeof(half) ~= "Vector2" then
		half = Vector2.new(560, 560)
	end
	if typeof(center) ~= "Vector3" then
		center = Vector3.new(0, 0, 0)
	end
	return center.X - half.X, center.X + half.X, center.Z - half.Y, center.Z + half.Y
end

local function getMapGeneratedBounds()
	local mapGenerated = worldFolder:FindFirstChild("MapGenerated")
	if not (mapGenerated and mapGenerated:IsA("Folder")) then
		return nil
	end

	local foundMinX = math.huge
	local foundMaxX = -math.huge
	local foundMinZ = math.huge
	local foundMaxZ = -math.huge

	for _, obj in ipairs(mapGenerated:GetDescendants()) do
		if obj:IsA("BasePart") then
			local half = obj.Size * 0.5
			foundMinX = math.min(foundMinX, obj.Position.X - half.X)
			foundMaxX = math.max(foundMaxX, obj.Position.X + half.X)
			foundMinZ = math.min(foundMinZ, obj.Position.Z - half.Z)
			foundMaxZ = math.max(foundMaxZ, obj.Position.Z + half.Z)
		end
	end

	if foundMinX == math.huge then
		return nil
	end
	return foundMinX, foundMaxX, foundMinZ, foundMaxZ
end

local function computeSplitX(boundsMinX: number, boundsMaxX: number): number
	local midpoint = (boundsMinX + boundsMaxX) * 0.5
	if not isValidNumber(midpoint) then
		warn("[District] Midpoint splitX invalid; forcing fallback splitX=0")
		return 0
	end

	local cityLayout = Constants.CityLayout or {}
	local blockSize = tonumber(cityLayout.BlockSize)
	if blockSize and blockSize > 0 then
		local snapped = math.floor((midpoint / blockSize) + 0.5) * blockSize
		if isValidNumber(snapped) then
			return math.clamp(snapped, boundsMinX + 0.01, boundsMaxX - 0.01)
		end
	end
	return midpoint
end

local function setBoundsAttrs(folder: Folder, bminX: number, bmaxX: number, bminZ: number, bmaxZ: number)
	folder:SetAttribute("BoundsMin", Vector3.new(bminX, 0, bminZ))
	folder:SetAttribute("BoundsMax", Vector3.new(bmaxX, 0, bmaxZ))
	folder:SetAttribute("Center", Vector3.new((bminX + bmaxX) * 0.5, 0, (bminZ + bmaxZ) * 0.5))
	folder:SetAttribute("Size", Vector2.new(math.max(1, bmaxX - bminX), math.max(1, bmaxZ - bminZ)))
end

local function createDistrict(id: string, heatLevel: number): Folder
	local folder = Instance.new("Folder")
	folder.Name = id
	folder:SetAttribute("Name", id)
	folder:SetAttribute("HeatLevel", heatLevel)
	folder:SetAttribute("HasDrones", false)
	folder:SetAttribute("DangerLevel", 0)
	folder:SetAttribute("DistrictDroneCount", 0)
	folder:SetAttribute("DroneSpawnRate", id == "DANGER" and 1.2 or 0.8)
	folder.Parent = districtsFolder
	return folder
end

local function updateSplitMarker()
	if not RunService:IsStudio() then
		return
	end
	local marker = worldFolder:FindFirstChild("SplitMarker")
	if not (marker and marker:IsA("BasePart")) then
		marker = Instance.new("Part")
		marker.Name = "SplitMarker"
		marker.Anchored = true
		marker.CanCollide = false
		marker.Material = Enum.Material.Neon
		marker.Color = Color3.fromRGB(220, 90, 90)
		marker.Transparency = 0.45
		marker.Parent = worldFolder
	end
	local width = math.max(4, maxX - minX)
	local depth = math.max(4, maxZ - minZ)
	marker.Size = Vector3.new(1, 40, depth)
	marker.Position = Vector3.new(splitX, 20, (minZ + maxZ) * 0.5)
end

local function rebuildDistricts()
	for _, child in ipairs(districtsFolder:GetChildren()) do
		child:Destroy()
	end
	table.clear(districtById)

	local mapMinX, mapMaxX, mapMinZ, mapMaxZ = getMapGeneratedBounds()
	if mapMinX ~= nil then
		minX, maxX, minZ, maxZ = mapMinX, mapMaxX, mapMinZ, mapMaxZ
	else
		minX, maxX, minZ, maxZ = getFallbackBounds()
	end

	local computedSplitX = computeSplitX(minX, maxX)
	if not isValidNumber(computedSplitX) then
		warn(("[District] computed splitX invalid (%s); forcing fallback splitX=0"):format(tostring(computedSplitX)))
		computedSplitX = 0
	end

	publishSplitX(computedSplitX)
	print(("[District] minX=%.2f maxX=%.2f splitX=%.2f"):format(minX, maxX, splitX))

	local safe = createDistrict("SAFE", 0)
	local danger = createDistrict("DANGER", 3)
	setBoundsAttrs(safe, minX, splitX, minZ, maxZ)
	setBoundsAttrs(danger, splitX, maxX, minZ, maxZ)
	districtById.SAFE = safe
	districtById.DANGER = danger
	updateSplitMarker()
end

local function districtIdFromX(x: number): string
	if x < splitX then
		return "SAFE"
	end
	return "DANGER"
end

local function applyDistrictAttributes(player: Player, character: Model?, districtId: string)
	local heatLevel = districtId == "DANGER" and 3 or 0
	local inDanger = districtId == "DANGER"

	player:SetAttribute("DistrictId", districtId)
	player:SetAttribute("DistrictHeatLevel", heatLevel)
	player:SetAttribute("InDanger", inDanger)
	player:SetAttribute("InDangerDistrict", inDanger)
	player:SetAttribute("InDangerZone", inDanger)

	if character then
		character:SetAttribute("DistrictId", districtId)
		character:SetAttribute("DistrictHeatLevel", heatLevel)
		character:SetAttribute("InDanger", inDanger)
	end
end

local function updatePlayerDistrict(player: Player, rootPart: BasePart)
	local newDistrictId = districtIdFromX(rootPart.Position.X)
	local oldDistrictId = tostring(player:GetAttribute("DistrictId") or "UNKNOWN")
	if oldDistrictId == newDistrictId then
		return
	end

	applyDistrictAttributes(player, player.Character, newDistrictId)
	print(("[District] %s %s->%s rootX=%.2f splitX=%.2f"):format(
		player.Name,
		oldDistrictId,
		newDistrictId,
		rootPart.Position.X,
		splitX
	))

	districtChangedRemote:FireClient(player, {
		name = newDistrictId,
		heat = newDistrictId == "DANGER" and 3 or 0,
		inDanger = newDistrictId == "DANGER",
	})
end

local function tryUpdatePlayer(player: Player)
	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if rootPart and rootPart:IsA("BasePart") then
		updatePlayerDistrict(player, rootPart)
		return
	end

	local now = os.clock()
	local lastWarn = missingRootWarnAt[player.UserId] or 0
	if now - lastWarn >= 1.5 then
		missingRootWarnAt[player.UserId] = now
		warn(("[District] HumanoidRootPart missing for %s; will retry"):format(player.Name))
	end
end

local function logSpawnDistrict()
	local spawnLocation = Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
	if not spawnLocation then
		return
	end
	local districtId = districtIdFromX(spawnLocation.Position.X)
	print(("[Spawn] current spawn in %s"):format(districtId))
end

local function onPlayerAdded(player: Player)
	applyDistrictAttributes(player, nil, "SAFE")

	player.CharacterAdded:Connect(function(character)
		applyDistrictAttributes(player, character, tostring(player:GetAttribute("DistrictId") or "SAFE"))
		task.spawn(function()
			for _ = 1, 20 do
				task.wait(0.15)
				local rootPart = character:FindFirstChild("HumanoidRootPart")
				if rootPart and rootPart:IsA("BasePart") then
					updatePlayerDistrict(player, rootPart)
					return
				end
				local now = os.clock()
				local lastWarn = missingRootWarnAt[player.UserId] or 0
				if now - lastWarn >= 1.5 then
					missingRootWarnAt[player.UserId] = now
					warn(("[District] HumanoidRootPart missing for %s on CharacterAdded; retrying"):format(player.Name))
				end
			end
		end)
	end)
end

rebuildDistricts()
logSpawnDistrict()

Players.PlayerAdded:Connect(onPlayerAdded)
for _, player in ipairs(Players:GetPlayers()) do
	onPlayerAdded(player)
end

Players.PlayerRemoving:Connect(function(player)
	missingRootWarnAt[player.UserId] = nil
end)

task.spawn(function()
	while true do
		task.wait(0.25)
		for _, player in ipairs(Players:GetPlayers()) do
			tryUpdatePlayer(player)
		end
	end
end)

print("[DistrictService] Initialized districts=2 (SAFE|DANGER)")
