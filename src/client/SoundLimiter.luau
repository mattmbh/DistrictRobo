local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SoundService = game:GetService("SoundService")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local SoundLimiter = {}

local recentPlays: {number} = {}
local lastPlayedByKey: {[string]: number} = {}

local function trimRecent(now: number)
	local kept = {}
	for _, timestamp in ipairs(recentPlays) do
		if now - timestamp <= 1 then
			table.insert(kept, timestamp)
		end
	end
	recentPlays = kept
end

local function canPlay(soundKey: string): boolean
	local now = time()
	trimRecent(now)

	local cooldown = Constants.Audio.Cooldowns[soundKey] or 0
	local last = lastPlayedByKey[soundKey] or 0
	if now - last < cooldown then
		return false
	end

	local currentCount = #recentPlays
	local maxPerSecond = Constants.Audio.MAX_PLAYS_PER_SECOND
	local priority = Constants.Audio.Priority[soundKey] or "low"

	if currentCount >= maxPerSecond then
		return false
	end

	-- Reserve a small portion of budget for important cues.
	if priority == "low" and currentCount >= (maxPerSecond - 1) then
		return false
	end

	return true
end

function SoundLimiter.Play2D(soundKey: string, soundId: string, volume: number, playbackSpeed: number?)
	if not canPlay(soundKey) then
		return false
	end

	local sound = Instance.new("Sound")
	sound.SoundId = soundId
	sound.Volume = volume
	sound.PlaybackSpeed = playbackSpeed or 1
	sound.Parent = SoundService
	sound:Play()
	sound.Ended:Connect(function()
		sound:Destroy()
	end)

	local now = time()
	lastPlayedByKey[soundKey] = now
	table.insert(recentPlays, now)
	return true
end

return SoundLimiter
