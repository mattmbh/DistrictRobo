local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Shared = ReplicatedStorage:WaitForChild("Shared")
local ArenaPredictionMath = require(Shared:WaitForChild("ArenaPredictionMath"))

local ArenaFighterDefs = {}

type FighterDefinition = {
	Id: string,
	Name: string,
	Style: string,
	Color: Color3,
	Tier: string,
	BasePower: number,
	BaseToughness: number,
	BaseSpeed: number,
	BaseAggression: number,
	UpgradePowerBonus: number,
	UpgradeToughnessBonus: number,
	UpgradeSpeedBonus: number,
	UpgradeAggressionBonus: number,
	SharedUpgradeLevelPower: number,
	SharedUpgradeLevelToughness: number,
	SharedUpgradeLevelSpeed: number,
	SharedUpgradeLevelAggression: number,
	UpgradeHooks: {[string]: any},
	UpgradeCosts: {[string]: {[string]: number}},
	Wins: number,
	Losses: number,
}

type EffectiveStats = {
	DisplayPower: number,
	DisplayToughness: number,
	DisplaySpeed: number,
	DisplayAggression: number,
	EffectivePower: number,
	EffectiveToughness: number,
	EffectiveSpeed: number,
	EffectiveAggression: number,
}

ArenaFighterDefs.Roster = {
	{
		Id = "scrapper_rust",
		Name = "Rust Scrapper",
		Style = "Brawler",
		Color = Color3.fromRGB(194, 118, 79),
		Tier = "Street",
		BasePower = 7,
		BaseToughness = 5,
		BaseSpeed = 5,
		BaseAggression = 8,
		UpgradePowerBonus = 0,
		UpgradeToughnessBonus = 0,
		UpgradeSpeedBonus = 0,
		UpgradeAggressionBonus = 0,
		SharedUpgradeLevelPower = 0,
		SharedUpgradeLevelToughness = 0,
		SharedUpgradeLevelSpeed = 0,
		SharedUpgradeLevelAggression = 0,
		UpgradeHooks = {
			PrimaryMaterial = "Scrap",
			Focus = "Power",
		},
		UpgradeCosts = {
			Power = {Materials = 3},
		},
		Wins = 0,
		Losses = 0,
	},
	{
		Id = "metro_guard",
		Name = "Metro Guard",
		Style = "Balanced",
		Color = Color3.fromRGB(99, 139, 189),
		Tier = "Civic",
		BasePower = 5,
		BaseToughness = 7,
		BaseSpeed = 6,
		BaseAggression = 5,
		UpgradePowerBonus = 0,
		UpgradeToughnessBonus = 0,
		UpgradeSpeedBonus = 0,
		UpgradeAggressionBonus = 0,
		SharedUpgradeLevelPower = 0,
		SharedUpgradeLevelToughness = 0,
		SharedUpgradeLevelSpeed = 0,
		SharedUpgradeLevelAggression = 0,
		UpgradeHooks = {
			PrimaryMaterial = "Alloy",
			Focus = "Toughness",
		},
		UpgradeCosts = {
			Toughness = {Materials = 3},
		},
		Wins = 0,
		Losses = 0,
	},
	{
		Id = "glass_jaw_jax",
		Name = "Glass Jaw Jax",
		Style = "Burst",
		Color = Color3.fromRGB(197, 82, 103),
		Tier = "Wildcard",
		BasePower = 8,
		BaseToughness = 3,
		BaseSpeed = 7,
		BaseAggression = 9,
		UpgradePowerBonus = 0,
		UpgradeToughnessBonus = 0,
		UpgradeSpeedBonus = 0,
		UpgradeAggressionBonus = 0,
		SharedUpgradeLevelPower = 0,
		SharedUpgradeLevelToughness = 0,
		SharedUpgradeLevelSpeed = 0,
		SharedUpgradeLevelAggression = 0,
		UpgradeHooks = {
			PrimaryMaterial = "Capacitor",
			Focus = "Aggression",
		},
		UpgradeCosts = {
			Aggression = {Materials = 3},
		},
		Wins = 0,
		Losses = 0,
	},
	{
		Id = "iron_mika",
		Name = "Iron Mika",
		Style = "Pressure",
		Color = Color3.fromRGB(126, 170, 105),
		Tier = "Factory",
		BasePower = 4,
		BaseToughness = 8,
		BaseSpeed = 6,
		BaseAggression = 7,
		UpgradePowerBonus = 0,
		UpgradeToughnessBonus = 0,
		UpgradeSpeedBonus = 0,
		UpgradeAggressionBonus = 0,
		SharedUpgradeLevelPower = 0,
		SharedUpgradeLevelToughness = 0,
		SharedUpgradeLevelSpeed = 0,
		SharedUpgradeLevelAggression = 0,
		UpgradeHooks = {
			PrimaryMaterial = "Plate",
			Focus = "Speed",
		},
		UpgradeCosts = {
			Speed = {Materials = 3},
		},
		Wins = 0,
		Losses = 0,
	},
} :: {FighterDefinition}

