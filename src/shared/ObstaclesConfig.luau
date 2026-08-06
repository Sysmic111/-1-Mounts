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
-- 1. La palanca del nivel es ESTRECHA por encima de 130, aunque ya no esté
--    agotada. World 2 tiene su propia curva de WalkSpeed con un tramo de cola más
--    empinado (SpeedConfig.WalkSpeedCurves), así que ws(131)=106.0 y ws(175)=130.0:
--    una banda del 23% para todo el mundo, frente al 8% de cuando compartía curva
--    con World 1. Sigue sin dar para diferenciar trece stages: si los obstáculos
--    tienen que ser más duros, las palancas son las constantes de geometría
--    (OPEN_DISTANCE, DISTANCE) y el propio .rbxl, no el nivel.
--
-- 2. Los tiempos en SEGUNDOS ABSOLUTOS no escalan con el nivel, y si se dejan
--    fijos se invierte la dificultad. Ejemplo real, las Walls: en World 1 el
--    ciclo es 2×(60/21.0) + 2.5 = 8.2 s, con el hueco abierto al 30% del ciclo.
--    Con el mismo 2.5 a nivel 134 el ciclo baja a 2×(60/111.7) + 2.5 = 3.6 s y el
--    hueco pasa al 70%: las paredes acabarían siendo MÁS FÁCILES que en World 1.
--    Por eso los holds viven aquí y no en el LocalScript.
--    OJO: la curva nueva de World 2 hace los obstáculos ~11% MÁS RÁPIDOS que antes
--    (se calibran en runtime contra getWalkSpeedForLevel, así que se movieron
--    solos al cambiarla). El jugador también corre más, pero los holds en segundos
--    NO: revisarlos cuando exista la geometría.
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
	Interval: number?,       -- IceCube: s entre clones
	Distance: number?,       -- IceCube: studs que recorre el clone antes de morir
	-- IceCube: velocidad ABSOLUTA en studs/s. Si está, manda sobre la que se
	-- derivaría de `Level`. Para un obstáculo cuyo ritmo no debe seguir al jugador
	-- (una plataforma que sube siempre igual), el nivel sigue documentando en qué
	-- punto del juego encaja, pero no decide la velocidad.
	Speed: number?,
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
		-- El IceCube hoy solo existe en la geometría de World 2. Esta fila está para
		-- que `get()` resuelva sin caer al fallback (que además ERROR-aría si World1
		-- tampoco lo tuviera, porque el LocalScript la pide al cargar, haya o no
		-- partes taggeadas). El nivel es la MISMA POSICIÓN RELATIVA que el de World 2
		-- (150 está al 44% del tramo 131..175; 58 lo está del 1..130), siguiendo el
		-- criterio del comentario de arriba. Sin probar: no hay geometría todavía.
		IceCube     = { Level = 58,  Interval = 4, Distance = 1800 },
		IceCube2    = { Level = 58,  Interval = 15, Distance = 200, Speed = 12 },
		-- Enemy del Ring. Speed 40 es EXACTAMENTE la constante que tenía
		-- RingEnemyService: este mundo no cambia de comportamiento al hacerse la
		-- tabla por mundo. Se probó ~88 y se descartó por demasiado rápido.
		-- El Level aquí es descriptivo (dónde vive el ring), no calibra nada: `Speed`
		-- manda. No está medido contra nada, no lo uses como referencia.
		Ring        = { Level = 90,  Speed = 40 },
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
		-- Nivel 150 -> ws(150) = 121.8 studs/s con la curva de World 2. El cubo viaja
		-- a esa misma velocidad, así que un jugador de ese nivel lo acompaña en vez de
		-- ser arrollado, y con Interval 4 los cubos van separados 487 studs (4 × 121.8):
		-- hueco de sobra para pasar entre uno y otro.
		IceCube     = { Level = 150, Interval = 4, Distance = 1800 },
		-- IceCube2 sube en vertical a velocidad FIJA (10 studs/s), no a la del
		-- jugador: es una plataforma/estorbo que asciende, y su dificultad está en el
		-- ritmo con el que aparece, no en si te alcanza. Por eso lleva `Speed` y su
		-- `Level` queda solo como documentación de dónde encaja.
		--
		-- Distance 200 da 16.7 s de vida, y con Interval 15 salen 180 studs entre
		-- cubos (15 × 12): nunca hay más de uno en el aire, con 1.7 s de hueco entre
		-- que muere uno y sale el siguiente.
		-- Distance es el único número que no venía dado: ajústalo al alto real de la
		-- columna. Si lo subes por encima de 180, volverán a solaparse dos.
		IceCube2    = { Level = 150, Interval = 15, Distance = 200, Speed = 12 },
		-- Enemy del Ring: SIN `Speed`, así que su velocidad la deriva del nivel igual
		-- que Tronco y Laser. Nivel 155 -> 123.7 studs/s.
		--
		-- Eso lo pone a la MISMA velocidad que un jugador de nivel 155, que es lo que
		-- convierte el ring en una puerta de nivel en vez de un adorno:
		--   · por debajo de 155 el enemy es más rápido y te acaba alcanzando
		--   · a partir de 155 le sacas ventaja y puedes cruzar
		-- En el 155 justo es un empate: no te gana terreno mientras corras en recta,
		-- pero cada giro se lo regalas. Mismo criterio que el Totem, cuya velocidad
		-- angular está calibrada para que "un jugador más lento no cruce a tiempo".
		--
		-- Es un salto grande respecto a lo que había (75, el 0.62 de la velocidad del
		-- jugador; esto es 1.0) y deja el enemy MUY por encima del ~109 que era el
		-- equivalente del ~88 descartado en World 1. Aquí es deliberado: ya no es un
		-- estorbo de posicionamiento, es un gate.
		Ring        = { Level = 155 },
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
