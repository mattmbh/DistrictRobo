local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

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

local function clearFolder(folder: Folder)
	for _, child in ipairs(folder:GetChildren()) do
		child:Destroy()
	end
end

local function createPart(config: {
	name: string,
	size: Vector3,
	position: Vector3,
	material: Enum.Material,
	color: Color3,
	reflectance: number?,
	transparency: number?,
	canCollide: boolean?,
	canTouch: boolean?,
	canQuery: boolean?,
	parent: Instance,
})
	local part = Instance.new("Part")
	part.Name = config.name
	part.Size = config.size
	part.Position = config.position
	part.Anchored = true
	part.Material = config.material
	part.Color = config.color
	part.Reflectance = config.reflectance or 0
	part.Transparency = config.transparency or 0
	part.CanCollide = if config.canCollide ~= nil then config.canCollide else true
	part.CanTouch = if config.canTouch ~= nil then config.canTouch else true
	part.CanQuery = if config.canQuery ~= nil then config.canQuery else true
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = config.parent
	return part
end

local function materialOrFallback(primary: Enum.Material, fallback: Enum.Material): Enum.Material
	local ok = pcall(function()
		local _ = primary.Name
	end)
	if ok then
		return primary
	end
	return fallback
end

type RoadLine = {
	center: number,
	width: number,
	isMain: boolean,
}

local function getWorldBounds(config: {[string]: any})
	local center = config.WorldCenter :: Vector3
	local halfSize = config.WorldHalfSizeXZ :: Vector2
	local groundY = 0.5

	local baseplate = Workspace:FindFirstChild("Baseplate")
	if config.UseBaseplateBounds and baseplate and baseplate:IsA("BasePart") then
		center = Vector3.new(baseplate.Position.X, center.Y, baseplate.Position.Z)
		halfSize = Vector2.new(
			math.max(40, baseplate.Size.X * 0.5 - config.BoundsMargin),
			math.max(40, baseplate.Size.Z * 0.5 - config.BoundsMargin)
		)
		groundY = baseplate.Position.Y + baseplate.Size.Y * 0.5 + config.BuildPadHeight * 0.5
	end

	return center, halfSize.X, halfSize.Y, groundY
end

local function buildAxisRoads(halfExtent: number, blockSize: number, mainWidth: number, sideWidth: number, blocksPerMain: number): {RoadLine}
	local roads: {RoadLine} = {
		{center = 0, width = mainWidth, isMain = true},
	}

	local function generateDirection(sign: number)
		local prevCenter = 0
		local prevWidth = mainWidth
		local roadIndex = 0

		while true do
			roadIndex += 1
			local isMain = roadIndex % blocksPerMain == 0
			local width = if isMain then mainWidth else sideWidth
			local nextCenter = prevCenter + sign * (prevWidth * 0.5 + blockSize + width * 0.5)
			if math.abs(nextCenter) - width * 0.5 > halfExtent then
				break
			end
			table.insert(roads, {
				center = nextCenter,
				width = width,
				isMain = isMain,
			})
			prevCenter = nextCenter
			prevWidth = width
		end
	end

	generateDirection(1)
	generateDirection(-1)

	table.sort(roads, function(a, b)
		return a.center < b.center
	end)

	return roads
end

local function createLaneMarks(
	parent: Instance,
	axis: "X" | "Z",
	roadCenterA: number,
	roadCenterB: number,
	roadY: number,
	halfExtent: number,
	config: {[string]: any}
)
	local length = config.LaneMarkLength
	local gap = config.LaneMarkGap
	local period = length + gap
	local startPos = -halfExtent + length * 0.5
	local endPos = halfExtent - length * 0.5
	local cursor = startPos
	local markIndex = 0

	while cursor <= endPos do
		markIndex += 1
		if axis == "X" then
			createPart({
				name = ("LaneMark_X_%d"):format(markIndex),
				size = Vector3.new(length, config.LaneMarkHeight, config.LaneMarkWidth),
				position = Vector3.new(roadCenterA + cursor, roadY + 0.53, roadCenterB),
				material = Enum.Material.SmoothPlastic,
				color = config.LaneMarkColor,
				reflectance = 0.02,
				canCollide = false,
				canTouch = false,
				canQuery = false,
				parent = parent,
			})
		else
			createPart({
				name = ("LaneMark_Z_%d"):format(markIndex),
				size = Vector3.new(config.LaneMarkWidth, config.LaneMarkHeight, length),
				position = Vector3.new(roadCenterA, roadY + 0.53, roadCenterB + cursor),
				material = Enum.Material.SmoothPlastic,
				color = config.LaneMarkColor,
				reflectance = 0.02,
				canCollide = false,
				canTouch = false,
				canQuery = false,
				parent = parent,
			})
		end
		cursor += period
	end
end

