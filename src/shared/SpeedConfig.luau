--!strict

local SpeedConfig = {
	Debug = true,

	BaseWalkSpeed = 10,
	MaxWalkSpeed = 80,
	WalkSpeedPerLevel = 1.25,

	BaseRequiredSpeed = 5,
	RequiredSpeedExponent = 1.45,

	StudsPerSpeed = 1,
	MovementCheckInterval = 0.1,
	TeleportDistanceBuffer = 25,
	TeleportSpeedMultiplier = 4,
}

function SpeedConfig.getRequiredSpeedForLevel(level: number): number
	return math.max(1, math.floor(SpeedConfig.BaseRequiredSpeed * (level ^ SpeedConfig.RequiredSpeedExponent)))
end

function SpeedConfig.getWalkSpeedForLevel(level: number): number
	return math.min(SpeedConfig.BaseWalkSpeed + ((level - 1) * SpeedConfig.WalkSpeedPerLevel), SpeedConfig.MaxWalkSpeed)
end

return SpeedConfig
