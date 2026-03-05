local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local HeatMath = require(Shared:WaitForChild("HeatMath"))
local Net = require(Shared:WaitForChild("Net"))

local runtimeFolder = ServerScriptService:WaitForChild("ServerRuntime")
local addHeatBindable = runtimeFolder:WaitForChild(Constants.Bindables.AddHeat) :: BindableEvent
local addMaterialsBindable = runtimeFolder:WaitForChild(Constants.Bindables.AddMaterials) :: BindableFunction

local empFiredRemote = Net.GetOrCreateRemoteEvent(Constants.Remotes.EMPFired)
local fxRemote = Net.GetOrCreateRemoteEvent(Constants.Remotes.FXEvent)
local droneSnapshotRemote = Net.GetOrCreateRemoteEvent(Constants.Remotes.DroneSnapshot)
local zoneDanger = Workspace:WaitForChild("Zone_Danger") :: BasePart
if not zoneDanger:IsA("BasePart") then
	error("Zone_Danger must be a BasePart")
end

local droneFolder = Workspace:FindFirstChild("Drones")
if not droneFolder then
	droneFolder = Instance.new("Folder")
	droneFolder.Name = "Drones"
	droneFolder.Parent = Workspace
end

local pickupFolder = Workspace:FindFirstChild("MaterialDrops")
if not pickupFolder then
	pickupFolder = Instance.new("Folder")
	pickupFolder.Name = "MaterialDrops"
	pickupFolder.Parent = Workspace
end

type DroneState = {
	id: number,
	instance: BasePart | Model,
	rootPart: BasePart,
	hitbox: BasePart,
	hitParts: {BasePart},
	districtFolder: Folder?,
	hp: number,
	disabledUntil: number,
	stunStartTime: number,
	stunSeed: number,
	stunBaseCFrame: CFrame,
	isEliminated: boolean,
	lastShotAt: number,
	mode: string,
	lastSeenAt: number,
	lastKnownPos: Vector3,
	scanPhase: number,
	lastScanFxAt: number,
	orbitSign: number,
}

local drones: {DroneState} = {}
local dronesByPart: {[BasePart]: DroneState} = {}
local lastEmpByUserId: {[number]: number} = {}
local spawnAccumulator = 0
local movementAccumulator = 0
local snapshotAccumulator = 0
local nextDroneId = 1
local lastDamageTimeByUserId: {[number]: number} = {}
local lastAggroDebugStateByUserId: {[number]: string} = {}
local forceAggroOnPlayer: (Player, Vector3) -> ()

Players.PlayerRemoving:Connect(function(player: Player)
	lastDamageTimeByUserId[player.UserId] = nil
	lastAggroDebugStateByUserId[player.UserId] = nil
end)

local DRONE_MOVE_STEP = 0.2
local SNAPSHOT_RATE = 1 / 15
local nextSpawnInterval = 4.5

local function lerp(minValue: number, maxValue: number, alpha: number): number
	return minValue + ((maxValue - minValue) * alpha)
end

local function rollSpawnInterval(): number
	return lerp(Constants.Drones.SpawnIntervalMin, Constants.Drones.SpawnIntervalMax, math.random())
end

nextSpawnInterval = rollSpawnInterval()

local function getDangerBoundsXZ(): (number, number, number, number, Vector3)
	local fallbackCenter = zoneDanger.Position
	local fallbackHalfSize = Vector2.new(zoneDanger.Size.X * 0.5, zoneDanger.Size.Z * 0.5)
	local minX = fallbackCenter.X - fallbackHalfSize.X
	local maxX = fallbackCenter.X + fallbackHalfSize.X
	local minZ = fallbackCenter.Z - fallbackHalfSize.Y
	local maxZ = fallbackCenter.Z + fallbackHalfSize.Y

	local world = Workspace:FindFirstChild("World")
	local districtsFolder = world and world:FindFirstChild("Districts")
	if districtsFolder then
		for _, child in ipairs(districtsFolder:GetChildren()) do
			if child:IsA("Folder") then
				local districtName = string.upper(tostring(child:GetAttribute("Name") or child.Name))
				if districtName == "DANGER" then
					local boundsMin = child:GetAttribute("BoundsMin")
					local boundsMax = child:GetAttribute("BoundsMax")
					if typeof(boundsMin) == "Vector3" and typeof(boundsMax) == "Vector3" then
						minX = math.min(boundsMin.X, boundsMax.X)
						maxX = math.max(boundsMin.X, boundsMax.X)
						minZ = math.min(boundsMin.Z, boundsMax.Z)
						maxZ = math.max(boundsMin.Z, boundsMax.Z)
						break
					end

					local center = child:GetAttribute("Center")
					local size = child:GetAttribute("Size")
					if typeof(center) == "Vector3" and typeof(size) == "Vector2" then
						minX = center.X - (size.X * 0.5)
						maxX = center.X + (size.X * 0.5)
						minZ = center.Z - (size.Y * 0.5)
						maxZ = center.Z + (size.Y * 0.5)
						break
					end
				end
			end
		end
	end

	local center = Vector3.new((minX + maxX) * 0.5, fallbackCenter.Y, (minZ + maxZ) * 0.5)
	return minX, maxX, minZ, maxZ, center
end

local function clampToPlatformXZ(position: Vector3): Vector3
	local minX, maxX, minZ, maxZ = getDangerBoundsXZ()
	local margin = Constants.Drones.SpawnMargin
	minX += margin
	maxX -= margin
	minZ += margin
	maxZ -= margin
	if minX > maxX then
		minX, maxX = maxX, minX
	end
	if minZ > maxZ then
		minZ, maxZ = maxZ, minZ
	end

	return Vector3.new(
		math.clamp(position.X, minX, maxX),
		position.Y,
		math.clamp(position.Z, minZ, maxZ)
	)
end

