--!strict

-- Servidor del admin panel. Dueño de la validación: TODO handler revalida que
-- quien dispara es admin (player.UserId es autoritativo en el servidor y no se
-- puede falsificar). El panel del cliente es solo cosmético; la única barrera real
-- contra exploits vive aquí.

local Players           = game:GetService("Players")
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local ServerStorage     = game:GetService("ServerStorage")
local CollectionService = game:GetService("CollectionService")
local MessagingService  = game:GetService("MessagingService")
local Workspace         = game:GetService("Workspace")

local AdminConfig          = require(ReplicatedStorage.Shared.AdminConfig)
local MountsConfig         = require(ReplicatedStorage.Shared.MountsConfig)
local SpeedConfig          = require(ReplicatedStorage.Shared.SpeedConfig)
local AdminAbuseConfig     = require(ReplicatedStorage.Shared.AdminAbuseConfig)
local AdminTreadmillConfig = require(ReplicatedStorage.Shared.AdminTreadmillConfig)
local Packets              = require(ReplicatedStorage.Shared.Packets)

type DataServiceServer = {
	hasProfile: (self: DataServiceServer, player: Player) -> boolean,
	get: (self: DataServiceServer, player: Player, path: any?) -> any,
	set: (self: DataServiceServer, player: Player, path: any, value: any, dontReplicate: boolean?) -> (),
}

-- Tope defensivo: aunque solo un admin llega hasta acá, evitamos que un valor
-- corrupto/gigante desde el cliente rompa la data (overflow, NaN, etc.).
local MAX_WINS_PER_GRANT = 1_000_000_000
local SLOW_SECONDS       = 10
local SLOW_WALKSPEED     = 1
local SLOW_REFRESH       = 0.2

-- Duraciones de ban permitidas (segundos). -1 = permanente. Se validan en el
-- servidor: aunque solo un admin llega, no aceptamos duraciones arbitrarias.
local ONE_DAY    = 86400
local ONE_WEEK   = 604800
local BAN_LABELS = {
	[ONE_DAY]  = "1 day",
	[ONE_WEEK] = "1 week",
	[-1]       = "permanent",
} :: { [number]: string }

-- Broadcast: topic de MessagingService (cross-server) y tope de longitud del
-- mensaje (protege la data y respeta el límite de 1KB de MessagingService).
local BROADCAST_TOPIC = "AdminBroadcast"
local MAX_MESSAGE_LEN = 150

-- Admin Abuse: topic de MessagingService (cross-server), separado del de Broadcast.
local ADMIN_ABUSE_TOPIC = "AdminAbuse"

local AdminService = {
	_dataService = nil :: DataServiceServer?,
	-- [Player] = os.clock() en que expira el slow. Presencia = hay loop activo.
	_slowUntil   = {} :: { [Player]: number },
	-- Estado actual de Admin Abuse en ESTE server (cacheado para sincronizar a
	-- jugadores que entran después de que se activó). endTime == 0 => sin cuenta
	-- regresiva (mensaje estático).
	_adminAbuse  = { active = false, message = "", endTime = 0 } :: { active: boolean, message: string, endTime: number },
	-- Referencia cacheada al modelo del treadmill de prueba (ServerStorage.AdminAbuse
	-- .Treadmill). Se guarda la PRIMERA vez que se encuentra: como el Instance no se
	-- invalida al reparentar, sigue siendo válida aunque el modelo viaje entre
	-- ServerStorage y Workspace.
	_adminTreadmill = nil :: Model?,
}

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	if not character then return nil end
	return character:FindFirstChildOfClass("Humanoid")
end

-- UserId escrito a mano en el panel: debe ser un entero positivo y finito.
local function isValidUserId(userId: number): boolean
	if type(userId) ~= "number" then return false end
	if userId ~= userId or userId == math.huge then return false end -- NaN / inf
	return userId >= 1 and math.floor(userId) == userId
end

local function isPremiumMount(mountName: string): boolean
	for _, mount in MountsConfig.Premium do
		if mount.Name == mountName then
			return true
		end
	end
	return false
end

