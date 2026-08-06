--!strict

-- Puerta de entrada a un mundo que no es el de inicio.
--
-- Sin portal, el place de World 2 es accesible por deep-link / URL, y el salto de
-- balance en la frontera es de ×341 (stage 14 de World 1 = 2.200 Wins → stage 2
-- de World 2 = 750.000). Como `WinCurrency` es un único valor de perfil
-- compartido entre places, una cuenta nueva que entrase directa se compraría la
-- cadena entera de monturas de World 1 (1.14M) con dos pulsaciones.
--
-- LA CONDICIÓN SON LOS STEPS, NO EL NIVEL. Un rebirth hecho estando en World 2
-- resetea `Level` a 1, así que un gate por nivel expulsaría precisamente al
-- jugador legítimo que acaba de rebirthear. Los steps son compra única y
-- sobreviven al rebirth: son la señal fiable de "este jugador ya pasó por ahí".
--
-- Generaliza a World 3 sin tocar código: basta con World3.RequiresWorld = "World2".

local Players         = game:GetService("Players")
local RunService      = game:GetService("RunService")
local TeleportService = game:GetService("TeleportService")
local Workspace       = game:GetService("Workspace")

local EconomyConfig = require(game.ReplicatedStorage.Shared.EconomyConfig)
local WorldsConfig  = require(game.ReplicatedStorage.Shared.WorldsConfig)
local Packets       = require(game.ReplicatedStorage.Shared.Packets)

-- Anti-spam del botón del menú. Un teleport tarda en llegar y el jugador sigue
-- pudiendo pulsar mientras tanto.
local TELEPORT_COOLDOWN = 3

-- Cada cuánto puede un jugador volver a activar la parte de teleport. El Touched
-- dispara decenas de veces mientras estás encima (mismo motivo que el HitBox del
-- reward de Admin Abuse), así que sin esto un jugador sin la cadena completa
-- generaría un aluvión de paquetes de error.
local TOUCH_DEBOUNCE = 2

-- Nombres aceptados para la carpeta y la part del portal, en orden de preferencia.
-- Son dos porque el .rbxl de World 1 lo tiene como `Workspace.Portal.Portal` y no
-- como `Teleport`. Se aceptan ambos en vez de imponer uno: renombrar en Studio no
-- vuelve al repo (Rojo va en una sola dirección), así que un nombre único obligaría
-- a tocar el place a mano y el fallo sería mudo hasta que alguien lo pisara.
local PORTAL_NAMES = { "Portal", "Teleport" }

local function findByNames(parent: Instance): Instance?
	for _, name in PORTAL_NAMES do
		local found = parent:FindFirstChild(name)
		if found then return found end
	end
	return nil
end

type DataServiceServer = {
	waitForData: (self: DataServiceServer, player: Player) -> any,
	hasProfile:  (self: DataServiceServer, player: Player) -> boolean,
	get:         (self: DataServiceServer, player: Player, path: { string }) -> any,
	set:         (self: DataServiceServer, player: Player, path: { string }, value: any) -> any,
}

local WorldsService = {
	_dataService = nil :: DataServiceServer?,
	-- player -> os.clock() del último teleport aceptado (anti-spam del botón).
	_lastTeleport = {} :: { [Player]: number },
	-- player -> os.clock() del último toque atendido en la parte de teleport.
	_lastTouch = {} :: { [Player]: number },
}

-- El mundo al que lleva la parte de teleport de ESTE place: el que declara que
-- requiere el actual. Se deriva del config en vez de escribir "World2" a pelo,
-- así que la misma parte copiada al .rbxl de World 2 llevaría a World 3 el día
-- que exista, sin tocar código.
--
-- nil = este es el último mundo (hoy World 2): la parte no tiene destino.
local function nextWorldKey(): string?
	local currentKey = WorldsConfig.currentKey()
	for _, key in WorldsConfig.Order do
		local world = WorldsConfig.Worlds[key]
		if world and world.RequiresWorld == currentKey then
			return key
		end
	end
	return nil