local function isOutsidePlatformXZ(position: Vector3): boolean
	local minX, maxX, minZ, maxZ = getDangerBoundsXZ()
	local margin = Constants.Drones.SpawnMargin
	minX += margin
	maxX -= margin
	minZ += margin
	maxZ -= margin
	return position.X < minX or position.X > maxX or position.Z < minZ or position.Z > maxZ
end

local function randomPointInDangerDistrict(): Vector3
	local minX, maxX, minZ, maxZ = getDangerBoundsXZ()
	local margin = math.max(2, Constants.Drones.SpawnMargin)
	minX += margin
	maxX -= margin
	minZ += margin
	maxZ -= margin
	if minX > maxX then
		minX, maxX = maxX, minX
	end
	if minZ > maxZ then
		minZ, maxZ = maxZ, minZ
	end

	local worldPoint = Vector3.new(
		lerp(minX, maxX, math.random()),
		Constants.Drones.PlatformCenter.Y + Constants.Drones.HoverHeight,
		lerp(minZ, maxZ, math.random())
	)
	local clamped = clampToPlatformXZ(worldPoint)
	return Vector3.new(clamped.X, Constants.Drones.PlatformCenter.Y + Constants.Drones.HoverHeight, clamped.Z)
end

local function getDistrictsFolder(): Folder?
	local world = Workspace:FindFirstChild("World")
	if not (world and world:IsA("Folder")) then
		return nil
	end
	local districts = world:FindFirstChild("Districts")
	if districts and districts:IsA("Folder") then
		return districts
	end
	return nil
end

local function getDistrictForPosition(position: Vector3): Folder?
	local districtsFolder = getDistrictsFolder()
	if not districtsFolder then
		return nil
	end

	for _, child in ipairs(districtsFolder:GetChildren()) do
		if child:IsA("Folder") then
			local boundsMin = child:GetAttribute("BoundsMin")
			local boundsMax = child:GetAttribute("BoundsMax")
			if typeof(boundsMin) == "Vector3" and typeof(boundsMax) == "Vector3" then
				if position.X >= boundsMin.X and position.X <= boundsMax.X and position.Z >= boundsMin.Z and position.Z <= boundsMax.Z then
					return child
				end
			end

			local center = child:GetAttribute("Center")
			local size = child:GetAttribute("Size")
			if typeof(center) == "Vector3" and typeof(size) == "Vector2" then
				local halfX = size.X * 0.5
				local halfZ = size.Y * 0.5
				if position.X >= center.X - halfX and position.X <= center.X + halfX and position.Z >= center.Z - halfZ and position.Z <= center.Z + halfZ then
					return child
				end
			end
		end
	end

	return nil
end

local function recomputeDistrictDroneState()
	local districtsFolder = getDistrictsFolder()
	if not districtsFolder then
		return
	end

	local counts: {[Folder]: number} = {}
	for _, child in ipairs(districtsFolder:GetChildren()) do
		if child:IsA("Folder") then
			counts[child] = 0
		end
	end

	for _, droneState in ipairs(drones) do
		if droneState.instance.Parent and not droneState.isEliminated then
			local district = droneState.districtFolder
			if not (district and district.Parent == districtsFolder) then
				district = getDistrictForPosition(droneState.rootPart.Position)
				droneState.districtFolder = district
			end
			if district and counts[district] ~= nil then
				counts[district] += 1
			end
		end
	end

	for district, count in pairs(counts) do
		local hasDrones = count > 0
		district:SetAttribute("DistrictDroneCount", count)
		district:SetAttribute("HasDrones", hasDrones)
		district:SetAttribute("DangerLevel", count)

		local heatLevel = tonumber(district:GetAttribute("HeatLevel")) or 1
		local districtName = tostring(district:GetAttribute("Name") or district.Name)
		if hasDrones and heatLevel < 3 then
			district:SetAttribute("HeatLevel", 3)
		elseif not hasDrones then
			if districtName == "SAFE" then
				district:SetAttribute("HeatLevel", 0)
			elseif districtName == "DANGER" then
				district:SetAttribute("HeatLevel", 3)
			elseif heatLevel > 2 then
				district:SetAttribute("HeatLevel", 1)
			end
		end
	end
end

local function getDangerPlayers(): {Player}
	local result = {}
	for _, player in ipairs(Players:GetPlayers()) do
		local character = player.Character
		local inDanger = false
		local heat = 0
		if character then
			if character:GetAttribute("InDanger") ~= nil then
				inDanger = character:GetAttribute("InDanger") == true
			else
				inDanger = player:GetAttribute("InDanger") == true
			end
			if character:GetAttribute("DistrictHeatLevel") ~= nil then
				heat = tonumber(character:GetAttribute("DistrictHeatLevel")) or 0
			else
				heat = tonumber(player:GetAttribute("DistrictHeatLevel")) or 0
			end
		else
			inDanger = player:GetAttribute("InDanger") == true
			heat = tonumber(player:GetAttribute("DistrictHeatLevel")) or 0
		end

		local eligible = inDanger or heat >= 1
		local stateKey = ("%s|%d"):format(tostring(inDanger), heat)
		if lastAggroDebugStateByUserId[player.UserId] ~= stateKey then
			lastAggroDebugStateByUserId[player.UserId] = stateKey
			print(("[Drone] target player inDanger=%s heat=%d"):format(tostring(inDanger), heat))
		end
		if eligible then
			table.insert(result, player)
		end
	end
	return result
end

local function getNearestDangerPlayer(position: Vector3): Player?
	local bestPlayer: Player? = nil
	local bestDistance = math.huge
	for _, player in ipairs(getDangerPlayers()) do
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if rootPart and rootPart:IsA("BasePart") then
			local distance = (rootPart.Position - position).Magnitude
			if distance < bestDistance then
				bestDistance = distance
				bestPlayer = player
			end
		end
	end
	return bestPlayer
end

local function getDroneTemplate(): Model?
	local assetsFolder = ReplicatedStorage:FindFirstChild("Assets")
	if not assetsFolder then
		return nil
	end

	local dronesFolder = assetsFolder:FindFirstChild("Drones")
	if not dronesFolder then
		return nil
	end

	local template = dronesFolder:FindFirstChild("DroneModel")
	if template and template:IsA("Model") and template.PrimaryPart then
		return template
	end

	return nil
