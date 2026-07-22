--!strict

-- Config del bonus por pertenecer al grupo de Roblox. En Shared porque lo usan:
--   servidor  → GroupId para IsInGroup, Multiplier para el TotalMultiplier
--   cliente   → GroupId para GroupService:PromptJoinAsync, Multiplier para la UI
local GroupBonusConfig = {
	GroupId = 312853982,

	-- Fuente ADITIVA como mount/hat/trail: aporta +(Multiplier-1) a la base del
	-- TotalMultiplier (ver SpeedService:_updateTotalMultiplier). NO es multiplicativo.
	Multiplier = 10,
}

return GroupBonusConfig
