local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local ArenaBuildService = {}

type ArenaLot = {
	xi: number,
	zi: number,
	part: BasePart,
	center: Vector3,
	size: Vector3,
	minX: number,
	maxX: number,
	minZ: number,
	maxZ: number,
}

type ArenaBuildData = {
	lot: ArenaLot,
	arenaModel: Model,
	spawnA: BasePart,
	spawnB: BasePart,
	focusPoint: BasePart,
	cameraAnchor: BasePart,
	jumbotronScreen: BasePart,
	cleanBanner: BasePart,
}

local cachedBuildData: ArenaBuildData? = nil

local function ensureFolder(parent: Instance, name: string): Folder
	local existing = parent:FindFirstChild(name)
	if existing and existing:IsA("Folder") then
		return existing
	end

	local folder = Instance.new("Folder")
	folder.Name = name
	folder.Parent = parent
	return folder
end

local function createPart(parent: Instance, name: string, size: Vector3, cframe: CFrame, color: Color3, material: Enum.Material): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Material = material
	part.Color = color
	part.Parent = parent
	return part
end

local function parseLotIndices(name: string): (number?, number?)
	local xi, zi = string.match(name, "^BuildPad_(%d+)_(%d+)$")
	if not xi or not zi then
		return nil, nil
	end
	return tonumber(xi), tonumber(zi)
end

local function getLotsFolder(): Folder
	local world = Workspace:WaitForChild("World")
	local mapGenerated = world:WaitForChild("MapGenerated")
	return mapGenerated:WaitForChild("Lots") :: Folder
end

local function getSplitX(): number
	local world = Workspace:WaitForChild("World")
	local splitX = world:GetAttribute("SplitX")
	if typeof(splitX) == "number" then
		return splitX
	end
	return 0
end

local function isSafeLot(lot: ArenaLot, splitX: number): boolean
	local buffer = Constants.Arena.SafeSideBuffer
	return lot.maxX <= (splitX - buffer)
end

local function collectSafeLots(): {ArenaLot}
	local lotsFolder = getLotsFolder()
	local splitX = getSplitX()
	local safeLots = {}

	for _, child in ipairs(lotsFolder:GetChildren()) do
		if child:IsA("BasePart") and string.match(child.Name, "^BuildPad_") then
			local xi, zi = parseLotIndices(child.Name)
			if xi and zi then
				local half = child.Size * 0.5
				local lot: ArenaLot = {
					xi = xi,
					zi = zi,
					part = child,
					center = child.Position,
					size = child.Size,
					minX = child.Position.X - half.X,
					maxX = child.Position.X + half.X,
					minZ = child.Position.Z - half.Z,
					maxZ = child.Position.Z + half.Z,
				}

				if isSafeLot(lot, splitX) then
					table.insert(safeLots, lot)
				end
			end
		end
	end

	table.sort(safeLots, function(a, b)
		local scoreA = math.abs(a.center.Z) + math.abs(a.center.X) * 0.2
		local scoreB = math.abs(b.center.Z) + math.abs(b.center.X) * 0.2
		if scoreA == scoreB then
			if a.xi == b.xi then
				return a.zi < b.zi
			end
			return a.xi > b.xi
		end
		return scoreA < scoreB
	end)

	return safeLots
end

local function removePlaceholderForLot(lot: ArenaLot)
	local lotsFolder = getLotsFolder()
	local placeholderName = ("PlaceholderBuilding_%d_%d"):format(lot.xi, lot.zi)
	local placeholder = lotsFolder:FindFirstChild(placeholderName)
	if placeholder and placeholder:IsA("BasePart") then
		placeholder:Destroy()
		print(("[ArenaBuild] Removed placeholder %s to clear arena plot"):format(placeholderName))
	end
end