local lastIndex = 0

local STYLE_MATCHUPS = {
	Brawler = {
		Burst = {Power = 1.06, Toughness = 1.02, Speed = 0.98, Aggression = 1.04},
		Pressure = {Power = 0.97, Toughness = 1.03, Speed = 0.97, Aggression = 0.98},
	},
	Balanced = {
		Brawler = {Power = 1.01, Toughness = 1.01, Speed = 1.02, Aggression = 1.0},
		Burst = {Power = 0.99, Toughness = 1.02, Speed = 1.03, Aggression = 0.99},
		Pressure = {Power = 1.02, Toughness = 1.02, Speed = 1.01, Aggression = 1.0},
	},
	Burst = {
		Balanced = {Power = 1.03, Toughness = 0.97, Speed = 1.05, Aggression = 1.03},
		Pressure = {Power = 1.07, Toughness = 0.96, Speed = 1.05, Aggression = 1.04},
	},
	Pressure = {
		Brawler = {Power = 1.03, Toughness = 0.99, Speed = 1.02, Aggression = 1.02},
		Balanced = {Power = 1.04, Toughness = 1.02, Speed = 1.04, Aggression = 1.01},
	},
}

local STYLE_DISTANCE_OFFSETS = {
	Brawler = -0.35,
	Balanced = 0,
	Burst = 0.45,
	Pressure = -0.2,
}

local function getRosterEntryById(id: string): FighterDefinition?
	for _, entry in ipairs(ArenaFighterDefs.Roster) do
		if entry.Id == id then
			return entry
		end
	end
	return nil
end

local function clampRating(value: number): number
	return math.clamp(math.floor(value + 0.5), 0, 10)
end

local function getEffectiveStats(definition: {[string]: any}): EffectiveStats
	local powerBonus = tonumber(definition.UpgradePowerBonus) or 0
	local toughnessBonus = tonumber(definition.UpgradeToughnessBonus) or 0
	local speedBonus = tonumber(definition.UpgradeSpeedBonus) or 0
	local aggressionBonus = tonumber(definition.UpgradeAggressionBonus) or 0

	return {
		DisplayPower = ArenaPredictionMath.GetDisplayStat(definition.BasePower, powerBonus),
		DisplayToughness = ArenaPredictionMath.GetDisplayStat(definition.BaseToughness, toughnessBonus),
		DisplaySpeed = ArenaPredictionMath.GetDisplayStat(definition.BaseSpeed, speedBonus),
		DisplayAggression = ArenaPredictionMath.GetDisplayStat(definition.BaseAggression, aggressionBonus),
		EffectivePower = ArenaPredictionMath.GetEffectiveStat(definition.BasePower, powerBonus),
		EffectiveToughness = ArenaPredictionMath.GetEffectiveStat(definition.BaseToughness, toughnessBonus),
		EffectiveSpeed = ArenaPredictionMath.GetEffectiveStat(definition.BaseSpeed, speedBonus),
		EffectiveAggression = ArenaPredictionMath.GetEffectiveStat(definition.BaseAggression, aggressionBonus),
	}
end

local function getStyleMatchup(style: string, opponentStyle: string): {[string]: number}
	local matchupByStyle = STYLE_MATCHUPS[style]
	local matchup = matchupByStyle and matchupByStyle[opponentStyle]
	if matchup then
		return matchup
	end

	return {
		Power = 1,
		Toughness = 1,
		Speed = 1,
		Aggression = 1,
	}
end

local function hashString(source: string): number
	local hash = 0
	for index = 1, #source do
		hash += string.byte(source, index) * (index + 17)
	end
	return hash
