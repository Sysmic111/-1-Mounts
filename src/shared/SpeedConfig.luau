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
	-- Growth es la palanca de duración del juego. Calibrado para el modelo ADITIVO
	-- de multiplicadores (total = (1+Σ(mult-1)) × rebirth) con mounts persistentes:
	-- 1.19 → ~5.6h hasta nivel 130, 1.20 → ~8.65h, 1.205 → ~11.2h.
	-- (Con el viejo modelo multiplicativo el valor era 1.230; ya no aplica.)
	-- Subido 1.200 → 1.204 al reforzar hats/trails (aporte a la base ~6-8× mayor):
	-- ese buff acortaba el nivel 130 a ~7.2h (-16%, todo en mid-late game); 1.204
	-- restaura ~8.6h (R8 6.7h) sin tocar el arranque (R1 sigue ~19min).
	BaseRequiredSpeed = 8,
	RequiredSpeedGrowth = 1.204,

	StudsPerSpeed = 5,
	MovementCheckInterval = 0.1,
	TeleportDistanceBuffer = 25,
	TeleportSpeedMultiplier = 4,
}

-- Speed necesario para pasar de `level` a `level + 1`.
-- req(1)=8, req(40)≈9.8K, req(130)≈1.4e11
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
