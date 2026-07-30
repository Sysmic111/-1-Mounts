--!strict

-- Tras ~5 min de sesión, ofrece al jugador el modal nativo de Roblox para
-- recibir notificaciones del próximo Experience Event. El evento se crea en el
-- dashboard; aquí solo se lanza el prompt de RSVP.
--
-- El eventId va como STRING a propósito: es ~5.2e18, por encima de la precisión
-- de los números de Lua (2^53), así que como número quedaría corrupto.

local SocialService = game:GetService("SocialService")

local EVENT_ID      = "2496037773681754725"
local DELAY_SECONDS = 300 -- 5 min de sesión

task.spawn(function()
	task.wait(DELAY_SECONDS)

	-- No re-preguntar si el jugador ya respondió (Going/Maybe/NotGoing).
	local statusOk, status = pcall(function()
		return SocialService:GetEventRsvpStatusAsync(EVENT_ID)
	end)
	if statusOk and status ~= nil and status ~= Enum.RsvpStatus.None then
		return
	end

	pcall(function()
		SocialService:PromptRsvpToEventAsync(EVENT_ID)
	end)
end)