local function buildArenaGeometry(lot: ArenaLot): ArenaBuildData
	local world = Workspace:WaitForChild("World")
	local arenaFolder = ensureFolder(world, "Arena")
	local existing = arenaFolder:FindFirstChild("Venue")
	if existing then
		existing:Destroy()
	end

	removePlaceholderForLot(lot)

	local arenaModel = Instance.new("Model")
	arenaModel.Name = "Venue"
	arenaModel.Parent = arenaFolder

	local inset = Constants.Arena.LotInset
	local usableSize = Vector3.new(
		math.max(36, lot.size.X - inset * 2),
		Constants.Arena.FloorHeight,
		math.max(36, lot.size.Z - inset * 2)
	)
	local floorY = lot.center.Y + (lot.size.Y * 0.5) + usableSize.Y * 0.5
	local arenaCenter = Vector3.new(lot.center.X, floorY, lot.center.Z)
	local wallThickness = 3
	local wallHeight = Constants.Arena.WallHeight
	local entranceWidth = 26
	local interiorWallInsetX = usableSize.X * 0.5 - wallThickness

	local floor = createPart(
		arenaModel,
		"ArenaFloor",
		usableSize,
		CFrame.new(arenaCenter),
		Color3.fromRGB(57, 60, 66),
		Enum.Material.Concrete
	)

	createPart(
		arenaModel,
		"NorthWall",
		Vector3.new(usableSize.X, wallHeight, wallThickness),
		CFrame.new(arenaCenter + Vector3.new(0, wallHeight * 0.5, -(usableSize.Z * 0.5 - wallThickness * 0.5))),
		Color3.fromRGB(43, 46, 52),
		Enum.Material.Metal
	)
	createPart(
		arenaModel,
		"SouthWall",
		Vector3.new(usableSize.X, wallHeight, wallThickness),
		CFrame.new(arenaCenter + Vector3.new(0, wallHeight * 0.5, usableSize.Z * 0.5 - wallThickness * 0.5)),
		Color3.fromRGB(43, 46, 52),
		Enum.Material.Metal
	)
	createPart(
		arenaModel,
		"WestWall",
		Vector3.new(wallThickness, wallHeight, usableSize.Z - entranceWidth),
		CFrame.new(arenaCenter + Vector3.new(-(usableSize.X * 0.5 - wallThickness * 0.5), wallHeight * 0.5, entranceWidth * 0.5)),
		Color3.fromRGB(43, 46, 52),
		Enum.Material.Metal
	)
	createPart(
		arenaModel,
		"EastWall",
		Vector3.new(wallThickness, wallHeight, usableSize.Z - entranceWidth),
		CFrame.new(arenaCenter + Vector3.new(usableSize.X * 0.5 - wallThickness * 0.5, wallHeight * 0.5, entranceWidth * 0.5)),
		Color3.fromRGB(43, 46, 52),
		Enum.Material.Metal
	)

	createPart(
		arenaModel,
		"EntranceLintel",
		Vector3.new(usableSize.X * 0.38, 3.2, 2.2),
		CFrame.new(arenaCenter + Vector3.new(0, 8.5, usableSize.Z * 0.5 - 2.4)),
		Color3.fromRGB(108, 77, 38),
		Enum.Material.Metal
	)

	local pitRadius = Constants.Arena.PitRadius
	local pitDepth = Constants.Arena.PitDepth
	createPart(
		arenaModel,
		"FightPit",
		Vector3.new(pitRadius * 2.4, 1, pitRadius * 2.0),
		CFrame.new(arenaCenter + Vector3.new(0, -pitDepth * 0.5, 0)),
		Color3.fromRGB(28, 30, 33),
		Enum.Material.Asphalt
	)

	createPart(
		arenaModel,
		"FightRing",
		Vector3.new(pitRadius * 2.8, 1.2, pitRadius * 2.4),
		CFrame.new(arenaCenter + Vector3.new(0, 0.6, 0)),
		Color3.fromRGB(124, 90, 50),
		Enum.Material.Metal
	)

	for row = 1, 3 do
		local depth = 8 + (row - 1) * 7
		local height = 1 + (row - 1) * 2
		createPart(
			arenaModel,
			("BleacherNorth_%d"):format(row),
			Vector3.new(usableSize.X - 26, 2, 6),
			CFrame.new(arenaCenter + Vector3.new(0, height, -(pitRadius + depth))),
			Color3.fromRGB(83, 87, 94),
			Enum.Material.Metal
		)
		createPart(
			arenaModel,
			("BleacherSouth_%d"):format(row),
			Vector3.new(usableSize.X - 26, 2, 6),
			CFrame.new(arenaCenter + Vector3.new(0, height, pitRadius + depth)),
			Color3.fromRGB(83, 87, 94),
			Enum.Material.Metal
		)
	end

	local standingNorth = createPart(
		arenaModel,
		"StandingZoneNorth",
		Vector3.new(usableSize.X - 20, 0.4, 10),
		CFrame.new(arenaCenter + Vector3.new(0, 0.2, -(usableSize.Z * 0.5 - 9))),
		Color3.fromRGB(66, 69, 74),
		Enum.Material.Concrete
	)
	standingNorth.CanCollide = true

	local standingSouth = createPart(
		arenaModel,
		"StandingZoneSouth",
		Vector3.new(usableSize.X - 20, 0.4, 10),
		CFrame.new(arenaCenter + Vector3.new(0, 0.2, usableSize.Z * 0.5 - 9)),
		Color3.fromRGB(66, 69, 74),
		Enum.Material.Concrete
	)
	standingSouth.CanCollide = true

	local spawnHeight = 3
	local spawnA = createPart(
		arenaModel,
		"FighterSpawnA",
		Vector3.new(4, 1, 4),
		CFrame.new(arenaCenter + Vector3.new(-Constants.Arena.SpawnOffset, spawnHeight * 0.5, 0)),
		Color3.fromRGB(193, 89, 89),
		Enum.Material.SmoothPlastic
	)
	spawnA.Transparency = 0.35

	local spawnB = createPart(
		arenaModel,
		"FighterSpawnB",
		Vector3.new(4, 1, 4),
		CFrame.new(arenaCenter + Vector3.new(Constants.Arena.SpawnOffset, spawnHeight * 0.5, 0)),
		Color3.fromRGB(86, 127, 194),
		Enum.Material.SmoothPlastic
	)
	spawnB.Transparency = 0.35

	local focusPoint = createPart(
		arenaModel,
		"FocusPoint",
		Vector3.new(1, 1, 1),
		CFrame.new(arenaCenter + Vector3.new(0, 8, 0)),
		Color3.fromRGB(255, 212, 92),
		Enum.Material.Neon
	)
	focusPoint.Transparency = 1
	focusPoint.CanCollide = false
	focusPoint.CanTouch = false
	focusPoint.CanQuery = false

	local cameraAnchor = createPart(
		arenaModel,
		"CameraAnchor",
		Vector3.new(1, 1, 1),
		CFrame.lookAt(
			arenaCenter + Vector3.new(-(usableSize.X * 0.5 - 18), 20, -(usableSize.Z * 0.5 - 18)),
			arenaCenter + Vector3.new(0, 5, 0)
		),
		Color3.fromRGB(255, 212, 92),
		Enum.Material.Neon
	)
	cameraAnchor.Transparency = 1
	cameraAnchor.CanCollide = false
	cameraAnchor.CanTouch = false
	cameraAnchor.CanQuery = false

	local marqueeBacking = createPart(
		arenaModel,
		"MarqueeBacking",
		Vector3.new(0.34, 7.2, 18.4),
		CFrame.new(arenaCenter + Vector3.new(-(interiorWallInsetX - 0.12), 12, 0)),
		Color3.fromRGB(28, 31, 36),
		Enum.Material.SmoothPlastic
	)
	marqueeBacking.CastShadow = false

	local marquee = createPart(
		arenaModel,
		"Marquee",
		Vector3.new(0.08, 6.5, 17.2),
		CFrame.new(arenaCenter + Vector3.new(-(interiorWallInsetX - 0.34), 12, 0)),
		Color3.fromRGB(215, 162, 72),
		Enum.Material.SmoothPlastic
	)
	marquee.CastShadow = false

	local jumbotronFrame = createPart(
		arenaModel,
		"JumbotronFrame",
		Vector3.new(0.34, 13, 28.4),
		CFrame.new(arenaCenter + Vector3.new(interiorWallInsetX - 0.12, 12, 0)),
		Color3.fromRGB(28, 31, 36),
		Enum.Material.SmoothPlastic
	)
	jumbotronFrame.CastShadow = false

	local jumbotronScreen = createPart(
		arenaModel,
		"JumbotronScreen",
		Vector3.new(0.08, 10.5, 24),
		CFrame.new(arenaCenter + Vector3.new(interiorWallInsetX - 0.34, 12, 0)),
		Color3.fromRGB(18, 24, 31),
		Enum.Material.SmoothPlastic
	)
	jumbotronScreen.CastShadow = false

	local cleanBanner = createPart(
		arenaModel,
		"OppositeWallBanner",
		Vector3.new(0.34, 10, 20),
		CFrame.new(arenaCenter + Vector3.new(-(usableSize.X * 0.5 - 0.98), 11, 0)),
		Color3.fromRGB(36, 40, 48),
		Enum.Material.SmoothPlastic
	)

	local bannerInset = createPart(
		arenaModel,
		"OppositeWallBannerInset",
		Vector3.new(0.12, 8, 16),
		cleanBanner.CFrame * CFrame.new(0.1, 0, 0),
		Color3.fromRGB(118, 84, 40),
		Enum.Material.SmoothPlastic
	)
	bannerInset.CastShadow = false

	for _, zSign in ipairs({-1, 1}) do
		local lightMount = createPart(
			arenaModel,
			("WallLightMount_%d"):format(zSign),
			Vector3.new(1.1, 7.5, 0.9),
			CFrame.new(arenaCenter + Vector3.new(usableSize.X * 0.5 - 3.25, 14, zSign * (usableSize.Z * 0.26))),
			Color3.fromRGB(58, 62, 70),
			Enum.Material.Metal
		)
		local lightStrip = createPart(
			arenaModel,
			("WallLightStrip_%d"):format(zSign),
			Vector3.new(0.35, 5.6, 0.35),
			lightMount.CFrame * CFrame.new(-0.5, 0, 0),
			Color3.fromRGB(255, 240, 208),
			Enum.Material.Neon
		)
		lightStrip.CastShadow = false

		local pointLight = Instance.new("PointLight")
		pointLight.Range = 36
		pointLight.Brightness = 1.6
		pointLight.Color = Color3.fromRGB(255, 233, 196)
		pointLight.Parent = lightStrip
	end

	arenaModel:SetAttribute("LotId", ("%d_%d"):format(lot.xi, lot.zi))
	arenaModel:SetAttribute("SafeDistrict", true)
	arenaModel:SetAttribute("LotCenter", lot.center)
	arenaModel:SetAttribute("FocusPoint", focusPoint.Position)
	arenaModel:SetAttribute("CameraAnchor", cameraAnchor.Position)
	arenaModel.PrimaryPart = floor

	print(("[ArenaBuild] Arena placed on BuildPad_%d_%d at (%.1f, %.1f, %.1f)"):format(
		lot.xi,
		lot.zi,
		lot.center.X,
		lot.center.Y,
		lot.center.Z
	))
	print(("[ArenaBuild] SAFE confirmation: splitX=%.1f lotMaxX=%.1f buffer=%d"):format(
		getSplitX(),
		lot.maxX,
		Constants.Arena.SafeSideBuffer
	))

	return {
		lot = lot,
		arenaModel = arenaModel,
		spawnA = spawnA,
		spawnB = spawnB,
		focusPoint = focusPoint,
		cameraAnchor = cameraAnchor,
		jumbotronScreen = jumbotronScreen,
		cleanBanner = cleanBanner,
	}
end

function ArenaBuildService.BuildArena(): ArenaBuildData
	if cachedBuildData then
		return cachedBuildData
	end

	local safeLots = collectSafeLots()
	assert(#safeLots > 0, "[ArenaBuild] No SAFE lot candidates were found for arena placement")

	cachedBuildData = buildArenaGeometry(safeLots[1])
	return cachedBuildData
end

function ArenaBuildService.GetArenaData(): ArenaBuildData
	return ArenaBuildService.BuildArena()
end

return ArenaBuildService