end

local function buildPairSeed(definitionA: {[string]: any}, definitionB: {[string]: any}, roundId: number): number
	local ids = {definitionA.Id, definitionB.Id}
	table.sort(ids)
	return roundId * 7919 + hashString(ids[1]) * 13 + hashString(ids[2]) * 17
end

local function buildCombatProfile(
	definition: {[string]: any},
	opponentDefinition: {[string]: any},
	stats: EffectiveStats,
	matchup: {[string]: number},
	winChance: number,
	performanceScalar: number,
	seed: number
)
	local random = Random.new(seed)
	local power = stats.EffectivePower * matchup.Power * performanceScalar * (1 + random:NextNumber(-0.035, 0.055))
	local toughness = stats.EffectiveToughness * matchup.Toughness * performanceScalar * (1 + random:NextNumber(-0.03, 0.05))
	local speed = stats.EffectiveSpeed * matchup.Speed * performanceScalar * (1 + random:NextNumber(-0.03, 0.05))
	local aggression = stats.EffectiveAggression * matchup.Aggression * performanceScalar * (1 + random:NextNumber(-0.025, 0.04))

	return {
		MaxHealth = 76 + toughness * 7.2 + aggression * 1.4,
		AttackDamage = 5.4 + power * 1.18 + aggression * 0.34,
		AttackCooldown = math.max(0.72, 1.5 - speed * 0.065 - aggression * 0.018),
		MoveSpeed = 9.8 + speed * 0.28 + aggression * 0.08,
		AttackWindup = math.max(0.18, 0.34 - speed * 0.012 - aggression * 0.004),
		PreferredCombatDistanceOffset = (STYLE_DISTANCE_OFFSETS[definition.Style] or 0) + (winChance - 0.5) * 0.2,
		MinimumCombatDistanceOffset = (STYLE_DISTANCE_OFFSETS[definition.Style] or 0) * 0.5,
		OpeningDelay = math.max(0.08, 0.28 - aggression * 0.018 - speed * 0.01 + random:NextNumber(-0.02, 0.07)),
	}
end

function ArenaFighterDefs.GetPublicProfile(definition: {[string]: any})
	local entry = getRosterEntryById(definition.Id)
	local wins = if entry then entry.Wins else 0
	local losses = if entry then entry.Losses else 0
	local stats = getEffectiveStats(definition)

	return {
		Id = definition.Id,
		Name = definition.Name,
		Style = definition.Style,
		Power = clampRating(stats.DisplayPower),
		Speed = clampRating(stats.DisplaySpeed),
		Toughness = clampRating(stats.DisplayToughness),
		Aggression = clampRating(stats.DisplayAggression),
		Wins = wins,
		Losses = losses,
		Record = ("%d-%d"):format(wins, losses),
	}
end

function ArenaFighterDefs.BuildMatchup(definitionA: {[string]: any}, definitionB: {[string]: any}, roundId: number)
	local statsA = getEffectiveStats(definitionA)
	local statsB = getEffectiveStats(definitionB)
	local matchupA = getStyleMatchup(definitionA.Style, definitionB.Style)
	local matchupB = getStyleMatchup(definitionB.Style, definitionA.Style)

	local pairSeed = buildPairSeed(definitionA, definitionB, roundId)
	local random = Random.new(pairSeed)

	local scoreA = ArenaPredictionMath.GetWeightedScore({
		Power = statsA.EffectivePower * matchupA.Power,
		Toughness = statsA.EffectiveToughness * matchupA.Toughness,
		Speed = statsA.EffectiveSpeed * matchupA.Speed,
		Aggression = statsA.EffectiveAggression * matchupA.Aggression,
	}) + ArenaPredictionMath.GetVariance(random)

	local scoreB = ArenaPredictionMath.GetWeightedScore({
		Power = statsB.EffectivePower * matchupB.Power,
		Toughness = statsB.EffectiveToughness * matchupB.Toughness,
		Speed = statsB.EffectiveSpeed * matchupB.Speed,
		Aggression = statsB.EffectiveAggression * matchupB.Aggression,
	}) + ArenaPredictionMath.GetVariance(random)

	local winChanceA, winChanceB = ArenaPredictionMath.CompressWinChance(scoreA, scoreB)
	local performanceA = ArenaPredictionMath.GetPerformanceScalar(winChanceA, random)
	local performanceB = ArenaPredictionMath.GetPerformanceScalar(winChanceB, random)

	return {
		FighterA = {
			PublicProfile = ArenaFighterDefs.GetPublicProfile(definitionA),
			EffectiveStats = statsA,
			WeightedScore = scoreA,
			WinChance = winChanceA,
			CombatProfile = buildCombatProfile(
				definitionA,
				definitionB,
				statsA,
				matchupA,
				winChanceA,
				performanceA,
				pairSeed + 101
			),
		},
		FighterB = {
			PublicProfile = ArenaFighterDefs.GetPublicProfile(definitionB),
			EffectiveStats = statsB,
			WeightedScore = scoreB,
			WinChance = winChanceB,
			CombatProfile = buildCombatProfile(
				definitionB,
				definitionA,
				statsB,
				matchupB,
				winChanceB,
				performanceB,
				pairSeed + 211
			),
		},
	}
