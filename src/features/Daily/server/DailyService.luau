--!strict

local ReplicatedStorage = game:GetService("ReplicatedStorage")

local DailyConfig = require(ReplicatedStorage.Shared.DailyConfig)
local Packets     = require(ReplicatedStorage.Shared.Packets)
local FunnelService = require(game.ServerScriptService.Server.FunnelService)

type DataServiceServer = {
	waitForData: (self: DataServiceServer, player: Player) -> any,
	hasProfile: (self: DataServiceServer, player: Player) -> boolean,
	get: (self: DataServiceServer, player: Player, path: any?) -> any,
	set: (self: DataServiceServer, player: Player, path: any, value: any, dontReplicate: boolean?) -> (),
}

local DailyService = {
	_dataService = nil :: DataServiceServer?,
}

function DailyService:init(dataService: DataServiceServer): ()
	self._dataService = dataService

	Packets.ClaimDaily.OnServerEvent:Connect(function(player: Player)
		self:_handleClaim(player)
	end)
end

-- El servidor es la única fuente de verdad del calendario: el cliente solo pide
-- "reclamar", nunca dice qué día es ni qué premio quiere.
function DailyService:_handleClaim(player: Player): ()
	local ds = self._dataService
	if not ds or not ds:hasProfile(player) then
		Packets.ClaimDailyResult:FireClient(player, false, 0, "Data not loaded yet")
		return
	end

	local today         = DailyConfig.getDayNumber(os.time())
	local lastClaimDate = (ds:get(player, { "DailyLastClaimDate" }) or 0) :: number

	if lastClaimDate >= today then
		Packets.ClaimDailyResult:FireClient(player, false, 0, "Already claimed today")
		return
	end

	local lastClaimedDay = (ds:get(player, { "DailyClaimedDay" }) or 0) :: number
	local day    = DailyConfig.getNextDay(lastClaimedDay)
	local reward = DailyConfig.getReward(day)
	if not reward then
		Packets.ClaimDailyResult:FireClient(player, false, 0, "Reward not available")
		return
	end

	-- Marcar el claim ANTES de dar el premio: si algo falla al otorgar, el jugador
	-- pierde ese premio pero nunca puede reclamar dos veces el mismo día.
	ds:set(player, { "DailyClaimedDay" }, day)
	ds:set(player, { "DailyLastClaimDate" }, today)
	FunnelService:onDailyClaimed(player, day)

	self:_grantReward(player, reward)

	Packets.ClaimDailyResult:FireClient(player, true, day, DailyConfig.getRewardLabel(day))
end

function DailyService:_grantReward(player: Player, reward: DailyConfig.DayReward): ()
	local ds = self._dataService
	if not ds then return end

	if reward.Kind == "Wins" then
		local current = (ds:get(player, { "WinCurrency" }) or 0) :: number
		ds:set(player, { "WinCurrency" }, current + (reward.Amount or 0))

	elseif reward.Kind == "Speed" then
		local current = (ds:get(player, { "SpeedCurrency" }) or 0) :: number
		ds:set(player, { "SpeedCurrency" }, current + (reward.Amount or 0))

	elseif reward.Kind == "Mount" then
		-- Días 7/14/21: pendientes de las 3 monturas nuevas. Con MountName vacío
		-- el claim avanza la racha sin otorgar nada.
		local mountName = reward.MountName
		if mountName and mountName ~= "" then
			if ds:get(player, { "Mounts", mountName }) ~= true then
				ds:set(player, { "Mounts", mountName }, true)
			end
		end
	end
end

return DailyService
