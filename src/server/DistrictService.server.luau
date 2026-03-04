local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Net = require(Shared:WaitForChild("Net"))

local districtChangedRemote = Net.GetOrCreateRemoteEvent(Constants.Remotes.DistrictChanged)

local DISTRICT_SIZE = 200
local DISTRICT_NAME_POOL = {
	"Industrial",
	"Market",
	"Transit",
	"Harbor",
	"Foundry",
	"Neon",
	"Arcade",
	"Depot",
	"Warehouse",
	"Core",
}

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

local zoneSafe = ensureZonePart("Zone_Safe", Vector3.new(0, 15, 0))
local zoneDanger = ensureZonePart("Zone_Danger", Vector3.new(320, 15, 0))
local worldFolder = Workspace:FindFirstChild("World")
if not (worldFolder and worldFolder:IsA("Folder")) then
	worldFolder = Instance.new("Folder")
	worldFolder.Name = "World"
	worldFolder.Parent = Workspace
end
local districtsFolder = worldFolder:FindFirstChild("Districts")
if not (districtsFolder and districtsFolder:IsA("Folder")) then
	districtsFolder = Instance.new("Folder")
	districtsFolder.Name = "Districts"
	districtsFolder.Parent = worldFolder
end

local districtLookup: {[string]: Folder} = {}
local districtStartX = 0
local districtStartZ = 0
local districtCountX = 1
local districtCountZ = 1

local function isPointInPart(part: BasePart, point: Vector3): boolean
	local relative = part.CFrame:PointToObjectSpace(point)
	local half = part.Size * 0.5
	return math.abs(relative.X) <= half.X
		and math.abs(relative.Y) <= half.Y
		and math.abs(relative.Z) <= half.Z
end

local function getGridBounds(): (Vector3, number, number)
	local center = Vector3.new(0, 0, 0)
	local halfX = Constants.CityLayout and Constants.CityLayout.WorldHalfSizeXZ.X or 560
	local halfZ = Constants.CityLayout and Constants.CityLayout.WorldHalfSizeXZ.Y or 560

	local baseplate = Workspace:FindFirstChild("Baseplate")
	if baseplate and baseplate:IsA("BasePart") then
		center = baseplate.Position
		halfX = baseplate.Size.X * 0.5
		halfZ = baseplate.Size.Z * 0.5
	end

	return center, halfX, halfZ
end

local function districtKey(ix: number, iz: number): string
	return ("%d_%d"):format(ix, iz)
end

local function buildDistrictGrid()
	for _, child in ipairs(districtsFolder:GetChildren()) do
		child:Destroy()
	end
	table.clear(districtLookup)

	local center, halfX, halfZ = getGridBounds()
	local totalX = math.max(DISTRICT_SIZE, halfX * 2)
	local totalZ = math.max(DISTRICT_SIZE, halfZ * 2)

	districtCountX = math.max(1, math.floor(totalX / DISTRICT_SIZE))
	districtCountZ = math.max(1, math.floor(totalZ / DISTRICT_SIZE))

	districtStartX = center.X - (districtCountX * DISTRICT_SIZE * 0.5)
	districtStartZ = center.Z - (districtCountZ * DISTRICT_SIZE * 0.5)

	for ix = 0, districtCountX - 1 do
		for iz = 0, districtCountZ - 1 do
			local key = districtKey(ix, iz)
			local districtFolder = Instance.new("Folder")
			districtFolder.Name = key

			local poolIndex = ((ix * 5 + iz * 7) % #DISTRICT_NAME_POOL) + 1
			local districtName = ("%s %d-%d"):format(DISTRICT_NAME_POOL[poolIndex], ix + 1, iz + 1)
			local heatLevel = (ix + iz) % 4
			local spawnRate = 0.8 + heatLevel * 0.3
			local centerX = districtStartX + ix * DISTRICT_SIZE + DISTRICT_SIZE * 0.5
			local centerZ = districtStartZ + iz * DISTRICT_SIZE + DISTRICT_SIZE * 0.5

			districtFolder:SetAttribute("Name", districtName)
			districtFolder:SetAttribute("HeatLevel", heatLevel)
			districtFolder:SetAttribute("DroneSpawnRate", spawnRate)
			districtFolder:SetAttribute("Center", Vector3.new(centerX, 0, centerZ))
			districtFolder:SetAttribute("Size", Vector2.new(DISTRICT_SIZE, DISTRICT_SIZE))

			districtFolder.Parent = districtsFolder
			districtLookup[key] = districtFolder
		end
	end
end

local function getDistrictFromPosition(position: Vector3): Folder?
	local relX = (position.X - districtStartX) / DISTRICT_SIZE
	local relZ = (position.Z - districtStartZ) / DISTRICT_SIZE
	local ix = math.floor(relX)
	local iz = math.floor(relZ)
	if ix < 0 or iz < 0 or ix >= districtCountX or iz >= districtCountZ then
		return nil
	end
	return districtLookup[districtKey(ix, iz)]
end

local function updatePlayerDistrict(player: Player, position: Vector3)
	local district = getDistrictFromPosition(position)
	local districtName = district and district:GetAttribute("Name") or "Outskirts"
	local heatLevel = district and district:GetAttribute("HeatLevel") or 0
	local spawnRate = district and district:GetAttribute("DroneSpawnRate") or 1
	local inDanger = isPointInPart(zoneDanger, position)

	player:SetAttribute("InDangerZone", inDanger)

	local currentDistrict = player:GetAttribute("DistrictId")
	if currentDistrict == districtName then
		return
	end

	player:SetAttribute("DistrictId", districtName)
	player:SetAttribute("DistrictHeatLevel", heatLevel)
	player:SetAttribute("DistrictDroneSpawnRate", spawnRate)

	districtChangedRemote:FireClient(player, {
		name = districtName,
		heat = heatLevel,
		droneSpawnRate = spawnRate,
		inDanger = inDanger,
	})
	print(("[District] Entered %s Heat:%d"):format(tostring(districtName), tonumber(heatLevel) or 0))
end

buildDistrictGrid()

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("DistrictId", Constants.Districts.SAFE)
	player:SetAttribute("InDangerZone", false)

	player.CharacterAdded:Connect(function(character)
		task.wait(0.2)
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart and rootPart:IsA("BasePart") then
			updatePlayerDistrict(player, rootPart.Position)
		end
	end)
end)

task.spawn(function()
	while true do
		task.wait(Constants.ZoneCheck.Interval)
		for _, player in ipairs(Players:GetPlayers()) do
			local character = player.Character
			local rootPart = character and character:FindFirstChild("HumanoidRootPart")
			if rootPart and rootPart:IsA("BasePart") then
				updatePlayerDistrict(player, rootPart.Position)
			end
		end
	end
end)

print(("[DistrictService] Initialized districts=%d (%dx%d)"):format(districtCountX * districtCountZ, districtCountX, districtCountZ))
