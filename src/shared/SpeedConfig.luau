--!strict

local WorldsConfig = require(game.ReplicatedStorage.Shared.WorldsConfig)

-- Curva de WalkSpeed de un mundo.
--
--   nivel <= AnchorLevel   -> lineal de BaseWalkSpeed a AnchorWalkSpeed
--   nivel  > AnchorLevel   -> AnchorWalkSpeed + SqrtK * sqrt(nivel - AnchorLevel)
--
-- El tramo de cola (opcional) es un SEGUNDO tramo sqrt que arranca en TailLevel y
-- se re-ancla al valor que la curva tenía justo ahí, así que la velocidad es
-- CONTINUA en la frontera: no hay salto al entrar al mundo. Su pendiente no se
-- escribe a mano — se deriva de "quiero llegar a TailTargetWalkSpeed en el nivel
-- TailTargetLevel", que es el número que de verdad se está diseñando. Si algún
-- día se alarga el mundo, se cambia el objetivo y la pendiente se recalcula sola.
export type WalkSpeedCurve = {
	AnchorLevel: number,
	AnchorWalkSpeed: number,
	SqrtK: number,
	TailLevel: number?,
	TailTargetLevel: number?,
	TailTargetWalkSpeed: number?,
	-- Derivados al cargar el módulo. No tocar a mano.
	TailWalkSpeed: number?,
	TailK: number?,
}

local SpeedConfig = {
	Debug = false,

	-- Velocidad en el nivel 1. Es común a todos los mundos: por debajo de la
	-- frontera las curvas coinciden y solo divergen en su tramo de cola.
	BaseWalkSpeed = 10,

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
	--
	-- OJO: esta curva es GLOBAL, no por mundo. El nivel cuesta lo mismo en los dos
	-- places (el perfil es compartido y `Level` es uno solo); lo único que cambia
	-- por mundo es lo rápido que se CORRE con ese nivel.
	BaseRequiredSpeed = 8,
	RequiredSpeedGrowth = 1.204,

	StudsPerSpeed = 5,
	MovementCheckInterval = 0.1,
	TeleportDistanceBuffer = 25,
	TeleportSpeedMultiplier = 4,
}

-- Una curva por mundo, resuelta por PLACE (igual que EconomyConfig.current()).
-- Vive en Shared y WorldsConfig resuelve por `game.PlaceId`, así que cliente y
-- servidor calculan lo mismo sin replicación ni orden de init: los scripts de
-- obstáculos de los stages se recalibran solos al mundo en el que corren.
SpeedConfig.WalkSpeedCurves = {
	-- World 1: la curva de siempre, intacta.
	-- K=4 → nvl 60≈83, 100≈98, 130≈105.8, 200≈119, ∞→∞
	-- Ganancia cada 10 niveles: ~+12 en 50-60, ~+2.5 en 90-100
	World1 = {
		AnchorLevel     = 50,
		AnchorWalkSpeed = 70,
		SqrtK           = 4,
	},

	-- World 2: idéntica a World 1 hasta el nivel 131 y más empinada a partir de
	-- ahí. La sqrt de World 1 ya está tan plana en esa zona que los 45 niveles del
	-- mundo entero solo daban +9.6 studs (105.8 → 115.6) y las trece carreras se
	-- sentían iguales; con la cola se convierten en +24 (106 → 130).
	--
	-- El corte es el 131 y no el 130 porque 131 es el primer nivel de World 2 y
	-- ahí la curva de World 1 vale 106.0 EXACTO (70 + 4·√81). La frontera queda
	-- limpia y sin salto.
	--
	-- Por debajo del 131 las dos curvas coinciden a propósito: `Level` se resetea
	-- a 1 en el rebirth y el gate de entrada al mundo es por STEPS, así que hay
	-- jugadores de nivel bajo dentro de World 2. Con esto un nivel 5 corre igual
	-- esté donde esté, y la única diferencia entre mundos es el tramo que World 1
	-- ni siquiera usa (su contenido acaba en el nivel 130).
	--
	-- Perfil resultante (nivel → ws):
	--   131 → 106.0    144 → 119.0    161 → 125.8
	--   133 → 111.1    147 → 120.5    165 → 127.1
	--   137 → 114.9    151 → 122.2    168 → 128.0
	--   140 → 116.9    154 → 123.4    172 → 129.2
	--                  158 → 124.8    175 → 130.0
	World2 = {
		AnchorLevel         = 50,
		AnchorWalkSpeed     = 70,
		SqrtK               = 4,
		TailLevel           = 131,
		TailTargetLevel     = 175, -- final del recorrido de World 2
		TailTargetWalkSpeed = 130,
	},
} :: { [string]: WalkSpeedCurve }

