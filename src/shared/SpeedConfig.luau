--!strict

local SpeedConfig = {
	Debug = false,

	BaseWalkSpeed = 10,     -- velocidad en nivel 1
	AnchorLevel     = 50,
	AnchorWalkSpeed = 70,   -- velocidad en nivel AnchorLevel

	-- Tramo superior (nivel > AnchorLevel): curva sqrt sin tope.
	-- WalkSpeed = AnchorWalkSpeed + SqrtK * sqrt(level - AnchorLevel)
	-- K=4 → nvl 60≈83, 100≈98, 200≈119, 400≈145, 1000≈193, ∞→∞
	-- Ganancia cada 10 niveles: ~+12 en 50-60, ~+2.5 en 90-100, ~+1 en 490-500
	SqrtK = 4,

	BaseRequiredSpeed = 5,
	RequiredSpeedExponent = 1.45,

	StudsPerSpeed = 5,
	MovementCheckInterval = 0.1,
	TeleportDistanceBuffer = 25,
	TeleportSpeedMultiplier = 4,
}

function SpeedConfig.getRequiredSpeedForLevel(level: number): number
	return math.max(1, math.floor(SpeedConfig.BaseRequiredSpeed * (level ^ SpeedConfig.RequiredSpeedExponent)))
end

function SpeedConfig.getWalkSpeedForLevel(level: number): number
	level = math.max(1, level)

	if level <= SpeedConfig.AnchorLevel then
		local t = (level - 1) / (SpeedConfig.AnchorLevel - 1)
		return SpeedConfig.BaseWalkSpeed + t * (SpeedConfig.AnchorWalkSpeed - SpeedConfig.BaseWalkSpeed)
	end

	return SpeedConfig.AnchorWalkSpeed + SpeedConfig.SqrtK * math.sqrt(level - SpeedConfig.AnchorLevel)
end

return SpeedConfig
