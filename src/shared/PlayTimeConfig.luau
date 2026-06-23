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

-- Returns 0–1 fill ratio within the current tier segment
function PlayTimeConfig.getProgress(elapsedSeconds: number): number
	for i, tier in PlayTimeConfig.Tiers do
		local next = PlayTimeConfig.Tiers[i + 1]
		if not next then
			return 1
		end
		if elapsedSeconds < next.MinSeconds then
			return (elapsedSeconds - tier.MinSeconds) / (next.MinSeconds - tier.MinSeconds)
		end
	end
	return 1
end

return PlayTimeConfig
