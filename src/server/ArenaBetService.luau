local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Net = require(Shared:WaitForChild("Net"))

local ArenaBetService = {}

type BetRecord = {
	roundId: number,
	slot: string,
	amount: number,
	player: Player,
}

local toastRemote = Net.GetOrCreateRemoteEvent(Constants.Remotes.Toast)
local placeBetRemote = Net.GetOrCreateRemoteEvent(Constants.Remotes.ArenaPlaceBet)

local betsByUserId: {[number]: BetRecord} = {}
local currentRoundId = 0
local currentFighters = {A = "", B = ""}
local bettingOpen = false
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

local function setPlayerBetState(player: Player, roundId: number, slot: string, amount: number)
	player:SetAttribute("ArenaBetRoundId", roundId)
	player:SetAttribute("ArenaBetSlot", slot)
	player:SetAttribute("ArenaBetAmount", amount)
	player:SetAttribute("ArenaOutcomeRoundId", -1)
	player:SetAttribute("ArenaOutcome", "")
end

local function clearPlayerBetState(player: Player, roundId: number)
	player:SetAttribute("ArenaBetRoundId", roundId)
	player:SetAttribute("ArenaBetSlot", "")
	player:SetAttribute("ArenaBetAmount", 0)
	player:SetAttribute("ArenaOutcomeRoundId", -1)
	player:SetAttribute("ArenaOutcome", "")
end

local function refreshBetTotals()
	if not stateFolder then
		return
	end

	local poolA = 0
	local poolB = 0
	local bettors = 0
	for _, bet in pairs(betsByUserId) do
		if bet.roundId == currentRoundId then
			bettors += 1
			if bet.slot == "A" then
				poolA += bet.amount
			else
				poolB += bet.amount
			end
		end
	end

	stateFolder:SetAttribute("BetPoolA", poolA)
	stateFolder:SetAttribute("BetPoolB", poolB)
	stateFolder:SetAttribute("PlayerBetCount", bettors)
end

function ArenaBetService.BindReplicatedState(folder: Folder)
	stateFolder = folder
	refreshBetTotals()
end

function ArenaBetService.Open(roundId: number, fighterAName: string, fighterBName: string)
	currentRoundId = roundId
	currentFighters.A = fighterAName
	currentFighters.B = fighterBName
	bettingOpen = true
	table.clear(betsByUserId)
	for _, player in ipairs(Players:GetPlayers()) do
		clearPlayerBetState(player, roundId)
	end
	refreshBetTotals()
	print(("[ArenaBet] Open round=%d fighterA=%s fighterB=%s"):format(roundId, fighterAName, fighterBName))
end

function ArenaBetService.Close()
	bettingOpen = false
	if stateFolder then
		stateFolder:SetAttribute("BettingOpen", false)
	end
	print(("[ArenaBet] Closed round=%d"):format(currentRoundId))
end

function ArenaBetService.Resolve(winningSlot: string?)
	if winningSlot ~= "A" and winningSlot ~= "B" then
		warn(("[ArenaBet] Invalid winningSlot '%s'; forcing A as fallback"):format(tostring(winningSlot)))
		winningSlot = "A"
	end

	local winners = 0

	for _, player in ipairs(Players:GetPlayers()) do
		if tonumber(player:GetAttribute("ArenaBetRoundId") or -1) == currentRoundId then
			player:SetAttribute("ArenaOutcomeRoundId", currentRoundId)
			player:SetAttribute("ArenaOutcome", "Lost")
		end
	end

	for _, bet in pairs(betsByUserId) do
		if bet.roundId == currentRoundId and winningSlot and bet.slot == winningSlot then
			local credits = ensureCreditsValue(bet.player)
			local payout = bet.amount * 2
			credits.Value += payout
			winners += 1
			bet.player:SetAttribute("ArenaOutcomeRoundId", currentRoundId)
			bet.player:SetAttribute("ArenaOutcome", "Won")
			toastRemote:FireClient(bet.player, ("Arena win: +%d credits on %s"):format(payout, if winningSlot == "A" then currentFighters.A else currentFighters.B))
			print(("[ArenaBet] %s won %d on %s"):format(bet.player.Name, payout, winningSlot))
		end
	end

	print(("[ArenaBet] Resolved round=%d winningSlot=%s winners=%d"):format(currentRoundId, winningSlot, winners))

	refreshBetTotals()
end

placeBetRemote.OnServerEvent:Connect(function(player: Player, fighterSlot: string, amount: number?)
	if not bettingOpen then
		toastRemote:FireClient(player, "Arena betting is closed.")
		return
	end

	if betsByUserId[player.UserId] ~= nil then
		toastRemote:FireClient(player, "You already placed an arena bet this round.")
		return
	end

	if fighterSlot ~= "A" and fighterSlot ~= "B" then
		toastRemote:FireClient(player, "Invalid arena fighter choice.")
		return
	end

	local betAmount = if typeof(amount) == "number" then math.floor(amount) else Constants.Arena.DefaultBetAmount
	betAmount = math.max(Constants.Arena.MinimumBetAmount, betAmount)

	local credits = ensureCreditsValue(player)
	if credits.Value < betAmount then
		toastRemote:FireClient(player, ("Need %d credits to bet."):format(betAmount))
		return
	end

	credits.Value -= betAmount
	betsByUserId[player.UserId] = {
		roundId = currentRoundId,
		slot = fighterSlot,
		amount = betAmount,
		player = player,
	}
	setPlayerBetState(player, currentRoundId, fighterSlot, betAmount)

	refreshBetTotals()
	local fighterName = if fighterSlot == "A" then currentFighters.A else currentFighters.B
	toastRemote:FireClient(player, ("Arena bet placed: %d on %s"):format(betAmount, fighterName))
	print(("[ArenaBet] %s bet %d on %s round=%d"):format(player.Name, betAmount, fighterSlot, currentRoundId))
end)

Players.PlayerRemoving:Connect(function(player)
	betsByUserId[player.UserId] = nil
	refreshBetTotals()
end)

Players.PlayerAdded:Connect(function(player)
	clearPlayerBetState(player, currentRoundId)
end)

return ArenaBetService
