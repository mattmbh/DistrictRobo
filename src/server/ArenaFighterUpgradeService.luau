local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArenaFighterDefs = require(Shared:WaitForChild("ArenaFighterDefs"))
local Constants = require(Shared:WaitForChild("Constants"))
local Net = require(Shared:WaitForChild("Net"))

local TutorialService = require(script.Parent:WaitForChild("TutorialService"))

local ArenaFighterUpgradeService = {}

type RefreshCallback = () -> ()

local toastRemote = Net.GetOrCreateRemoteEvent(Constants.Remotes.Toast)
local upgradeRemote = Net.GetOrCreateRemoteEvent(Constants.Remotes.ArenaUpgradeFighter)

local refreshCallback: RefreshCallback? = nil

local function getArenaPhase(): string
	local arenaState = ReplicatedStorage:FindFirstChild("ArenaState")
	if arenaState and arenaState:IsA("Folder") then
		return tostring(arenaState:GetAttribute("Phase") or "")
	end
	return ""
end

local function getLeaderstats(player: Player): Folder?
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats and leaderstats:IsA("Folder") then
		return leaderstats
	end
	return nil
end

local function getScrapValue(player: Player): IntValue?
	local leaderstats = getLeaderstats(player)
	if not leaderstats then
		return nil
	end

	local materials = leaderstats:FindFirstChild("Materials")
	if materials and materials:IsA("IntValue") then
		return materials
	end

	local scrap = leaderstats:FindFirstChild("Scrap")
	if scrap and scrap:IsA("IntValue") then
		return scrap
	end

	return nil
end

local function getBonusForLevel(level: number): number
	local bonusPerLevel = Constants.Arena.PowerUpgradeBaseBonus
	return math.max(0, level) * bonusPerLevel
end

function ArenaFighterUpgradeService.GetPlayerScrap(player: Player): number
	local scrapValue = getScrapValue(player)
	return if scrapValue then scrapValue.Value else 0
end

function ArenaFighterUpgradeService.AddPlayerScrap(player: Player, amount: number): boolean
	local scrapValue = getScrapValue(player)
	if not scrapValue then
		return false
	end

	scrapValue.Value += math.max(0, math.floor(amount))
	return true
end

function ArenaFighterUpgradeService.SpendPlayerScrap(player: Player, amount: number): boolean
	local scrapValue = getScrapValue(player)
	local cost = math.max(0, math.floor(amount))
	if not scrapValue or scrapValue.Value < cost then
		return false
	end

	scrapValue.Value -= cost
	return true
end

function ArenaFighterUpgradeService.GetSharedUpgradeLevel(fighterId: string, statName: string): number
	return ArenaFighterDefs.GetSharedUpgradeLevel(fighterId, statName)
end

function ArenaFighterUpgradeService.GetUpgradeCost(fighterId: string, statName: string): number
	if statName ~= Constants.Arena.UpgradeStatKey then
		return 0
	end

	local fighter = ArenaFighterDefs.GetRosterEntryById(fighterId)
	if not fighter then
		return 0
	end

	local nextLevel = ArenaFighterUpgradeService.GetSharedUpgradeLevel(fighterId, statName) + 1
	local costTable = Constants.Arena.PowerUpgradeCostByLevel
	local presetCost = costTable[nextLevel]
	if presetCost then
		return presetCost
	end

	local anchorLevel = #costTable
	local anchorCost = costTable[anchorLevel] or 25
	local extraLevels = math.max(0, nextLevel - anchorLevel)
	return math.floor(anchorCost * (Constants.Arena.PowerUpgradeCostGrowth ^ extraLevels) + 0.5)
end

function ArenaFighterUpgradeService.CanUpgradeFighter(fighterId: string, statName: string): boolean
	return statName == Constants.Arena.UpgradeStatKey and ArenaFighterDefs.GetRosterEntryById(fighterId) ~= nil
end

function ArenaFighterUpgradeService.SetRefreshCallback(callback: RefreshCallback)
	refreshCallback = callback
end

function ArenaFighterUpgradeService.ApplySharedUpgrade(player: Player, fighterId: string, statName: string): (boolean, string)
	if not ArenaFighterUpgradeService.CanUpgradeFighter(fighterId, statName) then
		return false, "Upgrade unavailable"
	end

	local phase = getArenaPhase()
	if phase == "FightActive" or phase == "Result" then
		return false, "Arena upgrades reopen next round"
	end

	local cost = ArenaFighterUpgradeService.GetUpgradeCost(fighterId, statName)
	if cost <= 0 then
		return false, "Upgrade unavailable"
	end

	if not ArenaFighterUpgradeService.SpendPlayerScrap(player, cost) then
		return false, ("Not enough %s"):format(Constants.Arena.UpgradeMaterialName)
	end

	local newLevel = ArenaFighterUpgradeService.GetSharedUpgradeLevel(fighterId, statName) + 1
	local rawBonus = getBonusForLevel(newLevel)
	local applied = ArenaFighterDefs.SetSharedUpgradeLevel(fighterId, statName, newLevel, rawBonus)
	if not applied then
		ArenaFighterUpgradeService.AddPlayerScrap(player, cost)
		return false, "Upgrade unavailable"
	end

	if refreshCallback then
		refreshCallback()
	end

	TutorialService.MarkFighterUpgrade(player)

	local fighter = ArenaFighterDefs.GetRosterEntryById(fighterId)
	local fighterName = fighter and fighter.Name or "Fighter"
	return true, ("%s Power Upgraded"):format(fighterName)
end

upgradeRemote.OnServerEvent:Connect(function(player: Player, fighterId: string, statName: string?)
	local requestedStat = if typeof(statName) == "string" and statName ~= "" then statName else Constants.Arena.UpgradeStatKey
	if typeof(fighterId) ~= "string" or fighterId == "" then
		toastRemote:FireClient(player, "Invalid fighter upgrade request")
		return
	end

	local success, message = ArenaFighterUpgradeService.ApplySharedUpgrade(player, fighterId, requestedStat)
	toastRemote:FireClient(player, message)
end)

return ArenaFighterUpgradeService
