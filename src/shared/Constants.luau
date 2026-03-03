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
	DroneSnapshot = "DroneSnapshot",
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
	HEAT_EMP_BASE = 1.2,
	HEAT_EMP_CHARGE_MULT = 4.5,
	HEAT_DRONE_DISABLED = 1.5,
	HEAT_CLUSTER_PER_SECOND = 0.3,
	SAFE_DECAY_PER_SEC = 3.5,
	DANGER_DECAY_PER_SEC = 0.6,
	MaxPlayerHeat = 150,
	MaxDistrictHeat = 600,
	BroadcastRate = 0.5,
}

Constants.Threat = {
	MaxLevel = 4,
	HeatThresholds = {70, 120, 135, 145},
}

Constants.EMP = {
	CHARGE_TIME = 1.25,
	EMP_COOLDOWN = 0.45,
	EMP_RANGE = 220,
	MaxRange = 220,
	HitRadius = 3.2,
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
	MaxAlive = 6,
	SpawnIntervalMin = 0.35,
	SpawnIntervalMax = 0.75,
	SpawnPerTickMin = 1,
	SpawnPerTickMax = 2,
	CountByThreatLevel = {
		[0] = 2,
		[1] = 3,
		[2] = 5,
		[3] = 5,
		[4] = 6,
	},
	DespawnAfter = 20,
	BaseSpeed = 10,
	SpeedMultiplierPerThreat = 0.12,
	AttackEnabled = true,
	AttackRange = 140,
	FireCooldown = 1.2,
	AimLead = 0.15,
	DamagePerShot = 8,
	DamagePerSecondCapPerPlayer = 20,
	DetectRange = 170,
	DetectFOVDeg = 85,
	LoseRange = 200,
	LoseLOSAfter = 2.5,
	SearchTime = 3.0,
	PreferredRange = 65,
	MinRange = 28,
	HoverHeight = 18,
	HoverJitter = 2.5,
	OrbitSpeed = 1.2,
	AimConeDegMin = 1.5,
	AimConeDegMax = 9.0,
	MovingConeBonusDeg = 5.0,
	PlatformCenter = Vector3.new(0, 0, 0),
	PlatformHalfSizeXZ = Vector2.new(560, 560),
	SpawnMargin = 22,
	DroneHP = 100,
	EMPDamagePerHit = 55,
	EMPDamageSplashScale = 0.75,
	SpawnReplacementDelayMin = 0.25,
	SpawnReplacementDelayMax = 0.6,
	DebrisLifetime = 4.0,
	StunWobblePos = 0.6,
	StunWobbleRotDeg = 8,
	StunWobbleHz = 8,
	HitboxSize = Vector3.new(6, 6, 6),
}

Constants.ZoneCheck = {
	Interval = 0.25,
	ClusterRadius = 35,
	ClusterMinNearbyPlayers = 2,
}

Constants.Accessibility = {
	ENABLE_SCREEN_PULSE = true,
}

Constants.CityLayout = {
	UseBaseplateBounds = true,
	WorldCenter = Vector3.new(0, 0, 0),
	WorldHalfSizeXZ = Vector2.new(560, 560),
	BoundsMargin = 8,
	RoadWidthMain = 48,
	RoadWidthSide = 32,
	BlockSize = 140,
	BlocksPerMainRoad = 3,
	RoadThickness = 1,
	BuildPadHeight = 1,
	LaneMarkingsEnabled = true,
	LaneMarkWidth = 0.45,
	LaneMarkLength = 12,
	LaneMarkGap = 10,
	LaneMarkHeight = 0.06,
	SidewalkEnabled = true,
	SidewalkWidth = 4,
	SidewalkHeight = 0.3,
	RoadColor = Color3.fromRGB(33, 35, 39),
	BuildPadColor = Color3.fromRGB(45, 47, 52),
	LaneMarkColor = Color3.fromRGB(214, 214, 214),
	SidewalkColor = Color3.fromRGB(90, 92, 98),
}

Constants.Audio = {
	MAX_PLAYS_PER_SECOND = 6,
	Cooldowns = {
		THREAT_UP = 2.0,
		EMP_BIG = 0.6,
		DRONE_ZAP = 0.15,
		DROP_CLINK = 0.20,
		PLASTIC_CLACK = 0.10,
		TOY_RATTLE = 0.10,
		METAL_TINK = 0.10,
		PICKUP = 0.12,
	},
	Priority = {
		THREAT_UP = "high",
		EMP_BIG = "high",
		DRONE_ZAP = "low",
		DROP_CLINK = "low",
		PLASTIC_CLACK = "low",
		TOY_RATTLE = "low",
		METAL_TINK = "low",
		PICKUP = "low",
	},
}

Constants.DroneDeathFx = {
	BurstParticles = 16,
	SoundVolume = 0.18,
	PlaybackMin = 0.92,
	PlaybackMax = 1.26,
}

return Constants