end

local function getModelParts(model: Model): {BasePart}
	local parts = {}
	for _, descendant in ipairs(model:GetDescendants()) do
		if descendant:IsA("BasePart") then
			table.insert(parts, descendant)
		end
	end
	return parts
end

local function rigDroneModel(model: Model): (BasePart, {BasePart})
	local parts = getModelParts(model)
	local primary = model.PrimaryPart
	if not primary then
		for _, part in ipairs(parts) do
			primary = part
			break
		end
		if primary then
			model.PrimaryPart = primary
		end
	end
	assert(primary, "DroneModel requires at least one BasePart descendant")

	for _, part in ipairs(parts) do
		part.CanCollide = false
		part.Massless = true
		part.Anchored = false
		if part ~= primary then
			local hasWeld = false
			for _, child in ipairs(part:GetChildren()) do
				if child:IsA("WeldConstraint") and child.Part0 == primary and child.Part1 == part then
					hasWeld = true
					break
				end
			end
			if not hasWeld then
				local weld = Instance.new("WeldConstraint")
				weld.Name = "DroneRigWeld"
				weld.Part0 = primary
				weld.Part1 = part
				weld.Parent = part
			end
		end
	end

	primary.CanCollide = false
	primary.Anchored = false
	pcall(function()
		primary:SetNetworkOwner(nil)
	end)
	return primary, parts
end

local function createDroneHitbox(rootPart: BasePart, container: Instance): BasePart
	local hitbox = Instance.new("Part")
	hitbox.Name = "Hitbox"
	hitbox.Size = Constants.Drones.HitboxSize
	hitbox.Transparency = 1
	hitbox.CanCollide = false
	hitbox.CanTouch = false
	hitbox.CanQuery = true
	hitbox.Anchored = false
	hitbox.Massless = true
	hitbox.CFrame = rootPart.CFrame
	hitbox.Parent = container

	local weld = Instance.new("WeldConstraint")
	weld.Name = "DroneHitboxWeld"
	weld.Part0 = rootPart
	weld.Part1 = hitbox
	weld.Parent = hitbox

	return hitbox
end

local function setDroneActiveVisual(droneState: DroneState)
	if droneState.instance:IsA("BasePart") then
		droneState.instance.Color = Color3.fromRGB(180, 180, 180)
	end
end

local function spawnDrone(spawnPositionOverride: Vector3?)
	local spawnPosition = spawnPositionOverride or randomPointInDangerDistrict()
	local droneTemplate = getDroneTemplate()

	local droneInstance: BasePart | Model
	local rootPart: BasePart
	local hitParts: {BasePart}
	local hitbox: BasePart

	if droneTemplate then
		local model = droneTemplate:Clone()
		model.Name = "Drone"
		model:PivotTo(CFrame.new(spawnPosition))
		model.Parent = droneFolder

		rootPart, hitParts = rigDroneModel(model)
		hitbox = createDroneHitbox(rootPart, model)
		table.insert(hitParts, hitbox)

		droneInstance = model
	else
		local part = Instance.new("Part")
		part.Name = "Drone"
		part.Shape = Enum.PartType.Ball
		part.Material = Enum.Material.Metal
		part.Color = Color3.fromRGB(180, 180, 180)
		part.Size = Vector3.new(4, 4, 4)
		part.Anchored = true
		part.CanCollide = false
		part.Position = spawnPosition
		part.Parent = droneFolder
		pcall(function()
			part:SetNetworkOwner(nil)
		end)

		rootPart = part
		hitParts = {part}
		droneInstance = part
		hitbox = createDroneHitbox(rootPart, droneFolder)
		table.insert(hitParts, hitbox)
	end

	local droneId = nextDroneId
	nextDroneId += 1
	droneInstance:SetAttribute("DroneId", droneId)
	rootPart:SetAttribute("DroneId", droneId)

	local droneState: DroneState = {
		id = droneId,
		instance = droneInstance,
		rootPart = rootPart,
		hitbox = hitbox,
		hitParts = hitParts,
		districtFolder = nil,
		hp = Constants.Drones.DroneHP,
		disabledUntil = 0,
		stunStartTime = 0,
		stunSeed = math.random() * math.pi * 2,
		stunBaseCFrame = droneInstance:GetPivot(),
		isEliminated = false,
		lastShotAt = 0,
		mode = "IDLE",
		lastSeenAt = 0,
		lastKnownPos = spawnPosition,
		scanPhase = math.random() * math.pi * 2,
		lastScanFxAt = 0,
		orbitSign = math.random(0, 1) == 0 and -1 or 1,
	}
	table.insert(drones, droneState)
	for _, part in ipairs(hitParts) do
		dronesByPart[part] = droneState
	end

	droneState.districtFolder = getDistrictForPosition(spawnPosition)
	recomputeDistrictDroneState()
	local districtName = droneState.districtFolder and tostring(droneState.districtFolder:GetAttribute("Name") or droneState.districtFolder.Name) or "Unknown"
	local sideName = (string.find(districtName, "DANGER", 1, true) and "DANGER") or "SAFE"
	print(("[Drone] spawned in district %s"):format(districtName))
	print(("[Drone] spawnX=%.2f -> %s"):format(spawnPosition.X, sideName))
end

local function cleanupDroneState()
	local kept = {}
	local remap: {[BasePart]: DroneState} = {}
	for _, droneState in ipairs(drones) do
		if droneState.instance.Parent ~= nil and droneState.rootPart.Parent ~= nil then
			table.insert(kept, droneState)
			for _, part in ipairs(droneState.hitParts) do
				if part.Parent ~= nil then
					remap[part] = droneState
				end
			end
		end
	end
	drones = kept
	dronesByPart = remap
	recomputeDistrictDroneState()
end

