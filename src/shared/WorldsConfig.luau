--!strict

-- Qué place es este. ÚNICO sitio del repo que conoce PlaceIds.
--
-- El juego son varios places que comparten este mismo codebase: World 1 es el
-- original y World 2 su continuación (mismos nombres de Workspace, geometría y
-- balance distintos). Todo lo que cambia entre places se resuelve preguntando
-- aquí y buscando el bloque del world en el config correspondiente
-- (EconomyConfig.Worlds, RaceConfig.Worlds, ObstaclesConfig.Worlds).
--
-- Vive en Shared para que cliente y servidor lo resuelvan igual, sin replicación
-- ni orden de init: `game.PlaceId` está disponible desde el primer frame.
--
-- OJO con el nombre: `MountsConfig.MountTiers` NO son places, son los tiers de
-- monturas del menú Index. Aquí "world" significa siempre "place".

export type WorldData = {
	Key: string,             -- va en las data keys y en los nombres de funnel
	Name: string,            -- texto para UI y analytics
	PlaceId: number,
	Order: number,           -- orden canónico de progresión
	-- World cuya cadena de steps hay que tener completa para poder estar aquí.
	-- nil = mundo de entrada. Lo aplica WorldsService.
	RequiresWorld: string?,
	StagesFunnel: string,
}

local WorldsConfig = {}

WorldsConfig.Worlds = {
	World1 = {
		Key           = "World1",
		Name          = "World 1",
		PlaceId       = 74139556114101,
		Order         = 1,
		RequiresWorld = nil,
		-- Se conserva la cadena EXACTA que ya estaba en producción para no partir
		-- el histórico del funnel de World 1.
		StagesFunnel  = "World1StagesV1",
	},
	World2 = {
		Key           = "World2",
		Name          = "World 2",
		PlaceId       = 88347344061446,
		Order         = 2,
		RequiresWorld = "World1",
		StagesFunnel  = "World2StagesV1",
	},
} :: { [string]: WorldData }

-- Orden de progresión. Es la fuente de verdad para encadenar los steps entre
-- mundos (EconomyConfig.getStepChain), no el orden de iteración de `Worlds`,
-- que en Luau no está definido.
WorldsConfig.Order = { "World1", "World2" }

WorldsConfig.Fallback = "World1"

-- Para probar OTRO mundo desde este place sin publicar nada. Todo lo que
-- depende del world (siembra, carreras, obstáculos, funnels) lo sigue, porque
-- todos resuelven por current().
-- COMMITEAR SIEMPRE A nil.
WorldsConfig.Override = nil :: string?

function WorldsConfig.get(key: string): WorldData?
	return WorldsConfig.Worlds[key]
end

function WorldsConfig.byPlaceId(placeId: number): WorldData?
	for _, world in WorldsConfig.Worlds do
		if world.PlaceId == placeId then
			return world
		end
	end
	return nil
end

-- Se resuelve UNA vez al cargar el módulo y se cachea: el PlaceId no cambia en
-- toda la vida del servidor, y así ningún consumidor paga el barrido.
local resolved: WorldData
do
	local override = WorldsConfig.Override
	if override and WorldsConfig.Worlds[override] then
		resolved = WorldsConfig.Worlds[override]
		warn(`[Worlds] Override activo: {resolved.Name} (el PlaceId real se está ignorando)`)
	else
		local byPlace = WorldsConfig.byPlaceId(game.PlaceId)
		if byPlace then
			resolved = byPlace
		else
			-- En un .rbxl local sin publicar game.PlaceId es 0, así que trabajar en
			-- Studio cae aquí y se comporta como World 1. Es lo que se quiere, pero
			-- el mismo mensaje en un place PUBLICADO significa que falta su fila.
			resolved = WorldsConfig.Worlds[WorldsConfig.Fallback]
			warn(`[Worlds] PlaceId {game.PlaceId} desconocido — usando {resolved.Name}`)
		end
	end
end

function WorldsConfig.current(): WorldData
	return resolved
end

function WorldsConfig.currentKey(): string
	return resolved.Key
end

return WorldsConfig
