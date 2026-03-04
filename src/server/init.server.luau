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

local function collectStraightSpans(halfExtent: number, crossRoads: {RoadLine}): {{startPos: number, endPos: number}}
	local spans = {}
	local cursor = -halfExtent

	for _, crossRoad in ipairs(crossRoads) do
		local intersectionStart = crossRoad.center - crossRoad.width * 0.5
		local intersectionEnd = crossRoad.center + crossRoad.width * 0.5
		if intersectionStart > cursor then
			table.insert(spans, {
				startPos = cursor,
				endPos = intersectionStart,
			})
		end
		cursor = math.max(cursor, intersectionEnd)
	end

	if cursor < halfExtent then
		table.insert(spans, {
			startPos = cursor,
			endPos = halfExtent,
		})
	end

	return spans
end

local function createDashedCenterLine(
	parent: Instance,
	axis: "X" | "Z",
	roadCenterA: number,
	roadCenterB: number,
	roadY: number,
	spanStart: number,
	spanEnd: number,
	config: {[string]: any}
)
	local length = config.LaneMarkLength
	local gap = config.LaneMarkGap
	local period = length + gap
	local stopOffset = config.LaneMarkEndOffset or 4
	local dashStart = spanStart + stopOffset
	local dashEnd = spanEnd - stopOffset

	if dashEnd - dashStart < length then
		return
	end

	local cursor = dashStart + length * 0.5
	local markIndex = 0

	while cursor <= dashEnd - length * 0.5 do
		markIndex += 1
		if axis == "X" then
			createPart({
				name = ("LaneMark_X_%d_%.0f"):format(markIndex, roadCenterB),
				size = Vector3.new(length, config.LaneMarkHeight, config.LaneMarkWidth),
				position = Vector3.new(roadCenterA + cursor, roadY + config.RoadThickness * 0.5 + config.LaneMarkHeight * 0.5, roadCenterB),
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
				name = ("LaneMark_Z_%d_%.0f"):format(markIndex, roadCenterA),
				size = Vector3.new(config.LaneMarkWidth, config.LaneMarkHeight, length),
				position = Vector3.new(roadCenterA, roadY + config.RoadThickness * 0.5 + config.LaneMarkHeight * 0.5, roadCenterB + cursor),
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

local function createCurbLip(
	parent: Instance,
	name: string,
	position: Vector3,
	roadY: number,
	isAlongX: boolean,
	length: number,
	config: {[string]: any}
)
	local curbTopY = roadY + config.RoadThickness * 0.5 + config.SidewalkHeight
	local curbCenterY = curbTopY - config.CurbHeight * 0.5
	createPart({
		name = name,
		size = if isAlongX
			then Vector3.new(length, config.CurbHeight, config.CurbThickness)
			else Vector3.new(config.CurbThickness, config.CurbHeight, length),
		position = Vector3.new(position.X, curbCenterY, position.Z),
		material = Enum.Material.Concrete,
		color = config.CurbColor,
		parent = parent,
	})
end

local function createCrosswalkRect(
	parent: Instance,
	centerPos: Vector3,
	size: Vector3,
	roadY: number,
	config: {[string]: any},
	namePrefix: string,
	intersectionBounds: {minX: number, maxX: number, minZ: number, maxZ: number}
)
	local part = createPart({
		name = namePrefix,
		size = size,
		position = Vector3.new(centerPos.X, roadY + config.RoadThickness * 0.5 + config.CrosswalkHeight * 0.5, centerPos.Z),
		material = Enum.Material.SmoothPlastic,
		color = config.LaneMarkColor,
		reflectance = 0,
		canCollide = false,
		canTouch = false,
		canQuery = false,
		parent = parent,
	})
	part.CastShadow = false

	local halfSize = part.Size * 0.5
	assert(
		part.Position.X - halfSize.X >= intersectionBounds.minX - 0.01
			and part.Position.X + halfSize.X <= intersectionBounds.maxX + 0.01
			and part.Position.Z - halfSize.Z >= intersectionBounds.minZ - 0.01
			and part.Position.Z + halfSize.Z <= intersectionBounds.maxZ + 0.01,
		("[CityLayout] Crosswalk part outside intersection AABB: %s"):format(part.Name)
	)
	return 1
end

local function createStreetLight(parent: Instance, name: string, basePosition: Vector3, armDirection: Vector3, config: {[string]: any})
	local poleHeight = 14
	local armLength = 4
	local lampOffset = 0.8

	local lightModel = Instance.new("Model")
	lightModel.Name = name
	lightModel.Parent = parent

	local pole = createPart({
		name = "Pole",
		size = Vector3.new(0.6, poleHeight, 0.6),
		position = basePosition + Vector3.new(0, poleHeight * 0.5, 0),
		material = Enum.Material.Metal,
		color = Color3.fromRGB(88, 92, 100),
		parent = lightModel,
	})

	createPart({
		name = "Arm",
		size = Vector3.new(0.35, 0.35, armLength),
		position = pole.Position + Vector3.new(armDirection.X * (armLength * 0.5), poleHeight * 0.42, armDirection.Z * (armLength * 0.5)),
		material = Enum.Material.Metal,
		color = Color3.fromRGB(104, 108, 116),
		parent = lightModel,
	}).CFrame = CFrame.lookAt(
		pole.Position + Vector3.new(0, poleHeight * 0.42, 0),
		pole.Position + Vector3.new(armDirection.X, poleHeight * 0.42, armDirection.Z)
	) * CFrame.new(0, 0, -armLength * 0.5)

	local lampHead = createPart({
		name = "LampHead",
		size = Vector3.new(0.9, 0.5, 0.9),
		position = pole.Position
			+ Vector3.new(armDirection.X * (armLength + lampOffset), poleHeight * 0.42 - 0.2, armDirection.Z * (armLength + lampOffset)),
		material = Enum.Material.Metal,
		color = Color3.fromRGB(126, 126, 128),
		parent = lightModel,
	})

	local pointLight = Instance.new("PointLight")
	pointLight.Name = "StreetLight"
	pointLight.Color = config.StreetLightColor
	pointLight.Brightness = config.StreetLightBrightness
	pointLight.Range = config.StreetLightRange
	pointLight.Shadows = true
	pointLight.Parent = lampHead
end

local function spawnStreetLightsAlongSegment(
	parent: Instance,
	axis: "X" | "Z",
	fixedCoord: number,
	baseY: number,
	spanStart: number,
	spanEnd: number,
	roadSideSign: number,
	config: {[string]: any},
	namePrefix: string
)
	local inset = math.max(2, config.StreetLightCornerInset)
	local spacing = math.max(20, config.StreetLightSpacing)
	local cursor = spanStart + inset
	local endPos = spanEnd - inset
	local index = 0

	if endPos <= cursor then
		return
	end

	while cursor <= endPos do
		index += 1
		if axis == "X" then
			local basePosition = Vector3.new(cursor, baseY, fixedCoord)
			createStreetLight(parent, ("%s_%d"):format(namePrefix, index), basePosition, Vector3.new(0, 0, -roadSideSign), config)
		else
			local basePosition = Vector3.new(fixedCoord, baseY, cursor)
			createStreetLight(parent, ("%s_%d"):format(namePrefix, index), basePosition, Vector3.new(-roadSideSign, 0, 0), config)
		end
		cursor += spacing
	end
end

local function shouldPlacePlaceholderBuilding(xi: number, zi: number, chance: number): boolean
	local hash = math.abs(math.sin(xi * 12.9898 + zi * 78.233) * 43758.5453123)
	return (hash - math.floor(hash)) < chance
end

local function buildCityGrid()
	local config = Constants.CityLayout
	local center, halfX, halfZ, roadY = getWorldBounds(config)
	local roadMaterial = materialOrFallback(Enum.Material.Asphalt, Enum.Material.SmoothPlastic)

	local worldFolder = ensureFolder(Workspace, "World")
	local cityFolder = ensureFolder(worldFolder, "MapGenerated")
	local roadsFolder = ensureFolder(cityFolder, "Roads")
	local intersectionsFolder = ensureFolder(cityFolder, "Intersections")
	local crosswalksFolder = ensureFolder(cityFolder, "Crosswalks")
	local lotsFolder = ensureFolder(cityFolder, "Lots")
	local markingsFolder = ensureFolder(cityFolder, "Markings")
	local sidewalksFolder = ensureFolder(cityFolder, "Sidewalks")
	local streetLightsFolder = ensureFolder(cityFolder, "StreetLights")
	clearFolder(crosswalksFolder)

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

	local zSpans = collectStraightSpans(halfZ, zRoads)
	local xSpans = collectStraightSpans(halfX, xRoads)
	local intersectionsProcessed = 0
	local crosswalkParts = 0

	for xi, xRoad in ipairs(xRoads) do
		for zi, zRoad in ipairs(zRoads) do
			intersectionsProcessed += 1
			local intersectionCenter = Vector3.new(center.X + xRoad.center, roadY, center.Z + zRoad.center)
			createPart({
				name = ("Intersection_%d_%d"):format(xi, zi),
				size = Vector3.new(xRoad.width, config.RoadThickness, zRoad.width),
				position = intersectionCenter,
				material = roadMaterial,
				color = config.RoadColor,
				reflectance = 0.05,
				parent = intersectionsFolder,
			})

			if config.CrosswalkEnabled then
				local roadWidthX = xRoad.width
				local roadWidthZ = zRoad.width
				local curbGap = config.CurbGap or config.CrosswalkInset
				local crosswalkDepth = config.CrosswalkDepth or config.CrosswalkBandDepth
				local edgeX = roadWidthX * 0.5 - curbGap
				local edgeZ = roadWidthZ * 0.5 - curbGap
				local spanX = math.max(0, roadWidthX - (config.SidewalkWidth * 2) - (curbGap * 2))
				local spanZ = math.max(0, roadWidthZ - (config.SidewalkWidth * 2) - (curbGap * 2))
				local effectiveDepth = math.max(0.5, math.min(crosswalkDepth, math.min(roadWidthX, roadWidthZ)))
				local northCenter = intersectionCenter + Vector3.new(0, 0, -(edgeZ - effectiveDepth * 0.5))
				local southCenter = intersectionCenter + Vector3.new(0, 0, edgeZ - effectiveDepth * 0.5)
				local westCenter = intersectionCenter + Vector3.new(-(edgeX - effectiveDepth * 0.5), 0, 0)
				local eastCenter = intersectionCenter + Vector3.new(edgeX - effectiveDepth * 0.5, 0, 0)
				local intersectionBounds = {
					minX = intersectionCenter.X - roadWidthX * 0.5,
					maxX = intersectionCenter.X + roadWidthX * 0.5,
					minZ = intersectionCenter.Z - roadWidthZ * 0.5,
					maxZ = intersectionCenter.Z + roadWidthZ * 0.5,
				}

				if spanX > 0 then
					crosswalkParts += createCrosswalkRect(
						crosswalksFolder,
						northCenter,
						Vector3.new(spanX, config.CrosswalkHeight, effectiveDepth),
						roadY,
						config,
						("Crosswalk_N_%d_%d"):format(xi, zi),
						intersectionBounds
					)
					crosswalkParts += createCrosswalkRect(
						crosswalksFolder,
						southCenter,
						Vector3.new(spanX, config.CrosswalkHeight, effectiveDepth),
						roadY,
						config,
						("Crosswalk_S_%d_%d"):format(xi, zi),
						intersectionBounds
					)
				end

				if spanZ > 0 then
					crosswalkParts += createCrosswalkRect(
						crosswalksFolder,
						westCenter,
						Vector3.new(effectiveDepth, config.CrosswalkHeight, spanZ),
						roadY,
						config,
						("Crosswalk_W_%d_%d"):format(xi, zi),
						intersectionBounds
					)
					crosswalkParts += createCrosswalkRect(
						crosswalksFolder,
						eastCenter,
						Vector3.new(effectiveDepth, config.CrosswalkHeight, spanZ),
						roadY,
						config,
						("Crosswalk_E_%d_%d"):format(xi, zi),
						intersectionBounds
					)
				end
			end
		end
	end

	for i, road in ipairs(xRoads) do
		for spanIndex, span in ipairs(zSpans) do
			local segmentLength = span.endPos - span.startPos
			if segmentLength > 1 then
				local segmentCenterZ = (span.startPos + span.endPos) * 0.5
				local roadPart = createPart({
					name = ("Road_NS_%d_%d"):format(i, spanIndex),
					size = Vector3.new(road.width, config.RoadThickness, segmentLength),
					position = Vector3.new(center.X + road.center, roadY, center.Z + segmentCenterZ),
					material = roadMaterial,
					color = config.RoadColor,
					reflectance = 0.05,
					parent = roadsFolder,
				})

				if config.LaneMarkingsEnabled then
					createDashedCenterLine(
						markingsFolder,
						"Z",
						roadPart.Position.X,
						center.Z,
						roadY,
						span.startPos,
						span.endPos,
						config
					)
				end

				if config.SidewalkEnabled then
					local curbOffset = road.width * 0.5 + config.SidewalkWidth * 0.5
					local sidewalkLeft = createPart({
						name = ("Sidewalk_NS_%d_%d_L"):format(i, spanIndex),
						size = Vector3.new(config.SidewalkWidth, config.SidewalkHeight, segmentLength),
						position = roadPart.Position + Vector3.new(-curbOffset, config.SidewalkHeight * 0.5 + 0.5, 0),
						material = Enum.Material.Concrete,
						color = config.SidewalkColor,
						parent = sidewalksFolder,
					})
					local sidewalkRight = createPart({
						name = ("Sidewalk_NS_%d_%d_R"):format(i, spanIndex),
						size = Vector3.new(config.SidewalkWidth, config.SidewalkHeight, segmentLength),
						position = roadPart.Position + Vector3.new(curbOffset, config.SidewalkHeight * 0.5 + 0.5, 0),
						material = Enum.Material.Concrete,
						color = config.SidewalkColor,
						parent = sidewalksFolder,
					})

					createCurbLip(
						sidewalksFolder,
						("Curb_NS_%d_%d_L"):format(i, spanIndex),
						sidewalkLeft.Position + Vector3.new(config.SidewalkWidth * 0.5 - config.CurbThickness * 0.5, 0, 0),
						roadY,
						false,
						segmentLength,
						config
					)
					createCurbLip(
						sidewalksFolder,
						("Curb_NS_%d_%d_R"):format(i, spanIndex),
						sidewalkRight.Position + Vector3.new(-config.SidewalkWidth * 0.5 + config.CurbThickness * 0.5, 0, 0),
						roadY,
						false,
						segmentLength,
						config
					)

					if config.StreetLightsEnabled then
						spawnStreetLightsAlongSegment(
							streetLightsFolder,
							"Z",
							sidewalkLeft.Position.X,
							sidewalkLeft.Position.Y + config.SidewalkHeight * 0.5,
							center.Z + span.startPos,
							center.Z + span.endPos,
							-1,
							config,
							("Light_NS_%d_%d_L"):format(i, spanIndex)
						)
						spawnStreetLightsAlongSegment(
							streetLightsFolder,
							"Z",
							sidewalkRight.Position.X,
							sidewalkRight.Position.Y + config.SidewalkHeight * 0.5,
							center.Z + span.startPos,
							center.Z + span.endPos,
							1,
							config,
							("Light_NS_%d_%d_R"):format(i, spanIndex)
						)
					end
				end
			end
		end
	end

	for i, road in ipairs(zRoads) do
		for spanIndex, span in ipairs(xSpans) do
			local segmentLength = span.endPos - span.startPos
			if segmentLength > 1 then
				local segmentCenterX = (span.startPos + span.endPos) * 0.5
				local roadPart = createPart({
					name = ("Road_EW_%d_%d"):format(i, spanIndex),
					size = Vector3.new(segmentLength, config.RoadThickness, road.width),
					position = Vector3.new(center.X + segmentCenterX, roadY, center.Z + road.center),
					material = roadMaterial,
					color = config.RoadColor,
					reflectance = 0.05,
					parent = roadsFolder,
				})

				if config.LaneMarkingsEnabled then
					createDashedCenterLine(
						markingsFolder,
						"X",
						center.X,
						roadPart.Position.Z,
						roadY,
						span.startPos,
						span.endPos,
						config
					)
				end

				if config.SidewalkEnabled then
					local curbOffset = road.width * 0.5 + config.SidewalkWidth * 0.5
					local sidewalkTop = createPart({
						name = ("Sidewalk_EW_%d_%d_T"):format(i, spanIndex),
						size = Vector3.new(segmentLength, config.SidewalkHeight, config.SidewalkWidth),
						position = roadPart.Position + Vector3.new(0, config.SidewalkHeight * 0.5 + 0.5, -curbOffset),
						material = Enum.Material.Concrete,
						color = config.SidewalkColor,
						parent = sidewalksFolder,
					})
					local sidewalkBottom = createPart({
						name = ("Sidewalk_EW_%d_%d_B"):format(i, spanIndex),
						size = Vector3.new(segmentLength, config.SidewalkHeight, config.SidewalkWidth),
						position = roadPart.Position + Vector3.new(0, config.SidewalkHeight * 0.5 + 0.5, curbOffset),
						material = Enum.Material.Concrete,
						color = config.SidewalkColor,
						parent = sidewalksFolder,
					})

					createCurbLip(
						sidewalksFolder,
						("Curb_EW_%d_%d_T"):format(i, spanIndex),
						sidewalkTop.Position + Vector3.new(0, 0, config.SidewalkWidth * 0.5 - config.CurbThickness * 0.5),
						roadY,
						true,
						segmentLength,
						config
					)
					createCurbLip(
						sidewalksFolder,
						("Curb_EW_%d_%d_B"):format(i, spanIndex),
						sidewalkBottom.Position + Vector3.new(0, 0, -config.SidewalkWidth * 0.5 + config.CurbThickness * 0.5),
						roadY,
						true,
						segmentLength,
						config
					)

					if config.StreetLightsEnabled then
						spawnStreetLightsAlongSegment(
							streetLightsFolder,
							"X",
							sidewalkTop.Position.Z,
							sidewalkTop.Position.Y + config.SidewalkHeight * 0.5,
							center.X + span.startPos,
							center.X + span.endPos,
							-1,
							config,
							("Light_EW_%d_%d_T"):format(i, spanIndex)
						)
						spawnStreetLightsAlongSegment(
							streetLightsFolder,
							"X",
							sidewalkBottom.Position.Z,
							sidewalkBottom.Position.Y + config.SidewalkHeight * 0.5,
							center.X + span.startPos,
							center.X + span.endPos,
							1,
							config,
							("Light_EW_%d_%d_B"):format(i, spanIndex)
						)
					end
				end
			end
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
						material = Enum.Material.Concrete,
						color = config.BuildPadColor,
						reflectance = 0.01,
						parent = lotsFolder,
					})

					local borderY = roadY + config.BuildPadHeight * 0.5 + config.LotBorderHeight * 0.5
					createPart({
						name = ("LotBorder_N_%d_%d"):format(xi, zi),
						size = Vector3.new(padSizeX, config.LotBorderHeight, config.LotBorderThickness),
						position = Vector3.new(center.X + padCenterX, borderY, center.Z + topInner + config.LotBorderThickness * 0.5),
						material = Enum.Material.Concrete,
						color = config.LotBorderColor,
						parent = lotsFolder,
					})
					createPart({
						name = ("LotBorder_S_%d_%d"):format(xi, zi),
						size = Vector3.new(padSizeX, config.LotBorderHeight, config.LotBorderThickness),
						position = Vector3.new(center.X + padCenterX, borderY, center.Z + bottomInner - config.LotBorderThickness * 0.5),
						material = Enum.Material.Concrete,
						color = config.LotBorderColor,
						parent = lotsFolder,
					})
					createPart({
						name = ("LotBorder_W_%d_%d"):format(xi, zi),
						size = Vector3.new(config.LotBorderThickness, config.LotBorderHeight, padSizeZ),
						position = Vector3.new(center.X + leftInner + config.LotBorderThickness * 0.5, borderY, center.Z + padCenterZ),
						material = Enum.Material.Concrete,
						color = config.LotBorderColor,
						parent = lotsFolder,
					})
					createPart({
						name = ("LotBorder_E_%d_%d"):format(xi, zi),
						size = Vector3.new(config.LotBorderThickness, config.LotBorderHeight, padSizeZ),
						position = Vector3.new(center.X + rightInner - config.LotBorderThickness * 0.5, borderY, center.Z + padCenterZ),
						material = Enum.Material.Concrete,
						color = config.LotBorderColor,
						parent = lotsFolder,
					})

					if config.PlaceholderBuildingsEnabled and shouldPlacePlaceholderBuilding(xi, zi, config.PlaceholderBuildingChance) then
						local footprint = math.max(8, math.min(padSizeX, padSizeZ) * config.PlaceholderBuildingFootprintScale)
						createPart({
							name = ("PlaceholderBuilding_%d_%d"):format(xi, zi),
							size = Vector3.new(footprint, config.PlaceholderBuildingHeight, footprint),
							position = Vector3.new(
								center.X + padCenterX,
								roadY + config.BuildPadHeight * 0.5 + config.PlaceholderBuildingHeight * 0.5,
								center.Z + padCenterZ
							),
							material = Enum.Material.Concrete,
							color = Color3.fromRGB(78, 82, 92),
							parent = lotsFolder,
						})
					end
				end
			end
		end
	end

	local expectedIntersections = #xRoads * #zRoads
	assert(
		#intersectionsFolder:GetChildren() == expectedIntersections,
		("[CityLayout] Intersection count mismatch. expected=%d got=%d")
			:format(expectedIntersections, #intersectionsFolder:GetChildren())
	)
	if config.CrosswalkEnabled then
		assert(
			crosswalkParts == expectedIntersections * 4,
			("[CityLayout] Crosswalk part count mismatch. expected=%d got=%d")
				:format(expectedIntersections * 4, crosswalkParts)
		)
	end
	for _, folder in ipairs({markingsFolder, crosswalksFolder}) do
		for _, child in ipairs(folder:GetDescendants()) do
			if child:IsA("BasePart") then
				assert(child.Material ~= Enum.Material.Neon, "[CityLayout] Neon material found in road markings/crosswalks")
			end
		end
	end

	print(
		("[CityLayout] World grid built in %s. RoadsX=%d RoadsZ=%d Intersections=%d Lots=%d Lights=%d")
			:format(cityFolder.Name, #xRoads, #zRoads, #intersectionsFolder:GetChildren(), #lotsFolder:GetChildren(), #streetLightsFolder:GetChildren())
	)
	print(("[CityLayout] Crosswalk debug: intersections=%d, stripes=%d"):format(intersectionsProcessed, crosswalkParts))
end

buildCityGrid()