end

-- Primer increment de `worldKey` que al jugador le falta por comprar, o nil si
-- tiene la cadena completa.
local function firstMissingStep(
	dataService: DataServiceServer,
	player: Player,
	worldKey: string
): number?
	local econ = EconomyConfig.forWorld(worldKey)
	for _, entry in econ.Steps do
		if dataService:get(player, { "StepUnlocked_" .. tostring(entry.Increment) }) ~= true then
			return entry.Increment
		end
	end
	return nil
end

-- Teleport con UN reintento: TeleportService falla de vez en cuando por
-- saturación. Devuelve si se llegó a lanzar; el jugador tarda en irse, así que un
-- `true` significa "aceptado", no "ya está allí".
local function tryTeleport(player: Player, placeId: number): boolean
	local ok = pcall(function()
		TeleportService:Teleport(placeId, player)
	end)
	if ok then return true end

	task.wait(2)
	if not player:IsDescendantOf(Players) then return true end

	return (pcall(function()
		TeleportService:Teleport(placeId, player)
	end))
end

function WorldsService:_enforce(player: Player): ()
	local world = WorldsConfig.current()
	local requiredKey = world.RequiresWorld
	-- Mundo de entrada: no hay nada que exigir.
	if not requiredKey then return end

	local required = WorldsConfig.get(requiredKey)
	if not required then
		warn(`[Worlds] {world.Name} exige "{requiredKey}", que no existe en WorldsConfig`)
		return
	end

	local dataService = self._dataService
	if not dataService then return end

	dataService:waitForData(player)
	if not player:IsDescendantOf(Players) then return end
	if not dataService:hasProfile(player) then return end

	local missing = firstMissingStep(dataService, player, requiredKey)
	if not missing then return end

	-- En Studio no se teleporta: no funciona entre places y dejaría el playtest
	-- inservible. Se avisa y se deja jugar.
	if RunService:IsStudio() then
		warn(
			`[Worlds] {player.Name} no tiene el step x{missing} de {required.Name}. `
				.. `En un servidor real se le mandaría a {required.Name}; en Studio se le deja pasar.`
		)
		return
	end

	print(`[Worlds] {player.Name} entra a {world.Name} sin el step x{missing} — devolviéndolo a {required.Name}`)

	if tryTeleport(player, required.PlaceId) then return end

	-- Sin teleport no se le puede dejar aquí: se llevaría los Wins de este mundo.
	player:Kick(`Finish {required.Name} first!`)
end

-- ── Menú Teleport ────────────────────────────────────────────────────────────

-- Por qué NO puede viajar a `worldKey`, o nil si puede. El mensaje va en inglés
-- porque lo pinta tal cual el alert del cliente.
--
-- Comprueba las DOS puertas y en este orden. El flag de desbloqueo es la del
-- menú; la cadena de steps es la que aplica `_enforce` AL LLEGAR, así que sin
-- este segundo check un flag a true con la cadena incompleta solo conseguiría un
-- viaje de ida y vuelta con un Kick al final.
function WorldsService:_denyReason(player: Player, worldKey: string): string?
	local dataService = self._dataService
	if not dataService then return "Try again in a moment!" end
	if not dataService:hasProfile(player) then return "Try again in a moment!" end

	local target = WorldsConfig.get(worldKey)
	if not target then return "That world doesn't exist!" end

	if WorldsConfig.needsUnlock(worldKey) then
		if dataService:get(player, { WorldsConfig.unlockKey(worldKey) }) ~= true then
			return `You haven't unlocked {target.Name} yet!`
		end
	end

	local requiredKey = target.RequiresWorld
	if requiredKey then
		local required = WorldsConfig.get(requiredKey)
		if required and firstMissingStep(dataService, player, requiredKey) then
			return `Finish {required.Name} first!`
		end
	end

	return nil
end

