local ok, err = pcall(function()
	local Players = game:GetService("Players")
	local ContextActionService = game:GetService("ContextActionService")
	local UserInputService = game:GetService("UserInputService")
	local Workspace = game:GetService("Workspace")
	local ReplicatedStorage = game:GetService("ReplicatedStorage")

	local Shared = ReplicatedStorage:WaitForChild("Shared")
	local Constants = require(Shared:WaitForChild("Constants"))
	local Net = require(Shared:WaitForChild("Net"))

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local arenaState = ReplicatedStorage:WaitForChild("ArenaState")
	local droneSnapshotRemote = Net.GetRemoteEvent(Constants.Remotes.DroneSnapshot)
	_G.__CityMapLoaded = true

	local ZOOM_MIN = 0.75
	local ZOOM_MAX = 1.75
	local ZOOM_STEP = 0.08
	local TOGGLE_ACTION = "ToggleCityMap"

	local TILE_SAFE_COLOR = Color3.fromRGB(69, 94, 82)
	local TILE_DANGER_COLOR = Color3.fromRGB(112, 64, 66)
	local TILE_TEXT_COLOR = Color3.fromRGB(214, 221, 232)
	local BORDER_COLOR = Color3.fromRGB(233, 184, 91)
	local MARKER_COLOR = Color3.fromRGB(239, 245, 252)
	local DRONE_MARKER_COLOR = Color3.fromRGB(111, 227, 244)
	local ARENA_MARKER_COLOR = Color3.fromRGB(255, 212, 122)

	local worldBounds = {
		minX = -560,
		maxX = 560,
		minZ = -560,
		maxZ = 560,
	}
	local splitX = 0
	local lastSplitLogKey = ""
	local splitFallbackWarned = false
	local droneDotsById: {[number]: Frame} = {}
	local dronePositions: {[number]: {position: Vector3, lastSeen: number}} = {}

	local currentZoom = 1
	local panOffset = Vector2.zero
	local isDragging = false
	local lastDragPos = nil
	local lastToggleAt = 0

	local gui = Instance.new("ScreenGui")
	gui.Name = "CityMapUI"
	gui.ResetOnSpawn = false
	gui.Enabled = true
	gui.Parent = playerGui

	local mapFrame = Instance.new("Frame")
	mapFrame.Name = "MapFrame"
	mapFrame.Size = UDim2.fromOffset(680, 540)
	mapFrame.Position = UDim2.fromScale(0.5, 0.5)
	mapFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mapFrame.BackgroundColor3 = Color3.fromRGB(12, 16, 24)
	mapFrame.BackgroundTransparency = 0.08
	mapFrame.BorderSizePixel = 0
	mapFrame.Parent = gui

	local mapStroke = Instance.new("UIStroke")
	mapStroke.Thickness = 2
	mapStroke.Color = BORDER_COLOR
	mapStroke.Parent = mapFrame

	local mapTitle = Instance.new("TextLabel")
	mapTitle.Name = "Title"
	mapTitle.Size = UDim2.new(1, -24, 0, 36)
	mapTitle.Position = UDim2.fromOffset(12, 8)
	mapTitle.BackgroundTransparency = 1
	mapTitle.TextXAlignment = Enum.TextXAlignment.Left
	mapTitle.Font = Enum.Font.GothamBlack
	mapTitle.TextSize = 24
	mapTitle.TextColor3 = ARENA_MARKER_COLOR
	mapTitle.Text = "CITY MAP"
	mapTitle.Parent = mapFrame

	local mapSubtitle = Instance.new("TextLabel")
	mapSubtitle.Name = "Subtitle"
	mapSubtitle.Size = UDim2.new(1, -24, 0, 16)
	mapSubtitle.Position = UDim2.fromOffset(12, 34)
	mapSubtitle.BackgroundTransparency = 1
	mapSubtitle.TextXAlignment = Enum.TextXAlignment.Left
	mapSubtitle.Font = Enum.Font.GothamSemibold
	mapSubtitle.TextSize = 12
	mapSubtitle.TextColor3 = Color3.fromRGB(190, 202, 216)
	mapSubtitle.Text = "Track districts, arena activity, and live drones."
	mapSubtitle.Parent = mapFrame

	local mapViewport = Instance.new("Frame")
	mapViewport.Name = "MapViewport"
	mapViewport.Size = UDim2.new(1, -24, 1, -128)
	mapViewport.Position = UDim2.fromOffset(12, 58)
	mapViewport.BackgroundColor3 = Color3.fromRGB(17, 21, 30)
	mapViewport.BorderSizePixel = 0
	mapViewport.ClipsDescendants = true
	mapViewport.Parent = mapFrame

	local viewportStroke = Instance.new("UIStroke")
	viewportStroke.Thickness = 1
	viewportStroke.Color = Color3.fromRGB(95, 76, 42)
	viewportStroke.Transparency = 0.15
	viewportStroke.Parent = mapViewport

	local mapCanvas = Instance.new("Frame")
	mapCanvas.Name = "MapCanvas"
	mapCanvas.Size = UDim2.fromScale(1, 1)
	mapCanvas.AnchorPoint = Vector2.new(0.5, 0.5)
	mapCanvas.Position = UDim2.fromScale(0.5, 0.5)
	mapCanvas.BackgroundTransparency = 1
	mapCanvas.Parent = mapViewport

	local mapScale = Instance.new("UIScale")
	mapScale.Parent = mapCanvas

	local districtGrid = Instance.new("Frame")
	districtGrid.Name = "DistrictGrid"
	districtGrid.Size = UDim2.fromScale(1, 1)
	districtGrid.BackgroundTransparency = 1
	districtGrid.BorderSizePixel = 0
	districtGrid.Parent = mapCanvas

	local markerLayer = Instance.new("Frame")
	markerLayer.Name = "MarkerLayer"
	markerLayer.Size = UDim2.fromScale(1, 1)
	markerLayer.BackgroundTransparency = 1
	markerLayer.BorderSizePixel = 0
	markerLayer.Parent = mapCanvas

	local safeTile = Instance.new("Frame")
	safeTile.Name = "SAFE"
	safeTile.BorderSizePixel = 0
	safeTile.BackgroundColor3 = TILE_SAFE_COLOR
	safeTile.Parent = districtGrid

	local safeBorder = Instance.new("UIStroke")
	safeBorder.Thickness = 1
	safeBorder.Color = BORDER_COLOR
	safeBorder.Transparency = 0.25
	safeBorder.Parent = safeTile

	local safeLabel = Instance.new("TextLabel")
	safeLabel.BackgroundTransparency = 1
	safeLabel.Size = UDim2.new(1, -8, 0, 18)
	safeLabel.Position = UDim2.fromOffset(4, 4)
	safeLabel.TextXAlignment = Enum.TextXAlignment.Left
	safeLabel.TextYAlignment = Enum.TextYAlignment.Top
	safeLabel.Font = Enum.Font.GothamSemibold
	safeLabel.TextSize = 11
	safeLabel.TextColor3 = TILE_TEXT_COLOR
	safeLabel.Text = "SAFE"
	safeLabel.Parent = safeTile

	local dangerTile = Instance.new("Frame")
	dangerTile.Name = "DANGER"
	dangerTile.BorderSizePixel = 0
	dangerTile.BackgroundColor3 = TILE_DANGER_COLOR
	dangerTile.Parent = districtGrid

	local dangerBorder = Instance.new("UIStroke")
	dangerBorder.Thickness = 1
	dangerBorder.Color = BORDER_COLOR
	dangerBorder.Transparency = 0.25
	dangerBorder.Parent = dangerTile

	local dangerLabel = Instance.new("TextLabel")
	dangerLabel.BackgroundTransparency = 1
	dangerLabel.Size = UDim2.new(1, -8, 0, 18)
	dangerLabel.Position = UDim2.fromOffset(4, 4)
	dangerLabel.TextXAlignment = Enum.TextXAlignment.Left
	dangerLabel.TextYAlignment = Enum.TextYAlignment.Top
	dangerLabel.Font = Enum.Font.GothamSemibold
	dangerLabel.TextSize = 11
	dangerLabel.TextColor3 = TILE_TEXT_COLOR
	dangerLabel.Text = "DANGER"
	dangerLabel.Parent = dangerTile

	local playerMarker = Instance.new("Frame")
	playerMarker.Name = "PlayerMarker"
	playerMarker.Size = UDim2.fromOffset(12, 12)
	playerMarker.AnchorPoint = Vector2.new(0.5, 0.5)
	playerMarker.BackgroundColor3 = MARKER_COLOR
	playerMarker.BorderSizePixel = 0
	playerMarker.Parent = markerLayer

	local markerCorner = Instance.new("UICorner")
	markerCorner.CornerRadius = UDim.new(1, 0)
	markerCorner.Parent = playerMarker

	local playerMarkerStroke = Instance.new("UIStroke")
	playerMarkerStroke.Thickness = 1
	playerMarkerStroke.Color = Color3.fromRGB(22, 26, 32)
	playerMarkerStroke.Parent = playerMarker

	local arenaMarker = Instance.new("Frame")
	arenaMarker.Name = "ArenaMarker"
	arenaMarker.Size = UDim2.fromOffset(10, 10)
	arenaMarker.AnchorPoint = Vector2.new(0.5, 0.5)
	arenaMarker.BackgroundColor3 = ARENA_MARKER_COLOR
	arenaMarker.BorderSizePixel = 0
	arenaMarker.Parent = markerLayer

	local arenaCorner = Instance.new("UICorner")
	arenaCorner.CornerRadius = UDim.new(1, 0)
	arenaCorner.Parent = arenaMarker

	local arenaStroke = Instance.new("UIStroke")
	arenaStroke.Thickness = 2
	arenaStroke.Color = Color3.fromRGB(60, 44, 16)
	arenaStroke.Parent = arenaMarker

	local arenaLabel = Instance.new("TextLabel")
	arenaLabel.Name = "ArenaLabel"
	arenaLabel.AnchorPoint = Vector2.new(0.5, 1)
	arenaLabel.Position = UDim2.new(0.5, 0, 0, -4)
	arenaLabel.Size = UDim2.fromOffset(54, 14)
	arenaLabel.BackgroundTransparency = 1
	arenaLabel.Font = Enum.Font.GothamBold
	arenaLabel.TextSize = 11
	arenaLabel.TextColor3 = ARENA_MARKER_COLOR
	arenaLabel.Text = "Arena"
	arenaLabel.Parent = arenaMarker

	local districtInfo = Instance.new("Frame")
	districtInfo.Name = "DistrictInfo"
	districtInfo.Size = UDim2.new(1, -24, 0, 52)
	districtInfo.Position = UDim2.new(0, 12, 1, -58)
	districtInfo.BackgroundColor3 = Color3.fromRGB(16, 20, 28)
	districtInfo.BackgroundTransparency = 0.08
	districtInfo.BorderSizePixel = 0
	districtInfo.Parent = mapFrame

	local districtInfoStroke = Instance.new("UIStroke")
	districtInfoStroke.Thickness = 1
	districtInfoStroke.Color = Color3.fromRGB(95, 76, 42)
	districtInfoStroke.Transparency = 0.1
	districtInfoStroke.Parent = districtInfo

	local districtNameLabel = Instance.new("TextLabel")
	districtNameLabel.Name = "DistrictName"
	districtNameLabel.Size = UDim2.new(0.46, -8, 1, 0)
	districtNameLabel.Position = UDim2.fromOffset(8, 0)
	districtNameLabel.BackgroundTransparency = 1
	districtNameLabel.TextXAlignment = Enum.TextXAlignment.Left
	districtNameLabel.Font = Enum.Font.GothamBold
	districtNameLabel.TextSize = 16
	districtNameLabel.TextColor3 = Color3.fromRGB(236, 242, 248)
	districtNameLabel.Text = "District: SAFE"
	districtNameLabel.Parent = districtInfo

	local districtHeatLabel = Instance.new("TextLabel")
	districtHeatLabel.Name = "DistrictHeat"
	districtHeatLabel.Size = UDim2.new(0.27, -8, 1, 0)
	districtHeatLabel.Position = UDim2.new(0.46, 0, 0, 0)
	districtHeatLabel.BackgroundTransparency = 1
	districtHeatLabel.TextXAlignment = Enum.TextXAlignment.Left
	districtHeatLabel.Font = Enum.Font.GothamBold
	districtHeatLabel.TextSize = 15
	districtHeatLabel.TextColor3 = Color3.fromRGB(220, 226, 238)
	districtHeatLabel.Text = "Drones: 0"
	districtHeatLabel.Parent = districtInfo

	local districtThreatLabel = Instance.new("TextLabel")
	districtThreatLabel.Name = "DistrictThreat"
	districtThreatLabel.Size = UDim2.new(0.27, -8, 1, 0)
	districtThreatLabel.Position = UDim2.new(0.73, 0, 0, 0)
	districtThreatLabel.BackgroundTransparency = 1
	districtThreatLabel.TextXAlignment = Enum.TextXAlignment.Right
	districtThreatLabel.Font = Enum.Font.GothamBold
	districtThreatLabel.TextSize = 15
	districtThreatLabel.TextColor3 = Color3.fromRGB(220, 226, 238)
	districtThreatLabel.Text = "Threat: --"
	districtThreatLabel.Parent = districtInfo

	local function updateTileLayout()
		local padding = 2
		local w = districtGrid.AbsoluteSize.X
		local h = districtGrid.AbsoluteSize.Y
		local tileW = math.max(20, math.floor((w - padding) * 0.5))
		safeTile.Size = UDim2.fromOffset(tileW, h)
		safeTile.Position = UDim2.fromOffset(0, 0)
		dangerTile.Size = UDim2.fromOffset(tileW, h)
		dangerTile.Position = UDim2.fromOffset(tileW + padding, 0)
	end

	local function readSplitX()
		local world = Workspace:FindFirstChild("World")
		local source = "fallback"
		local value = nil
		if world and world:IsA("Folder") then
			local attrValue = world:GetAttribute("SplitX")
			if typeof(attrValue) == "number" and attrValue == attrValue and attrValue ~= math.huge and attrValue ~= -math.huge then
				value = attrValue
				source = "attribute"
			else
				local legacy = world:FindFirstChild("SplitX")
				if legacy and legacy:IsA("NumberValue") then
					value = legacy.Value
					world:SetAttribute("SplitX", value)
					source = "legacy_numbervalue_bridge"
				end
			end
		end

		if typeof(value) ~= "number" or value ~= value or value == math.huge or value == -math.huge then
			if not splitFallbackWarned then
				splitFallbackWarned = true
				warn(("[CityMap] Invalid SplitX source=%s value=%s; forcing fallback splitX=0"):format(source, tostring(value)))
			end
			value = 0
			source = "forced_fallback"
		else
			splitFallbackWarned = false
		end

		splitX = value
		local logKey = ("%s|%s|%.4f"):format(source, typeof(splitX), splitX)
		if logKey ~= lastSplitLogKey then
			lastSplitLogKey = logKey
			print(("[CityMap] splitX=%.2f typeof=%s source=%s"):format(splitX, typeof(splitX), source))
		end
	end

	local function readBounds()
		local world = Workspace:FindFirstChild("World")
		local districts = world and world:FindFirstChild("Districts")
		if not (districts and districts:IsA("Folder")) then
			return
		end

		local minFoundX = math.huge
		local maxFoundX = -math.huge
		local minFoundZ = math.huge
		local maxFoundZ = -math.huge
		for _, child in ipairs(districts:GetChildren()) do
			if child:IsA("Folder") then
				local bmin = child:GetAttribute("BoundsMin")
				local bmax = child:GetAttribute("BoundsMax")
				if typeof(bmin) == "Vector3" and typeof(bmax) == "Vector3" then
					minFoundX = math.min(minFoundX, bmin.X)
					maxFoundX = math.max(maxFoundX, bmax.X)
					minFoundZ = math.min(minFoundZ, bmin.Z)
					maxFoundZ = math.max(maxFoundZ, bmax.Z)
				end
			end
		end
		if minFoundX < math.huge then
			worldBounds.minX = minFoundX
			worldBounds.maxX = maxFoundX
			worldBounds.minZ = minFoundZ
			worldBounds.maxZ = maxFoundZ
		end
	end

	local function readDangerState()
		local world = Workspace:FindFirstChild("World")
		local districts = world and world:FindFirstChild("Districts")
		if districts and districts:IsA("Folder") then
			for _, child in ipairs(districts:GetChildren()) do
				if child:IsA("Folder") then
					local name = string.upper(tostring(child:GetAttribute("Name") or child.Name))
					if name == "DANGER" then
						break
					end
				end
			end
		end
		dangerTile.BackgroundColor3 = TILE_DANGER_COLOR
		safeTile.BackgroundColor3 = TILE_SAFE_COLOR
	end

	local function getSpawnableDroneCount(threatLevel: number?): number
		local level = 0
		if typeof(threatLevel) == "number" then
			level = math.clamp(math.floor(threatLevel + 0.5), 0, Constants.Threat.MaxLevel)
		end
		local byThreat = Constants.Drones.CountByThreatLevel or {}
		local count = byThreat[level]
		if typeof(count) ~= "number" then
			count = Constants.Drones.BaseCount
		end
		return math.max(0, math.floor(count))
	end

	local function updateDistrictInfo()
		local districtName = tostring(player:GetAttribute("DistrictId") or "SAFE")
		local threat = player:GetAttribute("ThreatLevel")
		if threat == nil then
			threat = Workspace:GetAttribute("ThreatLevel")
		end
		local spawnableCount = getSpawnableDroneCount(tonumber(threat))
		districtNameLabel.Text = ("District: %s"):format(districtName)
		districtHeatLabel.Text = ("Drones: %d"):format(spawnableCount)
		districtThreatLabel.Text = ("Threat: %s"):format(threat == nil and "--" or tostring(threat))
	end

	local function worldToMarkerOffset(worldPosition: Vector3): Vector2
		updateTileLayout()

		local xMin = worldBounds.minX
		local xMax = worldBounds.maxX
		local zMin = worldBounds.minZ
		local zMax = worldBounds.maxZ
		local halfW = districtGrid.AbsoluteSize.X * 0.5
		local leftX = 0
		local rightX = halfW
		local markerX = 0

		if worldPosition.X < splitX then
			local alphaLeft = math.clamp((worldPosition.X - xMin) / math.max(1, splitX - xMin), 0, 1)
			markerX = leftX + (alphaLeft * halfW)
		else
			local alphaRight = math.clamp((worldPosition.X - splitX) / math.max(1, xMax - splitX), 0, 1)
			markerX = rightX + (alphaRight * halfW)
		end
		local alphaZ = math.clamp((worldPosition.Z - zMin) / math.max(1, zMax - zMin), 0, 1)
		local markerY = alphaZ * districtGrid.AbsoluteSize.Y
		return Vector2.new(markerX, markerY)
	end

	local function updateMarker()
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not (rootPart and rootPart:IsA("BasePart")) then
			playerMarker.Visible = false
			return
		end

		local markerPosition = worldToMarkerOffset(rootPart.Position)
		playerMarker.Position = UDim2.fromOffset(markerPosition.X, markerPosition.Y)
		playerMarker.Visible = true
	end

	local function updateArenaMarker()
		local arenaPosition = arenaState:GetAttribute("ArenaPosition")
		if typeof(arenaPosition) ~= "Vector3" then
			arenaMarker.Visible = false
			return
		end

		local markerPosition = worldToMarkerOffset(arenaPosition)
		arenaMarker.Position = UDim2.fromOffset(markerPosition.X, markerPosition.Y)
		arenaMarker.Visible = true
	end

	local function getOrCreateDroneDot(droneId: number): Frame
		local existing = droneDotsById[droneId]
		if existing and existing.Parent then
			return existing
		end

		local dot = Instance.new("Frame")
		dot.Name = ("Drone_%d"):format(droneId)
		dot.Size = UDim2.fromOffset(6, 6)
		dot.AnchorPoint = Vector2.new(0.5, 0.5)
		dot.BackgroundColor3 = DRONE_MARKER_COLOR
		dot.BorderSizePixel = 0
		dot.Parent = markerLayer

		local corner = Instance.new("UICorner")
		corner.CornerRadius = UDim.new(1, 0)
		corner.Parent = dot

		local stroke = Instance.new("UIStroke")
		stroke.Thickness = 1
		stroke.Color = Color3.fromRGB(12, 18, 24)
		stroke.Transparency = 0.2
		stroke.Parent = dot

		droneDotsById[droneId] = dot
		return dot
	end

	local function updateDroneDots()
		local now = Workspace:GetServerTimeNow()
		for droneId, dot in pairs(droneDotsById) do
			local state = dronePositions[droneId]
			if not state or (now - state.lastSeen) > 2 then
				dot:Destroy()
				droneDotsById[droneId] = nil
			end
		end

		for droneId, state in pairs(dronePositions) do
			if (now - state.lastSeen) <= 2 then
				local dot = getOrCreateDroneDot(droneId)
				local markerPosition = worldToMarkerOffset(state.position)
				dot.Position = UDim2.fromOffset(markerPosition.X, markerPosition.Y)
				dot.Visible = true
			end
		end
	end

	local function applyViewTransform(logZoom: boolean)
		local viewportSize = mapViewport.AbsoluteSize
		local maxPanX = math.max(0, (viewportSize.X * currentZoom) - viewportSize.X) * 0.5
		local maxPanY = math.max(0, (viewportSize.Y * currentZoom) - viewportSize.Y) * 0.5
		panOffset = Vector2.new(
			math.clamp(panOffset.X, -maxPanX, maxPanX),
			math.clamp(panOffset.Y, -maxPanY, maxPanY)
		)
		mapScale.Scale = currentZoom
		mapCanvas.Position = UDim2.fromScale(0.5, 0.5) + UDim2.fromOffset(panOffset.X, panOffset.Y)
		if logZoom then
			print(("[CityMap] zoom=%.2f"):format(currentZoom))
		end
	end

	local function buildTiles()
		updateTileLayout()
		readSplitX()
		readBounds()
		readDangerState()
		updateDistrictInfo()
		updateMarker()
		updateArenaMarker()
		updateDroneDots()
		print("[CityMap] tiles built: 2")
	end

	droneSnapshotRemote.OnClientEvent:Connect(function(payload)
		if typeof(payload) ~= "table" then
			return
		end

		local snapshot = payload.drones
		if typeof(snapshot) ~= "table" then
			return
		end

		local now = Workspace:GetServerTimeNow()
		for _, droneData in ipairs(snapshot) do
			if typeof(droneData) == "table"
				and typeof(droneData.id) == "number"
				and typeof(droneData.cf) == "CFrame"
			then
				dronePositions[droneData.id] = {
					position = droneData.cf.Position,
					lastSeen = now,
				}
			end
		end

		if gui.Enabled then
			updateDroneDots()
		end
	end)

	local function isPointInsideMapViewport(screenPos: Vector3): boolean
		local absPos = mapViewport.AbsolutePosition
		local absSize = mapViewport.AbsoluteSize
		return screenPos.X >= absPos.X
			and screenPos.Y >= absPos.Y
			and screenPos.X <= (absPos.X + absSize.X)
			and screenPos.Y <= (absPos.Y + absSize.Y)
	end

	local function toggleMap()
		local now = os.clock()
		if now - lastToggleAt < 0.08 then
			return Enum.ContextActionResult.Pass
		end
		lastToggleAt = now
		gui.Enabled = not gui.Enabled
		if gui.Enabled then
			buildTiles()
		end
		return Enum.ContextActionResult.Sink
	end

	local function onToggleMapAction(_actionName, inputState)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		return toggleMap()
	end

	ContextActionService:UnbindAction(TOGGLE_ACTION)
	ContextActionService:BindAction(TOGGLE_ACTION, onToggleMapAction, false, Enum.KeyCode.M)

	UserInputService.InputBegan:Connect(function(inputObject, gameProcessed)
		if gameProcessed then
			return
		end
		if inputObject.KeyCode == Enum.KeyCode.M then
			toggleMap()
			return
		end
		if gui.Enabled and inputObject.UserInputType == Enum.UserInputType.MouseButton1 and isPointInsideMapViewport(inputObject.Position) then
			isDragging = true
			lastDragPos = inputObject.Position
		end
	end)

	UserInputService.InputEnded:Connect(function(inputObject)
		if inputObject.UserInputType == Enum.UserInputType.MouseButton1 then
			isDragging = false
			lastDragPos = nil
		end
	end)

	UserInputService.InputChanged:Connect(function(inputObject, gameProcessed)
		if not gui.Enabled or gameProcessed then
			return
		end
		if inputObject.UserInputType == Enum.UserInputType.MouseWheel then
			local wheel = inputObject.Position.Z
			if wheel ~= 0 then
				currentZoom = math.clamp(currentZoom + (wheel * ZOOM_STEP), ZOOM_MIN, ZOOM_MAX)
				applyViewTransform(true)
			end
			return
		end
		if isDragging and lastDragPos and inputObject.UserInputType == Enum.UserInputType.MouseMovement then
			local delta = inputObject.Position - lastDragPos
			lastDragPos = inputObject.Position
			panOffset = panOffset + Vector2.new(delta.X, delta.Y)
			applyViewTransform(false)
		end
	end)

	mapViewport:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		updateTileLayout()
		if gui.Enabled then
			buildTiles()
		end
	end)

	player:GetAttributeChangedSignal("DistrictId"):Connect(updateDistrictInfo)
	player:GetAttributeChangedSignal("DistrictHeatLevel"):Connect(updateDistrictInfo)
	player:GetAttributeChangedSignal("ThreatLevel"):Connect(updateDistrictInfo)
	arenaState:GetAttributeChangedSignal("ArenaPosition"):Connect(function()
		if gui.Enabled then
			updateArenaMarker()
		end
	end)

	local worldFolderRef = Workspace:FindFirstChild("World")
	if worldFolderRef and worldFolderRef:IsA("Folder") then
		worldFolderRef:GetAttributeChangedSignal("SplitX"):Connect(function()
			readSplitX()
		end)
		local splitRef = worldFolderRef:FindFirstChild("SplitX")
		if splitRef and splitRef:IsA("NumberValue") then
			splitRef:GetPropertyChangedSignal("Value"):Connect(function()
				readSplitX()
			end)
		end
	end

	task.spawn(function()
		while true do
			task.wait(0.1)
			if gui.Enabled then
				readSplitX()
				readDangerState()
				updateDistrictInfo()
				updateMarker()
				updateArenaMarker()
				updateDroneDots()
			end
		end
	end)

	buildTiles()
	applyViewTransform(false)
	print("[CityMap] loaded")
end)

if not ok then
	warn("[CityMap] ERROR:", err)
end