local function removeDroneState(target: DroneState)
	local kept = {}
	local remap: {[BasePart]: DroneState} = {}
	for _, droneState in ipairs(drones) do
		if droneState ~= target and droneState.instance.Parent ~= nil and droneState.rootPart.Parent ~= nil then
			table.insert(kept, droneState)
			for _, part in ipairs(droneState.hitParts) do
				if part.Parent ~= nil then
					remap[part] = droneState
				end
			end
		end
	end
	drones = kept
	dronesByPart = remap
	recomputeDistrictDroneState()
end

local function getDesiredDroneCount(): number
	local districtHeat = Workspace:GetAttribute("DistrictHeat") or 0
	local threatLevel = HeatMath.GetThreatLevel(districtHeat)
	local desiredCount = Constants.Drones.CountByThreatLevel[threatLevel] or Constants.Drones.BaseCount
	return math.clamp(desiredCount, Constants.Drones.BaseCount, Constants.Drones.MaxAlive)
end

local function countAliveDrones(): number
	local alive = 0
	for _, droneState in ipairs(drones) do
		if droneState.instance.Parent and not droneState.isEliminated then
			alive += 1
		end
	end
	return alive
end

local function spawnPickup(hitPosition: Vector3)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {droneFolder, pickupFolder}

	local rayOrigin = hitPosition + Vector3.new(0, 10, 0)
	local groundResult = Workspace:Raycast(rayOrigin, Vector3.new(0, -500, 0), rayParams)

	local spawnPosition = hitPosition
	local groundFound = false
	if groundResult then
		groundFound = true
		local groundY = groundResult.Position.Y
		local target = groundResult.Position + Vector3.new(0, 1.5, 0)
		spawnPosition = Vector3.new(target.X, math.min(target.Y, groundY + 20), target.Z)
	end
	print(("[DroneDirector] Pickup spawn=%s groundFound=%s"):format(tostring(spawnPosition), tostring(groundFound)))

	local pickup = Instance.new("Part")
	pickup.Name = "MaterialPickup"
	pickup.Shape = Enum.PartType.Block
	pickup.Material = Enum.Material.Neon
	pickup.Color = Color3.fromRGB(0, 220, 255)
	pickup.Size = Vector3.new(1, 1, 1)
	pickup.Anchored = false
	pickup.CanCollide = true
	pickup.Massless = false
	pickup.CustomPhysicalProperties = PhysicalProperties.new(1, 0.6, 0.4)
	pickup.Position = spawnPosition
	pickup.AssemblyLinearVelocity = Vector3.new(0, -5, 0)
	pickup.Parent = pickupFolder
	fxRemote:FireAllClients({
		type = "DROP_CLINK",
		position = spawnPosition,
	})

	local taken = false
	pickup.Touched:Connect(function(hit)
		if taken then
			return
		end
		local player = Players:GetPlayerFromCharacter(hit.Parent)
		if not player then
			return
		end
		taken = true
		addMaterialsBindable:Invoke(player, 1, "drone_drop")
		pickup:Destroy()
	end)

	Debris:AddItem(pickup, 25)
end

local function setDronePhysics(droneState: DroneState, anchored: boolean, canCollide: boolean)
	if droneState.instance:IsA("BasePart") then
		droneState.instance.Anchored = anchored
		droneState.instance.CanCollide = canCollide
		return
	end

	for _, part in ipairs(droneState.hitParts) do
		if part.Parent ~= nil then
			part.Anchored = anchored
			part.CanCollide = canCollide
		end
	end
end

local function spawnDroneDebris(droneInstance: BasePart | Model)
	local debrisClone = droneInstance:Clone()
	debrisClone.Name = "DroneDebris"
	debrisClone.Parent = Workspace
	if debrisClone:IsA("Model") then
		debrisClone:PivotTo(droneInstance:GetPivot())
	end

	local parts = {}
	if debrisClone:IsA("Model") then
		for _, descendant in ipairs(debrisClone:GetDescendants()) do
			if descendant:IsA("BasePart") then
				if descendant.Name == "Hitbox" then
					descendant:Destroy()
				else
					table.insert(parts, descendant)
				end
			elseif descendant:IsA("WeldConstraint") then
				descendant:Destroy()
			end
		end
	elseif debrisClone:IsA("BasePart") then
		table.insert(parts, debrisClone)
	end

	for _, part in ipairs(parts) do
		for _, child in ipairs(part:GetChildren()) do
			if child:IsA("WeldConstraint") then
				child:Destroy()
			end
		end
		part.Anchored = false
		part.CanCollide = true
		part.Massless = false
		local scatter = Vector3.new(
			(math.random() * 2 - 1) * 18,
			(math.random() * 18) + 8,
			(math.random() * 2 - 1) * 18
		)
		part.AssemblyLinearVelocity = scatter
		part.AssemblyAngularVelocity = Vector3.new(
			(math.random() * 2 - 1) * 8,
			(math.random() * 2 - 1) * 8,
			(math.random() * 2 - 1) * 8
		)
	end

	Debris:AddItem(debrisClone, Constants.Drones.DebrisLifetime)
end

local function eliminateDrone(droneState: DroneState, reason: string)
	if droneState.isEliminated or droneState.instance.Parent == nil then
		return
	end

	droneState.isEliminated = true
	local origin = droneState.rootPart.Position
	fxRemote:FireAllClients({
		type = "DRONE_DEBRIS",
		position = origin,
		reason = reason,
	})

	spawnDroneDebris(droneState.instance)
	droneState.instance:Destroy()
	removeDroneState(droneState)

	local replacementDelay = lerp(
		Constants.Drones.SpawnReplacementDelayMin,
		Constants.Drones.SpawnReplacementDelayMax,
		math.random()
	)
	task.delay(replacementDelay, function()
		cleanupDroneState()
		if countAliveDrones() < getDesiredDroneCount() then
			spawnDrone(randomPointInDangerDistrict())
		end
	end)
end

