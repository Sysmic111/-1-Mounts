--!strict

-- Calibración de los obstáculos de los stages, por mundo.
--
-- Cada obstáculo se calibra contra un NIVEL DE DISEÑO: su velocidad sale de
-- `SpeedConfig.getWalkSpeedForLevel(Level)`, así que "va justo" para un jugador
-- que llega con ese nivel. Antes eran constantes de módulo dentro de cada
-- LocalScript, lo que en un juego multi-place significaba que un obstáculo de
-- World 2 se movería a velocidad de World 1.
--
-- Los niveles de World 2 están puestos en la MISMA POSICIÓN RELATIVA dentro del
-- tramo del mundo que los de World 1 (Walls ~8%, Laser ~38%, Tronco ~46%,
-- Totem ~61%, LavaRise ~69%, Transparent 100%), mapeada sobre 130→175.
-- HAY QUE REAPUNTARLOS cuando exista la geometría de World 2: qué stage lleva qué
-- obstáculo es un hecho del .rbxl y no se puede deducir del repo.
--
-- ── Dos avisos que no son obvios ────────────────────────────────────────────
--
-- 1. La palanca del nivel está CASI AGOTADA por encima de 130. La curva de
--    WalkSpeed es sqrt por encima del nivel 50, así que ws(130)=105.8 y
--    ws(175)=114.7: una banda del 8% para todo World 2. Si los obstáculos tienen
--    que ser más duros, las palancas son las constantes de geometría
--    (OPEN_DISTANCE, DISTANCE) y el propio .rbxl, no el nivel.
--
-- 2. Los tiempos en SEGUNDOS ABSOLUTOS no escalan con el nivel, y si se dejan
--    fijos se invierte la dificultad. Ejemplo real, las Walls: en World 1 el
--    ciclo es 2×(60/21.0) + 2.5 = 8.2 s, con el hueco abierto al 30% del ciclo.
--    Con el mismo 2.5 a nivel 134 el ciclo baja a 2×(60/106.7) + 2.5 = 3.6 s y el
--    hueco pasa al 69%: las paredes acabarían siendo MÁS FÁCILES que en World 1.
--    Por eso los holds viven aquí y no en el LocalScript.
--
-- Los valores de World1 son EXACTAMENTE los que ya estaban en producción.

local WorldsConfig = require(game.ReplicatedStorage.Shared.WorldsConfig)

export type ObstacleData = {
	Level: number,           -- nivel de diseño contra el que se calibra la velocidad
	OpenHold: number?,       -- Walls: s con la pared totalmente abierta
	ResetGap: number?,       -- Walls: s de pausa antes de reiniciar el ciclo
	RollRps: number?,        -- Tronco: rotaciones por segundo del rodillo
	WaitTime: number?,       -- LavaRise: s de espera antes de crecer
	InvisibleHold: number?,  -- Transparent: s invisible y sin colisión
}

local ObstaclesConfig = {}

ObstaclesConfig.Worlds = {
	World1 = {
		Walls       = { Level = 10,  OpenHold = 2.5, ResetGap = 0 },
		Laser       = { Level = 50 },
		Tronco      = { Level = 60,  RollRps = 1.5 },
		Totem       = { Level = 80 },
		LavaRise    = { Level = 90,  WaitTime = 1.5 },
		Transparent = { Level = 130, InvisibleHold = 3 },
	},
	World2 = {
		-- OpenHold 0.5 mantiene el hueco abierto en ~30% del ciclo, igual que en
		-- World 1 (ver aviso 2 de arriba).
		Walls       = { Level = 134, OpenHold = 0.5, ResetGap = 0 },
		Laser       = { Level = 147 },
		-- RollRps sube en la misma proporción que MOVE_SPEED (82.7 → 110.2) para
		-- que el rodillo no patine visualmente.
		Tronco      = { Level = 151, RollRps = 2 },
		Totem       = { Level = 157 },
		LavaRise    = { Level = 161, WaitTime = 1.25 },
		Transparent = { Level = 175, InvisibleHold = 2.75 },
	},
} :: { [string]: { [string]: ObstacleData } }

-- Datos del obstáculo `name` en el mundo actual. Si falta, cae a World1 con aviso
-- en vez de reventar: un obstáculo mal configurado debe seguir jugándose.
function ObstaclesConfig.get(name: string): ObstacleData
	local worldKey = WorldsConfig.currentKey()
	local world = ObstaclesConfig.Worlds[worldKey]
	local data = world and world[name]
	if data then
		return data
	end

	local fallback = ObstaclesConfig.Worlds.World1[name]
	if fallback then
		warn(`[Obstacles] "{name}" sin configurar en {worldKey} — usando los valores de World1`)
		return fallback
	end

	-- Ni siquiera World1 lo tiene: es un error de programación (nombre mal escrito
	-- en el LocalScript). Devolver nil dejaría el fallo para más adelante, en un
	-- índice nil dentro del bucle del obstáculo, mucho más difícil de leer.
	error(`[Obstacles] "{name}" no existe en ningún mundo — ¿nombre mal escrito?`)
end

return ObstaclesConfig