function AdminService:init(dataService: DataServiceServer): ()
	self._dataService = dataService

	Packets.AdminGiveMount.OnServerEvent:Connect(function(player: Player, targetUserId: number, mountName: string)
		if not AdminConfig.isAdmin(player.UserId) then return end
		if type(targetUserId) ~= "number" or type(mountName) ~= "string" then return end
		if not isPremiumMount(mountName) then return end

		local target = Players:GetPlayerByUserId(targetUserId)
		if not target then return end

		self:_giveMount(target, mountName)
	end)

	Packets.AdminGiveWins.OnServerEvent:Connect(function(player: Player, targetUserId: number, amount: number)
		if not AdminConfig.isAdmin(player.UserId) then return end
		if type(targetUserId) ~= "number" or type(amount) ~= "number" then return end
		-- Saneo del monto: entero, positivo, finito y con tope.
		if amount ~= amount or amount == math.huge then return end -- NaN / inf
		amount = math.floor(amount)
		if amount <= 0 then return end
		amount = math.min(amount, MAX_WINS_PER_GRANT)

		local target = Players:GetPlayerByUserId(targetUserId)
		if not target then return end

		self:_giveWins(target, amount)
	end)

	Packets.AdminSlow.OnServerEvent:Connect(function(player: Player, targetUserId: number)
		if not AdminConfig.isAdmin(player.UserId) then return end
		if type(targetUserId) ~= "number" then return end

		local target = Players:GetPlayerByUserId(targetUserId)
		if not target then return end

		self:_slow(target)
	end)

	Packets.AdminBan.OnServerEvent:Connect(function(player: Player, targetUserId: number, durationSeconds: number)
		if not AdminConfig.isAdmin(player.UserId) then return end
		if not isValidUserId(targetUserId) then return end
		if type(durationSeconds) ~= "number" then return end
		-- Solo aceptamos las tres duraciones definidas.
		if BAN_LABELS[durationSeconds] == nil then return end
		-- Protección: nunca banear a otro admin ni a uno mismo (evita self-ban
		-- accidental y que un admin banee a otro).
		if AdminConfig.isAdmin(targetUserId) then return end

		self:_ban(targetUserId, durationSeconds)
	end)

	Packets.AdminUnban.OnServerEvent:Connect(function(player: Player, targetUserId: number)
		if not AdminConfig.isAdmin(player.UserId) then return end
		if not isValidUserId(targetUserId) then return end

		self:_unban(targetUserId)
	end)

	Packets.AdminBroadcast.OnServerEvent:Connect(function(player: Player, message: string, scope: string, targetUserId: number)
		if not AdminConfig.isAdmin(player.UserId) then return end
		if type(message) ~= "string" or type(scope) ~= "string" then return end

		-- Saneo del mensaje: recortar espacios, rechazar vacío, cortar a la longitud máx.
		message = (message:gsub("^%s+", ""):gsub("%s+$", ""))
		if message == "" then return end
		if #message > MAX_MESSAGE_LEN then
			message = message:sub(1, MAX_MESSAGE_LEN)
		end

		-- El nombre y el estado de verificado los pone el SERVIDOR (autoritativo): un
		-- exploiter no puede falsear de quién viene ni fingir el badge de verificado.
		self:_broadcast(player.DisplayName, player.HasVerifiedBadge, message, scope, targetUserId)
	end)

	-- Suscripción cross-server: los mensajes "global"/"player-remoto" llegan por aquí.
	-- Envuelto en pcall porque SubscribeAsync es una llamada web (falla en Studio).
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(BROADCAST_TOPIC, function(packet: any)
				local data = packet.Data
				if type(data) ~= "table" or type(data.m) ~= "string" then return end
				-- Ignorar el eco de nuestro propio publish (ya lo mostramos localmente).
				if data.j == game.JobId then return end
				self:_showLocal(tostring(data.n or ""), data.v == true, data.m, tonumber(data.t) or 0)
			end)
		end)
		if not ok then
			warn("[Admin] SubscribeAsync (broadcast) falló: " .. tostring(err))
		end
	end)

	Packets.AdminAbuseTrigger.OnServerEvent:Connect(function(player: Player, presetId: string)
		if not AdminConfig.isAdmin(player.UserId) then return end
		if type(presetId) ~= "string" then return end

		-- El mensaje y la duración se resuelven SIEMPRE del config del servidor: el
		-- cliente solo manda un id, nunca texto libre (evita spoofear el mensaje).
		local preset = AdminAbuseConfig.byId[presetId]
		if not preset then return end

		local endTime = if preset.DurationSeconds > 0 then os.time() + preset.DurationSeconds else 0
		self:_applyAdminAbuseState(true, preset.Message, endTime)
		self:_publishAdminAbuse(true, preset.Message, endTime)
	end)

	Packets.AdminAbuseCancel.OnServerEvent:Connect(function(player: Player)
		if not AdminConfig.isAdmin(player.UserId) then return end

		self:_applyAdminAbuseState(false, "", 0)
		self:_publishAdminAbuse(false, "", 0)
	end)

	-- Suscripción cross-server para Admin Abuse: separado del topic de Broadcast.
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(ADMIN_ABUSE_TOPIC, function(packet: any)
				local data = packet.Data
				if type(data) ~= "table" then return end
				if data.j == game.JobId then return end -- ignorar nuestro propio eco
				self:_applyAdminAbuseState(data.a == true, tostring(data.m or ""), tonumber(data.e) or 0)
			end)
		end)
		if not ok then
			warn("[Admin] SubscribeAsync (admin abuse) falló: " .. tostring(err))
		end
	end)

	Players.PlayerAdded:Connect(function(newPlayer)
		-- Sincroniza al jugador recién llegado con el estado actual DE ESTE server
		-- (si Admin Abuse ya está activo, se lo mandamos directo en vez de esperar
		-- al próximo trigger/publish).
		local state = self._adminAbuse
		if state.active then
			Packets.AdminAbuseState:FireClient(newPlayer, true, state.message, state.endTime)
		end
	end)

	Packets.AdminTreadmillSpawn.OnServerEvent:Connect(function(player: Player, multiplier: number)
		if not AdminConfig.isAdmin(player.UserId) then return end
		if type(multiplier) ~= "number" then return end
		if not AdminTreadmillConfig.isAllowed(multiplier) then return end

		self:_spawnAdminTreadmill(multiplier)
	end)

	Packets.AdminTreadmillReturn.OnServerEvent:Connect(function(player: Player)
		if not AdminConfig.isAdmin(player.UserId) then return end

		self:_returnAdminTreadmill()
	end)

	Players.PlayerRemoving:Connect(function(player)
		self._slowUntil[player] = nil
	end)