function WorldsService:_handleTeleportRequest(player: Player, worldKey: string): ()
	local target = WorldsConfig.get(worldKey)
	-- Pedir el mundo en el que ya estás no es un error: el cliente ni siquiera
	-- manda el paquete, así que llegar aquí es un cliente modificado. Se ignora en
	-- silencio, que es lo mismo que ve el jugador legítimo.
	if not target or worldKey == WorldsConfig.currentKey() then return end

	local now  = os.clock()
	local last = self._lastTeleport[player]
	if last and now - last < TELEPORT_COOLDOWN then return end

	local reason = self:_denyReason(player, worldKey)
	if reason then
		Packets.WorldTeleportFailed:FireClient(player, reason)
		return
	end

	-- En Studio no se teleporta (no funciona entre places), igual que `_enforce`.
	-- Se avisa por consola y no se cobra el cooldown.
	if RunService:IsStudio() then
		warn(`[Worlds] {player.Name} viajaría a {target.Name}, pero en Studio no se teleporta entre places.`)
		Packets.WorldTeleportFailed:FireClient(player, `Teleports don't work in Studio ({target.Name}).`)
		return
	end

	self._lastTeleport[player] = now
	print(`[Worlds] {player.Name} viaja a {target.Name}`)

	if tryTeleport(player, target.PlaceId) then return end

	-- Falló hasta el reintento: se queda donde estaba, que es un estado válido.
	-- Se libera el cooldown para que pueda volver a intentarlo enseguida.
	self._lastTeleport[player] = nil
	if player:IsDescendantOf(Players) then
		Packets.WorldTeleportFailed:FireClient(player, "Teleport failed, try again!")
	end
end

-- ── Parte de teleport (Workspace.Teleport.Teleport) ──────────────────────────
--
-- Es la forma de DESBLOQUEAR el siguiente mundo, y hoy la única: pisarla con la
-- cadena de steps de este mundo completa pone `WorldUnlocked_<Key>` a true y te
-- manda allí. A partir de entonces el menú Teleport ya deja viajar.
--
-- La condición son los steps de ESTE mundo, que es exactamente lo que
-- `_enforce` va a exigir al llegar al otro lado: quien pasa por aquí nunca puede
-- rebotar.

function WorldsService:_handleTeleportTouch(player: Player): ()
	print(`[Worlds] {player.Name} pisó la parte de teleport`)

	local dataService = self._dataService
	if not dataService then
		warn("[Worlds] Toque ignorado: WorldsService no tiene DataService")
		return
	end
	if not dataService:hasProfile(player) then
		warn(`[Worlds] Toque ignorado: el perfil de {player.Name} todavía no está cargado`)
		return
	end

	local targetKey = nextWorldKey()
	if not targetKey then
		warn(`[Worlds] Toque ignorado: {WorldsConfig.current().Name} es el último mundo, no hay destino`)
		return
	end

	local target = WorldsConfig.get(targetKey)
	if not target then return end

	local currentKey = WorldsConfig.currentKey()
	local current    = WorldsConfig.current()

	local missing = firstMissingStep(dataService, player, currentKey)
	if missing then
		print(`[Worlds] {player.Name} no puede pasar: le falta el step x{missing} de {current.Name}`)
		Packets.WorldTeleportFailed:FireClient(
			player,
			`Buy all of {current.Name}'s Steps first!`
		)
		return
	end

	print(`[Worlds] {player.Name} tiene la cadena de {current.Name} completa — abriendo {target.Name}`)

	-- Idempotente: se pisa muchas veces y el desbloqueo es permanente.
	if dataService:get(player, { WorldsConfig.unlockKey(targetKey) }) ~= true then
		dataService:set(player, { WorldsConfig.unlockKey(targetKey) }, true)
		print(`[Worlds] {player.Name} desbloquea {target.Name}`)
	end

	-- Se reaprovecha el camino del menú a propósito: cooldown, aviso de Studio,
	-- reintento y mensaje de fallo son los mismos. Su `_denyReason` vuelve a
	-- comprobar el flag que acabamos de escribir y la cadena de steps que ya
	-- hemos validado, así que aquí siempre pasa.
	self:_handleTeleportRequest(player, targetKey)
