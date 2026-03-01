local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Net = require(Shared:WaitForChild("Net"))
local SoundLimiter = require(script.Parent:WaitForChild("SoundLimiter"))

local fxRemote = Net.GetRemoteEvent(Constants.Remotes.FXEvent)

local function playKeyedSound(soundKey: string)
	if soundKey == "DRONE_ZAP" then
		SoundLimiter.Play2D(soundKey, "rbxasset://sounds/electronicpingshort.wav", 0.24, 1.05)
	elseif soundKey == "DROP_CLINK" then
		SoundLimiter.Play2D(soundKey, "rbxasset://sounds/snap.wav", 0.14, 1.1)
	end
end

local function spawnSparks(position: Vector3)
	local anchor = Instance.new("Part")
	anchor.Name = "DroneSparksFx"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position
	anchor.Parent = Workspace

	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor

	local emitter = Instance.new("ParticleEmitter")
	emitter.Lifetime = NumberRange.new(0.18, 0.3)
	emitter.Speed = NumberRange.new(7, 12)
	emitter.SpreadAngle = Vector2.new(40, 40)
	emitter.Rate = 0
	emitter.LightEmission = 0.9
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.2),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.1),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(Color3.fromRGB(120, 220, 255), Color3.fromRGB(255, 255, 255))
	emitter.Parent = attachment
	emitter:Emit(14)

	Debris:AddItem(anchor, 0.5)
end

fxRemote.OnClientEvent:Connect(function(payload)
	if typeof(payload) ~= "table" then
		return
	end

	local eventType = payload.type
	local position = payload.position

	if eventType == "DRONE_ZAP" and typeof(position) == "Vector3" then
		spawnSparks(position)
		playKeyedSound("DRONE_ZAP")
	elseif eventType == "DROP_CLINK" then
		playKeyedSound("DROP_CLINK")
	end
end)

print("[FeedbackController] Ready")