end

-- Encuentra (y cachea) el modelo del treadmill de prueba. Se asume que arranca en
-- ServerStorage.AdminAbuse.Treadmill al bootear el server (así viene en el place).
function AdminService:_getAdminTreadmill(): Model?
	if self._adminTreadmill then
		return self._adminTreadmill
	end

	local folder = ServerStorage:FindFirstChild("AdminAbuse")
	local model = folder and folder:FindFirstChild("Treadmill")
	if model and model:IsA("Model") then
		self._adminTreadmill = model
	end
	return self._adminTreadmill
end

function AdminService:_spawnAdminTreadmill(multiplier: number): ()
	local model = self:_getAdminTreadmill()
	if not model then
		warn("[Admin] No se encontró ServerStorage.AdminAbuse.Treadmill")
		return
	end

	model:SetAttribute("Multiplier", multiplier)

	local sign = model:FindFirstChild("Sign")
	local surfaceGui = sign and sign:FindFirstChild("SurfaceGui")
	local quantity = surfaceGui and surfaceGui:FindFirstChild("Quantity")
	if quantity and quantity:IsA("TextLabel") then
		quantity.Text = "x" .. tostring(multiplier)
	end

	-- El resto del juego (SpeedService, cliente) detecta el treadmill por este tag +
	-- estar en Workspace; sin el tag no cuenta como treadmill válido.
	CollectionService:AddTag(model, "Treadmill")
	model.Parent = Workspace
end

function AdminService:_returnAdminTreadmill(): ()
	local model = self:_getAdminTreadmill()
	if not model then return end

	CollectionService:RemoveTag(model, "Treadmill")

	local folder = ServerStorage:FindFirstChild("AdminAbuse")
	if folder then
		model.Parent = folder
	end
end

-- Aplica el estado LOCALMENTE (este server): guarda el cache y lo manda a todos
-- los clientes ya conectados acá.
function AdminService:_applyAdminAbuseState(active: boolean, message: string, endTime: number): ()
	self._adminAbuse = { active = active, message = message, endTime = endTime }
	Packets.AdminAbuseState:Fire(active, message, endTime)
end

-- Publica a los demás servers vía MessagingService. j = JobId para que el server
-- emisor ignore su propio eco (ya aplicó el estado localmente).
function AdminService:_publishAdminAbuse(active: boolean, message: string, endTime: number): ()
	local ok, err = pcall(function()
		MessagingService:PublishAsync(ADMIN_ABUSE_TOPIC, {
			a = active,
			m = message,
			e = endTime,
			j = game.JobId,
		})
	end)
	if not ok then
		warn("[Admin] PublishAsync (admin abuse) falló: " .. tostring(err))
	end
end

function AdminService:_ban(targetUserId: number, durationSeconds: number): ()
	local label = BAN_LABELS[durationSeconds] or tostring(durationSeconds)
	-- Sistema propio de Roblox. Duration en segundos (-1 = permanente). Envuelto en
	-- pcall porque BanAsync es una llamada web: puede fallar (rate limit, Studio, etc.).
	local ok, err = pcall(function()
		Players:BanAsync({
			UserIds            = { targetUserId },
			Duration           = durationSeconds,
			DisplayReason      = "You have been banned by an administrator.",
			PrivateReason      = "Admin panel ban (" .. label .. ")",
			ApplyToUniverse    = true,
			ExcludeAltAccounts = false,
		})
	end)
	if not ok then
		warn("[Admin] BanAsync falló para " .. tostring(targetUserId) .. ": " .. tostring(err))
	end
