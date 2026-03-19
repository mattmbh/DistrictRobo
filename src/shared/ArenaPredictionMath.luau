local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local Constants = require(Shared:WaitForChild("Constants"))

local ArenaPredictionMath = {}

type StatSet = {
	Power: number,
	Toughness: number,
	Speed: number,
	Aggression: number,
}

local function clampStat(value: number): number
	return math.clamp(value, 0, 10)
end

function ArenaPredictionMath.ApplyDiminishingReturns(upgradeBonus: number): number
	if upgradeBonus <= 0 then
		return 0
	end

	local scale = Constants.Arena.UpgradeDiminishingScale
	local rate = Constants.Arena.UpgradeDiminishingRate
	return scale * (1 - math.exp(-upgradeBonus * rate))
end

function ArenaPredictionMath.GetDisplayStat(baseValue: number, upgradeBonus: number): number
	return clampStat(baseValue + math.max(0, upgradeBonus))
end

function ArenaPredictionMath.GetEffectiveStat(baseValue: number, upgradeBonus: number): number
	return clampStat(baseValue + ArenaPredictionMath.ApplyDiminishingReturns(math.max(0, upgradeBonus)))
end

function ArenaPredictionMath.GetWeightedScore(stats: StatSet): number
	local weights = Constants.Arena.PredictionWeights
	return stats.Power * weights.Power
		+ stats.Toughness * weights.Toughness
		+ stats.Speed * weights.Speed
		+ stats.Aggression * weights.Aggression
end

function ArenaPredictionMath.GetVariance(randomSource: Random): number
	return randomSource:NextNumber(-Constants.Arena.PredictionVariance, Constants.Arena.PredictionVariance)
end

function ArenaPredictionMath.CompressWinChance(scoreA: number, scoreB: number): (number, number)
	local safeA = math.max(0.1, scoreA)
	local safeB = math.max(0.1, scoreB)
	local rawShareA = safeA / (safeA + safeB)
	local centered = (rawShareA - 0.5) / 0.5
	local compression = Constants.Arena.PredictionCompression
	local cap = Constants.Arena.PredictionFavoriteCap
	local compressed = 0.5 + math.tanh(centered * compression) * (cap - 0.5)
	local chanceA = math.clamp(compressed, 1 - cap, cap)
	return chanceA, 1 - chanceA
end

function ArenaPredictionMath.GetPerformanceScalar(winChance: number, randomSource: Random): number
	local favoriteLean = (winChance - 0.5) * 0.18
	local swing = randomSource:NextNumber(-Constants.Arena.RoundPerformanceSwing, Constants.Arena.RoundPerformanceSwing)
	return math.clamp(1 + favoriteLean + swing, 0.9, 1.1)
end

return ArenaPredictionMath