local function disableDrone(droneState: DroneState, player: Player, duration: number, damage: number)
	if droneState.isEliminated or droneState.instance.Parent == nil then
		return
	end

	droneState.hp = math.max(0, droneState.hp - damage)
	local dronePosition = droneState.rootPart.Position
	addHeatBindable:Fire(player, Constants.Heat.HEAT_DRONE_DISABLED, "drone_disabled")
	forceAggroOnPlayer(player, dronePosition)

	if droneState.hp <= 0 then
		eliminateDrone(droneState, "emp_destroyed")
		spawnPickup(dronePosition)
		return
	end

	local now = time()
	droneState.disabledUntil = math.max(droneState.disabledUntil, time() + duration)
	droneState.stunStartTime = now
	droneState.stunSeed = math.random() * math.pi * 2
	droneState.stunBaseCFrame = droneState.instance:GetPivot()
	if droneState.instance:IsA("BasePart") then
		droneState.instance.Color = Color3.fromRGB(90, 90, 90)
	end
	setDronePhysics(droneState, true, false)
	fxRemote:FireAllClients({
		type = "DRONE_ZAP",
		position = dronePosition,
	})
end

local function isValidEmpFire(player: Player, origin: Vector3, charge01: number): boolean
	local userId = player.UserId
	local now = time()
	local lastFire = lastEmpByUserId[userId] or 0
	if now - lastFire < Constants.EMP.EMP_COOLDOWN then
		return false
	end

	local character = player.Character
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not (rootPart and rootPart:IsA("BasePart")) then
		return false
	end

	local originDistance = (rootPart.Position - origin).Magnitude
	if originDistance > Constants.EMP.OriginMaxDistanceFromPlayer then
		return false
	end

	lastEmpByUserId[userId] = now
	local empHeat = HeatMath.GetEMPHeatGain(charge01)
	addHeatBindable:Fire(player, empHeat, "emp_fired")
	return true
end

local function getDroneInRadius(position: Vector3, radius: number): {DroneState}
	local overlapParams = OverlapParams.new()
	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = {droneFolder}
	local parts = Workspace:GetPartBoundsInRadius(position, radius, overlapParams)

	local hitDrones = {}
	local seen: {[number]: boolean} = {}
	for _, part in ipairs(parts) do
		local droneState = dronesByPart[part]
		if droneState and not seen[droneState.id] then
			seen[droneState.id] = true
			table.insert(hitDrones, droneState)
		end
	end
	return hitDrones
end

local function pointSegmentDistanceSquared(point: Vector3, segA: Vector3, segB: Vector3): number
	local seg = segB - segA
	local segLenSq = seg:Dot(seg)
	if segLenSq <= 1e-6 then
		return (point - segA):Dot(point - segA)
	end
	local t = math.clamp((point - segA):Dot(seg) / segLenSq, 0, 1)
	local closest = segA + (seg * t)
	local delta = point - closest
	return delta:Dot(delta)
end

local function getDroneInSweep(startPos: Vector3, endPos: Vector3, radius: number): {DroneState}
	local hits = getDroneInRadius(endPos, radius)
	local seen: {[number]: boolean} = {}
	for _, droneState in ipairs(hits) do
		seen[droneState.id] = true
	end

	local expandedRadius = radius + 2
	local radiusSq = expandedRadius * expandedRadius
	for _, droneState in ipairs(drones) do
		if not seen[droneState.id] and droneState.instance.Parent and not droneState.isEliminated then
			local distSq = pointSegmentDistanceSquared(droneState.rootPart.Position, startPos, endPos)
			if distSq <= radiusSq then
				seen[droneState.id] = true
				table.insert(hits, droneState)
			end
		end
	end
	return hits
end

local function getDamageCooldownPerPlayer(): number
	local cap = math.max(Constants.Drones.DamagePerSecondCapPerPlayer, 0.01)
	local fromCap = Constants.Drones.DamagePerShot / cap
	return math.max(0.2, fromCap)
end

local function canDamagePlayer(player: Player, now: number): boolean
	local lastDamage = lastDamageTimeByUserId[player.UserId] or 0
	if now - lastDamage < getDamageCooldownPerPlayer() then
		return false
	end
	lastDamageTimeByUserId[player.UserId] = now
	return true
end

local function getDroneScanForward(droneState: DroneState): Vector3
	local flat = Vector3.new(droneState.rootPart.CFrame.LookVector.X, 0, droneState.rootPart.CFrame.LookVector.Z)
	if flat.Magnitude > 0.001 then
		return flat.Unit
	end
	return Vector3.new(math.cos(droneState.scanPhase), 0, math.sin(droneState.scanPhase)).Unit
end

local function getPredictedTargetPosition(rootPart: BasePart): Vector3
	return rootPart.Position + (rootPart.AssemblyLinearVelocity * Constants.Drones.AimLead)
end

local function canDetectTarget(droneState: DroneState, player: Player, ignoreFov: boolean?): (boolean, BasePart?, Vector3?)
	local character = player.Character
	local humanoid = character and character:FindFirstChildOfClass("Humanoid")
	local rootPart = character and character:FindFirstChild("HumanoidRootPart")
	if not (humanoid and humanoid.Health > 0 and rootPart and rootPart:IsA("BasePart")) then
		return false, nil, nil
	end

	local origin = droneState.rootPart.Position
	local targetPos = rootPart.Position
	local toTarget = targetPos - origin
	local distance = toTarget.Magnitude
	if distance > Constants.Drones.DetectRange then
		return false, nil, nil
	end

	local flatToTarget = Vector3.new(toTarget.X, 0, toTarget.Z)
	if flatToTarget.Magnitude <= 0.001 then
		return false, nil, nil
	end

	if not ignoreFov then
		local forward = getDroneScanForward(droneState)
		local fovCos = math.cos(math.rad(Constants.Drones.DetectFOVDeg * 0.5))
		if forward:Dot(flatToTarget.Unit) < fovCos then
			return false, nil, nil
		end
	end

	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {droneFolder, pickupFolder}
	local result = Workspace:Raycast(origin, toTarget, rayParams)
	if result and result.Instance and result.Instance:IsDescendantOf(character) then
		return true, rootPart, result.Position
	end
	return false, nil, nil
