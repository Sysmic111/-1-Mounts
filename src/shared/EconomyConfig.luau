--!strict

-- Fuente de verdad de los valores económicos que viven como atributos en
-- Workspace (WinsQuantity de los botones de stage y de los steps buttons).
--
-- Estos atributos estaban puestos a mano en Studio y ningún script los escribía:
-- todos los stages daban 1 win, así que el step de 1.000 wins exigía 1.000
-- vueltas al obby. EconomyService los siembra desde aquí al arrancar el servidor,
-- de modo que el balance se versiona en git en vez de vivir en el .rbxl.
--
-- MULTI-PLACE: los dos places tienen los MISMOS nombres de Workspace
-- (`Stage 2`..`Stage 14`, Models `Steps`), así que "stage 5" significa cosas
-- distintas según dónde corra el servidor. Por eso todo cuelga de `Worlds` y se
-- lee con `current()`, que resuelve por PlaceId vía WorldsConfig.
--
-- Las tablas son EXPLÍCITAS, no una fórmula, y es deliberado: las de World 1 no
-- son formulaicas (el ratio de StageWins va de 3.00 a 1.57, el de precios de
-- steps de 5.0 a 2.73). Una fórmula necesitaría esa deriva como parámetro y
-- sería una versión peor documentada de la tabla, además de esconder la frontera
-- entre mundos, que es justo lo que hay que ver en el diff.

local WorldsConfig = require(game.ReplicatedStorage.Shared.WorldsConfig)

export type StepEntry = {
	Increment: number,  -- el atributo StepsIncresement del Model (sic, el typo está en el place)
	Price: number,      -- coste en WinCurrency
}

export type WorldEconomy = {
	StageLevels: { [number]: number },
	StageWins: { [number]: number },
	-- ARRAY ORDENADO, no mapa: el orden ES la cadena de compra. El orden de
	-- iteración de un {[number]: number} en Luau no está definido, y una vez que
	-- la cadena cruza mundos su orden es una decisión de diseño que hay que
	-- declarar, no inferir de un table.sort.
	Steps: { StepEntry },
	-- Derivado al cargar el módulo: increment → precio, para búsqueda O(1).
	StepPrices: { [number]: number },
}

local EconomyConfig = {}

-- El botón premium de cada stage da StageWins × este factor.
-- Los botones premium comparten un único ProductId (WinsConfig.PremiumProductId),
-- o sea que cuestan lo mismo en Robux sin importar el stage: su valor tiene que
-- escalar con el stage o comprarlo en el 2 sería idéntico a comprarlo en el 14.
--
-- OJO ahora que hay dos mundos: ese mismo precio compra 2 Wins en el stage 2 de
-- World 1 y 400.000.000 en el stage 14 de World 2. Todo comprador racional compra
-- en el último stage del último mundo. Hace falta un ProductId por mundo, o
-- asumirlo conscientemente.
EconomyConfig.PremiumWinsFactor = 2

-- ── World 1 ──────────────────────────────────────────────────────────────────

-- Nivel de diseño de cada stage (para qué nivel está pensada su dificultad).
-- No se aplica por código — la dificultad es geometría — pero es la referencia
-- con la que se calibraron los wins, la curva de SpeedConfig, las velocidades de
-- los NPC de RaceConfig y los niveles de ObstaclesConfig.
local World1Levels = {
	[2]  = 1,   [3]  = 8,   [4]  = 16,  [5]  = 26,
	[6]  = 37,  [7]  = 49,  [8]  = 62,  [9]  = 75,
	[10] = 88,  [11] = 101, [12] = 114, [13] = 122,
	[14] = 130, -- final del recorrido de World 1
}

-- Wins del botón normal de cada stage. El Stage 1 es el spawn y no tiene botones.
local World1Wins = {
	[2]  = 1,
	[3]  = 3,
	[4]  = 7,
	[5]  = 15,
	[6]  = 30,
	[7]  = 55,
	[8]  = 100,
	[9]  = 175,
	[10] = 300,
	[11] = 500,
	[12] = 850,
	[13] = 1400,
	[14] = 2200,
}

