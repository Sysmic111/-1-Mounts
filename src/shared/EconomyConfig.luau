--!strict

-- Fuente de verdad de los valores económicos que viven como atributos en
-- Workspace (WinsQuantity de los botones de stage y de los steps buttons).
--
-- Estos atributos estaban puestos a mano en Studio y ningún script los escribía:
-- todos los stages daban 1 win, así que el step de 1.000 wins exigía 1.000
-- vueltas al obby. EconomyService los siembra desde aquí al arrancar el servidor,
-- de modo que el balance se versiona en git en vez de vivir en el .rbxl.

local EconomyConfig = {}

-- ── Stages ───────────────────────────────────────────────────────────────────

-- Wins del botón normal de cada stage. El Stage 1 es el spawn y no tiene botones.
--
-- Nivel de diseño de cada stage (para qué nivel está pensada su dificultad).
-- No se aplica por código — la dificultad es geometría — pero es la referencia
-- con la que se calibraron estos wins y la curva de SpeedConfig:
--   stage  2 → nivel 1     stage  9 → nivel 75
--   stage  3 → nivel 8     stage 10 → nivel 88
--   stage  4 → nivel 16    stage 11 → nivel 101
--   stage  5 → nivel 26    stage 12 → nivel 114
--   stage  6 → nivel 37    stage 13 → nivel 122
--   stage  7 → nivel 49    stage 14 → nivel 130  ← final del recorrido
--   stage  8 → nivel 62
EconomyConfig.StageWins = {
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
} :: { [number]: number }

-- El botón premium de cada stage da StageWins × este factor.
-- Los 13 botones premium comparten un único ProductId
-- (WinsConfig.PremiumProductId), o sea que cuestan lo mismo en Robux sin importar
-- el stage: su valor tiene que escalar con el stage o comprarlo en el 2 sería
-- idéntico a comprarlo en el 14.
EconomyConfig.PremiumWinsFactor = 4

-- ── Steps buttons ────────────────────────────────────────────────────────────

-- Precio en WinCurrency de cada step button, indexado por su StepsIncresement
-- (el atributo del modelo, sic — el typo está en el place y en StepsService).
-- El StepsIncresement multiplica directamente la ganancia de Speed, y la compra
-- es única: sobrevive a los rebirths.
EconomyConfig.StepPrices = {
	[1]    = 0,
	[2]    = 3,
	[4]    = 15,
	[8]    = 60,
	[16]   = 200,
	[32]   = 600,
	[64]   = 1800,
	[125]  = 5000,
	[250]  = 14000,
	[500]  = 40000,
	[1000] = 110000,
	[2000] = 300000,
} :: { [number]: number }

return EconomyConfig
