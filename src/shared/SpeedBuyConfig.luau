--!strict

-- Botones "+X Speed" del panel inferior (Bot): compran Speed CRUDO con Robux.
-- Se otorga vía SpeedService:GrantSpeed, que resuelve los level-ups al instante.
--
-- OJO (balance): una cantidad fija de Speed vale muchísimo temprano y NADA tarde
-- en la curva exponencial. Están pensados como boosters de arranque; pasado el
-- nivel ~50 dejan de comprar ni un nivel. Por eso el precio es de compra
-- impulsiva (15-99 Robux) y no escala con la cantidad. El botón (ButtonName) es
-- el nombre de la instancia dentro de Workspace/StarterGui.Bot.Content.Buttons.

export type SpeedBuyData = {
	ButtonName: string,
	ProductId: number,
	Amount: number,
}

local SpeedBuyConfig = {}

SpeedBuyConfig.Products = {
	{ ButtonName = "100k", ProductId = 3610533444, Amount = 100_000     },
	{ ButtonName = "1M",   ProductId = 3610533494, Amount = 1_000_000   },
	{ ButtonName = "10M",  ProductId = 3610533514, Amount = 10_000_000  },
	{ ButtonName = "100M", ProductId = 3610533535, Amount = 100_000_000 },
} :: { SpeedBuyData }

function SpeedBuyConfig.getByProductId(productId: number): SpeedBuyData?
	for _, data in SpeedBuyConfig.Products do
		if data.ProductId == productId then return data end
	end
	return nil
end

return SpeedBuyConfig