-- El StepsIncresement multiplica directamente la ganancia de Speed, y la compra
-- es única: sobrevive a los rebirths.
local World1Steps: { StepEntry } = {
	{ Increment = 1,    Price = 0 },
	{ Increment = 2,    Price = 3 },
	{ Increment = 4,    Price = 15 },
	{ Increment = 8,    Price = 60 },
	{ Increment = 16,   Price = 200 },
	{ Increment = 32,   Price = 600 },
	{ Increment = 64,   Price = 1800 },
	{ Increment = 125,  Price = 5000 },
	{ Increment = 250,  Price = 14000 },
	{ Increment = 500,  Price = 40000 },
	{ Increment = 1000, Price = 110000 },
	{ Increment = 2000, Price = 300000 },
}

-- ── World 2 ──────────────────────────────────────────────────────────────────

-- El tramo de World 2 (niveles 131..175) no es arbitrario: el único motor de
-- ingreso nuevo que trae este mundo es su cadena de steps, que multiplica el
-- ingreso ×4000. Contra la curva exponencial de SpeedConfig (1.204 por nivel):
--   ln(4000) / ln(1.204) = 44.7 niveles a ritmo constante
-- O sea que el mundo se paga a sí mismo, sin depender de que existan rebirths 9+
-- ni un tier de monturas propio.
--
-- ESTE ESPACIADO (~+3.5 niveles por stage) ES LA PALANCA DE DURACIÓN de World 2.
-- Más niveles por stage = mundo más largo, y hay que pagarlo con una cadena de
-- steps más larga o más empinada.
local World2Levels = {
	[2]  = 133, [3]  = 137, [4]  = 140, [5]  = 144,
	[6]  = 147, [7]  = 151, [8]  = 154, [9]  = 158,
	[10] = 161, [11] = 165, [12] = 168, [13] = 172,
	[14] = 175, -- final del recorrido de World 2
}

-- Calibrado manteniendo dos ratios estructurales de World 1: precio del step top
-- entre wins del stage top, y precio del step top entre vuelta completa. Desde el
-- step de 50B salen stage top ≈ 200M y vuelta ≈ 536M, y se desciende al ×1.6
-- asintótico de World 1.
--
-- La entrada NO es un muro: el primer step de World 2 (800K) sale con 2
-- pulsaciones del stage 2. Vuelta completa = 536.45M.
local World2Wins = {
	[2]  = 750000,
	[3]  = 1200000,
	[4]  = 2000000,
	[5]  = 3000000,
	[6]  = 5000000,
	[7]  = 7500000,
	[8]  = 12000000,
	[9]  = 20000000,
	[10] = 30000000,
	[11] = 50000000,
	[12] = 80000000,
	[13] = 125000000,
	[14] = 200000000,
}

-- Los increments son los de World 1 × 4000 (conserva sus rarezas, como el 125 →
-- 500.000, y la relación se explica en una frase).
--
-- Los precios siguen la ley ASINTÓTICA de World 1: ×2.75 de precio por cada ×2 de
-- increment (price ∝ increment^1.46). Los ×5.0 / ×4.0 / ×3.33 del principio de
-- World 1 son la rampa de onboarding y no deben repetirse en un mundo de endgame.
--
-- Cada compra vale ×2 de ingreso (~3.7 niveles de la curva) pero cuesta ×2.75 que
-- la anterior: el step marginal empeora, y eso es lo que impide que la cadena
-- cortocircuite la curva de niveles. Total de la cadena ≈ 79.9B Wins.
--
-- INVARIANTE: los Increment tienen que ser ÚNICOS entre TODOS los mundos. La
-- clave de datos es plana (`StepUnlocked_<increment>`), así que un increment
-- repetido en otro mundo se regalaría solo. Hay una aserción al final del módulo.
local World2Steps: { StepEntry } = {
	{ Increment = 4000,    Price = 800000 },
	{ Increment = 8000,    Price = 2200000 },
	{ Increment = 16000,   Price = 6000000 },
	{ Increment = 32000,   Price = 16000000 },
	{ Increment = 64000,   Price = 45000000 },
	{ Increment = 128000,  Price = 125000000 },
	{ Increment = 256000,  Price = 340000000 },
	{ Increment = 500000,  Price = 900000000 },
	{ Increment = 1000000, Price = 2500000000 },
	{ Increment = 2000000, Price = 7000000000 },
	{ Increment = 4000000, Price = 19000000000 },
	{ Increment = 8000000, Price = 50000000000 },
}

