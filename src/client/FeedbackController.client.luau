local Debris = game:GetService("Debris")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Workspace = game:GetService("Workspace")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Net = require(Shared:WaitForChild("Net"))
local SoundLimiter = require(script.Parent:WaitForChild("SoundLimiter"))

local fxRemote = Net.GetRemoteEvent(Constants.Remotes.FXEvent)

local DEATH_FX = {
	burstParticles = Constants.DroneDeathFx.BurstParticles,
	soundVolume = Constants.DroneDeathFx.SoundVolume,
	playbackMin = Constants.DroneDeathFx.PlaybackMin,
	playbackMax = Constants.DroneDeathFx.PlaybackMax,
	plasticClackId = "rbxasset://sounds/snap.wav",
	toyRattleId = "rbxasset://sounds/action_get.wav",
	metalTinkId = "rbxasset://sounds/snap.wav",
}

local function playKeyedSound(soundKey: string)
	if soundKey == "DRONE_ZAP" then
		SoundLimiter.Play2D(soundKey, "rbxasset://sounds/electronicpingshort.wav", 0.24, 1.05)
	elseif soundKey == "DROP_CLINK" then
		SoundLimiter.Play2D(soundKey, "rbxasset://sounds/snap.wav", 0.14, 1.1)
	end
end

local function playWorldDropClink(position: Vector3)
	local anchor = Instance.new("Part")
	anchor.Name = "DropClinkAnchor"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position
	anchor.Parent = Workspace

	local sound = Instance.new("Sound")
	sound.SoundId = "rbxasset://sounds/snap.wav"
	sound.Volume = 0.25
	sound.PlaybackSpeed = 1.1
	sound.RollOffMaxDistance = 60
	sound.RollOffMinDistance = 8
	sound.Parent = anchor
	sound:Play()

	Debris:AddItem(anchor, 2)
end

local function playDeathDebrisSound(position: Vector3)
	local anchor = Instance.new("Part")
	anchor.Name = "DroneDeathDebrisAudio"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position
	anchor.Parent = Workspace

	local clips = {
		{name = "plastic_clack", soundId = DEATH_FX.plasticClackId},
		{name = "toy_rattle", soundId = DEATH_FX.toyRattleId},
		{name = "metal_tink", soundId = DEATH_FX.metalTinkId},
	}
	local selected = clips[math.random(1, #clips)]

	local sound = Instance.new("Sound")
	sound.Name = selected.name
	sound.SoundId = selected.soundId
	sound.Volume = DEATH_FX.soundVolume
	sound.PlaybackSpeed = DEATH_FX.playbackMin + (math.random() * (DEATH_FX.playbackMax - DEATH_FX.playbackMin))
	sound.RollOffMaxDistance = 70
	sound.RollOffMinDistance = 7
	sound.Parent = anchor
	sound:Play()

	-- TODO: replace these placeholder built-in ids with custom non-branded debris assets.
	local layer = Instance.new("Sound")
	layer.Name = "plastic_clack_layer"
	layer.SoundId = DEATH_FX.plasticClackId
	layer.Volume = DEATH_FX.soundVolume * 0.55
	layer.PlaybackSpeed = sound.PlaybackSpeed + 0.16
	layer.RollOffMaxDistance = 55
	layer.RollOffMinDistance = 6
	layer.Parent = anchor
	task.delay(0.03, function()
		if layer.Parent then
			layer:Play()
		end
	end)

	Debris:AddItem(anchor, 2)
end

local function spawnDeathDebrisBurst(position: Vector3)
	local anchor = Instance.new("Part")
	anchor.Name = "DroneDeathDebrisFx"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position
	anchor.Parent = Workspace

	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor

	local emitter = Instance.new("ParticleEmitter")
	emitter.Lifetime = NumberRange.new(0.2, 0.45)
	emitter.Speed = NumberRange.new(8, 14)
	emitter.SpreadAngle = Vector2.new(55, 55)
	emitter.Rate = 0
	emitter.LightEmission = 0.05
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.22),
		NumberSequenceKeypoint.new(1, 0.05),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(Color3.fromRGB(230, 230, 230), Color3.fromRGB(180, 180, 180))
	emitter.RotSpeed = NumberRange.new(-140, 140)
	emitter.Parent = attachment
	emitter:Emit(DEATH_FX.burstParticles)

	Debris:AddItem(anchor, 0.7)
end

local function playDroneShotSound(position: Vector3)
	local anchor = Instance.new("Part")
	anchor.Name = "DroneShotAudio"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position
	anchor.Parent = Workspace

	local sound = Instance.new("Sound")
	sound.Name = "drone_shot_zap"
	sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	sound.Volume = 0.2
	sound.PlaybackSpeed = 1.05 + (math.random() * 0.2)
	sound.RollOffMaxDistance = 100
	sound.RollOffMinDistance = 10
	sound.Parent = anchor
	sound:Play()

	Debris:AddItem(anchor, 1)
end

local function spawnDroneShotBeam(origin: Vector3, hitPosition: Vector3)
	local delta = hitPosition - origin
	local distance = delta.Magnitude
	if distance <= 0.001 then
		return
	end

	local beamPart = Instance.new("Part")
	beamPart.Name = "DroneShotBeam"
	beamPart.Anchored = true
	beamPart.CanCollide = false
	beamPart.Material = Enum.Material.Neon
	beamPart.Color = Color3.fromRGB(255, 60, 60)
	beamPart.Size = Vector3.new(0.1, 0.1, distance)
	beamPart.CFrame = CFrame.lookAt(origin, hitPosition) * CFrame.new(0, 0, -distance * 0.5)
	beamPart.Parent = Workspace
	Debris:AddItem(beamPart, 0.08)
end

local function spawnShotImpactSpark(position: Vector3)
	local anchor = Instance.new("Part")
	anchor.Name = "DroneShotImpact"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position
	anchor.Parent = Workspace

	local attachment = Instance.new("Attachment")
	attachment.Parent = anchor

	local emitter = Instance.new("ParticleEmitter")
	emitter.Lifetime = NumberRange.new(0.08, 0.16)
	emitter.Speed = NumberRange.new(5, 10)
	emitter.SpreadAngle = Vector2.new(35, 35)
	emitter.Rate = 0
	emitter.LightEmission = 0.7
	emitter.Size = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.16),
		NumberSequenceKeypoint.new(1, 0),
	})
	emitter.Transparency = NumberSequence.new({
		NumberSequenceKeypoint.new(0, 0.05),
		NumberSequenceKeypoint.new(1, 1),
	})
	emitter.Color = ColorSequence.new(Color3.fromRGB(255, 160, 160), Color3.fromRGB(255, 255, 255))
	emitter.Parent = attachment
	emitter:Emit(8)

	Debris:AddItem(anchor, 0.3)
