--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local MountsConfig = require(ReplicatedStorage.Shared.MountsConfig)

type DataServiceServer = {
	waitForData: (self: DataServiceServer, player: Player) -> any,
	hasProfile:  (self: DataServiceServer, player: Player) -> boolean,
	get:         (self: DataServiceServer, player: Player, path: { string }) -> any,
	set:         (self: DataServiceServer, player: Player, path: { string }, value: any, dontReplicate: boolean?) -> (),
}

type RobuxServiceLike = {
	registerProduct: (self: any, productId: number, handler: (player: Player, receiptInfo: any) -> Enum.ProductPurchaseDecision) -> (),
}

local PremiumMountsService = {
	_dataService = nil :: DataServiceServer?,
}

-- Concede la propiedad de una montura Premium. Idempotente: seguro ante recibos
-- duplicados que Roblox reintenta.
function PremiumMountsService:_grantMount(player: Player, mountName: string): Enum.ProductPurchaseDecision
	local ds = self._dataService
	if not ds or not ds:hasProfile(player) then
		return Enum.ProductPurchaseDecision.NotProcessedYet
	end

	if ds:get(player, { "Mounts", mountName }) ~= true then
		ds:set(player, { "Mounts", mountName }, true)
	end

	return Enum.ProductPurchaseDecision.PurchaseGranted
end

function PremiumMountsService:init(dataService: DataServiceServer, robuxService: RobuxServiceLike): ()
	self._dataService = dataService

	-- Registrar cada Developer Product Premium en el router de recibos (RobuxService
	-- es dueño único de ProcessReceipt). El handler corre con el perfil ya cargado.
	for _, mount in MountsConfig.Premium do
		local productId = mount.ProductId
		if not productId then continue end
		local mountName = mount.Name
		robuxService:registerProduct(productId, function(player, _receiptInfo)
			return self:_grantMount(player, mountName)
		end)
	end
end

return PremiumMountsService
