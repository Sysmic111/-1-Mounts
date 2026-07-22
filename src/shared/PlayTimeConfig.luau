--!strict

local PlayTimeConfig = {}

-- Each tier activates at MinSeconds elapsed since session start
PlayTimeConfig.Tiers = {
	{ MinSeconds = 0,    Multiplier = 1  },
	{ MinSeconds = 1200, Multiplier = 2  }, -- 20 min
	{ MinSeconds = 2400, Multiplier = 5  }, -- 40 min
	{ MinSeconds = 3600, Multiplier = 10 }, -- 60 min
}

function PlayTimeConfig.getMultiplier(elapsedSeconds: number): number
	local result = 1
	for _, tier in PlayTimeConfig.Tiers do
		if elapsedSeconds >= tier.MinSeconds then
			result = tier.Multiplier
		end
	end
	return result
end

-- Returns 0–1 GLOBAL fill ratio across the whole bar. Cada tramo entre tiers ocupa
-- una parte igual de la barra (con 4 tiers → 3 tramos → 33% cada uno), de modo que
-- el fill llega a cada marcador (x2, x5, x10) justo al cumplirse su MinSeconds.
-- Antes devolvía el progreso DENTRO del tramo actual, así que la barra entera se
-- llenaba con el primer tier y el x2 se alcanzaba mucho antes de tiempo.
function PlayTimeConfig.getProgress(elapsedSeconds: number): number
	local segments = #PlayTimeConfig.Tiers - 1
	if segments <= 0 then
		return 1
	end
	for i, tier in PlayTimeConfig.Tiers do
		local next = PlayTimeConfig.Tiers[i + 1]
		if not next then
			return 1
		end
		if elapsedSeconds < next.MinSeconds then
			local within = (elapsedSeconds - tier.MinSeconds) / (next.MinSeconds - tier.MinSeconds)
			return ((i - 1) + within) / segments
		end
	end
	return 1
end

return PlayTimeConfig