end

function AdminService:_unban(targetUserId: number): ()
	local ok, err = pcall(function()
		Players:UnbanAsync({
			UserIds         = { targetUserId },
			ApplyToUniverse = true,
		})
	end)
	if not ok then
		warn("[Admin] UnbanAsync falló para " .. tostring(targetUserId) .. ": " .. tostring(err))
	end
end

-- Muestra el banner en ESTE servidor. targetUserId == 0 => a todos; si no, solo al
-- jugador con ese UserId si está presente aquí.
function AdminService:_showLocal(senderName: string, verified: boolean, message: string, targetUserId: number): ()
	if targetUserId == 0 then
		Packets.ShowBroadcast:Fire(senderName, message, verified) -- broadcast a todos los clientes del server
	else
		local target = Players:GetPlayerByUserId(targetUserId)
		if target then
			Packets.ShowBroadcast:FireClient(target, senderName, message, verified)
		end
	end
end

-- Publica a los demás servers vía MessagingService. j = JobId para que el server
-- emisor ignore su propio eco (ya mostró el mensaje localmente).
function AdminService:_publish(senderName: string, verified: boolean, message: string, targetUserId: number): ()
	local ok, err = pcall(function()
		MessagingService:PublishAsync(BROADCAST_TOPIC, {
			n = senderName,
			v = verified,
			m = message,
			t = targetUserId,
			j = game.JobId,
		})
	end)
	if not ok then
		warn("[Admin] PublishAsync (broadcast) falló: " .. tostring(err))
	end
end

function AdminService:_broadcast(senderName: string, verified: boolean, message: string, scope: string, targetUserId: number): ()
	if scope == "server" then
		self:_showLocal(senderName, verified, message, 0)
	elseif scope == "global" then
		-- Inmediato en este server + publish para el resto (ellos ignoran nuestro eco).
		self:_showLocal(senderName, verified, message, 0)
		self:_publish(senderName, verified, message, 0)
	elseif scope == "player" then
		if not isValidUserId(targetUserId) then return end
		-- Si está en este server, directo; si no (por id, remoto), lo resuelve el
		-- server que lo tenga vía MessagingService.
		if Players:GetPlayerByUserId(targetUserId) then
			self:_showLocal(senderName, verified, message, targetUserId)
		else
			self:_publish(senderName, verified, message, targetUserId)
		end
	end
end

function AdminService:_giveMount(target: Player, mountName: string): ()
	local ds = self._dataService
	if not ds or not ds:hasProfile(target) then return end
	-- Igual que una compra Premium: solo concede propiedad (idempotente). El jugador
	-- la equipa desde el Index.
	if ds:get(target, { "Mounts", mountName }) ~= true then
		ds:set(target, { "Mounts", mountName }, true)
	end
end

function AdminService:_giveWins(target: Player, amount: number): ()
	local ds = self._dataService
	if not ds or not ds:hasProfile(target) then return end
	-- Crédito crudo: sin multiplicador de rebirth (es un regalo admin, no un claim).
	local current = (ds:get(target, { "WinCurrency" }) or 0) :: number
	ds:set(target, { "WinCurrency" }, current + amount)
end

function AdminService:_slow(target: Player): ()
	local humanoid = getHumanoid(target)
	if not humanoid then return end

	local alreadySlowed = self._slowUntil[target] ~= nil
	self._slowUntil[target] = os.clock() + SLOW_SECONDS
	if alreadySlowed then
		-- Ya hay un loop corriendo: solo extendimos la expiración, no lanzamos otro.
		return
	end

	task.spawn(function()
		-- Re-clampea el WalkSpeed durante la ventana: si el jugador sube de nivel o
		-- re-morfa (que reaplican WalkSpeed), lo volvemos a bajar en <=0.2s.
		while true do
			local expiry = self._slowUntil[target]
			if not expiry or os.clock() >= expiry then break end
			if not target:IsDescendantOf(Players) then
				self._slowUntil[target] = nil
				return
			end
			local h = getHumanoid(target)
			if h then h.WalkSpeed = SLOW_WALKSPEED end
			task.wait(SLOW_REFRESH)
		end

		self._slowUntil[target] = nil

		-- Restaurar la velocidad correcta según el nivel actual.
		local ds = self._dataService
		if ds and ds:hasProfile(target) then
			local level = (ds:get(target, { "Level" }) or 1) :: number
			local h = getHumanoid(target)
			if h then h.WalkSpeed = SpeedConfig.getWalkSpeedForLevel(level) end
		end
	end)
end

return AdminService