end

function ArenaFighterDefs.RecordResult(winnerId: string, loserId: string)
	local winner = getRosterEntryById(winnerId)
	local loser = getRosterEntryById(loserId)
	if winner then
		winner.Wins += 1
	end
	if loser then
		loser.Losses += 1
	end
end

function ArenaFighterDefs.ApplyUpgrade(fighterId: string, statKey: string, rawBonusAmount: number): boolean
	local fighter = getRosterEntryById(fighterId)
	if not fighter then
		return false
	end

	local amount = math.max(0, rawBonusAmount)
	if statKey == "Power" then
		fighter.UpgradePowerBonus += amount
	elseif statKey == "Toughness" then
		fighter.UpgradeToughnessBonus += amount
	elseif statKey == "Speed" then
		fighter.UpgradeSpeedBonus += amount
	elseif statKey == "Aggression" then
		fighter.UpgradeAggressionBonus += amount
	else
		return false
	end

	return true
end

function ArenaFighterDefs.GetRosterEntryById(id: string): FighterDefinition?
	return getRosterEntryById(id)
end

function ArenaFighterDefs.GetSharedUpgradeLevel(fighterId: string, statKey: string): number
	local fighter = getRosterEntryById(fighterId)
	if not fighter then
		return 0
	end

	local key = statKey == "Power" and "SharedUpgradeLevelPower"
		or statKey == "Toughness" and "SharedUpgradeLevelToughness"
		or statKey == "Speed" and "SharedUpgradeLevelSpeed"
		or statKey == "Aggression" and "SharedUpgradeLevelAggression"
	if not key then
		return 0
	end

	return math.max(0, math.floor(tonumber((fighter :: any)[key]) or 0))
end

function ArenaFighterDefs.SetSharedUpgradeLevel(fighterId: string, statKey: string, level: number, rawBonusAmount: number): boolean
	local fighter = getRosterEntryById(fighterId)
	if not fighter then
		return false
	end

	local clampedLevel = math.max(0, math.floor(level))
	local amount = math.max(0, rawBonusAmount)
	if statKey == "Power" then
		fighter.SharedUpgradeLevelPower = clampedLevel
		fighter.UpgradePowerBonus = amount
	elseif statKey == "Toughness" then
		fighter.SharedUpgradeLevelToughness = clampedLevel
		fighter.UpgradeToughnessBonus = amount
	elseif statKey == "Speed" then
		fighter.SharedUpgradeLevelSpeed = clampedLevel
		fighter.UpgradeSpeedBonus = amount
	elseif statKey == "Aggression" then
		fighter.SharedUpgradeLevelAggression = clampedLevel
		fighter.UpgradeAggressionBonus = amount
	else
		return false
	end

	return true
end

function ArenaFighterDefs.GetDuelPair(roundId: number)
	local roster = ArenaFighterDefs.Roster
	local count = #roster
	assert(count >= 2, "[ArenaFight] ArenaFighterDefs requires at least 2 fighters")

	lastIndex = (lastIndex % count) + 1
	local first = roster[lastIndex]

	local secondIndex = ((lastIndex + math.max(1, roundId)) % count) + 1
	if secondIndex == lastIndex then
		secondIndex = (secondIndex % count) + 1
	end

	local second = roster[secondIndex]
	return table.clone(first), table.clone(second)
end

return ArenaFighterDefs
