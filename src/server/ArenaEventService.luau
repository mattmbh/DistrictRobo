local ReplicatedStorage = game:GetService("ReplicatedStorage")
local RunService = game:GetService("RunService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArenaFighterDefs = require(Shared:WaitForChild("ArenaFighterDefs"))
local Constants = require(Shared:WaitForChild("Constants"))

local ArenaPredictionService = require(script.Parent:WaitForChild("ArenaPredictionService"))
local ArenaBuildService = require(script.Parent:WaitForChild("ArenaBuildService"))
local ArenaCombatFX = require(script.Parent:WaitForChild("ArenaCombatFX"))
local ArenaDisplayService = require(script.Parent:WaitForChild("ArenaDisplayService"))

local ArenaEventService = {}

type CombatProfile = {
	MaxHealth: number,
	AttackDamage: number,
	AttackCooldown: number,
	MoveSpeed: number,
	AttackWindup: number,
	PreferredCombatDistanceOffset: number,
	MinimumCombatDistanceOffset: number,
	OpeningDelay: number,
}

type FighterState = {
	slot: string,
	definition: {[string]: any},
	combatProfile: CombatProfile,
	model: Model,
	humanoid: Humanoid,
	rootPart: BasePart,
	head: BasePart,
	healthFill: Frame,
	windupEndsAt: number,
	strikeAt: number,
	recoveryEndsAt: number,
	nextAttackAt: number,
	damageDealt: number,
	hitsLanded: number,
}

local replicatedFolder: Folder? = nil
local runtimeFolder: Folder? = nil
local currentRoundId = 0
local currentFighters: {FighterState} = {}

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

local function getReplicatedFolder(): Folder
	if replicatedFolder then
		return replicatedFolder
	end

	local existing = ReplicatedStorage:FindFirstChild("ArenaState")
	if existing and existing:IsA("Folder") then
		replicatedFolder = existing
	else
		replicatedFolder = Instance.new("Folder")
		replicatedFolder.Name = "ArenaState"
		replicatedFolder.Parent = ReplicatedStorage
	end

	return replicatedFolder
end

local function getRuntimeFolder(): Folder
	if runtimeFolder then
		return runtimeFolder
	end

	local buildData = ArenaBuildService.GetArenaData()
	runtimeFolder = ensureFolder(buildData.arenaModel, "Runtime")
	return runtimeFolder
end

local function updateState(updates: {[string]: any})
	local folder = getReplicatedFolder()
	for key, value in pairs(updates) do
		folder:SetAttribute(key, value)
	end
end

local function setPresentation(headline: string, detail: string, cue: string, countdown: number?)
	updateState({
		DisplayHeadline = headline,
		DisplayDetail = detail,
		EventCue = cue,
		CountdownNumber = countdown or 0,
	})
end

local function pulseArenaLights(color: Color3, brightness: number, duration: number)
	local buildData = ArenaBuildService.GetArenaData()
	local lights = {}
	for _, descendant in ipairs(buildData.arenaModel:GetDescendants()) do
		if descendant:IsA("PointLight") then
			table.insert(lights, {
				light = descendant,
				color = descendant.Color,
				brightness = descendant.Brightness,
			})
		end
	end

	for _, entry in ipairs(lights) do
		entry.light.Color = color
		entry.light.Brightness = brightness
	end

	task.delay(duration, function()
		for _, entry in ipairs(lights) do
			if entry.light.Parent then
				entry.light.Color = entry.color
				entry.light.Brightness = entry.brightness
			end
		end
	end)
end

local function setPublicChoiceState(prefix: string, definition: {[string]: any})
	local publicProfile = ArenaFighterDefs.GetPublicProfile(definition)
	updateState({
		[prefix .. "Name"] = publicProfile.Name,
		[prefix .. "Style"] = publicProfile.Style,
		[prefix .. "Power"] = publicProfile.Power,
		[prefix .. "Speed"] = publicProfile.Speed,
		[prefix .. "Toughness"] = publicProfile.Toughness,
		[prefix .. "Aggression"] = publicProfile.Aggression,
		[prefix .. "Wins"] = publicProfile.Wins,
		[prefix .. "Losses"] = publicProfile.Losses,
		[prefix .. "Record"] = publicProfile.Record,
	})
end

local function createNameplate(head: BasePart, definition: {[string]: any}): Frame
	local publicProfile = ArenaFighterDefs.GetPublicProfile(definition)
	local billboard = Instance.new("BillboardGui")
	billboard.Name = "ArenaNameplate"
	billboard.Size = UDim2.fromOffset(180, 58)
	billboard.StudsOffsetWorldSpace = Vector3.new(0, 2.8, 0)
	billboard.AlwaysOnTop = true
	billboard.MaxDistance = Constants.Arena.NameplateMaxDistance
	billboard.Parent = head

	local frame = Instance.new("Frame")
	frame.BackgroundColor3 = Color3.fromRGB(12, 16, 22)
	frame.BackgroundTransparency = 0.12
	frame.BorderSizePixel = 0
	frame.Size = UDim2.fromScale(1, 1)
	frame.Parent = billboard

	local stroke = Instance.new("UIStroke")
	stroke.Thickness = 1
	stroke.Color = definition.Color
	stroke.Parent = frame

	local nameLabel = Instance.new("TextLabel")
	nameLabel.BackgroundTransparency = 1
	nameLabel.Position = UDim2.fromOffset(8, 4)
	nameLabel.Size = UDim2.new(1, -16, 0, 20)
	nameLabel.TextXAlignment = Enum.TextXAlignment.Left
	nameLabel.Font = Enum.Font.GothamBold
	nameLabel.TextSize = 15
	nameLabel.TextColor3 = Color3.fromRGB(245, 248, 251)
	nameLabel.Text = definition.Name
	nameLabel.Parent = frame

	local styleLabel = Instance.new("TextLabel")
	styleLabel.BackgroundTransparency = 1
	styleLabel.Position = UDim2.fromOffset(8, 22)
	styleLabel.Size = UDim2.new(1, -16, 0, 14)
	styleLabel.TextXAlignment = Enum.TextXAlignment.Left
	styleLabel.Font = Enum.Font.GothamSemibold
	styleLabel.TextSize = 11
	styleLabel.TextColor3 = Color3.fromRGB(179, 192, 206)
	styleLabel.Text = ("%s  |  REC %s"):format(publicProfile.Style, publicProfile.Record)
	styleLabel.Parent = frame

	local barBack = Instance.new("Frame")
	barBack.BackgroundColor3 = Color3.fromRGB(40, 46, 54)
	barBack.BorderSizePixel = 0
	barBack.Position = UDim2.fromOffset(8, 40)
	barBack.Size = UDim2.new(1, -16, 0, 10)
	barBack.Parent = frame

	local healthFill = Instance.new("Frame")
	healthFill.Name = "HealthFill"
	healthFill.BackgroundColor3 = Color3.fromRGB(244, 207, 88)
	healthFill.BorderSizePixel = 0
	healthFill.Size = UDim2.fromScale(1, 1)
	healthFill.Parent = barBack

	return healthFill
end

local function updateHealthVisual(fighter: FighterState)
	local alpha = math.clamp(fighter.humanoid.Health / math.max(1, fighter.humanoid.MaxHealth), 0, 1)
	fighter.healthFill.Size = UDim2.fromScale(alpha, 1)
	if alpha > 0.6 then
		fighter.healthFill.BackgroundColor3 = Color3.fromRGB(118, 216, 120)
	elseif alpha > 0.3 then
		fighter.healthFill.BackgroundColor3 = Color3.fromRGB(246, 201, 86)
	else
		fighter.healthFill.BackgroundColor3 = Color3.fromRGB(223, 92, 92)
	end
end

local function createBodyPart(parent: Model, name: string, size: Vector3, cframe: CFrame, color: Color3): Part
	local part = Instance.new("Part")
	part.Name = name
	part.Size = size
	part.CFrame = cframe
	part.Anchored = true
	part.CanCollide = false
	part.Material = Enum.Material.SmoothPlastic
	part.Color = color
	part.TopSurface = Enum.SurfaceType.Smooth
	part.BottomSurface = Enum.SurfaceType.Smooth
	part.Parent = parent
	return part
end

local function weldParts(a: BasePart, b: BasePart)
	local weld = Instance.new("WeldConstraint")
	weld.Part0 = a
	weld.Part1 = b
	weld.Parent = a
end

local function spawnFighter(slot: string, definition: {[string]: any}, combatProfile: CombatProfile, spawnPart: BasePart): FighterState
	local model = Instance.new("Model")
	model.Name = ("%s_%s"):format(slot, definition.Name)
	model.Parent = getRuntimeFolder()

	local rootPart = createBodyPart(model, "HumanoidRootPart", Vector3.new(2, 2, 1), spawnPart.CFrame + Vector3.new(0, 3.5, 0), definition.Color)
	rootPart.Transparency = 1
	rootPart.CanCollide = false

	local torso = createBodyPart(model, "Torso", Vector3.new(2.5, 3, 1.5), spawnPart.CFrame + Vector3.new(0, 4.5, 0), definition.Color)
	local head = createBodyPart(model, "Head", Vector3.new(2, 1.6, 1.6), spawnPart.CFrame + Vector3.new(0, 6.9, 0), Color3.new(1, 0.86, 0.72))
	local leftArm = createBodyPart(model, "LeftArm", Vector3.new(1, 2.6, 1), spawnPart.CFrame + Vector3.new(-1.8, 4.6, 0), definition.Color)
	local rightArm = createBodyPart(model, "RightArm", Vector3.new(1, 2.6, 1), spawnPart.CFrame + Vector3.new(1.8, 4.6, 0), definition.Color)
	local leftLeg = createBodyPart(model, "LeftLeg", Vector3.new(1, 3, 1), spawnPart.CFrame + Vector3.new(-0.7, 1.8, 0), definition.Color)
	local rightLeg = createBodyPart(model, "RightLeg", Vector3.new(1, 3, 1), spawnPart.CFrame + Vector3.new(0.7, 1.8, 0), definition.Color)

	for _, bodyPart in ipairs({torso, head, leftArm, rightArm, leftLeg, rightLeg}) do
		weldParts(rootPart, bodyPart)
	end

	local humanoid = Instance.new("Humanoid")
	humanoid.NameDisplayDistance = 48
	humanoid.DisplayDistanceType = Enum.HumanoidDisplayDistanceType.Viewer
	humanoid.MaxHealth = combatProfile.MaxHealth
	humanoid.Health = combatProfile.MaxHealth
	humanoid.WalkSpeed = 0
	humanoid.AutoRotate = false
	humanoid.Parent = model

	model.PrimaryPart = rootPart
	model:PivotTo(spawnPart.CFrame + Vector3.new(0, 3.5, 0))
	model:SetAttribute("ArenaSlot", slot)
	model:SetAttribute("FighterName", definition.Name)
	model:SetAttribute("AttackDamage", combatProfile.AttackDamage)
	model:SetAttribute("AttackCooldown", combatProfile.AttackCooldown)
	model:SetAttribute("Style", definition.Style)
	model:SetAttribute("Aggression", ArenaFighterDefs.GetPublicProfile(definition).Aggression)

	local healthFill = createNameplate(head, definition)

	print(("[ArenaFight] Spawned %s as %s hp=%.1f dmg=%.1f cd=%.2f style=%s"):format(
		definition.Name,
		slot,
		combatProfile.MaxHealth,
		combatProfile.AttackDamage,
		combatProfile.AttackCooldown,
		definition.Style
	))

	return {
		slot = slot,
		definition = definition,
		combatProfile = combatProfile,
		model = model,
		humanoid = humanoid,
		rootPart = rootPart,
		head = head,
		healthFill = healthFill,
		windupEndsAt = 0,
		strikeAt = 0,
		recoveryEndsAt = 0,
		nextAttackAt = 0,
		damageDealt = 0,
		hitsLanded = 0,
	}
end

local function destroyCurrentFighters()
	for _, fighter in ipairs(currentFighters) do
		if fighter.model.Parent then
			fighter.model:Destroy()
		end
	end
	table.clear(currentFighters)
end

local function alive(fighter: FighterState): boolean
	return fighter.humanoid.Health > 0 and fighter.model.Parent ~= nil
end

local function getFightCenter(): Vector3?
	local fighterA = currentFighters[1]
	local fighterB = currentFighters[2]
	if fighterA and fighterB and fighterA.model.Parent and fighterB.model.Parent then
		return (fighterA.rootPart.Position + fighterB.rootPart.Position) * 0.5 + Vector3.new(0, 3, 0)
	end
	return nil
end

local function rotateToward(fighter: FighterState, lookTarget: Vector3)
	local origin = fighter.rootPart.Position
	fighter.model:PivotTo(CFrame.lookAt(origin, Vector3.new(lookTarget.X, origin.Y, lookTarget.Z)))
end

local function stageFighters()
	local fighterA = currentFighters[1]
	local fighterB = currentFighters[2]
	if not fighterA or not fighterB then
		return
	end
	rotateToward(fighterA, fighterB.rootPart.Position)
	rotateToward(fighterB, fighterA.rootPart.Position)
	local fightCenter = getFightCenter()
	if fightCenter then
		updateState({
			FightCenter = fightCenter,
			FighterAHealthCurrent = fighterA.humanoid.Health,
			FighterBHealthCurrent = fighterB.humanoid.Health,
		})
	end
end

local function armFightersForRound()
	local now = os.clock()
	for _, fighter in ipairs(currentFighters) do
		fighter.windupEndsAt = 0
		fighter.strikeAt = 0
		fighter.recoveryEndsAt = 0
		fighter.nextAttackAt = now + math.max(0.05, fighter.combatProfile.OpeningDelay)
	end
end

local function resolveWinnerByTiebreaker(): string
	local fighterA = currentFighters[1]
	local fighterB = currentFighters[2]
	assert(fighterA and fighterB, "[ArenaFight] Tiebreaker requires 2 fighters")

	local maxHealthA = math.max(1, fighterA.humanoid.MaxHealth)
	local maxHealthB = math.max(1, fighterB.humanoid.MaxHealth)
	local healthPctA = fighterA.humanoid.Health / maxHealthA
	local healthPctB = fighterB.humanoid.Health / maxHealthB

	if math.abs(healthPctA - healthPctB) > 0.0001 then
		return if healthPctA > healthPctB then "A" else "B"
	end
	if math.abs(fighterA.humanoid.Health - fighterB.humanoid.Health) > 0.0001 then
		return if fighterA.humanoid.Health > fighterB.humanoid.Health then "A" else "B"
	end
	if fighterA.damageDealt ~= fighterB.damageDealt then
		return if fighterA.damageDealt > fighterB.damageDealt then "A" else "B"
	end
	if fighterA.hitsLanded ~= fighterB.hitsLanded then
		return if fighterA.hitsLanded > fighterB.hitsLanded then "A" else "B"
	end
	return if currentRoundId % 2 == 0 then "A" else "B"
end

local function stepFighter(fighter: FighterState, opponent: FighterState, deltaTime: number, now: number)
	if not alive(fighter) or not alive(opponent) then
		return
	end

	local origin = fighter.rootPart.Position
	local target = opponent.rootPart.Position
	local planarDelta = Vector3.new(target.X - origin.X, 0, target.Z - origin.Z)
	local distance = planarDelta.Magnitude
	local desiredLook = if distance > 0.001 then planarDelta.Unit else Vector3.new(0, 0, -1)
	rotateToward(fighter, target)

	if now < fighter.recoveryEndsAt then
		return
	end

	if fighter.strikeAt > 0 then
		if now < fighter.strikeAt then
			local leanPosition = origin + desiredLook * 0.35
			fighter.model:PivotTo(CFrame.lookAt(leanPosition, Vector3.new(target.X, leanPosition.Y, target.Z)))
			return
		end

		fighter.strikeAt = 0
		fighter.windupEndsAt = 0
		fighter.recoveryEndsAt = now + Constants.Arena.AttackRecovery
		fighter.nextAttackAt = now + fighter.combatProfile.AttackCooldown

		local lungePosition = origin + desiredLook * 1.6
		fighter.model:PivotTo(CFrame.lookAt(lungePosition, Vector3.new(target.X, lungePosition.Y, target.Z)))
		opponent.humanoid:TakeDamage(fighter.combatProfile.AttackDamage)
		fighter.damageDealt += fighter.combatProfile.AttackDamage
		fighter.hitsLanded += 1
		updateHealthVisual(opponent)
		local recoilPosition = opponent.rootPart.Position - desiredLook * Constants.Arena.HitRecoilDistance
		opponent.model:PivotTo(CFrame.lookAt(recoilPosition, Vector3.new(origin.X, recoilPosition.Y, origin.Z)))
		opponent.recoveryEndsAt = math.max(opponent.recoveryEndsAt, now + 0.12)
		ArenaCombatFX.EmitHit(opponent.rootPart, fighter.combatProfile.AttackDamage)
		print(("[ArenaFight] %s hit %s for %.1f (hp=%.1f)"):format(
			fighter.definition.Name,
			opponent.definition.Name,
			fighter.combatProfile.AttackDamage,
			opponent.humanoid.Health
		))
		return
	end

	if now < fighter.windupEndsAt then
		local leanPosition = origin + desiredLook * 0.35
		fighter.model:PivotTo(CFrame.lookAt(leanPosition, Vector3.new(target.X, leanPosition.Y, target.Z)))
		return
	end

	local minimumCombatDistance = Constants.Arena.MinimumCombatDistance + fighter.combatProfile.MinimumCombatDistanceOffset
	local preferredCombatDistance = Constants.Arena.PreferredCombatDistance + fighter.combatProfile.PreferredCombatDistanceOffset

	if distance < minimumCombatDistance and now >= fighter.nextAttackAt then
		local backstep = math.min(fighter.combatProfile.MoveSpeed * 0.45 * deltaTime, minimumCombatDistance - distance)
		local newPosition = origin - desiredLook * math.max(0.08, backstep)
		fighter.model:PivotTo(CFrame.lookAt(newPosition, Vector3.new(target.X, newPosition.Y, target.Z)))
		return
	end

	if distance > Constants.Arena.FightRange then
		local moveStep = math.min(fighter.combatProfile.MoveSpeed * deltaTime, math.max(0, distance - preferredCombatDistance))
		local newPosition = origin + desiredLook * moveStep
		fighter.model:PivotTo(CFrame.lookAt(newPosition, Vector3.new(target.X, newPosition.Y, target.Z)))
		return
	end

	if now < fighter.nextAttackAt then
		return
	end

	fighter.windupEndsAt = now + fighter.combatProfile.AttackWindup
	fighter.strikeAt = fighter.windupEndsAt
end

local function runFight(): string?
	local startedAt = os.clock()
	local timeout = Constants.Arena.FighterTimeout
	local nextCountdownUpdate = math.huge
	local nextBroadcastAt = 0

	while os.clock() - startedAt <= timeout do
		local deltaTime = RunService.Heartbeat:Wait()
		local elapsed = os.clock() - startedAt
		local remaining = math.max(0, math.ceil(timeout - elapsed))
		if remaining ~= nextCountdownUpdate then
			nextCountdownUpdate = remaining
			updateState({
				TimeRemaining = remaining,
			})
		end
		local fighterA = currentFighters[1]
		local fighterB = currentFighters[2]

		if not fighterA or not fighterB then
			return "A"
		end

		if not alive(fighterA) and not alive(fighterB) then
			return resolveWinnerByTiebreaker()
		end
		if not alive(fighterA) then
			return "B"
		end
		if not alive(fighterB) then
			return "A"
		end

		local now = os.clock()
		stepFighter(fighterA, fighterB, deltaTime, now)
		stepFighter(fighterB, fighterA, deltaTime, now)

		if now >= nextBroadcastAt then
			nextBroadcastAt = now + Constants.Arena.StateBroadcastRate
			local fightCenter = getFightCenter()
			if fightCenter then
				updateState({
					FightCenter = fightCenter,
					FighterAHealthCurrent = fighterA.humanoid.Health,
					FighterBHealthCurrent = fighterB.humanoid.Health,
				})
			end
		end
	end

	return resolveWinnerByTiebreaker()
end

local function setPhase(phase: string, duration: number)
	updateState({
		Phase = phase,
		TimeRemaining = duration,
		PredictionOpen = phase == "PredictionWindow",
		FightActive = phase == "FightActive",
		ResultReady = phase == "Result",
	})
	print(("[ArenaEvent] Phase=%s duration=%ds round=%d"):format(phase, duration, currentRoundId))
end

local function tickPhase(duration: number, countdownCue: boolean?)
	local remaining = duration
	while remaining > 0 do
		updateState({
			TimeRemaining = remaining,
		})
		if countdownCue and remaining <= 3 then
			setPresentation(tostring(remaining), "FIGHT STARTING", "Countdown", remaining)
		end
		task.wait(1)
		remaining -= 1
	end
	updateState({
		TimeRemaining = 0,
		CountdownNumber = 0,
	})
end

function ArenaEventService.Initialize()
	local buildData = ArenaBuildService.GetArenaData()
	local folder = getReplicatedFolder()
	ArenaPredictionService.BindReplicatedState(folder)
	ArenaDisplayService.Attach(buildData.arenaModel)

	updateState({
		ArenaReady = true,
		EventType = "ArenaDuel",
		ArenaLotId = ("%d_%d"):format(buildData.lot.xi, buildData.lot.zi),
		ArenaDistrict = "SAFE",
		ArenaPosition = buildData.lot.center,
		FocusPosition = buildData.focusPoint.Position,
		CameraAnchorPosition = buildData.cameraAnchor.Position,
		FightCenter = buildData.focusPoint.Position,
		IsArenaActive = true,
		Phase = "Boot",
		TimeRemaining = 0,
		DisplayHeadline = "ROBO DISTRICT ARENA",
		DisplayDetail = "Loading event feed...",
		EventCue = "Idle",
		CountdownNumber = 0,
		FighterAPower = 0,
		FighterASpeed = 0,
		FighterAToughness = 0,
		FighterAAggression = 0,
		FighterAWins = 0,
		FighterALosses = 0,
		FighterARecord = "0-0",
		FighterBPower = 0,
		FighterBSpeed = 0,
		FighterBToughness = 0,
		FighterBAggression = 0,
		FighterBWins = 0,
		FighterBLosses = 0,
		FighterBRecord = "0-0",
		PredictionCountA = 0,
		PredictionCountB = 0,
		PlayerPredictionCount = 0,
		FighterAWinChance = 50,
		FighterBWinChance = 50,
	})
end

function ArenaEventService.Run()
	ArenaEventService.Initialize()

	local phaseDurations = Constants.Arena.PhaseDurations
	while true do
		currentRoundId += 1
		destroyCurrentFighters()

		local definitionA, definitionB = ArenaFighterDefs.GetDuelPair(currentRoundId)
		local matchup = ArenaFighterDefs.BuildMatchup(definitionA, definitionB, currentRoundId)
		local combatProfileA = matchup.FighterA.CombatProfile
		local combatProfileB = matchup.FighterB.CombatProfile
		local buildData = ArenaBuildService.GetArenaData()

		setPublicChoiceState("FighterA", definitionA)
		setPublicChoiceState("FighterB", definitionB)
		updateState({
			RoundId = currentRoundId,
			FighterAName = definitionA.Name,
			FighterBName = definitionB.Name,
			FighterAStyle = definitionA.Style,
			FighterBStyle = definitionB.Style,
			FighterAHealth = combatProfileA.MaxHealth,
			FighterBHealth = combatProfileB.MaxHealth,
			FighterAHealthCurrent = combatProfileA.MaxHealth,
			FighterBHealthCurrent = combatProfileB.MaxHealth,
			FighterAWinChance = math.floor(matchup.FighterA.WinChance * 100 + 0.5),
			FighterBWinChance = math.floor(matchup.FighterB.WinChance * 100 + 0.5),
			WinnerName = "",
			WinnerSlot = "",
		})

		setPhase("Intermission", phaseDurations.Intermission)
		setPresentation("NEXT MAIN EVENT", "Crowd reset and prep in progress.", "Intermission", 0)
		tickPhase(phaseDurations.Intermission)

		local fighterA = spawnFighter("A", definitionA, combatProfileA, buildData.spawnA)
		local fighterB = spawnFighter("B", definitionB, combatProfileB, buildData.spawnB)
		currentFighters = {fighterA, fighterB}
		updateHealthVisual(fighterA)
		updateHealthVisual(fighterB)
		stageFighters()

		setPhase("Introductions", phaseDurations.Introductions)
		setPresentation(
			("A: %s  VS  B: %s"):format(definitionA.Name, definitionB.Name),
			("%s [%s]  VS  %s [%s]"):format(
				definitionA.Style,
				ArenaFighterDefs.GetPublicProfile(definitionA).Record,
				definitionB.Style,
				ArenaFighterDefs.GetPublicProfile(definitionB).Record
			),
			"Introductions",
			0
		)
		tickPhase(phaseDurations.Introductions)

		ArenaPredictionService.Open(currentRoundId, definitionA.Name, definitionA.Id, definitionB.Name, definitionB.Id)
		setPhase("PredictionWindow", phaseDurations.PredictionWindow)
		setPresentation(
			("PREDICT THE WINNER"),
			("%s [%s]  VS  %s [%s]"):format(definitionA.Name, definitionA.Style, definitionB.Name, definitionB.Style),
			"PredictionWindow",
			0
		)
		tickPhase(phaseDurations.PredictionWindow, true)
		ArenaPredictionService.Close()

		armFightersForRound()
		setPhase("FightActive", phaseDurations.FightActive)
		setPresentation("FIGHT!", ("%s  VS  %s"):format(definitionA.Name, definitionB.Name), "FightStart", 0)
		pulseArenaLights(Color3.fromRGB(255, 204, 122), 2.8, 0.45)
		local winningSlot = runFight()
		local winnerName = ""
		local winnerId = definitionA.Id
		local loserId = definitionB.Id
		if winningSlot == "A" then
			winnerName = definitionA.Name
		else
			winnerName = definitionB.Name
			winnerId = definitionB.Id
			loserId = definitionA.Id
		end

		ArenaPredictionService.Resolve(winningSlot)
		ArenaFighterDefs.RecordResult(winnerId, loserId)
		updateState({
			WinnerSlot = winningSlot or "",
			WinnerName = winnerName,
			LastResult = winnerName,
		})

		print(("[ArenaEvent] Round %d result=%s"):format(currentRoundId, winnerName))
		setPhase("Result", phaseDurations.Result)
		setPresentation("WINNER!", winnerName:upper(), "Winner", 0)
		pulseArenaLights(Color3.fromRGB(123, 220, 126), 2.4, 0.7)
		tickPhase(phaseDurations.Result)

		destroyCurrentFighters()
	end
end

return ArenaEventService
