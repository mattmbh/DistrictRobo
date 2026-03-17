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
	},
}

local lastIndex = 0

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
