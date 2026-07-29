--!strict

-- Dos relojes distintos a propósito, no confundirlos:
--
--   · playtime de SESIÓN (`_joinTimes`, os.clock) → alimenta el multiplicador por
--     tiers. Es en memoria y se resetea al reconectar: es la mecánica.
--   · playtime ACUMULADO (`TotalPlayTime` en la data, os.time) → estadística de por
--     vida, sobrevive a reconexiones.
--
-- El acumulado usa os.time (wall clock, segundos Unix) y no os.clock: os.clock mide
-- tiempo de proceso desde que arrancó el server, así que solo sirve para intervalos
-- dentro de una sesión.
--
-- Se acredita cada FLUSH_INTERVAL y otra vez al salir, en vez de solo al salir: si
-- el server se cae o el jugador crashea, PlayerRemoving puede no llegar a correr y
-- se perdería la sesión completa. Con el flush se pierde menos de un minuto.

local Players = game:GetService("Players")

local PlayTimeConfig = require(game.ReplicatedStorage.Shared.PlayTimeConfig)

type DataServiceServer = {
	hasProfile: (self: DataServiceServer, player: Player) -> boolean,
	get: (self: DataServiceServer, player: Player, path: any?) -> any,
	set: (self: DataServiceServer, player: Player, path: any, value: any, dontReplicate: boolean?) -> (),
}

local FLUSH_INTERVAL = 60

local PlayTimeService = {
	_joinTimes    = {} :: { [Player]: number },
	-- os.time del último tramo ya acreditado a TotalPlayTime. Es lo que evita contar
	-- dos veces el mismo tiempo entre el flush periódico y el de salida.
	_lastCredit   = {} :: { [Player]: number },
	_speedService = nil :: any,
	_dataService  = nil :: DataServiceServer?,
}

function PlayTimeService:setSpeedService(speedService: any): ()
	self._speedService = speedService
end

function PlayTimeService:getElapsed(player: Player): number
	local joinTime = self._joinTimes[player]
	if not joinTime then return 0 end
	return os.clock() - joinTime
end

function PlayTimeService:getMultiplier(player: Player): number
	return PlayTimeConfig.getMultiplier(self:getElapsed(player))
end

function PlayTimeService:_scheduleUpdates(player: Player): ()
	local joinTime = self._joinTimes[player]
	if not joinTime then return end

	for _, tier in PlayTimeConfig.Tiers do
		if tier.MinSeconds == 0 then continue end
		local delay = tier.MinSeconds - (os.clock() - joinTime)
		if delay > 0 then
			task.delay(delay, function()
				if not player:IsDescendantOf(Players) then return end
				if self._speedService then
					self._speedService:updateTotalMultiplier(player)
				end
			end)
		end
	end
end

-- Suma a TotalPlayTime los segundos transcurridos desde la última acreditación.
-- Si el perfil todavía no cargó, sale SIN mover _lastCredit: así ese tramo no se
-- pierde, se acredita entero en el siguiente intento.
function PlayTimeService:_creditPlayTime(player: Player): ()
	local dataService = self._dataService
	if not dataService or not dataService:hasProfile(player) then return end

	local last = self._lastCredit[player]
	if not last then return end

	local now = os.time()
	local elapsed = now - last
	if elapsed <= 0 then return end

	self._lastCredit[player] = now

	local total = (dataService:get(player, { "TotalPlayTime" }) or 0) :: number
	dataService:set(player, { "TotalPlayTime" }, total + elapsed)
end

-- Segundos jugados de por vida, incluyendo el tramo de la sesión actual que todavía
-- no se ha acreditado (si no, el valor se vería congelado hasta el próximo flush).
function PlayTimeService:getTotalPlayTime(player: Player): number
	local dataService = self._dataService
	if not dataService or not dataService:hasProfile(player) then return 0 end

	local stored = (dataService:get(player, { "TotalPlayTime" }) or 0) :: number
	local last = self._lastCredit[player]
	if not last then return stored end

	return stored + math.max(0, os.time() - last)
end

function PlayTimeService:_track(player: Player): ()
	self._joinTimes[player] = os.clock()
	self._lastCredit[player] = os.time()
	self:_scheduleUpdates(player)
end

function PlayTimeService:init(dataService: DataServiceServer): ()
	self._dataService = dataService

	Players.PlayerAdded:Connect(function(player)
		self:_track(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		self:_creditPlayTime(player)
		self._joinTimes[player] = nil
		self._lastCredit[player] = nil
	end)

	for _, player in Players:GetPlayers() do
		self:_track(player)
	end

	-- Flush periódico de todos los jugadores a la vez: un solo loop para el server
	-- entero, no uno por jugador.
	task.spawn(function()
		while true do
			task.wait(FLUSH_INTERVAL)
			for _, player in Players:GetPlayers() do
				self:_creditPlayTime(player)
			end
		end
	end)
end

return PlayTimeService
