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
local DataStoreService  = game:GetService("DataStoreService")
local Workspace         = game:GetService("Workspace")

local AdminConfig          = require(ReplicatedStorage.Shared.AdminConfig)
local MountsConfig         = require(ReplicatedStorage.Shared.MountsConfig)
local SpeedConfig          = require(ReplicatedStorage.Shared.SpeedConfig)
local AdminAbuseConfig     = require(ReplicatedStorage.Shared.AdminAbuseConfig)
local AdminTreadmillConfig = require(ReplicatedStorage.Shared.AdminTreadmillConfig)
local Packets              = require(ReplicatedStorage.Shared.Packets)
local AlertsModule         = require(ReplicatedStorage.Packages.AlertsModule)

type DataServiceServer = {
	hasProfile: (self: DataServiceServer, player: Player) -> boolean,
	get: (self: DataServiceServer, player: Player, path: any?) -> any,
	set: (self: DataServiceServer, player: Player, path: any, value: any, dontReplicate: boolean?) -> (),
}

-- Tope defensivo: aunque solo un admin llega hasta acá, evitamos que un valor
-- corrupto/gigante desde el cliente rompa la data (overflow, NaN, etc.).
-- 1T. Tiene que ir por encima del preset más alto del panel (+1T) o los botones
-- grandes se saturarían en silencio. La escala la marca World 2: su cadena de
-- steps son 79.9B y la última montura 40B, así que un tope de 1B —el que había,
-- calibrado para World 1— dejaba el botón inservible para probar ese mundo.
local MAX_WINS_PER_GRANT = 1_000_000_000_000
-- Tope del Level que puede dejar un regalo de admin. Muy por encima del final del
-- recorrido (World 2 acaba en el 175): sirve para probar, no para restringir. La
-- curva de coste es exponencial (1.204^L), así que sin tope un valor corrupto deja
-- al jugador en un nivel cuyo requisito no cabe en un double.
local MAX_LEVEL          = 500
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
-- Mismas 3 capas que el reward y el treadmill. Acá la capa de DataStore es la MÁS
-- importante de las tres: la cuenta regresiva es lo que ANUNCIA el evento, o sea lo
-- que provoca la entrada masiva que hace que Roblox abra servers nuevos. Sin ella,
-- los jugadores que vienen por el anuncio son justo los que no lo ven.
local ADMIN_ABUSE_TOPIC      = "AdminAbuse"
local ADMIN_ABUSE_STORE_NAME = "AdminAbuse"
local ADMIN_ABUSE_STORE_KEY  = "Current"

-- Tope de seguridad. El banner NO se limpia solo al llegar el countdown a 0 (se queda
-- el mensaje sin reloj, que es lo que se quiere: "admin abuse in" → el evento ocurre
-- ahora), y los presets estáticos no tienen endTime. Sin este tope, un "happening
-- now!" sin cancelar quedaría anunciándose en todos los servers para siempre.
local ADMIN_ABUSE_MAX_SECONDS = 3 * 60 * 60

-- Reward de Admin Abuse (Workspace.AdminUtils): un obby detrás de un Barrier, con un
-- Reward al final que concede una montura exclusiva. El admin abre y cierra el
-- acceso; es la única forma de conseguir esa montura.
--
-- El Barrier se mueve a ServerStorage y vuelve (mismo patrón que el treadmill de
-- prueba): al ser el MISMO objeto conserva su posición exacta, y mientras está fuera
-- no colisiona ni proyecta sombras.
-- Propagación en tres capas, y hacen falta las tres:
--   1. MessagingService -> los servers vivos AHORA
--   2. DataStore        -> los que arranquen DESPUÉS
--   3. os.time absoluto -> todos coinciden en cuándo se cierra
-- La 2ª no es opcional: durante un evento entra una avalancha de gente y Roblox abre
-- servers nuevos por eso mismo. Sin ella, los jugadores que vienen AL evento son
-- justo los que se encuentran el obby cerrado.
local ADMIN_REWARD_TOPIC = "AdminReward"
local REWARD_STORE_NAME  = "AdminReward"
local REWARD_STORE_KEY   = "OpenUntil"

