local Players = game:GetService("Players")
local StarterPack = game:GetService("StarterPack")

local TOOL_NAME = "EMP Slingshot"

local function createHandle(): Part
	local handle = Instance.new("Part")
	handle.Name = "Handle"
	handle.Size = Vector3.new(1, 1, 1)
	handle.Transparency = 1
	handle.CanCollide = false
	handle.Anchored = false
	handle.Massless = true
	return handle
end

local function createTool(): Tool
	local tool = Instance.new("Tool")
	tool.Name = TOOL_NAME
	tool.CanBeDropped = false
	tool.RequiresHandle = true
	tool.ToolTip = "Click to fire EMP pulse"

	local handle = createHandle()
	handle.Parent = tool
	return tool
end

local function ensureToolInContainer(container: Instance)
	local existing = container:FindFirstChild(TOOL_NAME)
	if existing and existing:IsA("Tool") then
		local hasHandle = existing:FindFirstChild("Handle")
		if hasHandle and hasHandle:IsA("BasePart") then
			existing.CanBeDropped = false
			existing.RequiresHandle = true
			return
		end
		existing:Destroy()
	end

	local tool = createTool()
	tool.Parent = container
end

ensureToolInContainer(StarterPack)

Players.PlayerAdded:Connect(function(player)
	player.CharacterAdded:Connect(function()
		local backpack = player:WaitForChild("Backpack")
		ensureToolInContainer(backpack)
	end)
end)

print("[EMPToolService] EMP Slingshot provisioned")
