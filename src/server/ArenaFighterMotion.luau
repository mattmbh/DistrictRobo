local ArenaFighterMotion = {}

type MotionState = {
	mode: string,
	startedAt: number,
	endsAt: number,
	forward: Vector3,
	side: number,
}

local DEFAULT_FORWARD = Vector3.new(0, 0, -1)

local function planarDirection(fromPosition: Vector3, targetPosition: Vector3, fallback: Vector3?): Vector3
	local delta = Vector3.new(targetPosition.X - fromPosition.X, 0, targetPosition.Z - fromPosition.Z)
	if delta.Magnitude <= 0.001 then
		if fallback and fallback.Magnitude > 0.001 then
			return fallback.Unit
		end
		return DEFAULT_FORWARD
	end
	return delta.Unit
end

local function setMotion(fighter: any, mode: string, now: number, duration: number?, forward: Vector3?)
	local side = fighter.slot == "A" and -1 or 1
	fighter.motionState = {
		mode = mode,
		startedAt = now,
		endsAt = duration and (now + duration) or 0,
		forward = if forward and forward.Magnitude > 0.001 then forward.Unit else fighter.lastLookDirection or DEFAULT_FORWARD,
		side = side,
	} :: MotionState
end

function ArenaFighterMotion.Initialize(fighter: any, spawnPosition: Vector3, lookTarget: Vector3)
	fighter.logicalPosition = spawnPosition
	fighter.lookTarget = lookTarget
	fighter.lastLookDirection = planarDirection(spawnPosition, lookTarget, DEFAULT_FORWARD)
	fighter.idleSeed = (fighter.slot == "A" and 0.15 or 1.1) + math.random() * 2.5
	setMotion(fighter, "ready", os.clock(), 0.4, fighter.lastLookDirection)
end

function ArenaFighterMotion.SetBaseTransform(fighter: any, position: Vector3, lookTarget: Vector3)
	fighter.logicalPosition = position
	fighter.lookTarget = lookTarget
	fighter.lastLookDirection = planarDirection(position, lookTarget, fighter.lastLookDirection)
end

function ArenaFighterMotion.SetReady(fighter: any, now: number)
	if fighter.motionState and fighter.motionState.mode == "ko" then
		return
	end
	setMotion(fighter, "ready", now, 0.45, fighter.lastLookDirection)
end

function ArenaFighterMotion.StartWindup(fighter: any, now: number, forward: Vector3, duration: number)
	if fighter.motionState and fighter.motionState.mode == "ko" then
		return
	end
	setMotion(fighter, "windup", now, duration, forward)
end

function ArenaFighterMotion.StartStrike(fighter: any, now: number, forward: Vector3, duration: number)
	if fighter.motionState and fighter.motionState.mode == "ko" then
		return
	end
	setMotion(fighter, "strike", now, duration, forward)
end

function ArenaFighterMotion.StartHitReact(fighter: any, now: number, incomingForward: Vector3)
	if fighter.motionState and fighter.motionState.mode == "ko" then
		return
	end
	setMotion(fighter, "hit", now, 0.18, incomingForward)
end

function ArenaFighterMotion.StartKO(fighter: any, now: number, incomingForward: Vector3)
	setMotion(fighter, "ko", now, nil, incomingForward)
end

function ArenaFighterMotion.StartVictory(fighter: any, now: number)
	if fighter.motionState and fighter.motionState.mode == "ko" then
		return
	end
	setMotion(fighter, "victory", now, 1.2, fighter.lastLookDirection)
end

local function getOffsets(fighter: any, now: number): (number, number, number, number, number)
	local motion = fighter.motionState
	local forwardOffset = 0
	local lateralOffset = 0
	local verticalOffset = 0
	local pitch = 0
	local roll = 0

	if motion and motion.endsAt > 0 and now >= motion.endsAt then
		setMotion(fighter, "idle", now, 0, fighter.lastLookDirection)
		motion = fighter.motionState
	end

	if not motion then
		setMotion(fighter, "idle", now, 0, fighter.lastLookDirection)
		motion = fighter.motionState
	end

	local elapsed = now - motion.startedAt
	local side = motion.side
	if motion.mode == "ko" then
		forwardOffset = -0.85
		verticalOffset = -1.2
		pitch = math.rad(82)
		roll = math.rad(18 * side)
	elseif motion.mode == "victory" then
		local hopAlpha = math.max(0, math.sin(math.min(elapsed, 0.5) / 0.5 * math.pi))
		verticalOffset = hopAlpha * 0.42 + math.sin(elapsed * 7.5) * 0.03
		pitch = math.rad(-4)
		roll = math.sin(elapsed * 6.2) * math.rad(4 * side)
	elseif motion.mode == "windup" then
		local alpha = math.clamp(elapsed / math.max(0.01, motion.endsAt - motion.startedAt), 0, 1)
		forwardOffset = 0.18 + alpha * 0.22
		pitch = math.rad(-10 - alpha * 4)
	elseif motion.mode == "strike" then
		local alpha = math.clamp(elapsed / math.max(0.01, motion.endsAt - motion.startedAt), 0, 1)
		forwardOffset = 1.15 * (1 - math.abs(alpha - 0.45) / 0.55)
		forwardOffset = math.max(0, forwardOffset)
		pitch = math.rad(-14 + alpha * 6)
	elseif motion.mode == "hit" then
		local alpha = math.clamp(elapsed / math.max(0.01, motion.endsAt - motion.startedAt), 0, 1)
		local recoil = math.sin(alpha * math.pi)
		forwardOffset = -0.9 * recoil
		verticalOffset = 0.08 * recoil
		pitch = math.rad(10 * recoil)
		roll = math.rad(12 * recoil * side)
	elseif motion.mode == "ready" then
		local settle = math.max(0, 1 - math.min(elapsed / 0.45, 1))
		verticalOffset = settle * 0.08
		pitch = math.rad(-3 * settle)
	else
		local bob = math.sin(now * 2.5 + fighter.idleSeed) * 0.08
		local sway = math.sin(now * 1.7 + fighter.idleSeed * 1.3)
		verticalOffset = bob
		pitch = math.rad(-1.8 + bob * 8)
		roll = math.rad(sway * 2.5)
		lateralOffset = sway * 0.06
	end

	return forwardOffset, lateralOffset, verticalOffset, pitch, roll
end

function ArenaFighterMotion.Update(fighter: any, now: number)
	if not (fighter.model and fighter.model.Parent) then
		return
	end

	local logicalPosition = fighter.logicalPosition or fighter.rootPart.Position
	local lookDirection = planarDirection(logicalPosition, fighter.lookTarget or (logicalPosition + fighter.lastLookDirection), fighter.lastLookDirection)
	fighter.lastLookDirection = lookDirection

	local forwardOffset, lateralOffset, verticalOffset, pitch, roll = getOffsets(fighter, now)
	local right = Vector3.new(-lookDirection.Z, 0, lookDirection.X)
	local finalPosition = logicalPosition
		+ lookDirection * forwardOffset
		+ right * lateralOffset
		+ Vector3.new(0, verticalOffset, 0)
	local base = CFrame.lookAt(finalPosition, finalPosition + lookDirection)
	fighter.model:PivotTo(base * CFrame.Angles(pitch, 0, roll))
end

return ArenaFighterMotion
