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
	-- "" = todavía sin montura asignada. RaceService NO registra esa pista: la
	-- carrera queda inerte (el prompt ni aparece) en vez de construir un NPC con
	-- una montura equivocada.
	Mount: string,
}

local WorldsConfig = require(game.ReplicatedStorage.Shared.WorldsConfig)

local RaceConfig = {}

-- NpcSpeed ≈ 0.9 × el WalkSpeed del nivel de diseño del stage (el mapa stage→nivel
-- está comentado en EconomyConfig.luau; el WalkSpeed sale de
-- SpeedConfig.getWalkSpeedForLevel). O sea: "un poco más lento" que un jugador que
-- llega al stage con el nivel para el que está pensado. Un jugador muy por encima de
-- ese nivel gana siempre — es deliberado: el premio son los Wins de ESE stage, que en
-- late-game son calderilla.
--
-- Mount = la montura de MountsConfig.World1 cuyo gate de Level cuadra con ese
-- mismo nivel (ojo: "World1" ahí es el TIER de monturas, no el place).
local World1Stages = {
	[2]  = { NpcName = "Miren",     NpcSpeed = 9,  Mount = "Chonk"   }, -- nivel   1, ws  10.0
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

-- ── World 2 ──────────────────────────────────────────────────────────────────
--
-- Niveles de diseño 133..175 (ver EconomyConfig.Worlds.World2.StageLevels).
--
-- Estos NpcSpeed son 0.9 × la curva de WalkSpeed de WORLD 2, que es distinta a la
-- de World 1 a partir del nivel 131 (SpeedConfig.WalkSpeedCurves). Son constantes
-- horneadas: a diferencia de los scripts de obstáculos de los stages —que llaman a
-- getWalkSpeedForLevel en runtime y se recalibran solos al place— si se toca esa
-- curva hay que rehacer esta columna a mano.
--
-- La palanca de NpcSpeed sigue siendo ESTRECHA aunque ya no esté agotada: el mundo
-- entero cabe entre 100 y 117 (antes 96-103). Para diferenciar de verdad las trece
-- carreras la palanca es la LONGITUD DE LA PISTA en el .rbxl (los marcadores
-- Player/Npc/Goal del Model "Race"), no este número.
--
-- Mount = "" en todas: las monturas de World 2 ya existen en MountsConfig, pero
-- sus rigs todavía no están en RojoShared/Mounts.rbxm. Mientras tanto RaceService
-- no registra estas pistas y las carreras quedan inertes — que es justo lo que se
-- quiere hasta que los modelos estén, en vez de reventar al construir el NPC.
local World2Stages = {
	[2]  = { NpcName = "Racer", NpcSpeed = 100, Mount = "" }, -- nivel 133, ws 111.1
	[3]  = { NpcName = "Racer", NpcSpeed = 103, Mount = "" }, -- nivel 137, ws 114.9
	[4]  = { NpcName = "Racer", NpcSpeed = 105, Mount = "" }, -- nivel 140, ws 116.9
	[5]  = { NpcName = "Racer", NpcSpeed = 107, Mount = "" }, -- nivel 144, ws 119.0
	[6]  = { NpcName = "Racer", NpcSpeed = 108, Mount = "" }, -- nivel 147, ws 120.5
	[7]  = { NpcName = "Racer", NpcSpeed = 110, Mount = "" }, -- nivel 151, ws 122.2
	[8]  = { NpcName = "Racer", NpcSpeed = 111, Mount = "" }, -- nivel 154, ws 123.4
	[9]  = { NpcName = "Racer", NpcSpeed = 112, Mount = "" }, -- nivel 158, ws 124.8
	[10] = { NpcName = "Racer", NpcSpeed = 113, Mount = "" }, -- nivel 161, ws 125.8
	[11] = { NpcName = "Racer", NpcSpeed = 114, Mount = "" }, -- nivel 165, ws 127.1
	[12] = { NpcName = "Racer", NpcSpeed = 115, Mount = "" }, -- nivel 168, ws 128.0
	[13] = { NpcName = "Racer", NpcSpeed = 116, Mount = "" }, -- nivel 172, ws 129.2
	[14] = { NpcName = "Racer", NpcSpeed = 117, Mount = "" }, -- nivel 175, ws 130.0
} :: { [number]: RaceData }

-- Para un stage con geometría de carrera pero sin fila propia.
RaceConfig.Default = { NpcName = "Racer", NpcSpeed = 12, Mount = "Chonk" } :: RaceData

-- === Outfits ==============================================================
--
-- El look completo de cada NPC, por asset id. Va en su propia tabla (y no dentro
-- de la tabla de Stages) para no romper la alineación de la tabla de balance de
-- arriba, que se lee de un vistazo con sus comentarios de nivel/WalkSpeed.
--
-- El servidor lo aplica UNA vez al arrancar (RaceService:_applyOutfit) montando
-- una HumanoidDescription. Esta tabla es la verdad completa del vestuario: todo
-- lo que no esté aquí, el NPC no lo lleva puesto, aunque venga en el .rbxl. Lo
-- que NO toca son la anatomía del rig (meshes de las partes del cuerpo) ni la
-- escala salvo que se declare `Scale`.
--
-- Como el corredor de la carrera es un clon del rig de escaparate
-- (MorphService.BuildMountRig clona track.npcModel), hereda el outfit gratis:
-- no hay que volver a vestirlo al empezar cada carrera.
--
-- 0 y {} son placeholders inertes (mismo criterio que los "rbxassetid://0" de
-- MountsConfig): no cambian nada hasta que se les pone un id real. Los ids son
-- los del catálogo (el número de la URL del asset), NO rbxassetid://.
--
-- Slots de accesorio = los de HumanoidDescription; cada uno admite varios ids.

export type Outfit = {
	Shirt: number,   -- Shirt (camiseta clásica 2D)
	Pants: number,   -- Pants
	TShirt: number,  -- GraphicTShirt
	Face: number,    -- textura de cara
	Hair: { number },
	Hats: { number },
	FaceAccessories: { number },
	Front: { number },
	Back: { number },
	Neck: { number },
	Shoulders: { number },
	Waist: { number },
	-- Opcionales: nil = se respeta lo que traiga el rig del .rbxl.
	SkinColor: Color3?,
	Scale: {
		Height: number?,
		Width: number?,
		Head: number?,
		Depth: number?,
		BodyType: number?,
		Proportion: number?,
	}?,
}

-- Todos los ids de abajo son assets creados por la cuenta oficial de Roblox y
-- están comprobados uno a uno contra la API del catálogo: los de Shirt son
-- assetType 11 (Classic Shirt), los de Pants assetType 12 (Classic Pants) y los
-- de Hats assetType 8. Se eligieron oficiales a propósito: los de creadores de
-- la comunidad pueden retirarse del catálogo y dejarían al NPC medio desnudo.
--
-- El NPC NO necesita poseer nada de esto: ApplyDescription viste un rig con
-- cualquier asset válido, no mira inventario ni cobra Robux.
--
-- La progresión es cosmética y sigue la del recorrido: los NPC de stages bajos
-- van de calle (gorra + vaqueros) y los de stages altos llevan las fedoras de
-- coleccionista, hasta el Medieval Hood de Nyxara, que cierra World 1.
-- Tonos de piel. El rig de escaparate viene con el color por defecto, y como
-- applyOutfit reconstruye la HumanoidDescription desde cero, sin esto los trece
-- NPC salen del mismo gris. Se reparten para que no parezcan clones.
--
-- SkinColor pinta cabeza, torso, brazos y piernas de una vez, pero con Shirt y
-- Pants puestos lo que de verdad se ve es la cabeza y las manos.
local SKIN = {
	Light  = Color3.fromRGB(255, 204, 153),
	Warm   = Color3.fromRGB(234, 184, 146),
	Medium = Color3.fromRGB(205, 154, 110),
	Tan    = Color3.fromRGB(175, 120, 80),
	Brown  = Color3.fromRGB(143, 96, 62),
	Dark   = Color3.fromRGB(105, 70, 46),
}

local World1Outfits = {
	[2] = { -- Lyx — Teal Shirt / Jean Shorts / Roblox Baseball Cap
		Shirt = 382537702, Pants = 382537806, TShirt = 0, Face = 0,
		Hair = {}, Hats = { 607702162 }, FaceAccessories = {},
		Front = {}, Back = {}, Neck = {}, Shoulders = {}, Waist = {},
		SkinColor = SKIN.Light,
	},
	[3] = { -- Bramble — Blue Plaid Shirt / Jeans / Down to Earth Hair
		Shirt = 398635081, Pants = 129458426, TShirt = 0, Face = 0,
		Hair = {}, Hats = { 1772336109 }, FaceAccessories = {},
		Front = {}, Back = {}, Neck = {}, Shoulders = {}, Waist = {},
		SkinColor = SKIN.Tan,
	},
	[4] = { -- Kessa — Pastel Starburst Top / Beautiful You Jeans
		Shirt = 398634295, Pants = 398634487, TShirt = 0, Face = 0,
		Hair = {}, Hats = {}, FaceAccessories = {},
		Front = {}, Back = {}, Neck = {}, Shoulders = {}, Waist = {},
		SkinColor = SKIN.Warm,
	},
	[5] = { -- Torvo — Motorcycle Shirt / Black Jeans / Red Roblox Cap
		Shirt = 144076358, Pants = 382537569, TShirt = 0, Face = 0,
		Hair = {}, Hats = { 48474313 }, FaceAccessories = {},
		Front = {}, Back = {}, Neck = {}, Shoulders = {}, Waist = {},
		SkinColor = SKIN.Brown,
	},
	[6] = { -- Mirra — I <3 Pizza Shirt / Jean Shorts w/ White Shoes / 'R' Cap
		Shirt = 382537085, Pants = 382537950, TShirt = 0, Face = 0,
		Hair = {}, Hats = { 417457461 }, FaceAccessories = {},
		Front = {}, Back = {}, Neck = {}, Shoulders = {}, Waist = {},
		SkinColor = SKIN.Medium,
	},
	[7] = { -- Dask — Grey Striped + Denim Jacket / Dark Green Jeans / Fedora Brazil
		Shirt = 144076436, Pants = 144076760, TShirt = 0, Face = 0,
		Hair = {}, Hats = { 4047554959 }, FaceAccessories = {},
		Front = {}, Back = {}, Neck = {}, Shoulders = {}, Waist = {},
		SkinColor = SKIN.Dark,
	},
	[8] = { -- Volen — Denim Jacket w/ White Hoodie / Ripped Skater / Fedora Mexico
		Shirt = 398633584, Pants = 398635338, TShirt = 0, Face = 0,
		Hair = {}, Hats = { 4094878701 }, FaceAccessories = {},
		Front = {}, Back = {}, Neck = {}, Shoulders = {}, Waist = {},
		SkinColor = SKIN.Warm,
	},
	[9] = { -- Ysra — My Favorite Pizza / Black Jeans w/ Sneakers / Fedora Spain + Orange Shades
		Shirt = 4047884939, Pants = 382538503, TShirt = 0, Face = 0,
		Hair = {}, Hats = { 4246228452 }, FaceAccessories = { 376527500 },
		Front = {}, Back = {}, Neck = {}, Shoulders = {}, Waist = {},
		SkinColor = SKIN.Light,
	},
	[10] = { -- Corvyn — Guitar Tee w/ Black Jacket / Black Jeans w/ White Shoes / Fedora Canada
		Shirt = 382538295, Pants = 398633812, TShirt = 0, Face = 0,
		Hair = {}, Hats = { 3398308134 }, FaceAccessories = {},
		Front = {}, Back = {}, Neck = {}, Shoulders = {}, Waist = {},
		SkinColor = SKIN.Tan,
	},
	[11] = { -- Thane — ROBLOX Jacket / Ripped Skater Pants / Fedora Germany
		Shirt = 607785314, Pants = 398635338, TShirt = 0, Face = 0,
		Hair = {}, Hats = { 3033910400 }, FaceAccessories = {},
		Front = {}, Back = {}, Neck = {}, Shoulders = {}, Waist = {},
		SkinColor = SKIN.Medium,
	},
	[12] = { -- Solara — Roblox Shirt Simple Pattern / Beautiful You Jeans / Fedora Japan
		Shirt = 3670737444, Pants = 398634487, TShirt = 0, Face = 0,
		Hair = {}, Hats = { 4324158403 }, FaceAccessories = {},
		Front = {}, Back = {}, Neck = {}, Shoulders = {}, Waist = {},
		SkinColor = SKIN.Warm,
	},
	[13] = { -- Vhal — Guitar Tee w/ Black Jacket / Black Jeans / Fedora France
		Shirt = 4047884046, Pants = 382537569, TShirt = 0, Face = 0,
		Hair = {}, Hats = { 3033908130 }, FaceAccessories = {},
		Front = {}, Back = {}, Neck = {}, Shoulders = {}, Waist = {},
		SkinColor = SKIN.Brown,
	},
	[14] = { -- Nyxara — ROBLOX Jacket / Black Jeans w/ Sneakers / Medieval Hood of Mystery
		Shirt = 607785314, Pants = 382538503, TShirt = 0, Face = 0,
		Hair = {}, Hats = { 617605556 }, FaceAccessories = { 376527500 },
		Front = {}, Back = {}, Neck = {}, Shoulders = {}, Waist = {},
		SkinColor = SKIN.Dark,
	},
} :: { [number]: Outfit }

-- Para un stage con NPC pero sin fila de outfit propia. Todo a cero: el NPC se
-- queda con la anatomía de su rig y sin ropa ni accesorios.
RaceConfig.DefaultOutfit = {
	Shirt = 0, Pants = 0, TShirt = 0, Face = 0,
	Hair = {}, Hats = {}, FaceAccessories = {},
	Front = {}, Back = {}, Neck = {}, Shoulders = {}, Waist = {},
} :: Outfit

-- Nombres de las partes dentro del Model "Race". El Model tiene además SEIS hijos
-- llamados "Baseplate" (suelo y paredes de la pista); estos tres sí son únicos.
RaceConfig.PlayerMarkerName = "Player"
RaceConfig.NpcMarkerName    = "Npc"
RaceConfig.GoalName         = "Goal"

-- Animación del NPC de escaparate mientras espera: saluda con la mano en bucle.
-- "R15Wave", oficial de Roblox (assetType 24) — el rig de los stages es R15
-- (UpperTorso/LowerTorso), así que NO vale la versión R6 (128777973), que en un
-- R15 no mueve nada.
RaceConfig.NpcIdleAnimation = "rbxassetid://507770239"

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

-- ── Tabla por mundo ──────────────────────────────────────────────────────────
--
-- Los dos places usan los MISMOS nombres de stage, así que sin esto el "Stage 2"
-- de World 2 heredaría a Lyx corriendo a velocidad 9 sobre un Chonk en una
-- carrera de nivel 133.
RaceConfig.Worlds = {
	World1 = { Stages = World1Stages, Outfits = World1Outfits },
	World2 = {
		Stages = World2Stages,
		-- TODO contenido: vestuario propio de World 2. Apunta por referencia al de
		-- World 1 mientras tanto — inventarse 13 juegos de asset ids sin poder
		-- verificarlos contra el catálogo sería peor que un placeholder honesto.
		Outfits = World1Outfits,
	},
} :: { [string]: { Stages: { [number]: RaceData }, Outfits: { [number]: Outfit } } }

local function worldRace(worldKey: string?)
	local key = worldKey or WorldsConfig.currentKey()
	return RaceConfig.Worlds[key] or RaceConfig.Worlds.World1
end

-- worldKey nil = el mundo de este place. Las firmas no cambian respecto de antes,
-- así que RaceService sigue llamándolas igual.
function RaceConfig.get(stage: number, worldKey: string?): RaceData
	return worldRace(worldKey).Stages[stage] or RaceConfig.Default
end

function RaceConfig.getOutfit(stage: number, worldKey: string?): Outfit
	return worldRace(worldKey).Outfits[stage] or RaceConfig.DefaultOutfit
end

return RaceConfig
