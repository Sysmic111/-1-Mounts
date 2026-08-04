--!strict

-- Datos de las carreras contra NPC. Clave = número de stage.
--
-- Un stage entra en el sistema por GEOMETRÍA, no por config: le basta con tener un
-- Model "Npc" (el rig con el ProximityPrompt) y un Model "Race" (con las partes
-- "Player", "Npc" y "Goal"). Esta tabla solo pone el nombre, la velocidad y la
-- montura; un stage con la geometría pero sin fila aquí funciona igual con Default.

export type RaceData = {
	NpcName: string,
	NpcSpeed: number,
	Mount: string,
}

local RaceConfig = {}

-- NpcSpeed ≈ 0.9 × el WalkSpeed del nivel de diseño del stage (el mapa stage→nivel
-- está comentado en EconomyConfig.luau; el WalkSpeed sale de
-- SpeedConfig.getWalkSpeedForLevel). O sea: "un poco más lento" que un jugador que
-- llega al stage con el nivel para el que está pensado. Un jugador muy por encima de
-- ese nivel gana siempre — es deliberado: el premio son los Wins de ESE stage, que en
-- late-game son calderilla.
--
-- Mount = la montura de World1 cuyo gate de Level cuadra con ese mismo nivel.
RaceConfig.Stages = {
	[2]  = { NpcName = "Lyx",     NpcSpeed = 9,  Mount = "Chonk"   }, -- nivel   1, ws  10.0
	[3]  = { NpcName = "Bramble", NpcSpeed = 17, Mount = "Moru"    }, -- nivel   8, ws  18.6
	[4]  = { NpcName = "Kessa",   NpcSpeed = 26, Mount = "Lirael"  }, -- nivel  16, ws  28.4
	[5]  = { NpcName = "Torvo",   NpcSpeed = 37, Mount = "Zahmir"  }, -- nivel  26, ws  40.6
	[6]  = { NpcName = "Mirra",   NpcSpeed = 49, Mount = "Sahari"  }, -- nivel  37, ws  54.1
	[7]  = { NpcName = "Dask",    NpcSpeed = 62, Mount = "Khar"    }, -- nivel  49, ws  68.8
	[8]  = { NpcName = "Volen",   NpcSpeed = 76, Mount = "Lutra"   }, -- nivel  62, ws  83.9
	[9]  = { NpcName = "Ysra",    NpcSpeed = 81, Mount = "Takaari" }, -- nivel  75, ws  90.0
	[10] = { NpcName = "Corvyn",  NpcSpeed = 85, Mount = "Rook"    }, -- nivel  88, ws  94.6
	[11] = { NpcName = "Thane",   NpcSpeed = 89, Mount = "Apex"    }, -- nivel 101, ws  98.6
	[12] = { NpcName = "Solara",  NpcSpeed = 92, Mount = "Regal"   }, -- nivel 114, ws 102.0
	[13] = { NpcName = "Vhal",    NpcSpeed = 94, Mount = "Kharvox" }, -- nivel 122, ws 103.9
	[14] = { NpcName = "Nyxara",  NpcSpeed = 95, Mount = "Nyxion"  }, -- nivel 130, ws 105.8
} :: { [number]: RaceData }

-- Para un stage con geometría de carrera pero sin fila propia.
RaceConfig.Default = { NpcName = "Racer", NpcSpeed = 12, Mount = "Chonk" } :: RaceData

-- Nombres de las partes dentro del Model "Race". El Model tiene además SEIS hijos
-- llamados "Baseplate" (suelo y paredes de la pista); estos tres sí son únicos.
RaceConfig.PlayerMarkerName = "Player"
RaceConfig.NpcMarkerName    = "Npc"
RaceConfig.GoalName         = "Goal"

RaceConfig.NpcModelName  = "Npc"      -- el rig de escaparate dentro del stage
RaceConfig.RaceModelName = "Race"     -- el Model de la pista
RaceConfig.RacerName     = "RaceNpc"  -- nombre del corredor instanciado en Workspace

-- Cuenta atrás. El último elemento es el que da la salida.
RaceConfig.CountdownSteps   = { "3", "2", "1", "Start!" }
RaceConfig.CountdownStep    = 1

RaceConfig.WinFactor  = 2    -- ganar = x2 los Wins del stage
RaceConfig.LoseFactor = 0.5  -- perder = la mitad

-- Corte de seguridad: si nadie cruza la meta (jugador atascado, NPC bloqueado), la
-- carrera se cierra como derrota y libera la pista. Sin esto, un corredor colgado
-- dejaría la pista ocupada para todo el server.
RaceConfig.MaxRaceSeconds = 180

-- Knob anti-farm: segundos entre dos carreras del mismo jugador en el mismo stage.
-- Hoy 0 (repetible sin límite); el premio de un stage bajo no lo justifica todavía.
RaceConfig.CooldownSeconds = 0

RaceConfig.GoalRadius  = 6  -- tolerancia de cruce de meta, en studs
RaceConfig.SpawnHeight = 5  -- clearance al plantar al jugador sobre el marcador

function RaceConfig.get(stage: number): RaceData
	return RaceConfig.Stages[stage] or RaceConfig.Default
end

return RaceConfig
