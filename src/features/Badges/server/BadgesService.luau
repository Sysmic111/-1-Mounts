--!strict

-- Otorga badges. Por ahora: un badge de bienvenida al entrar al juego.
-- Los badges se crean en el dashboard de Roblox; aquí solo se conceden.

local BadgeService = game:GetService("BadgeService")
local Players      = game:GetService("Players")

local JOIN_BADGE_ID = 1874991418878301

local BadgesService = {}

local function awardJoinBadge(player: Player): ()
	task.spawn(function()
		-- ¿Ya lo tiene? Evita la llamada de concesión si ya es suyo.
		local ownsOk, owns = pcall(function()
			return BadgeService:UserHasBadgeAsync(player.UserId, JOIN_BADGE_ID)
		end)
		if ownsOk and owns then return end

		-- AwardBadge falla de forma controlada si el badge está deshabilitado o no
		-- pertenece a esta experiencia; se protege con pcall.
		pcall(function()
			BadgeService:AwardBadge(player.UserId, JOIN_BADGE_ID)
		end)
	end)
end

function BadgesService:init(): ()
	Players.PlayerAdded:Connect(awardJoinBadge)
	for _, player in Players:GetPlayers() do
		awardJoinBadge(player)
	end
end

return BadgesService
