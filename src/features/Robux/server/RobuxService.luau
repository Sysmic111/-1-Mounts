--!strict

local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local RobuxConfig = require(game.ReplicatedStorage.Shared.RobuxConfig)
local FunnelService = require(game.ServerScriptService.Analytics.FunnelService)

type DataServiceServer = {
	waitForData: (self: DataServiceServer, player: Player) -> any,
	hasProfile:  (self: DataServiceServer, player: Player) -> boolean,
	get:         (self: DataServiceServer, player: Player, path: { string }) -> any,
	set:         (self: DataServiceServer, player: Player, path: { string }, value: any, dontReplicate: boolean?) -> (),
}

type ReceiptHandler = (player: Player, receiptInfo: any) -> Enum.ProductPurchaseDecision

local RobuxService = {
	_dataService = nil :: DataServiceServer?,
	-- Otros features registran aquí sus Developer Products (productId → handler).
	-- ProcessReceipt es único en el juego, así que RobuxService actúa como router.
	_productHandlers = {} :: { [number]: ReceiptHandler },
}

function RobuxService:init(dataService: DataServiceServer): ()
	self._dataService = dataService

	-- ProcessReceipt must be set exactly once; it's the only server-authoritative
	-- path for granting paid access. Never trust client claims.
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		return self:_processReceipt(receiptInfo)
	end
end

-- Permite que otros services manejen sus propios Developer Products sin pelear
-- por ProcessReceipt. El handler corre con el perfil del jugador ya cargado.
function RobuxService:registerProduct(productId: number, handler: ReceiptHandler): ()
	self._productHandlers[productId] = handler
end

-- Returns true only if DataStore confirms the player owns this tier.
function RobuxService:hasTreadmill(player: Player, tier: string): boolean
	local ds = self._dataService
	if not ds or not ds:hasProfile(player) then return false end
	return ds:get(player, { RobuxConfig.treadmillKey(tier) }) == true
end

function RobuxService:_processReceipt(receiptInfo: any): Enum.ProductPurchaseDecision
	local productId = receiptInfo.ProductId
	local playerId  = receiptInfo.PlayerId

	local tier    = RobuxConfig.ProductToTier[productId]
	local handler = self._productHandlers[productId]
	if not tier and not handler then
		-- Unknown product — grant immediately so the player isn't stuck
		return Enum.ProductPurchaseDecision.PurchaseGranted
	end

	local player = Players:GetPlayerByUserId(playerId)
	if not player then
		-- Player left mid-purchase; Roblox will retry when they rejoin
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	local ds = self._dataService
	if not ds then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Wait for DataStore profile to be ready (safe to yield inside ProcessReceipt)
	if not ds:hasProfile(player) then
		ds:waitForData(player)
	end
	if not ds:hasProfile(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	-- Developer Products registrados por otros features (ej. monturas Premium)
	if handler then
		local decision = handler(player, receiptInfo)
		if decision == Enum.ProductPurchaseDecision.PurchaseGranted then
			FunnelService:onReceiptGranted(player, productId)
		end
		return decision
	end

	-- Grant access (idempotent — safe to re-run on duplicate receipts)
	local key = RobuxConfig.treadmillKey(tier :: string)
	if ds:get(player, { key }) ~= true then
		ds:set(player, { key }, true)
	end

	FunnelService:onReceiptGranted(player, productId)
	return Enum.ProductPurchaseDecision.PurchaseGranted
end

return RobuxService
