--!strict

local TrailsData = require(game.ReplicatedStorage.Shared.TrailsData)
local Packets    = require(game.ReplicatedStorage.Shared.Packets)
local FormatNumber = require(game.ReplicatedStorage.Packages.FormatNumber)

type DataServiceServer = {
	waitForData: (self: DataServiceServer, player: Player) -> any,
	hasProfile: (self: DataServiceServer, player: Player) -> boolean,
	get: (self: DataServiceServer, player: Player, path: any?) -> any,
	set: (self: DataServiceServer, player: Player, path: any, value: any, dontReplicate: boolean?) -> (),
}

local TrailsService = {
	_dataService  = nil :: DataServiceServer?,
	_speedService = nil :: any,
	_morphService = nil :: any,
}

function TrailsService:setSpeedService(speedService: any): ()
	self._speedService = speedService
end

function TrailsService:setMorphService(morphService: any): ()
	self._morphService = morphService
end

function TrailsService:_applyTrail(player: Player): ()
	if self._morphService then
		self._morphService.ApplyTrail(player)
	end
end

function TrailsService:init(dataService: DataServiceServer): ()
	self._dataService = dataService

	Packets.BuyTrail.OnServerEvent:Connect(function(player: Player, trailName: string)
		if type(trailName) ~= "string" then return end
		self:_handleBuy(player, trailName)
	end)

	Packets.EquipTrail.OnServerEvent:Connect(function(player: Player, trailName: string)
		if type(trailName) ~= "string" then return end
		self:_handleEquip(player, trailName)
	end)
end

-- Multiplicador del trail equipado (1 si no hay ninguno). Lo consume SpeedService.
function TrailsService:GetMultiplier(player: Player): number
	local dataService = self._dataService
	if not dataService or not dataService:hasProfile(player) then return 1 end

	local trailName = dataService:get(player, { "EquippedTrail" }) :: string?
	if not trailName or trailName == "" then return 1 end

	local trailData = TrailsData.getTrailData(trailName)
	if not trailData then return 1 end

	return trailData.Multiplier
end

function TrailsService:_recalcMultiplier(player: Player): ()
	if self._speedService then
		self._speedService:updateTotalMultiplier(player)
	end
end

function TrailsService:_handleBuy(player: Player, trailName: string): ()
	local dataService = self._dataService
	if not dataService or not dataService:hasProfile(player) then return end

	local trailData = TrailsData.getTrailData(trailName)
	if not trailData then
		Packets.BuyTrailResult:FireClient(player, false, "That trail does not exist.")
		return
	end

	local owned = dataService:get(player, { "Trails", trailName })
	if owned then
		Packets.BuyTrailResult:FireClient(player, false, "You already own this trail.")
		return
	end

	local wins = (dataService:get(player, { "WinCurrency" }) or 0) :: number
	if wins < trailData.Price then
		Packets.BuyTrailResult:FireClient(player, false,
			"You need " .. FormatNumber:formatNumberCoins(trailData.Price)
			.. " Wins (you have " .. FormatNumber:formatNumberCoins(wins) .. ").")
		return
	end

	dataService:set(player, { "WinCurrency" }, wins - trailData.Price)
	dataService:set(player, { "Trails", trailName }, true)

	-- La primera compra equipa automáticamente
	local equipped = dataService:get(player, { "EquippedTrail" }) :: string?
	if not equipped or equipped == "" then
		dataService:set(player, { "EquippedTrail" }, trailName)
		self:_recalcMultiplier(player)
		self:_applyTrail(player)
	end

	Packets.BuyTrailResult:FireClient(player, true, "")
end

function TrailsService:_handleEquip(player: Player, trailName: string): ()
	local dataService = self._dataService
	if not dataService or not dataService:hasProfile(player) then return end

	-- Quitar el trail (opción "Remove" del menú)
	if trailName == "None" or trailName == "" then
		dataService:set(player, { "EquippedTrail" }, "")
		self:_recalcMultiplier(player)
		self:_applyTrail(player)
		Packets.EquipTrailResult:FireClient(player, true, "")
		return
	end

	local owned = dataService:get(player, { "Trails", trailName })
	if not owned then
		Packets.EquipTrailResult:FireClient(player, false, "You don't own this trail.")
		return
	end

	dataService:set(player, { "EquippedTrail" }, trailName)
	self:_recalcMultiplier(player)
	self:_applyTrail(player)
	Packets.EquipTrailResult:FireClient(player, true, "")
end

return TrailsService
