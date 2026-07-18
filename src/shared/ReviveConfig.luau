--!strict

-- Sistema de revive (Stages). Dos Developer Products:
--   · InfiniteRevives: compra única. Con él, el botón Revive revive gratis y sin
--     mostrar el costo. Se guarda en la data como `InfiniteRevives = true`.
--   · ReviveOnce: consumible. Sin InfiniteRevives, el botón Revive lanza esta
--     compra y cada compra concede un revive (teleport al último stage).

local ReviveConfig = {
	InfiniteRevivesProductId = 3606125748,
	ReviveOnceProductId      = 3610486956,

	-- Posición de retorno al último stage. La altura final también incluye la
	-- distancia real entre el HRP y la parte más baja de la montura.
	TeleportBackOffset        = 10,
	MinimumTeleportHeight     = 5,
	GroundClearance           = 2,
}

return ReviveConfig