local function buildCityGrid()
	local config = Constants.CityLayout
	local center, halfX, halfZ, roadY = getWorldBounds(config)
	local roadMaterial = materialOrFallback(Enum.Material.Asphalt, Enum.Material.SmoothPlastic)

	local cityFolder = ensureFolder(Workspace, "City")
	local roadsFolder = ensureFolder(cityFolder, "Roads")
	local lotsFolder = ensureFolder(cityFolder, "Lots")
	local markingsFolder = ensureFolder(cityFolder, "Markings")
	local sidewalksFolder = ensureFolder(cityFolder, "Sidewalks")

	clearFolder(roadsFolder)
	clearFolder(lotsFolder)
	clearFolder(markingsFolder)
	clearFolder(sidewalksFolder)

	local xRoads = buildAxisRoads(
		halfX,
		config.BlockSize,
		config.RoadWidthMain,
		config.RoadWidthSide,
		math.max(1, config.BlocksPerMainRoad)
	)
	local zRoads = buildAxisRoads(
		halfZ,
		config.BlockSize,
		config.RoadWidthMain,
		config.RoadWidthSide,
		math.max(1, config.BlocksPerMainRoad)
	)

	local fullSpanX = halfX * 2
	local fullSpanZ = halfZ * 2

	for i, road in ipairs(xRoads) do
		local roadPart = createPart({
			name = ("Road_NS_%d"):format(i),
			size = Vector3.new(road.width, config.RoadThickness, fullSpanZ),
			position = Vector3.new(center.X + road.center, roadY, center.Z),
			material = roadMaterial,
			color = config.RoadColor,
			reflectance = 0.05,
			parent = roadsFolder,
		})

		if config.LaneMarkingsEnabled then
			createLaneMarks(markingsFolder, "Z", roadPart.Position.X, roadPart.Position.Z, roadY, halfZ, config)
		end

		if config.SidewalkEnabled then
			local curbOffset = road.width * 0.5 + config.SidewalkWidth * 0.5
			createPart({
				name = ("Sidewalk_NS_%d_L"):format(i),
				size = Vector3.new(config.SidewalkWidth, config.SidewalkHeight, fullSpanZ),
				position = roadPart.Position + Vector3.new(-curbOffset, config.SidewalkHeight * 0.5 + 0.5, 0),
				material = Enum.Material.Concrete,
				color = config.SidewalkColor,
				parent = sidewalksFolder,
			})
			createPart({
				name = ("Sidewalk_NS_%d_R"):format(i),
				size = Vector3.new(config.SidewalkWidth, config.SidewalkHeight, fullSpanZ),
				position = roadPart.Position + Vector3.new(curbOffset, config.SidewalkHeight * 0.5 + 0.5, 0),
				material = Enum.Material.Concrete,
				color = config.SidewalkColor,
				parent = sidewalksFolder,
			})
		end
	end

	for i, road in ipairs(zRoads) do
		local roadPart = createPart({
			name = ("Road_EW_%d"):format(i),
			size = Vector3.new(fullSpanX, config.RoadThickness, road.width),
			position = Vector3.new(center.X, roadY, center.Z + road.center),
			material = roadMaterial,
			color = config.RoadColor,
			reflectance = 0.05,
			parent = roadsFolder,
		})

		if config.LaneMarkingsEnabled then
			createLaneMarks(markingsFolder, "X", roadPart.Position.X, roadPart.Position.Z, roadY, halfX, config)
		end

		if config.SidewalkEnabled then
			local curbOffset = road.width * 0.5 + config.SidewalkWidth * 0.5
			createPart({
				name = ("Sidewalk_EW_%d_T"):format(i),
				size = Vector3.new(fullSpanX, config.SidewalkHeight, config.SidewalkWidth),
				position = roadPart.Position + Vector3.new(0, config.SidewalkHeight * 0.5 + 0.5, -curbOffset),
				material = Enum.Material.Concrete,
				color = config.SidewalkColor,
				parent = sidewalksFolder,
			})
			createPart({
				name = ("Sidewalk_EW_%d_B"):format(i),
				size = Vector3.new(fullSpanX, config.SidewalkHeight, config.SidewalkWidth),
				position = roadPart.Position + Vector3.new(0, config.SidewalkHeight * 0.5 + 0.5, curbOffset),
				material = Enum.Material.Concrete,
				color = config.SidewalkColor,
				parent = sidewalksFolder,
			})
		end
	end

	for xi = 1, #xRoads - 1 do
		local leftRoad = xRoads[xi]
		local rightRoad = xRoads[xi + 1]
		local leftInner = leftRoad.center + leftRoad.width * 0.5
		local rightInner = rightRoad.center - rightRoad.width * 0.5
		local padSizeX = rightInner - leftInner

		if padSizeX > 2 then
			for zi = 1, #zRoads - 1 do
				local topRoad = zRoads[zi]
				local bottomRoad = zRoads[zi + 1]
				local topInner = topRoad.center + topRoad.width * 0.5
				local bottomInner = bottomRoad.center - bottomRoad.width * 0.5
				local padSizeZ = bottomInner - topInner

				if padSizeZ > 2 then
					local padCenterX = (leftInner + rightInner) * 0.5
					local padCenterZ = (topInner + bottomInner) * 0.5
					createPart({
						name = ("BuildPad_%d_%d"):format(xi, zi),
						size = Vector3.new(padSizeX, config.BuildPadHeight, padSizeZ),
						position = Vector3.new(center.X + padCenterX, roadY, center.Z + padCenterZ),
						material = Enum.Material.SmoothPlastic,
						color = config.BuildPadColor,
						reflectance = 0.01,
						parent = lotsFolder,
					})
				end
			end
		end
	end

	print(("[CityLayout] World grid built. RoadsX=%d RoadsZ=%d Pads=%d"):format(#xRoads, #zRoads, #lotsFolder:GetChildren()))
end

buildCityGrid()