-- Caducidad de seguridad. El reward se guarda como un os.time() absoluto de cierre,
-- no como un booleano: así un admin que se olvide de cerrarlo no deja contenido
-- exclusivo abierto para siempre en servers que nadie supervisa. Es más largo que
-- cualquier admin abuse real, así que en la práctica siempre se cierra a mano.
local REWARD_MAX_OPEN_SECONDS = 3 * 60 * 60

-- Treadmill de prueba: mismo esquema de 3 capas + caducidad que el reward. La
-- caducidad importa AÚN MÁS acá: una cinta x100 puesta en todos los servers infla el
-- Speed de todo el juego, y encima el multiplicador se valida por máximo global (ver
-- "Trampas conocidas" en AGENTS.md), así que ni siquiera hay que pisarla.
local ADMIN_TREADMILL_TOPIC      = "AdminTreadmill"
local TREADMILL_STORE_NAME       = "AdminTreadmill"
local TREADMILL_STORE_KEY        = "Current"
local TREADMILL_MAX_OPEN_SECONDS = 3 * 60 * 60

local REWARD_MOUNT_NAME  = "Vezkitt"
-- Rareza para el ItemNotification. Las válidas salen de ReplicatedStorage.Models.UI
-- .Colors (Common/Rare/Epic/Legendary/Unique); si no coincide, la card sale sin
-- gradiente en vez de romperse.
local REWARD_RARITY   = "Unique"
local REWARD_SUBTITLE = "Admin Abuse Reward"

local AdminService = {
	_dataService = nil :: DataServiceServer?,
	-- [Player] = os.clock() en que expira el slow. Presencia = hay loop activo.
	_slowUntil   = {} :: { [Player]: number },
	-- Estado actual de Admin Abuse en ESTE server (cacheado para sincronizar a
	-- jugadores que entran después de que se activó). endTime == 0 => sin cuenta
	-- regresiva (mensaje estático).
	-- expiresAt es el tope de seguridad (os.time absoluto), distinto de endTime: endTime
	-- es cuándo llega a 0 la cuenta regresiva del banner, expiresAt es cuándo se deja
	-- de anunciar del todo. Un preset estático tiene endTime 0 pero sí expiresAt.
	_adminAbuse  = { active = false, message = "", endTime = 0, expiresAt = 0 } :: { active: boolean, message: string, endTime: number, expiresAt: number },
	-- Invalida el task.delay de auto-limpieza anterior cuando llega un estado nuevo.
	_adminAbuseCloseToken = 0,
	_adminAbuseStore = nil :: DataStore?,
	-- Referencia cacheada al modelo del treadmill de prueba (ServerStorage.AdminAbuse
	-- .Treadmill). Se guarda la PRIMERA vez que se encuentra: como el Instance no se
	-- invalida al reparentar, sigue siendo válida aunque el modelo viaje entre
	-- ServerStorage y Workspace.
	_adminTreadmill = nil :: Model?,
	-- Invalida el task.delay de auto-retirada anterior cuando llega un estado nuevo.
	_treadmillCloseToken = 0,
	_treadmillStore = nil :: DataStore?,
	-- Reward de Admin Abuse. _rewardActive es la ÚNICA autorización para conceder la
	-- montura: el Touched está siempre conectado y consulta este flag, así que si el
	-- reward está cerrado tocar el modelo no hace nada.
	_rewardActive = false,
	-- Invalida el task.delay de auto-cierre anterior cuando llega un estado nuevo.
	_rewardCloseToken = 0,
	_rewardStore = nil :: DataStore?,
	-- Referencias cacheadas de Workspace.AdminUtils. Como con el treadmill, un
	-- Instance no se invalida al reparentar: la ref sigue sirviendo aunque el Barrier
	-- viaje entre Workspace y ServerStorage.
	_barrier      = nil :: Model?,
	_rewardHitBox = nil :: BasePart?,
}

