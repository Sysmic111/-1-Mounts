--!strict

local HatsData = require(game.ReplicatedStorage.Shared.HatsData)
local Packets  = require(game.ReplicatedStorage.Shared.Packets)

type DataServiceServer = {
	waitForData: (self: DataServiceServer, player: Player) -> any,
	hasProfile: (self: DataServiceServer, player: Player) -> boolean,
	get: (self: DataServiceServer, player: Player, path: any?) -> any,
	set: (self: DataServiceServer, player: Player, path: any, value: any, dontReplicate: boolean?) -> (),
}

local HatsService = {
	_dataService  = nil :: DataServiceServer?,
	_speedService = nil :: any,
	_morphService = nil :: any,
}

function HatsService:setSpeedService(speedService: any): ()
	self._speedService = speedService
end

function HatsService:setMorphService(morphService: any): ()
	self._morphService = morphService
end

function HatsService:_applyHat(player: Player): ()
	if self._morphService then
		self._morphService.ApplyHat(player)
	end
end

function HatsService:init(dataService: DataServiceServer): ()
	self._dataService = dataService

	Packets.BuyHat.OnServerEvent:Connect(function(player: Player, hatName: string)
		if type(hatName) ~= "string" then return end
		self:_handleBuy(player, hatName)
	end)

	Packets.EquipHat.OnServerEvent:Connect(function(player: Player, hatName: string)
		if type(hatName) ~= "string" then return end
		self:_handleEquip(player, hatName)
	end)
end

-- Multiplicador del hat equipado (1 si no hay ninguno). Lo consume SpeedService.
function HatsService:GetMultiplier(player: Player): number
	local dataService = self._dataService
	if not dataService or not dataService:hasProfile(player) then return 1 end

	local hatName = dataService:get(player, { "EquippedHat" }) :: string?
	if not hatName or hatName == "" then return 1 end

	local hatData = HatsData.getHatData(hatName)
	if not hatData then return 1 end

	return hatData.Multiplier
end

function HatsService:_recalcMultiplier(player: Player): ()
	if self._speedService then
		self._speedService:updateTotalMultiplier(player)
	end
end

function HatsService:_handleBuy(player: Player, hatName: string): ()
	local dataService = self._dataService
	if not dataService or not dataService:hasProfile(player) then return end

	local hatData = HatsData.getHatData(hatName)
	if not hatData then
		Packets.BuyHatResult:FireClient(player, false, "That hat does not exist.")
		return
	end

	local owned = dataService:get(player, { "Hats", hatName })
	if owned then
		Packets.BuyHatResult:FireClient(player, false, "You already own this hat.")
		return
	end

	local wins = (dataService:get(player, { "WinCurrency" }) or 0) :: number
	if wins < hatData.Price then
		Packets.BuyHatResult:FireClient(player, false, "You need " .. hatData.Price .. " Wins (you have " .. wins .. ").")
		return
	end

	dataService:set(player, { "WinCurrency" }, wins - hatData.Price)
	dataService:set(player, { "Hats", hatName }, true)

	-- La primera compra equipa automáticamente
	local equipped = dataService:get(player, { "EquippedHat" }) :: string?
	if not equipped or equipped == "" then
		dataService:set(player, { "EquippedHat" }, hatName)
		self:_recalcMultiplier(player)
		self:_applyHat(player)
	end

	Packets.BuyHatResult:FireClient(player, true, "")
end

function HatsService:_handleEquip(player: Player, hatName: string): ()
	local dataService = self._dataService
	if not dataService or not dataService:hasProfile(player) then return end

	-- Quitar el hat (opción "Remove" del menú)
	if hatName == "None" or hatName == "" then
		dataService:set(player, { "EquippedHat" }, "")
		self:_recalcMultiplier(player)
		self:_applyHat(player)
		Packets.EquipHatResult:FireClient(player, true, "")
		return
	end

	local owned = dataService:get(player, { "Hats", hatName })
	if not owned then
		Packets.EquipHatResult:FireClient(player, false, "You don't own this hat.")
		return
	end

	dataService:set(player, { "EquippedHat" }, hatName)
	self:_recalcMultiplier(player)
	self:_applyHat(player)
	Packets.EquipHatResult:FireClient(player, true, "")
end

return HatsService
