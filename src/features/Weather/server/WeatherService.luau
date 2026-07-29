--!strict

-- Weather Events: eventos globales que activa un admin desde el panel y que dan un
-- bonus mientras están activos. Dueño ÚNICO del estado del evento.
--
-- Los handlers de packet viven acá (no en AdminService) con su propio gate
-- AdminConfig.isAdmin: el weather es un sistema de gameplay que además se dispara
-- desde el panel, así que se mantiene autocontenido en vez de sumarle otra
-- dependencia cruzada a AdminService. AdminConfig es shared justamente para esto.
--
-- El bonus viaja por ATRIBUTOS de Player (mismo canal que FriendsBoost), así no hay
-- que cablear este servicio dentro de SpeedService ni de WinsService:
--   WeatherBoost     -> lo suma SpeedService en _updateTotalMultiplier (aditivo)
--   WeatherWinsBoost -> lo multiplica WinsService en _creditWins (multiplicativo)
-- Ambos valen 1 cuando no hay evento.
--
-- Tres capas de propagación, porque el evento NO caduca solo:
--   1. Packets.WeatherState  -> los clientes de ESTE server
--   2. MessagingService      -> los demás servers vivos
--   3. DataStore             -> los servers que arranquen DESPUÉS del trigger
-- Sin la 3ª, un server nuevo levantaría sin el weather y los jugadores verían cosas
-- distintas según dónde cayeran.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local MessagingService  = game:GetService("MessagingService")
local DataStoreService  = game:GetService("DataStoreService")

local AdminConfig   = require(ReplicatedStorage.Shared.AdminConfig)
local WeatherConfig = require(ReplicatedStorage.Shared.WeatherConfig)
local Packets       = require(ReplicatedStorage.Shared.Packets)

type SpeedServiceLike = {
	updateTotalMultiplier: (self: any, player: Player) -> (),
}

-- Topic de MessagingService y clave del DataStore (comparten nombre, son sistemas
-- distintos).
local WEATHER_TOPIC = "WeatherEvent"
local STORE_NAME    = "WeatherEvent"
local STORE_KEY     = "Current"

local WeatherService = {
	_speedService = nil :: SpeedServiceLike?,
	-- Id del weather activo en ESTE server, o nil si no hay ninguno. Se cachea para
	-- poder sincronizar a los que entren después.
	_current = nil :: string?,
	_store = nil :: DataStore?,
}

function WeatherService:setSpeedService(speedService: SpeedServiceLike): ()
	self._speedService = speedService
end

-- Escribe los dos atributos de bonus en un jugador según el weather activo.
function WeatherService:_applyToPlayer(player: Player): ()
	local preset = if self._current then WeatherConfig.byId[self._current] else nil

	player:SetAttribute("WeatherBoost", if preset then preset.Multiplier else 1)
	player:SetAttribute("WeatherWinsBoost", if preset then preset.WinsMultiplier else 1)

	-- Speed hay que recalcularlo a mano: el atributo solo lo LEE SpeedService, no
	-- dispara nada por sí mismo (mismo contrato que el resto de fuentes).
	local speedService = self._speedService
	if speedService then
		speedService:updateTotalMultiplier(player)
	end
end

-- Aplica el estado LOCALMENTE (este server): cachea, reparte bonus y avisa a los
-- clientes ya conectados acá. weatherId nil = sin evento.
function WeatherService:_applyState(weatherId: string?): ()
	self._current = weatherId

	for _, player in Players:GetPlayers() do
		self:_applyToPlayer(player)
	end

	Packets.WeatherState:Fire(weatherId ~= nil, weatherId or "")
end

-- Publica a los demás servers. j = JobId para que el emisor ignore su propio eco
-- (ya aplicó el estado localmente). Mismo patrón que AdminService._publishAdminAbuse.
function WeatherService:_publish(weatherId: string?): ()
	local ok, err = pcall(function()
		MessagingService:PublishAsync(WEATHER_TOPIC, {
			w = weatherId or "",
			j = game.JobId,
		})
	end)
	if not ok then
		warn("[Weather] PublishAsync falló: " .. tostring(err))
	end
end

-- Persiste el estado para los servers que todavía no existen. Cadena vacía = sin
-- evento (no se borra la clave, así el GetAsync del arranque siempre lee algo).
function WeatherService:_persist(weatherId: string?): ()
	local store = self._store
	if not store then return end

	local ok, err = pcall(function()
		store:SetAsync(STORE_KEY, weatherId or "")
	end)
	if not ok then
		warn("[Weather] SetAsync falló: " .. tostring(err))
	end
end

-- Punto único de entrada: aplica + publica + persiste. weatherId ya validado.
function WeatherService:_setWeather(weatherId: string?): ()
	self:_applyState(weatherId)
	self:_publish(weatherId)
	self:_persist(weatherId)
end

function WeatherService:init(): ()
	local storeOk, store = pcall(function()
		return DataStoreService:GetDataStore(STORE_NAME)
	end)
	if storeOk then
		self._store = store
	else
		warn("[Weather] GetDataStore falló: " .. tostring(store))
	end

	-- Estado inicial desde el DataStore. Si falla (o el id guardado ya no existe en
	-- el config porque se renombró un preset), el server arranca sin weather: es el
	-- fallback seguro.
	task.spawn(function()
		local dataStore = self._store
		if not dataStore then return end

		local ok, saved = pcall(function()
			return dataStore:GetAsync(STORE_KEY)
		end)
		if not ok then
			warn("[Weather] GetAsync falló: " .. tostring(saved))
			return
		end

		-- Si mientras se resolvía el GetAsync un admin ya activó algo en este server,
		-- no lo pisamos con el valor viejo del store.
		if self._current ~= nil then return end

		if type(saved) == "string" and WeatherConfig.byId[saved] then
			self:_applyState(saved)
		end
	end)

	Packets.AdminWeatherTrigger.OnServerEvent:Connect(function(player: Player, weatherId: string)
		if not AdminConfig.isAdmin(player.UserId) then return end
		if type(weatherId) ~= "string" then return end

		-- El multiplicador y los visuales salen SIEMPRE del config del servidor: el
		-- cliente solo manda un id, nunca números (evita spoofear el bonus).
		if not WeatherConfig.byId[weatherId] then return end

		self:_setWeather(weatherId)
	end)

	Packets.AdminWeatherClear.OnServerEvent:Connect(function(player: Player)
		if not AdminConfig.isAdmin(player.UserId) then return end

		self:_setWeather(nil)
	end)

	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(WEATHER_TOPIC, function(packet: any)
				local data = packet.Data
				if type(data) ~= "table" then return end
				if data.j == game.JobId then return end -- ignorar nuestro propio eco

				local weatherId = tostring(data.w or "")
				self:_applyState(if WeatherConfig.byId[weatherId] then weatherId else nil)
			end)
		end)
		if not ok then
			warn("[Weather] SubscribeAsync falló: " .. tostring(err))
		end
	end)

	Players.PlayerAdded:Connect(function(newPlayer)
		-- Los atributos se ponen SIEMPRE (aunque no haya evento): así SpeedService y
		-- WinsService leen un 1 explícito en vez de un nil, y el jugador que entra a
		-- mitad de un weather no se queda sin bonus hasta el próximo trigger.
		self:_applyToPlayer(newPlayer)

		if self._current then
			Packets.WeatherState:FireClient(newPlayer, true, self._current)
		end
	end)

	-- Los que ya estaban (el init corre después de que puedan haber entrado).
	for _, player in Players:GetPlayers() do
		self:_applyToPlayer(player)
	end
end

return WeatherService
