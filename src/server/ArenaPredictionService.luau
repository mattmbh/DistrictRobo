local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Net = require(Shared:WaitForChild("Net"))

local PlayerRewardUpgradeService = require(script.Parent:WaitForChild("PlayerRewardUpgradeService"))
local TutorialService = require(script.Parent:WaitForChild("TutorialService"))

local ArenaPredictionService = {}

type PredictionRecord = {
	roundId: number,
	slot: string,
	fighterId: string,
	predictionLocked: boolean,
	rewardGranted: boolean,
	player: Player,
}

local toastRemote = Net.GetOrCreateRemoteEvent(Constants.Remotes.Toast)
local predictWinnerRemote = Net.GetOrCreateRemoteEvent(Constants.Remotes.ArenaPredictWinner)

local predictionsByUserId: {[number]: PredictionRecord} = {}
local currentRoundId = 0
local currentFighters = {
	A = {Name = "", Id = ""},
	B = {Name = "", Id = ""},
}
local predictionOpen = false
local stateFolder: Folder? = nil

local function ensureLeaderstats(player: Player): Folder
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats and leaderstats:IsA("Folder") then
		return leaderstats
	end

	leaderstats = Instance.new("Folder")
	leaderstats.Name = "leaderstats"
	leaderstats.Parent = player
	return leaderstats
end

local function ensureCreditsValue(player: Player): IntValue
	local leaderstats = ensureLeaderstats(player)
	local credits = leaderstats:FindFirstChild("Credits")
	if credits and credits:IsA("IntValue") then
		return credits
	end

	local value = Instance.new("IntValue")
	value.Name = "Credits"
	value.Value = Constants.GameSettings.StartingCoins
	value.Parent = leaderstats
	return value
end

local function setPlayerPredictionState(player: Player, roundId: number, slot: string, fighterId: string, locked: boolean, rewardGranted: boolean)
	player:SetAttribute("ArenaPredictionRoundId", roundId)
	player:SetAttribute("ArenaPredictionSlot", slot)
	player:SetAttribute("ArenaPredictionFighterId", fighterId)
	player:SetAttribute("ArenaPredictionLocked", locked)
	player:SetAttribute("ArenaPredictionRewardGranted", rewardGranted)
	player:SetAttribute("ArenaOutcomeRoundId", -1)
	player:SetAttribute("ArenaOutcome", "")
	player:SetAttribute("ArenaOutcomeReward", 0)
end

local function clearPlayerPredictionState(player: Player, roundId: number)
	player:SetAttribute("ArenaPredictionRoundId", roundId)
	player:SetAttribute("ArenaPredictionSlot", "")
	player:SetAttribute("ArenaPredictionFighterId", "")
	player:SetAttribute("ArenaPredictionLocked", false)
	player:SetAttribute("ArenaPredictionRewardGranted", false)
	player:SetAttribute("ArenaOutcomeRoundId", -1)
	player:SetAttribute("ArenaOutcome", "")
	player:SetAttribute("ArenaOutcomeReward", 0)
end

local function refreshPredictionTotals()
	if not stateFolder then
		return
	end

	local countA = 0
	local countB = 0
	local predictors = 0
	for _, prediction in pairs(predictionsByUserId) do
		if prediction.roundId == currentRoundId then
			predictors += 1
			if prediction.slot == "A" then
				countA += 1
			elseif prediction.slot == "B" then
				countB += 1
			end
		end
	end

	stateFolder:SetAttribute("PredictionCountA", countA)
	stateFolder:SetAttribute("PredictionCountB", countB)
	stateFolder:SetAttribute("PlayerPredictionCount", predictors)
end

function ArenaPredictionService.BindReplicatedState(folder: Folder)
	stateFolder = folder
	refreshPredictionTotals()
end

function ArenaPredictionService.Open(roundId: number, fighterAName: string, fighterAId: string, fighterBName: string, fighterBId: string)
	currentRoundId = roundId
	currentFighters.A = {Name = fighterAName, Id = fighterAId}
	currentFighters.B = {Name = fighterBName, Id = fighterBId}
	predictionOpen = true
	table.clear(predictionsByUserId)
	for _, player in ipairs(Players:GetPlayers()) do
		clearPlayerPredictionState(player, roundId)
	end
	if stateFolder then
		stateFolder:SetAttribute("PredictionOpen", true)
	end
	refreshPredictionTotals()
	print(("[ArenaPrediction] Open round=%d fighterA=%s fighterB=%s"):format(roundId, fighterAName, fighterBName))
