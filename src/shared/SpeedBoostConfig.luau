--!strict

-- Speed Tiers: multiplicador permanente de ganancia de Speed comprado con Robux.
-- Cada tier es un Developer Product independiente. El multiplicador es ABSOLUTO
-- (comprar el tier 3 = x8, reemplaza al x4 del tier 2, no se acumula): se guarda
-- el tier más alto poseído en `SpeedTier` y el multiplicador es 2^tier.
--
-- El botón del panel Right muestra siempre el SIGUIENTE tier a comprar
-- (SpeedTier + 1). Al comprarlo, avanza al siguiente.
--
-- Los `Price` son el precio base (fallback): el cliente los pide en vivo a Roblox
-- con GetProductInfo para que sigan al dashboard. Roblox no expone el precio
-- regional del jugador antes del prompt, así que estos son el precio base.

export type TierData = {
	Tier: number,
	ProductId: number,
	Multiplier: number,
	Price: number,
}

local SpeedBoostConfig = {}

SpeedBoostConfig.Tiers = {
	{ Tier = 1,  ProductId = 3610520169, Multiplier = 2,    Price = 3    },
	{ Tier = 2,  ProductId = 3610520206, Multiplier = 4,    Price = 6    },
	{ Tier = 3,  ProductId = 3610520251, Multiplier = 8,    Price = 13   },
	{ Tier = 4,  ProductId = 3610520283, Multiplier = 16,   Price = 24   },
	{ Tier = 5,  ProductId = 3610520369, Multiplier = 32,   Price = 39   },
	{ Tier = 6,  ProductId = 3610520410, Multiplier = 64,   Price = 79   },
	{ Tier = 7,  ProductId = 3610520442, Multiplier = 128,  Price = 149  },
	{ Tier = 8,  ProductId = 3610520483, Multiplier = 256,  Price = 249  },
	{ Tier = 9,  ProductId = 3610520565, Multiplier = 512,  Price = 399  },
	{ Tier = 10, ProductId = 3610520592, Multiplier = 1024, Price = 629  },
	{ Tier = 11, ProductId = 3610520608, Multiplier = 2048, Price = 949  },
	{ Tier = 12, ProductId = 3610520656, Multiplier = 4096, Price = 1374 },
} :: { TierData }

SpeedBoostConfig.MaxTier = #SpeedBoostConfig.Tiers

function SpeedBoostConfig.getByTier(tier: number): TierData?
	return SpeedBoostConfig.Tiers[tier]
end

function SpeedBoostConfig.getByProductId(productId: number): TierData?
	for _, data in SpeedBoostConfig.Tiers do
		if data.ProductId == productId then return data end
	end
	return nil
end

-- Multiplicador del tier poseído (1 si no tiene ninguno).
function SpeedBoostConfig.getMultiplier(ownedTier: number): number
	if ownedTier <= 0 then return 1 end
	local data = SpeedBoostConfig.Tiers[math.min(ownedTier, SpeedBoostConfig.MaxTier)]
	return data and data.Multiplier or 1
end

return SpeedBoostConfig
