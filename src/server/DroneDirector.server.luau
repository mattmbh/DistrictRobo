local Debris = game:GetService("Debris")
local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
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
local zoneDanger = Workspace:WaitForChild("Zone_Danger") :: BasePart

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
	part: BasePart,
	disabledUntil: number,
}

local drones: {DroneState} = {}
local dronesByPart: {[BasePart]: DroneState} = {}
local lastEmpByUserId: {[number]: number} = {}
local spawnAccumulator = 0

local function lerp(minValue: number, maxValue: number, alpha: number): number
	return minValue + ((maxValue - minValue) * alpha)
end

local function randomPointInZone(zone: BasePart): Vector3
	local half = zone.Size * 0.5
	local localPoint = Vector3.new(
		(math.random() * 2 - 1) * (half.X - 6),
		2,
		(math.random() * 2 - 1) * (half.Z - 6)
	)
	return zone.CFrame:PointToWorldSpace(localPoint)
end

local function getDangerPlayers(): {Player}
	local result = {}
	for _, player in ipairs(Players:GetPlayers()) do
		if player:GetAttribute("InDangerZone") then
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

local function spawnDrone()
	local drone = Instance.new("Part")
	drone.Name = "Drone"
	drone.Shape = Enum.PartType.Ball
	drone.Material = Enum.Material.Metal
	drone.Color = Color3.fromRGB(180, 180, 180)
	drone.Size = Vector3.new(4, 4, 4)
	drone.Anchored = true
	drone.CanCollide = false
	drone.Position = randomPointInZone(zoneDanger)
	drone.Parent = droneFolder

	local droneState: DroneState = {
		part = drone,
		disabledUntil = 0,
	}
	table.insert(drones, droneState)
	dronesByPart[drone] = droneState
end

local function cleanupDroneState()
	local kept = {}
	local remap: {[BasePart]: DroneState} = {}
	for _, droneState in ipairs(drones) do
		if droneState.part.Parent ~= nil then
			table.insert(kept, droneState)
			remap[droneState.part] = droneState
		end
	end
	drones = kept
	dronesByPart = remap
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

local function disableDrone(droneState: DroneState, player: Player, duration: number)
	if droneState.part.Parent == nil then
		return
	end

	droneState.disabledUntil = math.max(droneState.disabledUntil, time() + duration)
	local dronePart = droneState.part
	dronePart.Anchored = false
	dronePart.CanCollide = true
	dronePart.Color = Color3.fromRGB(90, 90, 90)
	fxRemote:FireAllClients({
		type = "DRONE_ZAP",
		position = dronePart.Position,
	})

	addHeatBindable:Fire(player, Constants.Heat.HEAT_DRONE_DISABLED, "drone_disabled")
	spawnPickup(dronePart.Position)
	Debris:AddItem(dronePart, duration + 0.2)
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
	local seen: {[BasePart]: boolean} = {}
	for _, part in ipairs(parts) do
		local droneState = dronesByPart[part]
		if droneState and not seen[droneState.part] then
			seen[droneState.part] = true
			table.insert(hitDrones, droneState)
		end
	end
	return hitDrones
end

local function launchEMPProjectile(player: Player, origin: Vector3, direction: Vector3, charge01: number)
	local dir = direction.Magnitude > 0 and direction.Unit or Vector3.new(0, 0, -1)
	local speed = lerp(Constants.EMP.EMP_PROJECTILE_SPEED_MIN, Constants.EMP.EMP_PROJECTILE_SPEED_MAX, charge01)
	local hitRadius = lerp(Constants.EMP.EMP_HIT_RADIUS_MIN, Constants.EMP.EMP_HIT_RADIUS_MAX, charge01)
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

	while projectile.Parent and traveled < Constants.EMP.EMP_RANGE do
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

		local hitDrones = getDroneInRadius(nextPos, hitRadius)
		if #hitDrones > 0 then
			print("Drone hit")
			for _, droneState in ipairs(hitDrones) do
				disableDrone(droneState, player, disableDuration)
			end

			if impactRadius > 0 then
				for _, droneState in ipairs(getDroneInRadius(nextPos, impactRadius)) do
					disableDrone(droneState, player, disableDuration * 0.8)
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

empFiredRemote.OnServerEvent:Connect(function(player: Player, origin: Vector3, direction: Vector3, charge01: number)
	if typeof(origin) ~= "Vector3" or typeof(direction) ~= "Vector3" or typeof(charge01) ~= "number" then
		return
	end

	local clampedCharge = math.clamp(charge01, 0, 1)
	if not isValidEmpFire(player, origin, clampedCharge) then
		return
	end

	print(("EMPFired from %s charge=%.2f"):format(player.Name, clampedCharge))
	launchEMPProjectile(player, origin, direction, clampedCharge)
end)

task.spawn(function()
	while true do
		local deltaTime = task.wait(0.2)
		local districtHeat = Workspace:GetAttribute("DistrictHeat") or 0
		local threatLevel = HeatMath.GetThreatLevel(districtHeat)
		local desiredCount = math.clamp(
			Constants.Drones.BaseCount + (threatLevel * Constants.Drones.MAX_DRONES_PER_THREAT),
			Constants.Drones.BaseCount,
			math.huge
		)

		local spawnInterval = math.clamp(
			Constants.Drones.SPAWN_INTERVAL_MAX - (Constants.Drones.SPAWN_INTERVAL_THREAT_STEP * threatLevel),
			Constants.Drones.SPAWN_INTERVAL_MIN,
			Constants.Drones.SPAWN_INTERVAL_MAX
		)

		spawnAccumulator += deltaTime
		if spawnAccumulator >= spawnInterval then
			spawnAccumulator = 0
			cleanupDroneState()

			local alive = 0
			for _, droneState in ipairs(drones) do
				if droneState.part.Parent then
					alive += 1
				end
			end

			while alive < desiredCount do
				spawnDrone()
				alive += 1
			end
			print(("[DroneDirector] Threat %d | DistrictHeat %.1f | Drones %d"):format(threatLevel, districtHeat, alive))
		end

		local speedMultiplier = 1 + (Constants.Drones.SpeedMultiplierPerThreat * threatLevel)
		for _, droneState in ipairs(drones) do
			if droneState.part.Parent and time() >= droneState.disabledUntil then
				droneState.part.Anchored = true
				droneState.part.CanCollide = false
				droneState.part.Color = Color3.fromRGB(180, 180, 180)

				local target = getNearestDangerPlayer(droneState.part.Position)
				if target then
					local root = target.Character and target.Character:FindFirstChild("HumanoidRootPart")
					if root and root:IsA("BasePart") then
						local offset = root.Position - droneState.part.Position
						if offset.Magnitude > 0.001 then
							local step = offset.Unit * Constants.Drones.BaseSpeed * speedMultiplier * deltaTime
							droneState.part.CFrame = CFrame.new(droneState.part.Position + step)
						end
					end
				end
			end
		end
	end
end)

print("[DroneDirector] Initialized")