-- ── Tabla y accesores ────────────────────────────────────────────────────────

-- Deriva el mapa increment → precio de un array de Steps.
local function buildStepPrices(steps: { StepEntry }): { [number]: number }
	local prices: { [number]: number } = {}
	for _, entry in steps do
		prices[entry.Increment] = entry.Price
	end
	return prices
end

EconomyConfig.Worlds = {
	World1 = {
		StageLevels = World1Levels,
		StageWins   = World1Wins,
		Steps       = World1Steps,
		StepPrices  = buildStepPrices(World1Steps),
	},
	World2 = {
		StageLevels = World2Levels,
		StageWins   = World2Wins,
		Steps       = World2Steps,
		StepPrices  = buildStepPrices(World2Steps),
	},
} :: { [string]: WorldEconomy }

function EconomyConfig.forWorld(worldKey: string): WorldEconomy
	local econ = EconomyConfig.Worlds[worldKey]
	if not econ then
		warn(`[Economy] No hay balance para el mundo "{worldKey}" — usando World1`)
		return EconomyConfig.Worlds.World1
	end
	return econ
end

-- El balance del place en el que corre esto. NO se cachea en un local de módulo
-- a nivel de fichero en los consumidores: un alias resuelto en el require es
-- justo lo que acabaría pagando tarifas de World 1 en World 2.
function EconomyConfig.current(): WorldEconomy
	return EconomyConfig.forWorld(WorldsConfig.currentKey())
end

-- La cadena de steps COMPLETA, de todos los mundos, en orden de progresión.
--
-- Es lo que hace que la cadena sea global: para comprar el primer step de World 2
-- hay que tener todos los de World 1. Si se derivara de los botones presentes en
-- el place (como se hacía antes), en World 2 el mínimo sería su propio primer
-- botón y se podría saltar World 1 entero.
local stepChain: { number } = {}
do
	for _, worldKey in WorldsConfig.Order do
		local econ = EconomyConfig.Worlds[worldKey]
		if not econ then continue end
		for _, entry in econ.Steps do
			table.insert(stepChain, entry.Increment)
		end
	end
end

function EconomyConfig.getStepChain(): { number }
	return stepChain
end

-- A qué mundo pertenece un increment. Sirve para decirle al jugador QUÉ mundo
-- tiene pendiente en vez de un "compra los anteriores" que no dice nada.
function EconomyConfig.getWorldForIncrement(increment: number): string?
	for _, worldKey in WorldsConfig.Order do
		local econ = EconomyConfig.Worlds[worldKey]
		if econ and econ.StepPrices[increment] then
			return worldKey
		end
	end
	return nil
end

-- Aserción del invariante: increments únicos entre mundos. Si dos mundos comparten
-- uno, el jugador que lo compre en uno lo tiene gratis en el otro (la clave
-- `StepUnlocked_<N>` es plana) y la cadena global saldría con duplicados.
do
	local seen: { [number]: string } = {}
	for _, worldKey in WorldsConfig.Order do
		local econ = EconomyConfig.Worlds[worldKey]
		if not econ then continue end
		for _, entry in econ.Steps do
			local previous = seen[entry.Increment]
			if previous then
				error(
					`[Economy] StepsIncresement {entry.Increment} repetido en "{previous}" y "{worldKey}". `
						.. "Tienen que ser únicos entre TODOS los mundos: la clave StepUnlocked_<N> es plana."
				)
			end
			seen[entry.Increment] = worldKey
		end
	end
end

return EconomyConfig