end

local function playScanPingSound(position: Vector3)
	local anchor = Instance.new("Part")
	anchor.Name = "DroneScanPingAudio"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position
	anchor.Parent = Workspace

	local sound = Instance.new("Sound")
	sound.Name = "drone_scan_ping"
	sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	sound.Volume = 0.12
	sound.PlaybackSpeed = 1.4
	sound.RollOffMaxDistance = 90
	sound.RollOffMinDistance = 8
	sound.Parent = anchor
	sound:Play()

	Debris:AddItem(anchor, 1)
end

local function playLockSound(position: Vector3)
	local anchor = Instance.new("Part")
	anchor.Name = "DroneLockAudio"
	anchor.Anchored = true
	anchor.CanCollide = false
	anchor.Transparency = 1
	anchor.Size = Vector3.new(0.2, 0.2, 0.2)
	anchor.Position = position
	anchor.Parent = Workspace

	local sound = Instance.new("Sound")
	sound.Name = "drone_lock"
	sound.SoundId = "rbxasset://sounds/electronicpingshort.wav"
	sound.Volume = 0.2
	sound.PlaybackSpeed = 0.75
	sound.RollOffMaxDistance = 100
	sound.RollOffMinDistance = 10
	sound.Parent = anchor
	sound:Play()

	Debris:AddItem(anchor, 1.2)
end

local function spawnScanPulse(position: Vector3, color: Color3, radius: number)
	local part = Instance.new("Part")
	part.Name = "DroneScanPulse"
	part.Shape = Enum.PartType.Ball
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.Neon
	part.Color = color
	part.Transparency = 0.35
	part.Size = Vector3.new(1.4, 1.4, 1.4)
	part.Position = position
	part.Parent = Workspace

	local growSteps = 6
	for step = 1, growSteps do
		task.delay((step - 1) * 0.02, function()
			if part.Parent then
				local alpha = step / growSteps
				local size = 1.4 + (radius * alpha)
				part.Size = Vector3.new(size, size, size)
				part.Transparency = 0.35 + (alpha * 0.6)
			end
		end)
	end

	Debris:AddItem(part, 0.16)
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
		if typeof(position) == "Vector3" then
			playWorldDropClink(position)
		else
			playKeyedSound("DROP_CLINK")
		end
	elseif eventType == "DRONE_DEBRIS" and typeof(position) == "Vector3" then
		spawnDeathDebrisBurst(position)
		playDeathDebrisSound(position)
	elseif eventType == "DRONE_SHOT" then
		local origin = payload.origin
		local hitPosition = payload.hitPosition
		if typeof(origin) == "Vector3" and typeof(hitPosition) == "Vector3" then
			spawnDroneShotBeam(origin, hitPosition)
			playDroneShotSound(origin)
			if payload.hit == true then
				spawnShotImpactSpark(hitPosition)
			end
		end
	elseif eventType == "DRONE_SCAN_PING" and typeof(position) == "Vector3" then
		spawnScanPulse(position, Color3.fromRGB(120, 210, 255), 5)
		playScanPingSound(position)
	elseif eventType == "DRONE_LOCK" and typeof(position) == "Vector3" then
		spawnScanPulse(position, Color3.fromRGB(255, 95, 95), 7)
		playLockSound(position)
	end
end)

print("[FeedbackController] Ready")
