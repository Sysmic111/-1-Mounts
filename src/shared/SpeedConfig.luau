--!strict

local SpeedConfig = {
	Debug = false,

	BaseWalkSpeed = 10,     -- velocidad en nivel 1
	MaxLevel      = 400,    -- nivel máximo (a partir de aquí la velocidad no sube)
	MaxWalkSpeed  = 140,    -- velocidad en el nivel máximo

	-- Anclaje: la curva es por tramos. De nivel 1 a AnchorLevel sube de
	-- BaseWalkSpeed a AnchorWalkSpeed (inicio del juego como antes). De AnchorLevel
	-- a MaxLevel sube +10 cada 50 niveles (0.2/nivel): 50→70, 100→80, 150→90, ...
	-- 400→140.
	AnchorLevel     = 50,
	AnchorWalkSpeed = 70,

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
	level = math.clamp(level, 1, SpeedConfig.MaxLevel)

	if level <= SpeedConfig.AnchorLevel then
		-- Tramo inicial: recta de BaseWalkSpeed (nivel 1) a AnchorWalkSpeed (AnchorLevel).
		local t = (level - 1) / (SpeedConfig.AnchorLevel - 1)
		return SpeedConfig.BaseWalkSpeed + t * (SpeedConfig.AnchorWalkSpeed - SpeedConfig.BaseWalkSpeed)
	end

	-- Tramo superior: +10 cada 50 niveles (0.2/nivel) hasta MaxWalkSpeed en MaxLevel.
	local lateSlope = (SpeedConfig.MaxWalkSpeed - SpeedConfig.AnchorWalkSpeed)
		/ (SpeedConfig.MaxLevel - SpeedConfig.AnchorLevel)
	return SpeedConfig.AnchorWalkSpeed + (level - SpeedConfig.AnchorLevel) * lateSlope
end

return SpeedConfig
