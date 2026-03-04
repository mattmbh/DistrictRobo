local ok, err = pcall(function()
	local Players = game:GetService("Players")
	local ContextActionService = game:GetService("ContextActionService")
	local UserInputService = game:GetService("UserInputService")
	local Workspace = game:GetService("Workspace")

	local player = Players.LocalPlayer
	local playerGui = player:WaitForChild("PlayerGui")
	local scriptParentName = script.Parent and script.Parent:GetFullName() or "nil"
	print("[CityMap] LocalScript loaded; parent=", scriptParentName)
	_G.__CityMapLoaded = true

	local DISTRICT_COLORS = {
		Safe = Color3.fromRGB(78, 112, 86), -- muted green
		Industrial = Color3.fromRGB(170, 126, 64), -- amber
		Corporate = Color3.fromRGB(74, 100, 150), -- blue
		Danger = Color3.fromRGB(96, 42, 42), -- dark red
	}

	local gui = Instance.new("ScreenGui")
	gui.Name = "CityMapUI"
	gui.ResetOnSpawn = false
	gui.Enabled = true
	gui.Parent = playerGui

	local statusLabel = Instance.new("TextLabel")
	statusLabel.Name = "CityMapDebugStatus"
	statusLabel.AnchorPoint = Vector2.new(1, 0)
	statusLabel.Position = UDim2.new(1, -12, 0, 12)
	statusLabel.Size = UDim2.fromOffset(180, 22)
	statusLabel.BackgroundColor3 = Color3.fromRGB(56, 56, 56)
	statusLabel.BackgroundTransparency = 0.35
	statusLabel.TextColor3 = Color3.fromRGB(220, 220, 220)
	statusLabel.BorderSizePixel = 0
	statusLabel.Font = Enum.Font.Gotham
	statusLabel.TextSize = 12
	statusLabel.TextXAlignment = Enum.TextXAlignment.Center
	statusLabel.Text = "CityMap: OPEN"
	statusLabel.Parent = gui

	local mapFrame = Instance.new("Frame")
	mapFrame.Name = "MapFrame"
	mapFrame.Size = UDim2.fromOffset(640, 520)
	mapFrame.Position = UDim2.fromScale(0.5, 0.5)
	mapFrame.AnchorPoint = Vector2.new(0.5, 0.5)
	mapFrame.BackgroundColor3 = Color3.fromRGB(30, 34, 40)
	mapFrame.BorderSizePixel = 0
	mapFrame.Parent = gui

	local mapTitle = Instance.new("TextLabel")
	mapTitle.Name = "Title"
	mapTitle.Size = UDim2.new(1, -24, 0, 36)
	mapTitle.Position = UDim2.fromOffset(12, 8)
	mapTitle.BackgroundTransparency = 1
	mapTitle.TextXAlignment = Enum.TextXAlignment.Left
	mapTitle.Font = Enum.Font.GothamBold
	mapTitle.TextSize = 22
	mapTitle.TextColor3 = Color3.fromRGB(220, 226, 238)
	mapTitle.Text = "TACTICAL CITY MAP"
	mapTitle.Parent = mapFrame

	local districtGrid = Instance.new("Frame")
	districtGrid.Name = "DistrictGrid"
	districtGrid.Size = UDim2.new(1, -24, 1, -110)
	districtGrid.Position = UDim2.fromOffset(12, 48)
	districtGrid.BackgroundColor3 = Color3.fromRGB(20, 22, 27)
	districtGrid.BorderSizePixel = 0
	districtGrid.Parent = mapFrame

	local gridLayout = Instance.new("UIGridLayout")
	gridLayout.FillDirection = Enum.FillDirection.Horizontal
	gridLayout.SortOrder = Enum.SortOrder.LayoutOrder
	gridLayout.HorizontalAlignment = Enum.HorizontalAlignment.Center
	gridLayout.VerticalAlignment = Enum.VerticalAlignment.Center
	gridLayout.CellPadding = UDim2.fromOffset(2, 2)
	gridLayout.Parent = districtGrid

	local playerMarker = Instance.new("Frame")
	playerMarker.Name = "PlayerMarker"
	playerMarker.Size = UDim2.fromOffset(10, 10)
	playerMarker.AnchorPoint = Vector2.new(0.5, 0.5)
	playerMarker.BackgroundColor3 = Color3.fromRGB(255, 255, 255)
	playerMarker.BorderSizePixel = 0
	playerMarker.Visible = false
	playerMarker.Parent = mapFrame

	local markerCorner = Instance.new("UICorner")
	markerCorner.CornerRadius = UDim.new(1, 0)
	markerCorner.Parent = playerMarker

	local districtInfo = Instance.new("Frame")
	districtInfo.Name = "DistrictInfo"
	districtInfo.Size = UDim2.new(1, -24, 0, 44)
	districtInfo.Position = UDim2.new(0, 12, 1, -54)
	districtInfo.BackgroundColor3 = Color3.fromRGB(26, 29, 35)
	districtInfo.BorderSizePixel = 0
	districtInfo.Parent = mapFrame

	local districtNameLabel = Instance.new("TextLabel")
	districtNameLabel.Name = "DistrictName"
	districtNameLabel.Size = UDim2.new(0.7, -8, 1, 0)
	districtNameLabel.Position = UDim2.fromOffset(8, 0)
	districtNameLabel.BackgroundTransparency = 1
	districtNameLabel.TextXAlignment = Enum.TextXAlignment.Left
	districtNameLabel.Font = Enum.Font.GothamSemibold
	districtNameLabel.TextSize = 17
	districtNameLabel.TextColor3 = Color3.fromRGB(230, 235, 242)
	districtNameLabel.Text = "District: Unknown"
	districtNameLabel.Parent = districtInfo

	local districtHeatLabel = Instance.new("TextLabel")
	districtHeatLabel.Name = "DistrictHeat"
	districtHeatLabel.Size = UDim2.new(0.3, -8, 1, 0)
	districtHeatLabel.Position = UDim2.new(0.7, 0, 0, 0)
	districtHeatLabel.BackgroundTransparency = 1
	districtHeatLabel.TextXAlignment = Enum.TextXAlignment.Right
	districtHeatLabel.Font = Enum.Font.GothamSemibold
	districtHeatLabel.TextSize = 17
	districtHeatLabel.TextColor3 = Color3.fromRGB(230, 235, 242)
	districtHeatLabel.Text = "Heat: 0"
	districtHeatLabel.Parent = districtInfo

	local worldBounds = nil
	local TOGGLE_ACTION = "ToggleCityMap"
	local lastToggleAt = 0

	local function classifyDistrictColor(name, heatLevel)
		local lower = string.lower(name)
		if string.find(lower, "danger", 1, true) or heatLevel >= 3 then
			return DISTRICT_COLORS.Danger
		end
		if string.find(lower, "industrial", 1, true) then
			return DISTRICT_COLORS.Industrial
		end
		if string.find(lower, "corporate", 1, true) then
			return DISTRICT_COLORS.Corporate
		end
		if string.find(lower, "safe", 1, true) then
			return DISTRICT_COLORS.Safe
		end
		if heatLevel >= 2 then
			return DISTRICT_COLORS.Industrial
		end
		return DISTRICT_COLORS.Safe
	end

	local function parseDistrictIndex(folderName)
		local underscoreIndex = string.find(folderName, "_", 1, true)
		if not underscoreIndex then
			return nil
		end
		local xStr = string.sub(folderName, 1, underscoreIndex - 1)
		local zStr = string.sub(folderName, underscoreIndex + 1)
		local ix = tonumber(xStr)
		local iz = tonumber(zStr)
		if ix == nil or iz == nil then
			return nil
		end
		return ix, iz
	end

	local function clearDistrictGrid()
		for _, child in ipairs(districtGrid:GetChildren()) do
			if child:IsA("Frame") then
				child:Destroy()
			end
		end
	end

	local function loadDistricts()
		clearDistrictGrid()
		local districtsRoot = Workspace:FindFirstChild("World")
		districtsRoot = districtsRoot and districtsRoot:FindFirstChild("Districts")
		if not (districtsRoot and districtsRoot:IsA("Folder")) then
			playerMarker.Visible = false
			print("[CityMap] districts loaded: 0")
			return
		end

		local folders = {}
		local minX = math.huge
		local minZ = math.huge
		local maxX = -math.huge
		local maxZ = -math.huge
		local maxIX = 0
		local maxIZ = 0

		for _, child in ipairs(districtsRoot:GetChildren()) do
			if child:IsA("Folder") then
				local ix, iz = parseDistrictIndex(child.Name)
				if ix and iz then
					table.insert(folders, { folder = child, ix = ix, iz = iz })
					maxIX = math.max(maxIX, ix)
					maxIZ = math.max(maxIZ, iz)
				end

				local center = child:GetAttribute("Center")
				local size = child:GetAttribute("Size")
				if typeof(center) == "Vector3" and typeof(size) == "Vector2" then
					minX = math.min(minX, center.X - size.X * 0.5)
					maxX = math.max(maxX, center.X + size.X * 0.5)
					minZ = math.min(minZ, center.Z - size.Y * 0.5)
					maxZ = math.max(maxZ, center.Z + size.Y * 0.5)
				end
			end
		end

		local countX = maxIX + 1
		local countZ = maxIZ + 1
		if countX <= 0 then
			countX = 1
		end
		if countZ <= 0 then
			countZ = 1
		end

		local cellSize = math.floor(math.min((districtGrid.AbsoluteSize.X - ((countX - 1) * 2)) / countX, (districtGrid.AbsoluteSize.Y - ((countZ - 1) * 2)) / countZ))
		cellSize = math.max(12, cellSize)
		gridLayout.CellSize = UDim2.fromOffset(cellSize, cellSize)

		for _, item in ipairs(folders) do
			local district = item.folder
			local districtName = tostring(district:GetAttribute("Name") or district.Name)
			local heatLevel = tonumber(district:GetAttribute("HeatLevel")) or 0

			local tile = Instance.new("Frame")
			tile.Name = district.Name
			tile.BackgroundColor3 = classifyDistrictColor(districtName, heatLevel)
			tile.BorderSizePixel = 0
			tile.LayoutOrder = item.iz * countX + item.ix
			tile.Parent = districtGrid
		end

		if minX < math.huge and minZ < math.huge then
			worldBounds = {
				minX = minX,
				maxX = maxX,
				minZ = minZ,
				maxZ = maxZ,
			}
		else
			worldBounds = nil
		end

		print(("[CityMap] districts loaded: %d"):format(#folders))
	end

	local function updateDistrictInfo()
		local districtName = tostring(player:GetAttribute("DistrictId") or "Unknown")
		local heatLevel = tonumber(player:GetAttribute("DistrictHeatLevel")) or 0
		districtNameLabel.Text = ("District: %s"):format(districtName)
		districtHeatLabel.Text = ("Heat: %d"):format(heatLevel)
	end

	local function updateMarker()
		if not gui.Enabled then
			return
		end
		local bounds = worldBounds
		local character = player.Character
		local rootPart = character and character:FindFirstChild("HumanoidRootPart")
		if not bounds or not (rootPart and rootPart:IsA("BasePart")) then
			playerMarker.Visible = false
			return
		end

		local width = math.max(1, bounds.maxX - bounds.minX)
		local depth = math.max(1, bounds.maxZ - bounds.minZ)
		local nx = math.clamp((rootPart.Position.X - bounds.minX) / width, 0, 1)
		local nz = math.clamp((rootPart.Position.Z - bounds.minZ) / depth, 0, 1)

		local gridPos = districtGrid.AbsolutePosition
		local gridSize = districtGrid.AbsoluteSize
		playerMarker.Position = UDim2.fromOffset(
			gridPos.X - mapFrame.AbsolutePosition.X + nx * gridSize.X,
			gridPos.Y - mapFrame.AbsolutePosition.Y + nz * gridSize.Y
		)
		playerMarker.Visible = true
	end

	local function toggleMap(source)
		local now = os.clock()
		if now - lastToggleAt < 0.08 then
			return Enum.ContextActionResult.Pass
		end
		lastToggleAt = now

		print(("[CityMap] Toggle pressed (%s)"):format(source))
		gui.Enabled = not gui.Enabled
		statusLabel.Text = gui.Enabled and "CityMap: OPEN" or "CityMap: CLOSED"
		if gui.Enabled then
			loadDistricts()
			updateDistrictInfo()
			updateMarker()
		end
		return Enum.ContextActionResult.Sink
	end

	local function onToggleMapAction(_actionName, inputState)
		if inputState ~= Enum.UserInputState.Begin then
			return Enum.ContextActionResult.Pass
		end
		return toggleMap("CAS")
	end

	ContextActionService:UnbindAction(TOGGLE_ACTION)
	ContextActionService:BindAction(TOGGLE_ACTION, onToggleMapAction, false, Enum.KeyCode.M)
	print("[CityMap] BindAction complete")

	UserInputService.InputBegan:Connect(function(inputObject, gameProcessedEvent)
		if gameProcessedEvent then
			return
		end
		if inputObject.KeyCode ~= Enum.KeyCode.M then
			return
		end
		print("[CityMap] UIS fallback pressed")
		toggleMap("UIS")
	end)

	player:GetAttributeChangedSignal("DistrictId"):Connect(updateDistrictInfo)
	player:GetAttributeChangedSignal("DistrictHeatLevel"):Connect(updateDistrictInfo)

	districtGrid:GetPropertyChangedSignal("AbsoluteSize"):Connect(function()
		if gui.Enabled then
			loadDistricts()
			updateMarker()
		end
	end)

	task.spawn(function()
		while true do
			task.wait(0.05)
			updateMarker()
		end
	end)

	loadDistricts()
	updateDistrictInfo()
	updateMarker()
end)

if not ok then
	warn("[CityMap] ERROR:", err)
end
