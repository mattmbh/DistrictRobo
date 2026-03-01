local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Net = require(Shared:WaitForChild("Net"))

local districtChangedRemote = Net.GetOrCreateRemoteEvent(Constants.Remotes.DistrictChanged)

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

local function isPointInPart(part: BasePart, point: Vector3): boolean
	local relative = part.CFrame:PointToObjectSpace(point)
	local half = part.Size * 0.5
	return math.abs(relative.X) <= half.X
		and math.abs(relative.Y) <= half.Y
		and math.abs(relative.Z) <= half.Z
end

local function getDistrictFromPosition(position: Vector3): string
	if isPointInPart(zoneDanger, position) then
		return Constants.Districts.DANGEROUS
	end
	return Constants.Districts.SAFE
end

local function updatePlayerDistrict(player: Player, newDistrict: string)
	local currentDistrict = player:GetAttribute("DistrictId")
	if currentDistrict == newDistrict then
		return
	end

	player:SetAttribute("DistrictId", newDistrict)
	player:SetAttribute("InDangerZone", newDistrict == Constants.Districts.DANGEROUS)

	districtChangedRemote:FireClient(player, newDistrict)
	print(("[DistrictService] %s entered %s"):format(player.Name, newDistrict))
end

Players.PlayerAdded:Connect(function(player)
	player:SetAttribute("DistrictId", Constants.Districts.SAFE)
	player:SetAttribute("InDangerZone", false)

	player.CharacterAdded:Connect(function(character)
		task.wait(0.2)
		local rootPart = character:FindFirstChild("HumanoidRootPart")
		if rootPart and rootPart:IsA("BasePart") then
			local district = getDistrictFromPosition(rootPart.Position)
			updatePlayerDistrict(player, district)
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
				local district = getDistrictFromPosition(rootPart.Position)
				updatePlayerDistrict(player, district)
			end
		end
	end
end)

print("[DistrictService] Initialized with Zone_Safe and Zone_Danger")
