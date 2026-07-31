--!strict

-- Bonus de jugador nuevo: quedarse DurationSeconds SEGUIDOS en una sesión regala
-- una montura Premium. Ver NewPlayerBonusConfig para la intención del diseño.
--
-- El reloj no se persiste a propósito: vive en `_readyTimes` y muere con la sesión.
-- Lo que sí se guarda son las dos cosas que tienen que sobrevivir a la reconexión:
-- cuántas sesiones se ha ofrecido ya (`NewPlayerBonusSessions`) y si se reclamó
-- (`NewPlayerBonusClaimed`).
--
-- No hace falta task.delay para "activar" el claim: el instante de vencimiento es
-- un os.time() absoluto que el cliente pinta solo y el servidor revalida al recibir
-- el claim. Un timer programado sería una segunda fuente de verdad que se puede
-- desincronizar; el instante absoluto no.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local Packets               = require(ReplicatedStorage.Shared.Packets)
local MountsConfig          = require(ReplicatedStorage.Shared.MountsConfig)
local NewPlayerBonusConfig  = require(ReplicatedStorage.Shared.NewPlayerBonusConfig)

type DataServiceServer = {
	waitForData: (self: DataServiceServer, player: Player) -> any,
	hasProfile:  (self: DataServiceServer, player: Player) -> boolean,
	get:         (self: DataServiceServer, player: Player, path: { string }) -> any,
	set:         (self: DataServiceServer, player: Player, path: { string }, value: any, dontReplicate: boolean?) -> (),
}

-- Margen para el desfase de reloj cliente/servidor. Ambos usan os.time() (epoch
-- Unix), así que la diferencia es de milisegundos, pero sin esto un cliente un
-- segundo adelantado vería "Claim" y se comería un rechazo con el botón muerto.
local CLAIM_GRACE_SECONDS = 2

local NewPlayerBonusService = {
	-- os.time() absoluto en que el bonus pasa a ser reclamable, por jugador. Solo
	-- existe mientras la oferta está viva en ESTA sesión.
	_readyTimes  = {} :: { [Player]: number },
	_dataService = nil :: DataServiceServer?,
}

local function isPremiumMount(mountName: string): boolean
	for _, mount in MountsConfig.Premium do
		if mount.Name == mountName then return true end
	end
	return false
end

function NewPlayerBonusService:_hide(player: Player): ()
	self._readyTimes[player] = nil
	Packets.NewPlayerBonusState:FireClient(player, false, 0)
end

-- Decide si este jugador ve la oferta y arranca su reloj de sesión.
function NewPlayerBonusService:_offer(player: Player): ()
	local ds = self._dataService
	if not ds then return end

	ds:waitForData(player)
	-- waitForData yield: el jugador puede haberse ido mientras cargaba el perfil.
	if not player:IsDescendantOf(Players) or not ds:hasProfile(player) then return end

	if ds:get(player, { "NewPlayerBonusClaimed" }) == true then return end

	local sessions = (ds:get(player, { "NewPlayerBonusSessions" }) or 0) :: number
	if sessions >= NewPlayerBonusConfig.MaxSessions then return end

	-- Ya la tiene comprada con Robux: regalársela no haría nada y el botón sería
	-- una promesa vacía. Se marca la oferta como agotada para no reevaluar nunca más.
	if ds:get(player, { "Mounts", NewPlayerBonusConfig.MountName }) == true then
		ds:set(player, { "NewPlayerBonusSessions" }, NewPlayerBonusConfig.MaxSessions)
		return
	end

	-- Corte de veteranos: jugadores que ya llevaban muchas sesiones antes de que
	-- esta feature existiera y tienen NewPlayerBonusSessions en 0. TimesJoined lo
	-- incrementa GroupBonusService en paralelo a esto, así que puede leerse con ±1
	-- de desfase; da igual, nadie con 4+ entradas es un jugador nuevo.
	local timesJoined = (ds:get(player, { "TimesJoined" }) or 0) :: number
	if timesJoined > NewPlayerBonusConfig.MaxSessions then
		ds:set(player, { "NewPlayerBonusSessions" }, NewPlayerBonusConfig.MaxSessions)
		return
	end

	-- Consumir el intento AL MOSTRARLO, no al fallarlo: si se contara al salir,
	-- un crash del server regalaría intentos infinitos.
	ds:set(player, { "NewPlayerBonusSessions" }, sessions + 1)

	local readyTime = os.time() + NewPlayerBonusConfig.DurationSeconds
	self._readyTimes[player] = readyTime
	Packets.NewPlayerBonusState:FireClient(player, true, readyTime)
end

function NewPlayerBonusService:_handleClaim(player: Player): ()
	local ds = self._dataService
	if not ds or not ds:hasProfile(player) then
		Packets.NewPlayerBonusResult:FireClient(player, false, "Data not loaded yet")
		return
	end

	local readyTime = self._readyTimes[player]
	if not readyTime then
		Packets.NewPlayerBonusResult:FireClient(player, false, "Offer not available")
		return
	end

	if os.time() + CLAIM_GRACE_SECONDS < readyTime then
		Packets.NewPlayerBonusResult:FireClient(player, false, "Not ready yet")
		return
	end

	-- Idempotente: dos clicks seguidos (o un cliente spameando el packet) no pueden
	-- hacer nada dos veces porque el flag se comprueba aquí y _hide borra el reloj.
	if ds:get(player, { "NewPlayerBonusClaimed" }) == true then
		self:_hide(player)
		return
	end

	local mountName = NewPlayerBonusConfig.MountName
	ds:set(player, { "Mounts", mountName }, true)
	ds:set(player, { "NewPlayerBonusClaimed" }, true)

	self:_hide(player)
	Packets.NewPlayerBonusResult:FireClient(player, true, mountName)
end

function NewPlayerBonusService:init(dataService: DataServiceServer): ()
	self._dataService = dataService

	-- Un nombre mal escrito en el config dejaría la oferta concediendo una montura
	-- que el Index no conoce. Mejor enterarse al arrancar que por un reporte.
	if not isPremiumMount(NewPlayerBonusConfig.MountName) then
		warn(("[NewPlayerBonus] '%s' no está en MountsConfig.Premium; la oferta queda desactivada")
			:format(NewPlayerBonusConfig.MountName))
		return
	end

	Packets.NewPlayerBonusClaim.OnServerEvent:Connect(function(player: Player)
		self:_handleClaim(player)
	end)

	Players.PlayerAdded:Connect(function(player)
		task.spawn(function()
			self:_offer(player)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self._readyTimes[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		task.spawn(function()
			self:_offer(player)
		end)
	end
end

return NewPlayerBonusService
