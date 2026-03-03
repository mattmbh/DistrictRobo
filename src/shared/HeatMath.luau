local ReplicatedStorage = game:GetService("ReplicatedStorage")
local Constants = require(ReplicatedStorage:WaitForChild("Shared"):WaitForChild("Constants"))

local HeatMath = {}

local function clamp(value: number, minValue: number, maxValue: number): number
	return math.max(minValue, math.min(maxValue, value))
end

function HeatMath.GetEMPHeatGain(chargeAmount: number): number
	local normalizedCharge = clamp(chargeAmount, 0, 1)
	return Constants.Heat.HEAT_EMP_BASE + ((normalizedCharge ^ 1.6) * Constants.Heat.HEAT_EMP_CHARGE_MULT)
end

function HeatMath.ApplyDecay(currentHeat: number, deltaTime: number, inDangerZone: boolean): number
	local decayPerSec = inDangerZone and Constants.Heat.DANGER_DECAY_PER_SEC or Constants.Heat.SAFE_DECAY_PER_SEC
	local nextHeat = currentHeat - (decayPerSec * deltaTime)
	return clamp(nextHeat, 0, Constants.Heat.MaxPlayerHeat)
end

function HeatMath.GetThreatLevel(districtHeat: number): number
	local thresholds = Constants.Threat.HeatThresholds
	if typeof(thresholds) ~= "table" then
		return 0
	end

	local level = 0
	for thresholdLevel, minHeat in ipairs(thresholds) do
		if districtHeat >= minHeat then
			level = thresholdLevel
		else
			break
		end
	end

	return clamp(level, 0, Constants.Threat.MaxLevel)
end

function HeatMath.ComputeDistrictHeat(playerHeatMap: {[number]: number}): number
	local total = 0
	for _, heatValue in pairs(playerHeatMap) do
		total += heatValue
	end
	return clamp(total, 0, Constants.Heat.MaxDistrictHeat)
end

return HeatMath
