--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local SpeedBoostConfig = require(ReplicatedStorage.Shared.SpeedBoostConfig)

type DataServiceServer = {
	waitForData: (self: DataServiceServer, player: Player) -> any,
	hasProfile:  (self: DataServiceServer, player: Player) -> boolean,
	get:         (self: DataServiceServer, player: Player, path: { string }) -> any,
	set:         (self: DataServiceServer, player: Player, path: { string }, value: any, dontReplicate: boolean?) -> (),
}

type RobuxServiceLike = {
	registerProduct: (self: any, productId: number, handler: (player: Player, receiptInfo: any) -> Enum.ProductPurchaseDecision) -> (),
}

local SpeedBoostService = {
	_dataService  = nil :: DataServiceServer?,
	_speedService = nil :: any,
}

-- Concede un tier. El multiplicador es absoluto, así que solo sube el tier si el
-- comprado es mayor que el actual (comprar uno inferior no debería bajarlo, y un
-- recibo reintentado es idempotente).
function SpeedBoostService:_grant(player: Player, tier: number): Enum.ProductPurchaseDecision
	local ds = self._dataService
	if not ds or not ds:hasProfile(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local current = (ds:get(player, { "SpeedTier" }) or 0) :: number
	if tier > current then
		ds:set(player, { "SpeedTier" }, tier)
		if self._speedService then
			self._speedService:updateTotalMultiplier(player)
		end
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function SpeedBoostService:init(dataService: DataServiceServer, robuxService: RobuxServiceLike, speedService: any): ()
	self._dataService  = dataService
	self._speedService = speedService

	for _, data in SpeedBoostConfig.Tiers do
		local tier = data.Tier
		robuxService:registerProduct(data.ProductId, function(player, _receiptInfo)
			return self:_grant(player, tier)
		end)
	end
end

return SpeedBoostService