end

local function getClosestVisibleTarget(droneState: DroneState, ignoreFov: boolean?): (Player?, BasePart?, Vector3?)
	local bestDistance = math.huge
	local bestPlayer: Player? = nil
	local bestRoot: BasePart? = nil
	local bestHit: Vector3? = nil
	for _, player in ipairs(getDangerPlayers()) do
		local seen, rootPart, hitPos = canDetectTarget(droneState, player, ignoreFov)
		if seen and rootPart and hitPos then
			local dist = (rootPart.Position - droneState.rootPart.Position).Magnitude
			if dist < bestDistance then
				bestDistance = dist
				bestPlayer = player
				bestRoot = rootPart
				bestHit = hitPos
			end
		end
	end
	return bestPlayer, bestRoot, bestHit
end

forceAggroOnPlayer = function(player: Player, sourcePosition: Vector3)
	local character = player.Character
	local root = character and character:FindFirstChild("HumanoidRootPart")
	if not (root and root:IsA("BasePart")) then
		return
	end

	local now = time()
	for _, candidate in ipairs(drones) do
		if candidate.instance.Parent and now >= candidate.disabledUntil then
			local distance = (candidate.rootPart.Position - sourcePosition).Magnitude
			if distance <= Constants.Drones.DetectRange * 1.5 then
				if candidate.mode ~= "AGGRO" then
					fxRemote:FireAllClients({
						type = "DRONE_LOCK",
						position = candidate.rootPart.Position,
					})
				end
				candidate.mode = "AGGRO"
				candidate.lastSeenAt = now
				candidate.lastKnownPos = root.Position
			end
		end
	end
end

local function randomDirectionInCone(baseDir: Vector3, coneDeg: number): Vector3
	local dir = baseDir.Magnitude > 0 and baseDir.Unit or Vector3.new(0, 0, -1)
	if coneDeg <= 0.01 then
		return dir
	end
	local upRef = math.abs(dir:Dot(Vector3.new(0, 1, 0))) > 0.98 and Vector3.new(1, 0, 0) or Vector3.new(0, 1, 0)
	local right = dir:Cross(upRef).Unit
	local up = right:Cross(dir).Unit
	local angle = math.rad(coneDeg) * math.sqrt(math.random())
	local theta = math.random() * math.pi * 2
	local spread = (right * math.cos(theta) + up * math.sin(theta)) * math.sin(angle)
	return (dir * math.cos(angle) + spread).Unit
end

local function computeShotDirection(droneState: DroneState, targetRoot: BasePart): (Vector3, number)
	local origin = droneState.rootPart.Position
	local predicted = getPredictedTargetPosition(targetRoot)
	local ideal = predicted - origin
	local distance = ideal.Magnitude
	local distanceAlpha = math.clamp(distance / math.max(Constants.Drones.AttackRange, 1), 0, 1)
	local cone = lerp(Constants.Drones.AimConeDegMin, Constants.Drones.AimConeDegMax, distanceAlpha)
	local moveSpeed = targetRoot.AssemblyLinearVelocity.Magnitude
	local moveAlpha = math.clamp(moveSpeed / 20, 0, 1)
	local totalCone = cone + (Constants.Drones.MovingConeBonusDeg * moveAlpha)
	return randomDirectionInCone(ideal, totalCone), distance
end

local function tryDroneAttack(droneState: DroneState)
	if not Constants.Drones.AttackEnabled or droneState.mode ~= "AGGRO" then
		return
	end
	if droneState.isEliminated then
		return
	end
	if droneState.instance.Parent == nil or time() < droneState.disabledUntil then
		return
	end

	local now = time()
	if now - droneState.lastShotAt < Constants.Drones.FireCooldown then
		return
	end

	local shotOrigin = droneState.rootPart.Position
	local targetPlayer, targetRoot = getClosestVisibleTarget(droneState, true)
	if not (targetPlayer and targetRoot) then
		return
	end

	local shotDir = computeShotDirection(droneState, targetRoot)
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {droneFolder, pickupFolder}
	local rayDistance = Constants.Drones.AttackRange
	local result = Workspace:Raycast(shotOrigin, shotDir * rayDistance, rayParams)
	local hitPosition = shotOrigin + (shotDir * rayDistance)
	local didHitTarget = false
	local didDamage = false

	if result then
		hitPosition = result.Position
		local targetCharacter = targetRoot.Parent
		if targetCharacter and result.Instance and result.Instance:IsDescendantOf(targetCharacter) then
			didHitTarget = true
			if canDamagePlayer(targetPlayer, now) then
				local targetHumanoid = targetCharacter:FindFirstChildOfClass("Humanoid")
				if targetHumanoid and targetHumanoid.Health > 0 then
					targetHumanoid:TakeDamage(Constants.Drones.DamagePerShot)
					didDamage = true
				end
			end
		end
	end

	droneState.lastShotAt = now
	fxRemote:FireAllClients({
		type = "DRONE_SHOT",
		origin = shotOrigin,
		hitPosition = hitPosition,
		hit = didHitTarget,
		damaged = didDamage,
	})
end

