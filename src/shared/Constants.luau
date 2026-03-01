local Constants = {}

Constants.Districts = {
	SAFE = "SAFE",
	DANGEROUS = "DANGEROUS",
}

Constants.Remotes = {
	DistrictChanged = "DistrictChanged",
	HeatUpdated = "HeatUpdated",
	EMPFired = "EMPFired",
	Toast = "Toast",
	FXEvent = "FXEvent",
}

Constants.Bindables = {
	AddHeat = "AddHeat",
	GetHeat = "GetHeat",
	AddMaterials = "AddMaterials",
}

Constants.GameSettings = {
	StartingCoins = 0,
	StartingMaterials = 0,
	SellPricePerMaterial = 12,
}

Constants.Heat = {
	HEAT_EMP_BASE = 4,
	HEAT_EMP_CHARGE_MULT = 18,
	HEAT_DRONE_DISABLED = 6,
	HEAT_CLUSTER_PER_SECOND = 1.2,
	SAFE_DECAY_PER_SEC = 3.5,
	DANGER_DECAY_PER_SEC = 0.6,
	MaxPlayerHeat = 150,
	MaxDistrictHeat = 600,
	BroadcastRate = 0.5,
}

Constants.Threat = {
	MaxLevel = 6,
	StepHeat = 25,
}

Constants.EMP = {
	CHARGE_TIME = 1.25,
	EMP_COOLDOWN = 0.45,
	EMP_RANGE = 220,
	EMP_PROJECTILE_SPEED_MIN = 260,
	EMP_PROJECTILE_SPEED_MAX = 360,
	EMP_HIT_RADIUS_MIN = 1.4,
	EMP_HIT_RADIUS_MAX = 3.0,
	DISABLE_DURATION_MIN = 1.5,
	DISABLE_DURATION_MAX = 6.0,
	IMPACT_RADIUS_MIN = 0.0,
	IMPACT_RADIUS_MAX = 10.0,
	OriginMaxDistanceFromPlayer = 14,
	ProjectileLifetime = 2.5,
}

Constants.Drones = {
	BaseCount = 2,
	MAX_DRONES_PER_THREAT = 2,
	SPAWN_INTERVAL_MAX = 2.0,
	SPAWN_INTERVAL_MIN = 0.9,
	SPAWN_INTERVAL_THREAT_STEP = 0.2,
	DespawnAfter = 20,
	BaseSpeed = 10,
	SpeedMultiplierPerThreat = 0.12,
}

Constants.ZoneCheck = {
	Interval = 0.25,
	ClusterRadius = 35,
	ClusterMinNearbyPlayers = 2,
}

Constants.Accessibility = {
	ENABLE_SCREEN_PULSE = true,
}

Constants.Audio = {
	MAX_PLAYS_PER_SECOND = 6,
	Cooldowns = {
		THREAT_UP = 2.0,
		EMP_BIG = 0.6,
		DRONE_ZAP = 0.15,
		DROP_CLINK = 0.20,
		PICKUP = 0.12,
	},
	Priority = {
		THREAT_UP = "high",
		EMP_BIG = "high",
		DRONE_ZAP = "low",
		DROP_CLINK = "low",
		PICKUP = "low",
	},
}

return Constants