end

function ArenaPredictionService.Close()
	predictionOpen = false
	if stateFolder then
		stateFolder:SetAttribute("PredictionOpen", false)
	end

	for _, player in ipairs(Players:GetPlayers()) do
		if tonumber(player:GetAttribute("ArenaPredictionRoundId") or -1) == currentRoundId then
			player:SetAttribute("ArenaPredictionLocked", true)
		end
	end

	for _, prediction in pairs(predictionsByUserId) do
		if prediction.roundId == currentRoundId then
			prediction.predictionLocked = true
		end
	end

	print(("[ArenaPrediction] Locked round=%d"):format(currentRoundId))
end

function ArenaPredictionService.Resolve(winningSlot: string?)
	if winningSlot ~= "A" and winningSlot ~= "B" then
		warn(("[ArenaPrediction] Invalid winningSlot '%s'; forcing A as fallback"):format(tostring(winningSlot)))
		winningSlot = "A"
	end

	local rewarded = 0
	for _, prediction in pairs(predictionsByUserId) do
		if prediction.roundId == currentRoundId then
			prediction.player:SetAttribute("ArenaOutcomeRoundId", currentRoundId)
			if prediction.slot == winningSlot then
				local credits = ensureCreditsValue(prediction.player)
				local multiplier = PlayerRewardUpgradeService.GetRewardMultiplier(prediction.player)
				local reward = math.max(1, math.floor(Constants.Arena.CorrectPredictionReward * multiplier + 0.5))
				credits.Value += reward
				prediction.rewardGranted = true
				prediction.player:SetAttribute("ArenaPredictionRewardGranted", true)
				prediction.player:SetAttribute("ArenaOutcome", "Correct")
				prediction.player:SetAttribute("ArenaOutcomeReward", reward)
				rewarded += 1
			else
				prediction.rewardGranted = false
				prediction.player:SetAttribute("ArenaPredictionRewardGranted", false)
				prediction.player:SetAttribute("ArenaOutcome", "Missed")
				prediction.player:SetAttribute("ArenaOutcomeReward", 0)
			end
		end
	end

	print(("[ArenaPrediction] Resolved round=%d winningSlot=%s rewarded=%d"):format(currentRoundId, winningSlot, rewarded))
	refreshPredictionTotals()
end

predictWinnerRemote.OnServerEvent:Connect(function(player: Player, fighterSlot: string)
	if not predictionOpen then
		toastRemote:FireClient(player, "Arena prediction window is closed.")
		return
	end

	if predictionsByUserId[player.UserId] ~= nil then
		toastRemote:FireClient(player, "You already predicted this arena round.")
		return
	end

	if fighterSlot ~= "A" and fighterSlot ~= "B" then
		toastRemote:FireClient(player, "Invalid arena fighter choice.")
		return
	end

	local fighterState = currentFighters[fighterSlot]
	predictionsByUserId[player.UserId] = {
		roundId = currentRoundId,
		slot = fighterSlot,
		fighterId = fighterState.Id,
		predictionLocked = false,
		rewardGranted = false,
		player = player,
	}
	setPlayerPredictionState(player, currentRoundId, fighterSlot, fighterState.Id, false, false)
	TutorialService.MarkPredictionMade(player)

	refreshPredictionTotals()
	toastRemote:FireClient(player, ("Prediction locked in: %s"):format(fighterState.Name))
	print(("[ArenaPrediction] %s predicted %s round=%d"):format(player.Name, fighterSlot, currentRoundId))
end)

Players.PlayerRemoving:Connect(function(player)
	predictionsByUserId[player.UserId] = nil
	refreshPredictionTotals()
end)

Players.PlayerAdded:Connect(function(player)
	PlayerRewardUpgradeService.InitializePlayer(player)
	clearPlayerPredictionState(player, currentRoundId)
end)

return ArenaPredictionService