local function launchEMPProjectile(player: Player, origin: Vector3, direction: Vector3, charge01: number)
	local dir = direction.Magnitude > 0 and direction.Unit or Vector3.new(0, 0, -1)
	local speed = lerp(Constants.EMP.EMP_PROJECTILE_SPEED_MIN, Constants.EMP.EMP_PROJECTILE_SPEED_MAX, charge01)
	local hitRadius = Constants.EMP.HitRadius
	local impactRadius = lerp(Constants.EMP.IMPACT_RADIUS_MIN, Constants.EMP.IMPACT_RADIUS_MAX, charge01)
	local disableDuration = lerp(Constants.EMP.DISABLE_DURATION_MIN, Constants.EMP.DISABLE_DURATION_MAX, charge01)

	local projectile = Instance.new("Part")
	projectile.Name = "EMPProjectile"
	projectile.Shape = Enum.PartType.Ball
	projectile.Material = Enum.Material.Neon
	projectile.Color = Color3.fromRGB(90, 220, 255)
	projectile.Size = Vector3.new(0.9, 0.9, 0.9)
	projectile.CanCollide = false
	projectile.Anchored = true
	projectile.Position = origin + Vector3.new(0, 1.5, 0)
	projectile.Parent = Workspace
	Debris:AddItem(projectile, Constants.EMP.ProjectileLifetime)

	local traveled = 0
	local rayParams = RaycastParams.new()
	rayParams.FilterType = Enum.RaycastFilterType.Exclude
	rayParams.FilterDescendantsInstances = {projectile, player.Character}

	while projectile.Parent and traveled < Constants.EMP.MaxRange do
		local deltaTime = task.wait(0.02)
		local step = dir * speed * deltaTime
		local currentPos = projectile.Position
		local nextPos = currentPos + step

		local result = Workspace:Raycast(currentPos, step, rayParams)
		if result then
			nextPos = result.Position
		end

		projectile.Position = nextPos
		traveled += step.Magnitude

		local hitDrones = getDroneInSweep(currentPos, nextPos, hitRadius)
		if #hitDrones > 0 then
			print("Drone hit")
			for _, droneState in ipairs(hitDrones) do
				disableDrone(droneState, player, disableDuration, Constants.Drones.EMPDamagePerHit)
			end

			if impactRadius > 0 then
				for _, droneState in ipairs(getDroneInSweep(nextPos, nextPos, impactRadius)) do
					disableDrone(
						droneState,
						player,
						disableDuration * 0.8,
						Constants.Drones.EMPDamagePerHit * Constants.Drones.EMPDamageSplashScale
					)
				end
			end

			projectile:Destroy()
			return
		end

		if result then
			projectile:Destroy()
			return
		end
	end

	if projectile.Parent then
		projectile:Destroy()
	end
end

local function setDroneCFrame(droneState: DroneState, targetCFrame: CFrame)
	if droneState.instance:IsA("BasePart") then
		droneState.instance.CFrame = targetCFrame
	else
		droneState.instance:PivotTo(targetCFrame)
	end
end

local function getHoverY(droneState: DroneState): number
	return Constants.Drones.PlatformCenter.Y
		+ Constants.Drones.HoverHeight
		+ (math.sin(droneState.scanPhase * 1.7) * Constants.Drones.HoverJitter)
end

local function setDroneWorldPosition(droneState: DroneState, desiredPosition: Vector3, lookDir: Vector3?)
	local wasOutside = isOutsidePlatformXZ(droneState.rootPart.Position)
	local clamped = clampToPlatformXZ(desiredPosition)
	local finalPosition = Vector3.new(clamped.X, getHoverY(droneState), clamped.Z)
	local forward = lookDir and lookDir.Magnitude > 0.001 and lookDir.Unit or getDroneScanForward(droneState)
	if wasOutside then
		local _, _, _, _, center = getDangerBoundsXZ()
		local inward = Vector3.new(center.X - finalPosition.X, 0, center.Z - finalPosition.Z)
		if inward.Magnitude > 0.001 then
			forward = (forward + inward.Unit).Unit
		end
	end
	setDroneCFrame(droneState, CFrame.lookAt(finalPosition, finalPosition + forward))
end

local function applyDroneStunWobble(droneState: DroneState, now: number)
	local t = (now - droneState.stunStartTime) * Constants.Drones.StunWobbleHz
	local seed = droneState.stunSeed
	local wobblePos = Constants.Drones.StunWobblePos
	local wobbleRot = math.rad(Constants.Drones.StunWobbleRotDeg)

	local offset = Vector3.new(
		math.sin((t * 2.1) + seed) * wobblePos,
		math.sin((t * 2.7) + (seed * 0.7)) * wobblePos * 0.5,
		math.cos((t * 1.9) + (seed * 1.3)) * wobblePos
	)
	local targetPos = droneState.stunBaseCFrame.Position + offset
	local clampedPosXZ = clampToPlatformXZ(targetPos)
	local finalPos = Vector3.new(clampedPosXZ.X, getHoverY(droneState), clampedPosXZ.Z)

	local yaw = math.sin((t * 0.8) + (seed * 1.1)) * math.rad(4)
	local pitch = math.sin((t * 1.6) + (seed * 0.5)) * wobbleRot
	local roll = math.cos((t * 1.4) + (seed * 0.9)) * wobbleRot
	local baseLook = droneState.stunBaseCFrame.LookVector
	local look = (CFrame.fromAxisAngle(Vector3.new(0, 1, 0), yaw) * CFrame.new(baseLook)).Position.Unit
	local stunnedCF = CFrame.lookAt(finalPos, finalPos + look) * CFrame.Angles(pitch, 0, roll)

	setDroneCFrame(droneState, stunnedCF)
end

local function updateDroneMode(droneState: DroneState, now: number): BasePart?
	local seenPlayer, seenRoot
	if droneState.mode == "IDLE" then
		seenPlayer, seenRoot = getClosestVisibleTarget(droneState, false)
	else
		seenPlayer, seenRoot = getClosestVisibleTarget(droneState, true)
	end
	if seenPlayer and seenRoot then
		if droneState.mode ~= "AGGRO" then
			fxRemote:FireAllClients({
				type = "DRONE_LOCK",
				position = droneState.rootPart.Position,
			})
		end
		droneState.mode = "AGGRO"
		droneState.lastSeenAt = now
		droneState.lastKnownPos = seenRoot.Position
		return seenRoot
	end

	local secondsSinceSeen = now - droneState.lastSeenAt
	if droneState.mode == "AGGRO" then
		if secondsSinceSeen >= Constants.Drones.LoseLOSAfter then
			droneState.mode = "SEARCH"
			droneState.lastSeenAt = now
		end
	elseif droneState.mode == "SEARCH" then
		if secondsSinceSeen >= Constants.Drones.SearchTime then
			droneState.mode = "IDLE"
		end
	end

	return nil
