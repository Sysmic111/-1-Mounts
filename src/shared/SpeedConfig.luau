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

	-- Coste por nivel: geométrico, NO polinómico.
	-- Dentro de un mismo ciclo de rebirth el ingreso crece x3.600.000
	-- (mount 1→90 × steps 1→2000 × hat 1→5 × trail 1→4). Una curva polinómica
	-- crecía solo x10 entre el nivel 50 y el 130 y los multiplicadores la
	-- reventaban: el nivel 130 caía en segundos.
	-- Growth es la palanca de duración del juego: 1.215 → ~6.7h hasta nivel 130,
	-- 1.225 → ~8.9h, 1.235 → ~11.8h.
	BaseRequiredSpeed = 8,
	RequiredSpeedGrowth = 1.225,

	StudsPerSpeed = 5,
	MovementCheckInterval = 0.1,
	TeleportDistanceBuffer = 25,
	TeleportSpeedMultiplier = 4,
}

-- Speed necesario para pasar de `level` a `level + 1`.
-- req(1)=8, req(40)=21.864, req(130)=1.87e12
function SpeedConfig.getRequiredSpeedForLevel(level: number): number
	return math.max(1, math.floor(SpeedConfig.BaseRequiredSpeed * (SpeedConfig.RequiredSpeedGrowth ^ (level - 1))))
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
