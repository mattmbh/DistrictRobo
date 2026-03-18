local ArenaFighterDefs = {}

ArenaFighterDefs.Roster = {
	{
		Id = "scrapper_rust",
		Name = "Rust Scrapper",
		Health = 105,
		AttackDamage = 12,
		AttackCooldown = 1.2,
		Style = "Brawler",
		Aggression = 0.9,
		MoveSpeed = 11.5,
		Color = Color3.fromRGB(194, 118, 79),
		Wins = 0,
		Losses = 0,
	},
	{
		Id = "metro_guard",
		Name = "Metro Guard",
		Health = 120,
		AttackDamage = 10,
		AttackCooldown = 1.0,
		Style = "Balanced",
		Aggression = 0.75,
		MoveSpeed = 12,
		Color = Color3.fromRGB(99, 139, 189),
		Wins = 0,
		Losses = 0,
	},
	{
		Id = "glass_jaw_jax",
		Name = "Glass Jaw Jax",
		Health = 88,
		AttackDamage = 16,
		AttackCooldown = 1.35,
		Style = "Burst",
		Aggression = 1.0,
		MoveSpeed = 12.5,
		Color = Color3.fromRGB(197, 82, 103),
		Wins = 0,
		Losses = 0,
	},
	{
		Id = "iron_mika",
		Name = "Iron Mika",
		Health = 132,
		AttackDamage = 9,
		AttackCooldown = 0.9,
		Style = "Pressure",
		Aggression = 0.85,
		MoveSpeed = 11.8,
		Color = Color3.fromRGB(126, 170, 105),
		Wins = 0,
		Losses = 0,
	},
}

local lastIndex = 0

local function getRosterEntryById(id: string)
	for _, entry in ipairs(ArenaFighterDefs.Roster) do
		if entry.Id == id then
			return entry
		end
	end
	return nil
end

local function clampRating(value: number): number
	return math.clamp(math.floor(value + 0.5), 1, 10)
end

local function getScaleRating(value: number, minValue: number, maxValue: number): number
	if maxValue <= minValue then
		return 5
	end
	local alpha = math.clamp((value - minValue) / (maxValue - minValue), 0, 1)
	return clampRating(3 + alpha * 7)
end

local function getPowerRating(definition: {[string]: any}): number
	return getScaleRating(definition.AttackDamage + definition.Aggression * 2, 9, 19)
end

local function getSpeedRating(definition: {[string]: any}): number
	local attackTempo = (2.2 - definition.AttackCooldown) * 4
	return getScaleRating(definition.MoveSpeed + attackTempo, 11.5, 17.5)
end

local function getToughnessRating(definition: {[string]: any}): number
	return getScaleRating(definition.Health, 88, 132)
end

local STYLE_MATCHUPS = {
	Brawler = {
		Burst = {power = 1.08, speed = 0.98, toughness = 1.02},
		Pressure = {power = 0.97, speed = 0.97, toughness = 1.03},
	},
	Balanced = {
		Brawler = {power = 1.02, speed = 1.01, toughness = 1.01},
		Burst = {power = 0.99, speed = 1.03, toughness = 1.02},
		Pressure = {power = 1.01, speed = 1.01, toughness = 1.02},
	},
	Burst = {
		Pressure = {power = 1.07, speed = 1.06, toughness = 0.97},
		Balanced = {power = 1.02, speed = 1.03, toughness = 0.98},
	},
	Pressure = {
		Balanced = {power = 1.04, speed = 1.05, toughness = 1.02},
		Brawler = {power = 1.03, speed = 1.02, toughness = 0.99},
	},
}

local STYLE_DISTANCE_OFFSETS = {
	Brawler = -0.35,
	Balanced = 0,
	Burst = 0.45,
	Pressure = -0.2,
}

local function getStyleMatchup(style: string, opponentStyle: string): {[string]: number}
	local matchupByStyle = STYLE_MATCHUPS[style]
	local matchup = matchupByStyle and matchupByStyle[opponentStyle]
	if matchup then
		return matchup
	end
	return {
		power = 1,
		speed = 1,
		toughness = 1,
	}
end

function ArenaFighterDefs.GetPublicProfile(definition: {[string]: any})
	local entry = getRosterEntryById(definition.Id)
	local wins = if entry then entry.Wins else 0
	local losses = if entry then entry.Losses else 0

	return {
		Id = definition.Id,
		Name = definition.Name,
		Style = definition.Style,
		Power = getPowerRating(definition),
		Speed = getSpeedRating(definition),
		Toughness = getToughnessRating(definition),
		Wins = wins,
		Losses = losses,
		Record = ("%d-%d"):format(wins, losses),
	}
end

function ArenaFighterDefs.GetCombatProfile(definition: {[string]: any}, opponentDefinition: {[string]: any}, roundId: number)
	local seed = roundId * 7919
	for _, source in ipairs({definition.Id, opponentDefinition.Id}) do
		for index = 1, #source do
			seed += string.byte(source, index) * (index + 13)
		end
	end

	local random = Random.new(seed)
	local matchup = getStyleMatchup(definition.Style, opponentDefinition.Style)
	local volatility = 0.08 + random:NextNumber(0, 0.08)
	local hotStreak = 1 + random:NextNumber(-volatility, volatility)
	local composure = 1 + random:NextNumber(-0.06, 0.06)
	local durability = 1 + random:NextNumber(-0.08, 0.08)

	return {
		MaxHealth = definition.Health * matchup.toughness * durability,
		AttackDamage = definition.AttackDamage * matchup.power * hotStreak,
		AttackCooldown = definition.AttackCooldown / math.max(0.8, matchup.speed * composure),
		MoveSpeed = definition.MoveSpeed * math.max(0.9, matchup.speed * (1 + random:NextNumber(-0.04, 0.04))),
		AttackWindup = 0.26 / math.max(0.85, matchup.speed * (1 + random:NextNumber(-0.03, 0.05))),
		PreferredCombatDistanceOffset = STYLE_DISTANCE_OFFSETS[definition.Style] or 0,
		MinimumCombatDistanceOffset = (STYLE_DISTANCE_OFFSETS[definition.Style] or 0) * 0.5,
		OpeningDelay = 0.22 + random:NextNumber(0.04, 0.32) - definition.Aggression * 0.12,
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