end

local function getPreferredMoveDirection(droneState: DroneState, targetPosition: Vector3): Vector3
	if isOutsidePlatformXZ(droneState.rootPart.Position) then
		local _, _, _, _, center = getDangerBoundsXZ()
		local inward = Vector3.new(
			center.X - droneState.rootPart.Position.X,
			0,
			center.Z - droneState.rootPart.Position.Z
		)
		if inward.Magnitude > 0.001 then
			return inward.Unit
		end
	end

	local toTarget = targetPosition - droneState.rootPart.Position
	local toTargetFlat = Vector3.new(toTarget.X, 0, toTarget.Z)
	if toTargetFlat.Magnitude <= 0.001 then
		return getDroneScanForward(droneState)
	end

	local distance = toTargetFlat.Magnitude
	local radial = toTargetFlat.Unit
	local strafe = Vector3.new(-radial.Z, 0, radial.X) * droneState.orbitSign
	if distance < Constants.Drones.MinRange then
		return -radial
	elseif distance > Constants.Drones.PreferredRange then
		return radial
	else
		return (strafe + (radial * 0.2)).Unit
	end
end

local function updateDroneMovement(deltaTime: number, speedMultiplier: number)
	local now = time()
	for _, droneState in ipairs(drones) do
		if droneState.instance.Parent and not droneState.isEliminated then
			if now < droneState.disabledUntil then
				applyDroneStunWobble(droneState, now)
				continue
			end

			setDronePhysics(droneState, true, false)
			setDroneActiveVisual(droneState)

			droneState.scanPhase += deltaTime * Constants.Drones.OrbitSpeed
			local currentTargetRoot = updateDroneMode(droneState, now)

			if droneState.mode == "IDLE" then
				if now - droneState.lastScanFxAt >= 1.1 then
					droneState.lastScanFxAt = now
					fxRemote:FireAllClients({
						type = "DRONE_SCAN_PING",
						position = droneState.rootPart.Position,
					})
				end
				local scanDir = getDroneScanForward(droneState)
				local drift = scanDir * (Constants.Drones.BaseSpeed * 0.15 * deltaTime)
				setDroneWorldPosition(droneState, droneState.rootPart.Position + drift, scanDir)
			else
				local targetPos = currentTargetRoot and currentTargetRoot.Position or droneState.lastKnownPos
				local moveDir = getPreferredMoveDirection(droneState, targetPos)
				local moveStep = moveDir * Constants.Drones.BaseSpeed * speedMultiplier * deltaTime
				setDroneWorldPosition(droneState, droneState.rootPart.Position + moveStep, moveDir)
			end
		end

		tryDroneAttack(droneState)
	end
end

local function broadcastDroneSnapshots()
	local snapshot = {}
	for _, droneState in ipairs(drones) do
		if droneState.instance.Parent then
			table.insert(snapshot, {
				id = droneState.id,
				cf = droneState.rootPart.CFrame,
				disabled = time() < droneState.disabledUntil,
			})
		end
	end

	droneSnapshotRemote:FireAllClients({
		serverTime = Workspace:GetServerTimeNow(),
		drones = snapshot,
	})
end

empFiredRemote.OnServerEvent:Connect(function(player: Player, aimRay: {[string]: any}, charge01: number)
	if typeof(aimRay) ~= "table" or typeof(charge01) ~= "number" then
		return
	end
	local origin = aimRay.origin
	local direction = aimRay.direction
	local timestamp = aimRay.timestamp
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" or typeof(timestamp) ~= "number" then
		return
	end
	if direction.Magnitude <= 0.001 then
		return
	end

	local clampedCharge = math.clamp(charge01, 0, 1)
	if not isValidEmpFire(player, origin, clampedCharge) then
		return
	end

	print(("EMPFired from %s charge=%.2f"):format(player.Name, clampedCharge))
	launchEMPProjectile(player, origin, direction.Unit, clampedCharge)
end)

RunService.Heartbeat:Connect(function(deltaTime)
	local districtHeat = Workspace:GetAttribute("DistrictHeat") or 0
	local threatLevel = HeatMath.GetThreatLevel(districtHeat)
	local desiredCount = Constants.Drones.CountByThreatLevel[threatLevel] or Constants.Drones.BaseCount
	desiredCount = math.clamp(desiredCount, Constants.Drones.BaseCount, Constants.Drones.MaxAlive)

	spawnAccumulator += deltaTime
	if spawnAccumulator >= nextSpawnInterval then
		spawnAccumulator -= nextSpawnInterval
		nextSpawnInterval = rollSpawnInterval()
		cleanupDroneState()

		local alive = 0
		for _, droneState in ipairs(drones) do
			if droneState.instance.Parent then
				alive += 1
			end
		end

		local missing = math.max(0, desiredCount - alive)
		local burst = math.random(Constants.Drones.SpawnPerTickMin, Constants.Drones.SpawnPerTickMax)
		local toSpawn = math.clamp(burst, 0, missing)
		for _ = 1, toSpawn do
			spawnDrone()
			alive += 1
		end
		print(("[DroneDirector] Threat %d | DistrictHeat %.1f | Drones %d | NextSpawn %.2fs"):format(threatLevel, districtHeat, alive, nextSpawnInterval))
	end

	movementAccumulator += deltaTime
	local speedMultiplier = 1 + (Constants.Drones.SpeedMultiplierPerThreat * threatLevel)
	while movementAccumulator >= DRONE_MOVE_STEP do
		movementAccumulator -= DRONE_MOVE_STEP
		updateDroneMovement(DRONE_MOVE_STEP, speedMultiplier)
	end

	snapshotAccumulator += deltaTime
	if snapshotAccumulator >= SNAPSHOT_RATE then
		snapshotAccumulator -= SNAPSHOT_RATE
		broadcastDroneSnapshots()
	end
end)

print("[DroneDirector] Initialized")