end

function WorldsService:_setupTeleportPart(): ()
	local folder = findByNames(Workspace)
	if not folder then
		-- Antes esto era un `return` mudo y era imposible saber desde el juego si el
		-- feature estaba apagado o roto. La carpeta vive en el mundo de ORIGEN, así
		-- que su ausencia es normal en el último mundo, pero nunca en World 1.
		warn(
			`[Worlds] No hay Workspace.Portal (ni Workspace.Teleport) en {WorldsConfig.current().Name} `
				.. "— el portal no existe en este place"
		)
		return
	end

	local teleport = findByNames(folder)
	if not teleport then
		warn(`[Worlds] {folder:GetFullName()} existe pero no contiene ningún Portal/Teleport dentro`)
		return
	end

	-- Vale una BasePart suelta o un Model (entonces cuentan todas sus partes),
	-- mismo criterio que Lava e Ice.
	local parts: { BasePart } = {}
	if teleport:IsA("BasePart") then
		table.insert(parts, teleport)
	else
		for _, descendant in teleport:GetDescendants() do
			if descendant:IsA("BasePart") then
				table.insert(parts, descendant)
			end
		end
	end

	if #parts == 0 then
		warn(`[Worlds] {teleport:GetFullName()} no tiene ninguna BasePart que pueda tocarse`)
		return
	end

	local targetKey = nextWorldKey()
	local target    = targetKey and WorldsConfig.get(targetKey)
	if not target then
		-- El último mundo no tiene a dónde mandar a nadie. No es un error: es la
		-- misma parte copiada en el .rbxl de los dos places.
		warn(`[Worlds] Hay una parte de teleport en {WorldsConfig.current().Name}, que es el último mundo — no hace nada`)
		return
	end

	print(`[Worlds] Parte de teleport lista: {#parts} part(s) en {teleport:GetFullName()} -> lleva a {target.Name}`)

	-- Se conecta UNA vez al arrancar y el filtrado va dentro, igual que el HitBox
	-- del reward de Admin Abuse: nada de conectar y desconectar señales.
	for _, part in parts do
		part.Touched:Connect(function(hit: BasePart)
			local character = hit:FindFirstAncestorOfClass("Model")
			if not character then return end

			local player = Players:GetPlayerFromCharacter(character)
			if not player then return end

			local now  = os.clock()
			local last = self._lastTouch[player]
			if last and now - last < TOUCH_DEBOUNCE then return end
			self._lastTouch[player] = now

			task.spawn(function()
				self:_handleTeleportTouch(player)
			end)
		end)
	end
end

function WorldsService:init(dataService: DataServiceServer): ()
	self._dataService = dataService

	-- El menú Teleport se atiende en TODOS los mundos, y va ANTES del return de
	-- abajo: World 1 no tiene RequiresWorld (no hay nada que vigilar al entrar)
	-- pero es justo el mundo desde el que más se viaja.
	Packets.RequestWorldTeleport.OnServerEvent:Connect(function(player: Player, worldKey: string)
		if typeof(worldKey) ~= "string" then return end
		task.spawn(function()
			self:_handleTeleportRequest(player, worldKey)
		end)
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		self._lastTeleport[player] = nil
		self._lastTouch[player]    = nil
	end)

	-- También fuera del `if` de abajo: la parte vive en el mundo de ORIGEN, que es
	-- justo el que no tiene RequiresWorld.
	self:_setupTeleportPart()

	local world = WorldsConfig.current()
	if not world.RequiresWorld then
		-- Nada que vigilar en el mundo de entrada; ni se conecta la señal.
		return
	end

	local function setupPlayer(player: Player)
		task.spawn(function()
			self:_enforce(player)
		end)
	end

	Players.PlayerAdded:Connect(setupPlayer)
	for _, player in Players:GetPlayers() do
		setupPlayer(player)
	end
end

return WorldsService
