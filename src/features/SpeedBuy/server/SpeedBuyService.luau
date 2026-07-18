--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpeedBuyConfig = require(ReplicatedStorage.Shared.SpeedBuyConfig)

type DataServiceServer = {
	hasProfile: (self: DataServiceServer, player: Player) -> boolean,
}

type RobuxServiceLike = {
	registerProduct: (self: any, productId: number, handler: (player: Player, receiptInfo: any) -> Enum.ProductPurchaseDecision) -> (),
}

local SpeedBuyService = {
	_dataService  = nil :: DataServiceServer?,
	_speedService = nil :: any,
}

function SpeedBuyService:init(dataService: DataServiceServer, robuxService: RobuxServiceLike, speedService: any): ()
	self._dataService  = dataService
	self._speedService = speedService

	-- Consumibles: cada compra otorga su cantidad de Speed. Se concede en el
	-- recibo, y como se devuelve PurchaseGranted, Roblox no reintenta (no hay
	-- riesgo de doble concesión por reintento).
	for _, data in SpeedBuyConfig.Products do
		local amount = data.Amount
		robuxService:registerProduct(data.ProductId, function(player, _receiptInfo)
			if not dataService:hasProfile(player) then
				return Enum.ProductPurchaseDecision.NotProcessedYet
			end
			if self._speedService then
				self._speedService:GrantSpeed(player, amount)
			end
			return Enum.ProductPurchaseDecision.PurchaseGranted
		end)
	end
end

return SpeedBuyService
