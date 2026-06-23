--!strict

local Players            = game:GetService("Players")
local MarketplaceService = game:GetService("MarketplaceService")

local RobuxConfig = require(game.ReplicatedStorage.Shared.RobuxConfig)

type DataServiceServer = {
	waitForData: (self: DataServiceServer, player: Player) -> any,
	hasProfile:  (self: DataServiceServer, player: Player) -> boolean,
	get:         (self: DataServiceServer, player: Player, path: { string }) -> any,
	set:         (self: DataServiceServer, player: Player, path: { string }, value: any, dontReplicate: boolean?) -> (),
}

local RobuxService = {
	_dataService = nil :: DataServiceServer?,
}

function RobuxService:init(dataService: DataServiceServer): ()
	self._dataService = dataService

	-- ProcessReceipt must be set exactly once; it's the only server-authoritative
	-- path for granting paid access. Never trust client claims.
	MarketplaceService.ProcessReceipt = function(receiptInfo)
		return self:_processReceipt(receiptInfo)
	end
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

	local tier = RobuxConfig.ProductToTier[productId]
	if not tier then
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

	-- Grant access (idempotent — safe to re-run on duplicate receipts)
	local key = RobuxConfig.treadmillKey(tier)
	if ds:get(player, { key }) ~= true then
		ds:set(player, { key }, true)
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

return RobuxService
