--!strict

-- Group bonus: premia con un multiplicador permanente (+x10 aditivo) a quien pertenece
-- al grupo de Roblox y ha reconectado al menos una vez (proxy de "dio like al juego").
--
-- Flujo del botón Verify (cliente → Packets.VerifyGroupBonus → aquí):
--   * ya reclamado           → "AlreadyClaimed"
--   * no es del grupo        → "NotInGroup"   (el cliente lanza PromptJoinAsync)
--   * del grupo, 1ª sesión   → "NeedLikeRejoin" (el cliente muestra el error)
--   * del grupo, 2ª sesión+  → concede el bonus y responde "Granted"
--
-- El flag GroupBonusClaimed lo lee SpeedService:_updateTotalMultiplier como fuente
-- aditiva; aquí solo lo marcamos y pedimos recalcular.

local Players = game:GetService("Players")

local Packets          = require(game.ReplicatedStorage.Shared.Packets)
local GroupBonusConfig = require(game.ReplicatedStorage.Shared.GroupBonusConfig)

type DataServiceServer = {
	waitForData: (self: DataServiceServer, player: Player) -> any,
	hasProfile: (self: DataServiceServer, player: Player) -> boolean,
	get: (self: DataServiceServer, player: Player, path: any?) -> any,
	set: (self: DataServiceServer, player: Player, path: any, value: any, dontReplicate: boolean?) -> (),
}

local GroupBonusService = {
	_dataService  = nil :: DataServiceServer?,
	_speedService = nil :: any,
}

function GroupBonusService:setSpeedService(speedService: any): ()
	self._speedService = speedService
end

-- Incrementa el contador de por vida de entradas. Se llama una vez por sesión, tras
-- cargar el perfil. La 1ª entrada de la vida del jugador deja TimesJoined = 1.
function GroupBonusService:_countJoin(player: Player): ()
	local dataService = self._dataService
	if not dataService then return end

	dataService:waitForData(player)
	if not player:IsDescendantOf(Players) or not dataService:hasProfile(player) then
		return
	end

	local previous = (dataService:get(player, { "TimesJoined" }) or 0) :: number
	dataService:set(player, { "TimesJoined" }, previous + 1)
end

-- Comprueba pertenencia al grupo. Es una llamada web que yield y tiene rate limit,
-- así que se envuelve en pcall (igual que FriendsBoostService con IsFriendsWith).
local function isInGroup(player: Player): boolean
	local ok, result = pcall(function()
		return player:IsInGroup(GroupBonusConfig.GroupId)
	end)
	return (ok and result) or false
end

function GroupBonusService:_handleVerify(player: Player): ()
	local dataService = self._dataService
	if not dataService or not dataService:hasProfile(player) then
		return
	end

	-- Idempotente: si ya lo tiene, no revalidamos ni re-concedemos.
	if dataService:get(player, { "GroupBonusClaimed" }) == true then
		Packets.GroupBonusResult:FireClient(player, "AlreadyClaimed")
		return
	end

	if not isInGroup(player) then
		Packets.GroupBonusResult:FireClient(player, "NotInGroup")
		return
	end

	-- No hay API para saber si dio "like"; se aproxima exigiendo una reconexión:
	-- solo se puede likear tras jugar un rato, así que a la 2ª sesión ya pudo hacerlo.
	local timesJoined = (dataService:get(player, { "TimesJoined" }) or 0) :: number
	if timesJoined < 2 then
		Packets.GroupBonusResult:FireClient(player, "NeedLikeRejoin")
		return
	end

	-- Marcar ANTES de conceder (patrón idempotente de StarterPackBought), luego recalcular.
	dataService:set(player, { "GroupBonusClaimed" }, true)
	if self._speedService then
		self._speedService:updateTotalMultiplier(player)
	end
	Packets.GroupBonusResult:FireClient(player, "Granted")
end

function GroupBonusService:init(dataService: DataServiceServer): ()
	self._dataService = dataService

	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			self:_countJoin(player)
		end)
	end)
	for _, player in Players:GetPlayers() do
		task.spawn(function()
			self:_countJoin(player)
		end)
	end

	Packets.VerifyGroupBonus.OnServerEvent:Connect(function(player: Player)
		self:_handleVerify(player)
	end)
end

return GroupBonusService