-- Resuelve el jugador desde la parte que disparó un Touched, subiendo por los
-- ancestros. NO vale con hit.Parent: el character de este juego es un modelo de
-- montura y MorphService le cuelga el hat como un Model hijo ("Hat"), así que tocar
-- con el sombrero daría hit.Parent = ese Model y GetPlayerFromCharacter = nil.
local function getPlayerFromTouch(hit: BasePart): Player?
	local instance: Instance? = hit
	while instance do
		if instance:IsA("Model") then
			local player = Players:GetPlayerFromCharacter(instance)
			if player then return player end
		end
		instance = instance.Parent
	end
	return nil
end

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

	Packets.AdminGiveLevels.OnServerEvent:Connect(function(player: Player, targetUserId: number, amount: number)
		if not AdminConfig.isAdmin(player.UserId) then return end
		if type(targetUserId) ~= "number" or type(amount) ~= "number" then return end
		-- Mismo saneo que Give Wins: entero, positivo y finito.
		if amount ~= amount or amount == math.huge then return end -- NaN / inf
		amount = math.floor(amount)
		if amount <= 0 then return end

		local target = Players:GetPlayerByUserId(targetUserId)
		if not target then return end

		self:_giveLevels(target, amount)
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
		-- El tope se cuenta desde el disparo, no desde endTime: un "warning 10m" y un
		-- "happening now" se dejan de anunciar a las 3h por igual.
		local expiresAt = os.time() + ADMIN_ABUSE_MAX_SECONDS

		self:_applyAdminAbuseState(true, preset.Message, endTime, expiresAt)
		self:_publishAdminAbuse(true, preset.Message, endTime, expiresAt)
		self:_persistAdminAbuse(true, preset.Message, endTime, expiresAt)
	end)

	Packets.AdminAbuseCancel.OnServerEvent:Connect(function(player: Player)
		if not AdminConfig.isAdmin(player.UserId) then return end

		self:_applyAdminAbuseState(false, "", 0, 0)
		self:_publishAdminAbuse(false, "", 0, 0)
		self:_persistAdminAbuse(false, "", 0, 0)
	end)

	-- Suscripción cross-server para Admin Abuse: separado del topic de Broadcast.
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(ADMIN_ABUSE_TOPIC, function(packet: any)
				local data = packet.Data
				if type(data) ~= "table" then return end
				if data.j == game.JobId then return end -- ignorar nuestro propio eco
				self:_applyAdminAbuseState(
					data.a == true,
					tostring(data.m or ""),
					tonumber(data.e) or 0,
					tonumber(data.x) or 0
				)
			end)
		end)
		if not ok then
			warn("[Admin] SubscribeAsync (admin abuse) falló: " .. tostring(err))
		end
	end)

	-- Anuncio guardado: un server creado a mitad de la cuenta regresiva arranca ya
	-- mostrando el banner, en vez de dejar a esos jugadores sin enterarse.
	task.spawn(function()
		self:_restoreAdminAbuse()
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

		-- La duración la decide el SERVIDOR: el cliente solo manda el multiplicador.
		local openUntil = os.time() + TREADMILL_MAX_OPEN_SECONDS

		self:_applyTreadmillState(multiplier, openUntil)
		self:_publishTreadmillState(multiplier, openUntil)
		self:_persistTreadmillState(multiplier, openUntil)
	end)

	Packets.AdminTreadmillReturn.OnServerEvent:Connect(function(player: Player)
		if not AdminConfig.isAdmin(player.UserId) then return end

		self:_applyTreadmillState(0, 0)
		self:_publishTreadmillState(0, 0)
		self:_persistTreadmillState(0, 0)
	end)

	-- Suscripción cross-server del treadmill. Topic propio, separado de los demás.
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(ADMIN_TREADMILL_TOPIC, function(packet: any)
				local data = packet.Data
				if type(data) ~= "table" then return end
				if data.j == game.JobId then return end -- ignorar nuestro propio eco

				local multiplier = tonumber(data.m) or 0
				-- Se revalida en el receptor: nunca se confía en el multiplicador que
				-- llega por el topic, aunque venga de otro server nuestro.
				if multiplier > 0 and not AdminTreadmillConfig.isAllowed(multiplier) then return end

				self:_applyTreadmillState(multiplier, tonumber(data.u) or 0)
			end)
		end)
		if not ok then
			warn("[Admin] SubscribeAsync (treadmill) falló: " .. tostring(err))
		end
	end)

	task.spawn(function()
		self:_restoreTreadmillState()
	end)

	Packets.AdminRewardSet.OnServerEvent:Connect(function(player: Player, active: boolean)
		if not AdminConfig.isAdmin(player.UserId) then return end
		if type(active) ~= "boolean" then return end

		-- La duración la decide el SERVIDOR: el cliente solo dice abrir o cerrar.
		local openUntil = if active then os.time() + REWARD_MAX_OPEN_SECONDS else 0

		self:_applyRewardState(openUntil)
		self:_publishRewardState(openUntil)
		self:_persistRewardState(openUntil)
	end)

	-- Suscripción cross-server del reward. Topic propio, separado de los anteriores.
	task.spawn(function()
		local ok, err = pcall(function()
			MessagingService:SubscribeAsync(ADMIN_REWARD_TOPIC, function(packet: any)
				local data = packet.Data
				if type(data) ~= "table" then return end
				if data.j == game.JobId then return end -- ignorar nuestro propio eco
				self:_applyRewardState(tonumber(data.u) or 0)
			end)
		end)
		if not ok then
			warn("[Admin] SubscribeAsync (reward) falló: " .. tostring(err))
		end
	end)

	self:_setupRewardTouch()

	-- Estado guardado: si el evento sigue vivo, este server arranca ya con el obby
	-- abierto en vez de esperar a que un admin lo reabra.
	task.spawn(function()
		self:_restoreRewardState()
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
	model.Parent = self:_getStorageFolder()
end

-- Aplica el estado LOCALMENTE (este server). multiplier == 0 o openUntil ya pasado
-- => la cinta vuelve a storage. Un openUntil caducado se lee como "retirada", que es
-- lo que hace que un server recién arrancado descarte solo un estado viejo del store.
function AdminService:_applyTreadmillState(multiplier: number, openUntil: number): ()
	self._treadmillCloseToken += 1
	local myToken = self._treadmillCloseToken

	local remaining = openUntil - os.time()
	local active = multiplier > 0 and remaining > 0

	if not active then
		self:_returnAdminTreadmill()
		return
	end

	self:_spawnAdminTreadmill(multiplier)

	-- Auto-retirada local al llegar la hora. Cada server la programa por su cuenta
	-- contra el MISMO instante absoluto, así todos la quitan a la vez sin que nadie
	-- tenga que publicar el cierre.
	task.delay(remaining, function()
		if myToken ~= self._treadmillCloseToken then return end
		self:_applyTreadmillState(0, 0)
	end)
end

function AdminService:_publishTreadmillState(multiplier: number, openUntil: number): ()
	local ok, err = pcall(function()
		MessagingService:PublishAsync(ADMIN_TREADMILL_TOPIC, {
			m = multiplier,
			u = openUntil,
			j = game.JobId,
		})
	end)
	if not ok then
		warn("[Admin] PublishAsync (treadmill) falló: " .. tostring(err))
	end
end

function AdminService:_persistTreadmillState(multiplier: number, openUntil: number): ()
	local store = self._treadmillStore
	if not store then return end

	local ok, err = pcall(function()
		store:SetAsync(TREADMILL_STORE_KEY, { m = multiplier, u = openUntil })
	end)
	if not ok then
		warn("[Admin] SetAsync (treadmill) falló: " .. tostring(err))
	end
end

-- Levanta el estado guardado al arrancar: un server creado a mitad del evento
-- aparece ya con la cinta puesta y el tiempo restante correcto.
function AdminService:_restoreTreadmillState(): ()
	local storeOk, store = pcall(function()
		return DataStoreService:GetDataStore(TREADMILL_STORE_NAME)
	end)
	if not storeOk then
		warn("[Admin] GetDataStore (treadmill) falló: " .. tostring(store))
		return
	end
	self._treadmillStore = store

	local ok, saved = pcall(function()
		return store:GetAsync(TREADMILL_STORE_KEY)
	end)
	if not ok then
		warn("[Admin] GetAsync (treadmill) falló: " .. tostring(saved))
		return
	end

	-- Si un admin ya tocó la cinta en ESTE server mientras se resolvía el GetAsync,
	-- no la pisamos con el valor del store.
	if self._treadmillCloseToken > 0 then return end
	if type(saved) ~= "table" then return end

	local multiplier = tonumber(saved.m) or 0
	-- Se revalida contra el config: si se quitó un multiplicador permitido desde que
	-- se guardó, no se resucita una cinta que ya no es legal.
	if multiplier > 0 and not AdminTreadmillConfig.isAllowed(multiplier) then return end

	self:_applyTreadmillState(multiplier, tonumber(saved.u) or 0)
end

-- ── Reward de Admin Abuse (Workspace.AdminUtils) ─────────────────────────────

-- Carpeta de ServerStorage donde se guarda el Barrier mientras está quitado. Se crea
-- si no existe: el Barrier vive en Workspace en el .rbxl, así que la primera vez que
-- se abre el reward puede no haber carpeta todavía.
function AdminService:_getStorageFolder(): Folder
	local folder = ServerStorage:FindFirstChild("AdminAbuse")
	if folder and folder:IsA("Folder") then
		return folder
	end

	local created = Instance.new("Folder")
	created.Name = "AdminAbuse"
	created.Parent = ServerStorage
	return created
end

function AdminService:_getAdminUtils(): Folder?
	local folder = Workspace:FindFirstChild("AdminUtils")
	if folder and folder:IsA("Folder") then
		return folder
	end
	return nil
end

function AdminService:_getBarrier(): Model?
	if self._barrier then
		return self._barrier
	end

	local utils = self:_getAdminUtils()
	local barrier = utils and utils:FindFirstChild("Barrier")
	if barrier and barrier:IsA("Model") then
		self._barrier = barrier
	end
	return self._barrier
end

-- El Reward es un rig (Humanoid + Motor6D) con un Part "HitBox" dedicado: la
-- detección va contra ESE part, no contra el modelo entero, para no dispararse con
-- cada mesh del cuerpo.
function AdminService:_getRewardHitBox(): BasePart?
	if self._rewardHitBox then
		return self._rewardHitBox
	end

	local utils = self:_getAdminUtils()
	local reward = utils and utils:FindFirstChild("Reward")
	local hitBox = reward and reward:FindFirstChild("HitBox")
	if hitBox and hitBox:IsA("BasePart") then
		self._rewardHitBox = hitBox
	end
	return self._rewardHitBox
end

function AdminService:_grantRewardMount(player: Player): ()
	local dataService = self._dataService
	if not dataService or not dataService:hasProfile(player) then return end

	-- Ya la tiene: no se re-concede ni se repite la notificación (el Touched dispara
	-- muchas veces mientras estás encima del HitBox).
	if dataService:get(player, { "Mounts", REWARD_MOUNT_NAME }) == true then return end

	dataService:set(player, { "Mounts", REWARD_MOUNT_NAME }, true)

	local image = ""
	for _, mount in MountsConfig.Premium do
		if mount.Name == REWARD_MOUNT_NAME then
			image = mount.Image
			break
		end
	end

	AlertsModule.ShowAlert(player, "ItemNotification", REWARD_MOUNT_NAME, REWARD_RARITY, image, REWARD_SUBTITLE)
end

-- El Touched se conecta UNA vez al arrancar y queda vivo siempre; lo que abre y
-- cierra el reward es el flag _rewardActive. Así no hay que reconectar/desconectar
-- señales cada vez que un admin lo activa.
function AdminService:_setupRewardTouch(): ()
	local hitBox = self:_getRewardHitBox()
	if not hitBox then
		warn("[Admin] No se encontró Workspace.AdminUtils.Reward.HitBox")
		return
	end

	hitBox.Touched:Connect(function(hit: BasePart)
		if not self._rewardActive then return end

		local player = getPlayerFromTouch(hit)
		if not player then return end

		self:_grantRewardMount(player)
	end)
end

-- Aplica el estado LOCALMENTE (este server). openUntil es un os.time() absoluto:
-- abierto = barrier fuera + reward concediendo; cerrado = barrier en su sitio y
-- reward inerte. Un openUntil ya pasado cuenta como cerrado, que es lo que hace que
-- un server recién arrancado descarte solo un estado caducado del DataStore.
function AdminService:_applyRewardState(openUntil: number): ()
	self._rewardCloseToken += 1
	local myToken = self._rewardCloseToken

	local remaining = openUntil - os.time()
	local active = remaining > 0

	self._rewardActive = active

	local barrier = self:_getBarrier()
	if not barrier then
		warn("[Admin] No se encontró Workspace.AdminUtils.Barrier")
		return
	end

	if active then
		barrier.Parent = self:_getStorageFolder()

		-- Auto-cierre local al llegar la hora. Cada server lo programa por su cuenta
		-- contra el MISMO instante absoluto, así no hace falta que nadie publique el
		-- cierre: todos lo hacen a la vez.
		task.delay(remaining, function()
			if myToken ~= self._rewardCloseToken then return end
			self:_applyRewardState(0)
		end)
	else
		local utils = self:_getAdminUtils()
		if utils then
			barrier.Parent = utils
		end
	end
end

function AdminService:_publishRewardState(openUntil: number): ()
	local ok, err = pcall(function()
		MessagingService:PublishAsync(ADMIN_REWARD_TOPIC, {
			u = openUntil,
			j = game.JobId,
		})
	end)
	if not ok then
		warn("[Admin] PublishAsync (reward) falló: " .. tostring(err))
	end
end

-- Persiste el instante de cierre para los servers que todavía no existen. No hace
-- falta limpiar la clave al cerrar: un openUntil pasado ya se lee como cerrado.
function AdminService:_persistRewardState(openUntil: number): ()
	local store = self._rewardStore
	if not store then return end

	local ok, err = pcall(function()
		store:SetAsync(REWARD_STORE_KEY, openUntil)
	end)
	if not ok then
		warn("[Admin] SetAsync (reward) falló: " .. tostring(err))
	end
end

-- Levanta el estado guardado al arrancar el server. Es lo que hace que un server
-- creado a mitad del evento aparezca ya con el obby abierto.
function AdminService:_restoreRewardState(): ()
	local storeOk, store = pcall(function()
		return DataStoreService:GetDataStore(REWARD_STORE_NAME)
	end)
	if not storeOk then
		warn("[Admin] GetDataStore (reward) falló: " .. tostring(store))
		return
	end
	self._rewardStore = store

	local ok, saved = pcall(function()
		return store:GetAsync(REWARD_STORE_KEY)
	end)
	if not ok then
		warn("[Admin] GetAsync (reward) falló: " .. tostring(saved))
		return
	end

	-- Si un admin ya abrió o cerró el reward en ESTE server mientras se resolvía el
	-- GetAsync, no lo pisamos con el valor del store.
	if self._rewardCloseToken > 0 then return end

	if type(saved) == "number" then
		self:_applyRewardState(saved)
	end
end

-- Aplica el estado LOCALMENTE (este server): guarda el cache y lo manda a todos
-- los clientes ya conectados acá. expiresAt ya pasado cuenta como inactivo, que es
-- lo que hace que un server recién arrancado descarte solo un anuncio caducado.
function AdminService:_applyAdminAbuseState(active: boolean, message: string, endTime: number, expiresAt: number): ()
	self._adminAbuseCloseToken += 1
	local myToken = self._adminAbuseCloseToken

	local remaining = expiresAt - os.time()
	if active and remaining <= 0 then
		active = false
	end

	if not active then
		self._adminAbuse = { active = false, message = "", endTime = 0, expiresAt = 0 }
		Packets.AdminAbuseState:Fire(false, "", 0)
		return
	end

	self._adminAbuse = { active = true, message = message, endTime = endTime, expiresAt = expiresAt }
	Packets.AdminAbuseState:Fire(true, message, endTime)

	-- Auto-limpieza local al llegar el tope. Cada server la programa por su cuenta
	-- contra el MISMO instante absoluto, así todos dejan de anunciarlo a la vez.
	task.delay(remaining, function()
		if myToken ~= self._adminAbuseCloseToken then return end
		self:_applyAdminAbuseState(false, "", 0, 0)
	end)
end

-- Publica a los demás servers vía MessagingService. j = JobId para que el server
-- emisor ignore su propio eco (ya aplicó el estado localmente).
function AdminService:_publishAdminAbuse(active: boolean, message: string, endTime: number, expiresAt: number): ()
	local ok, err = pcall(function()
		MessagingService:PublishAsync(ADMIN_ABUSE_TOPIC, {
			a = active,
			m = message,
			e = endTime,
			x = expiresAt,
			j = game.JobId,
		})
	end)
	if not ok then
		warn("[Admin] PublishAsync (admin abuse) falló: " .. tostring(err))
	end
end

function AdminService:_persistAdminAbuse(active: boolean, message: string, endTime: number, expiresAt: number): ()
	local store = self._adminAbuseStore
	if not store then return end

	local ok, err = pcall(function()
		store:SetAsync(ADMIN_ABUSE_STORE_KEY, {
			a = active,
			m = message,
			e = endTime,
			x = expiresAt,
		})
	end)
	if not ok then
		warn("[Admin] SetAsync (admin abuse) falló: " .. tostring(err))
	end
end

-- Levanta el anuncio guardado al arrancar: un server creado a mitad de la cuenta
-- regresiva aparece ya con el banner y el tiempo restante correcto.
function AdminService:_restoreAdminAbuse(): ()
	local storeOk, store = pcall(function()
		return DataStoreService:GetDataStore(ADMIN_ABUSE_STORE_NAME)
	end)
	if not storeOk then
		warn("[Admin] GetDataStore (admin abuse) falló: " .. tostring(store))
		return
	end
	self._adminAbuseStore = store

	local ok, saved = pcall(function()
		return store:GetAsync(ADMIN_ABUSE_STORE_KEY)
	end)
	if not ok then
		warn("[Admin] GetAsync (admin abuse) falló: " .. tostring(saved))
		return
	end

	-- Si un admin ya lanzó o canceló algo en ESTE server mientras se resolvía el
	-- GetAsync, no lo pisamos con el valor del store.
	if self._adminAbuseCloseToken > 0 then return end
	if type(saved) ~= "table" then return end
	if saved.a ~= true then return end

	self:_applyAdminAbuseState(
		true,
		tostring(saved.m or ""),
		tonumber(saved.e) or 0,
		tonumber(saved.x) or 0
	)
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

-- Sube el Level N niveles de golpe.
--
-- NO toca SpeedCurrency: el sobrante que llevara encima sigue siendo suyo y, si da
-- para otro nivel, lo resuelve `SpeedService:_addSpeed` en el siguiente paquete de
-- movimiento (igual que los regalos de Speed crudo del Daily o el StarterPack).
--
-- Aplica el WalkSpeed a mano porque el level-up normal lo hace SpeedService y aquí
-- el nivel cambia por fuera de él. Se usa `SpeedConfig.getWalkSpeedForLevel`, que
-- resuelve la curva del mundo de este place. Los leaderstats se ponen al día solos
-- (los relee del perfil cada 2 s).
--
-- A propósito no llama a `FunnelService:onProgressChanged`: esto es data de prueba
-- y no debería aparecer en los embudos de progresión.
function AdminService:_giveLevels(target: Player, amount: number): ()
	local ds = self._dataService
	if not ds or not ds:hasProfile(target) then return end

	local current  = (ds:get(target, { "Level" }) or 1) :: number
	local newLevel = math.clamp(current + amount, 1, MAX_LEVEL)
	if newLevel == current then return end

	ds:set(target, { "Level" }, newLevel)

	local humanoid = getHumanoid(target)
	if humanoid then
		humanoid.WalkSpeed = SpeedConfig.getWalkSpeedForLevel(newLevel)
	end
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