-- Velocidad del tramo principal (sin cola). Es el valor al que se re-ancla la
-- cola, y por eso se calcula aparte: la cola necesita saber dónde empieza.
local function baseWalkSpeed(curve: WalkSpeedCurve, level: number): number
	if level <= curve.AnchorLevel then
		local t = (level - 1) / (curve.AnchorLevel - 1)
		return SpeedConfig.BaseWalkSpeed + t * (curve.AnchorWalkSpeed - SpeedConfig.BaseWalkSpeed)
	end
	return curve.AnchorWalkSpeed + curve.SqrtK * math.sqrt(level - curve.AnchorLevel)
end

-- Deriva la pendiente de cada cola una sola vez, al cargar el módulo.
for worldKey, curve in SpeedConfig.WalkSpeedCurves do
	local tailLevel = curve.TailLevel
	if not tailLevel then continue end

	local targetLevel = curve.TailTargetLevel
	local targetSpeed = curve.TailTargetWalkSpeed
	if not targetLevel or not targetSpeed then
		error(`[Speed] La curva de "{worldKey}" declara TailLevel sin TailTargetLevel/TailTargetWalkSpeed`)
	end
	if targetLevel <= tailLevel then
		error(`[Speed] La curva de "{worldKey}" tiene TailTargetLevel {targetLevel} <= TailLevel {tailLevel}`)
	end

	local tailSpeed = baseWalkSpeed(curve, tailLevel)
	if targetSpeed < tailSpeed then
		error(
			`[Speed] La curva de "{worldKey}" bajaría de velocidad: en el nivel {tailLevel} vale {tailSpeed} `
				.. `y el objetivo del nivel {targetLevel} es {targetSpeed}. La cola solo puede acelerar.`
		)
	end

	curve.TailWalkSpeed = tailSpeed
	curve.TailK = (targetSpeed - tailSpeed) / math.sqrt(targetLevel - tailLevel)
end

function SpeedConfig.getCurve(worldKey: string): WalkSpeedCurve
	local curve = SpeedConfig.WalkSpeedCurves[worldKey]
	if not curve then
		warn(`[Speed] No hay curva de WalkSpeed para el mundo "{worldKey}" — usando World1`)
		return SpeedConfig.WalkSpeedCurves.World1
	end
	return curve
end

-- Speed necesario para pasar de `level` a `level + 1`.
-- req(1)=8, req(40)≈9.8K, req(130)≈1.4e11
function SpeedConfig.getRequiredSpeedForLevel(level: number): number
	return math.max(1, math.floor(SpeedConfig.BaseRequiredSpeed * (SpeedConfig.RequiredSpeedGrowth ^ (level - 1))))
end

-- WalkSpeed de un nivel en un mundo. `worldKey` es opcional y por defecto es el
-- place en el que corre esto: los llamantes existentes no cambian y siguen
-- resolviendo lo correcto. Se pasa explícito solo para comparar mundos (p.ej.
-- calibrar los NpcSpeed de RaceConfig desde otro place).
function SpeedConfig.getWalkSpeedForLevel(level: number, worldKey: string?): number
	level = math.max(1, level)

	local curve = SpeedConfig.getCurve(worldKey or WorldsConfig.currentKey())

	local tailLevel = curve.TailLevel
	if tailLevel and level > tailLevel then
		return (curve.TailWalkSpeed :: number) + (curve.TailK :: number) * math.sqrt(level - tailLevel)
	end

	return baseWalkSpeed(curve, level)
end

return SpeedConfig
