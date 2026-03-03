local RunService = game:GetService("RunService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Net = require(Shared:WaitForChild("Net"))

local snapshotRemote = Net.GetRemoteEvent(Constants.Remotes.DroneSnapshot)

local droneStates: {[number]: {
	instance: Instance?,
	targetCFrame: CFrame,
	renderCFrame: CFrame,
	travelDir: Vector3,
	rollDeg: number,
	lastSeen: number,
	disabled: boolean,
}} = {}

local function findDroneInstance(droneId: number): Instance?
	local folder = Workspace:FindFirstChild("Drones")
	if not folder then
		return nil
	end

	for _, child in ipairs(folder:GetChildren()) do
		if child:GetAttribute("DroneId") == droneId then
			return child
		end
		if child:IsA("Model") then
			local primary = child.PrimaryPart
			if primary and primary:GetAttribute("DroneId") == droneId then
				return child
			end
		end
	end

	return nil
end

snapshotRemote.OnClientEvent:Connect(function(payload)
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
			local droneId = droneData.id
			local state = droneStates[droneId]
			if not state then
				state = {
					instance = nil,
					targetCFrame = droneData.cf,
					renderCFrame = droneData.cf,
					travelDir = droneData.cf.LookVector,
					rollDeg = 0,
					lastSeen = now,
					disabled = droneData.disabled == true,
				}
				droneStates[droneId] = state
			else
				local delta = droneData.cf.Position - state.targetCFrame.Position
				if delta.Magnitude > 0.0001 then
					state.travelDir = delta.Unit
				end
				state.targetCFrame = droneData.cf
				state.disabled = droneData.disabled == true
				state.lastSeen = now
			end
		end
	end
end)

RunService.RenderStepped:Connect(function(deltaTime)
	local now = Workspace:GetServerTimeNow()
	for droneId, state in pairs(droneStates) do
		if now - state.lastSeen > 2 then
			droneStates[droneId] = nil
			continue
		end

		if not state.instance or state.instance.Parent == nil then
			state.instance = findDroneInstance(droneId)
			if not state.instance then
				continue
			end
		end

		if state.disabled then
			continue
		end

		local alpha = 1 - math.exp(-deltaTime * 14)
		state.renderCFrame = state.renderCFrame:Lerp(state.targetCFrame, alpha)

		local desiredDir = state.travelDir.Magnitude > 0.001 and state.travelDir.Unit or state.renderCFrame.LookVector
		local flattened = Vector3.new(desiredDir.X, 0, desiredDir.Z)
		local yawDir = flattened.Magnitude > 0.001 and flattened.Unit or Vector3.new(0, 0, -1)
		local turnStrength = state.renderCFrame.LookVector:Cross(yawDir).Y
		local targetRoll = math.clamp(-turnStrength * 28, -16, 16)
		state.rollDeg += (targetRoll - state.rollDeg) * math.clamp(deltaTime * 8, 0, 1)

		local bob = math.sin((now * 2.3) + (droneId * 0.37)) * 0.55
		local basePos = state.renderCFrame.Position + Vector3.new(0, bob, 0)
		local visualCFrame = CFrame.lookAt(basePos, basePos + yawDir) * CFrame.Angles(0, 0, math.rad(state.rollDeg))

		if state.instance:IsA("BasePart") then
			state.instance.CFrame = visualCFrame
		elseif state.instance:IsA("Model") then
			state.instance:PivotTo(visualCFrame)
		end
	end
end)

print("[DroneSmoothing] Ready")
