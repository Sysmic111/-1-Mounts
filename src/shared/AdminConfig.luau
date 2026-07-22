--!strict

-- Allowlist de administradores. Fuente ÚNICA de verdad compartida por cliente y
-- servidor:
--   · el cliente la usa solo para decidir si CONSTRUYE el panel (cosmético)
--   · el servidor la usa para VALIDAR cada acción admin (seguridad real)
--
-- La seguridad NO depende de ocultar el panel: cualquier cliente puede disparar
-- los remotes admin a mano. Lo que impide el exploit es que AdminService revalida
-- `player.UserId` (autoritativo en el servidor, no se puede falsificar) contra esta
-- lista en TODOS los handlers. Que estos IDs sean públicos no es un problema.

local AdminConfig = {}

AdminConfig.Ids = {
	[6407237]   = true,
	[310122234] = true,
} :: { [number]: boolean }

function AdminConfig.isAdmin(userId: number): boolean
	return AdminConfig.Ids[userId] == true
end

return AdminConfig
