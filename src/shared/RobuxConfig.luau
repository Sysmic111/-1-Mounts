--!strict

export type TierConfig = {
	ProductId:  number,
	Multiplier: number,
}

local RobuxConfig = {}

RobuxConfig.Treadmills = {
	Gold    = { ProductId = 3606123151, Multiplier = 5   } :: TierConfig,
	Diamond = { ProductId = 3606123211, Multiplier = 10  } :: TierConfig,
	Emerald = { ProductId = 3606123312, Multiplier = 25  } :: TierConfig,
	Ruby    = { ProductId = 3606123460, Multiplier = 100 } :: TierConfig,
}

-- ProductId → tier name (for ProcessReceipt lookup)
RobuxConfig.ProductToTier = {
	[3606123151] = "Gold",
	[3606123211] = "Diamond",
	[3606123312] = "Emerald",
	[3606123460] = "Ruby",
}

-- DataStore key for a given tier
function RobuxConfig.treadmillKey(tier: string): string
	return "Treadmill" .. tier
end

return RobuxConfig
