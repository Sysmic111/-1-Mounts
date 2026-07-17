--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local StarterPackConfig = require(ReplicatedStorage.Shared.StarterPackConfig)

type DataServiceServer = {
	waitForData: (self: DataServiceServer, player: Player) -> any,
	hasProfile:  (self: DataServiceServer, player: Player) -> boolean,
	get:         (self: DataServiceServer, player: Player, path: { string }) -> any,
	set:         (self: DataServiceServer, player: Player, path: { string }, value: any, dontReplicate: boolean?) -> (),
}

type RobuxServiceLike = {
	registerProduct: (self: any, productId: number, handler: (player: Player, receiptInfo: any) -> Enum.ProductPurchaseDecision) -> (),
}

local StarterPackService = {
	_dataService = nil :: DataServiceServer?,
}

-- Concede el pack. Idempotente: Roblox reintenta los recibos, y sin el guard de
-- StarterPackBought un reintento regalaría las recompensas dos veces.
function StarterPackService:_grant(player: Player): Enum.ProductPurchaseDecision
	local ds = self._dataService
	if not ds or not ds:hasProfile(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if ds:get(player, { "StarterPackBought" }) == true then
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	-- Marcar primero: si fallara algo al acreditar, el jugador pierde el pack pero
	-- nunca se le cobra dos veces ni se le duplican las recompensas.
	ds:set(player, { "StarterPackBought" }, true)

	local wins = (ds:get(player, { "WinCurrency" }) or 0) :: number
	ds:set(player, { "WinCurrency" }, wins + StarterPackConfig.Wins)

	-- El Speed va crudo a SpeedCurrency, igual que los premios del Daily: el
	-- level-up lo resuelve SpeedService:_addSpeed en el siguiente paquete de
	-- movimiento (décimas de segundo después).
	local speed = (ds:get(player, { "SpeedCurrency" }) or 0) :: number
	ds:set(player, { "SpeedCurrency" }, speed + StarterPackConfig.Speed)

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function StarterPackService:init(dataService: DataServiceServer, robuxService: RobuxServiceLike): ()
	self._dataService = dataService

	robuxService:registerProduct(StarterPackConfig.ProductId, function(player, _receiptInfo)
		return self:_grant(player)
	end)
end

return StarterPackService
