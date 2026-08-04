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

local EconomyConfig = require(game.ReplicatedStorage.Shared.EconomyConfig)
local WorldsConfig  = require(game.ReplicatedStorage.Shared.WorldsConfig)

type DataServiceServer = {
	waitForData: (self: DataServiceServer, player: Player) -> any,
	hasProfile:  (self: DataServiceServer, player: Player) -> boolean,
	get:         (self: DataServiceServer, player: Player, path: { string }) -> any,
}

local WorldsService = {
	_dataService = nil :: DataServiceServer?,
}

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

	local ok = pcall(function()
		TeleportService:Teleport(required.PlaceId, player)
	end)
	if ok then return end

	-- Un reintento: TeleportService falla de vez en cuando por saturación.
	task.wait(2)
	if not player:IsDescendantOf(Players) then return end

	local retryOk = pcall(function()
		TeleportService:Teleport(required.PlaceId, player)
	end)
	if retryOk then return end

	-- Sin teleport no se le puede dejar aquí: se llevaría los Wins de este mundo.
	player:Kick(`Finish {required.Name} first!`)
end

function WorldsService:init(dataService: DataServiceServer): ()
	self._dataService = dataService

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
