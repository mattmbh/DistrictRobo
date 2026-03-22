local Players = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))
local Net = require(Shared:WaitForChild("Net"))

local PlayerRewardUpgradeService = {}

local toastRemote = Net.GetOrCreateRemoteEvent(Constants.Remotes.Toast)
local rewardUpgradeRemote = Net.GetOrCreateRemoteEvent(Constants.Remotes.ArenaUpgradeRewardMultiplier)

local function getLeaderstats(player: Player): Folder?
	local leaderstats = player:FindFirstChild("leaderstats")
	if leaderstats and leaderstats:IsA("Folder") then
		return leaderstats
	end
	return nil
end

local function getCreditsValue(player: Player): IntValue?
	local leaderstats = getLeaderstats(player)
	if not leaderstats then
		return nil
	end

	local credits = leaderstats:FindFirstChild("Credits")
	if credits and credits:IsA("IntValue") then
		return credits
	end

	return nil
end

function PlayerRewardUpgradeService.GetRewardUpgradeLevel(player: Player): number
	return math.clamp(math.floor(tonumber(player:GetAttribute("RewardUpgradeLevel") or 0) or 0), 0, #Constants.Arena.RewardMultiplierByLevel)
end

function PlayerRewardUpgradeService.GetRewardMultiplier(player: Player): number
	local level = PlayerRewardUpgradeService.GetRewardUpgradeLevel(player)
	if level <= 0 then
		return 1.0
	end
	return Constants.Arena.RewardMultiplierByLevel[level] or 1.0
end

function PlayerRewardUpgradeService.GetUpgradeCost(level: number): number
	local nextLevel = math.clamp(level + 1, 1, #Constants.Arena.RewardUpgradeCostByLevel)
	return Constants.Arena.RewardUpgradeCostByLevel[nextLevel] or 0
end

local function syncPlayerAttributes(player: Player)
	local level = PlayerRewardUpgradeService.GetRewardUpgradeLevel(player)
	local multiplier = PlayerRewardUpgradeService.GetRewardMultiplier(player)
	local nextCost = if level >= #Constants.Arena.RewardMultiplierByLevel then 0 else PlayerRewardUpgradeService.GetUpgradeCost(level)
	player:SetAttribute("RewardUpgradeLevel", level)
	player:SetAttribute("RewardMultiplier", multiplier)
	player:SetAttribute("RewardUpgradeNextCost", nextCost)
end

function PlayerRewardUpgradeService.InitializePlayer(player: Player)
	if player:GetAttribute("RewardUpgradeLevel") == nil then
		player:SetAttribute("RewardUpgradeLevel", 0)
	end
	syncPlayerAttributes(player)
end

function PlayerRewardUpgradeService.UpgradeRewardMultiplier(player: Player): (boolean, string)
	local level = PlayerRewardUpgradeService.GetRewardUpgradeLevel(player)
	if level >= #Constants.Arena.RewardMultiplierByLevel then
		return false, "Earnings multiplier maxed"
	end

	local credits = getCreditsValue(player)
	if not credits then
		return false, "Credits unavailable"
	end

	local cost = PlayerRewardUpgradeService.GetUpgradeCost(level)
	if credits.Value < cost then
		return false, ("Need %d Credits"):format(cost)
	end

	credits.Value -= cost
	player:SetAttribute("RewardUpgradeLevel", level + 1)
	syncPlayerAttributes(player)
	return true, ("Earnings multiplier upgraded to x%.2f"):format(PlayerRewardUpgradeService.GetRewardMultiplier(player))
end

rewardUpgradeRemote.OnServerEvent:Connect(function(player: Player)
	local success, message = PlayerRewardUpgradeService.UpgradeRewardMultiplier(player)
	toastRemote:FireClient(player, message)
end)

Players.PlayerAdded:Connect(function(player)
	PlayerRewardUpgradeService.InitializePlayer(player)
end)

for _, player in ipairs(Players:GetPlayers()) do
	PlayerRewardUpgradeService.InitializePlayer(player)
end

return PlayerRewardUpgradeService
