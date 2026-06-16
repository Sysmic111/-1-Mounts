--!strict

local CollectionService = game:GetService("CollectionService")
local Players = game:GetService("Players")
local Workspace = game:GetService("Workspace")

local WinsConfig = require(script.Parent.WinsConfig)

type DataServiceServer = {
	hasProfile: (self: DataServiceServer, player: Player) -> boolean,
	get: (self: DataServiceServer, player: Player, path: any?) -> any,
	set: (self: DataServiceServer, player: Player, path: any, value: any, dontReplicate: boolean?) -> (),
}

type WinZoneState = {
	connections: { RBXScriptConnection },
	debounceByPlayer: { [Player]: boolean },
}

local WinsService = {
	_dataService = nil :: DataServiceServer?,
	_winZoneStates = {} :: { [Instance]: WinZoneState },
}

local function debugPrint(message: string)
	if WinsConfig.Debug then
		print("[Wins] " .. message)
	end
end

local function getPlayerFromTouchedPart(part: BasePart): Player?
	local character = part:FindFirstAncestorOfClass("Model")
	if not character then
		return nil
	end

	local humanoid = character:FindFirstChildOfClass("Humanoid")
	if not humanoid then
		return nil
	end

	return Players:GetPlayerFromCharacter(character)
end

local function getTouchPart(winZone: Instance): BasePart?
	local touchPart = winZone:FindFirstChild(WinsConfig.TouchPartName, true)
	if touchPart and touchPart:IsA("BasePart") then
		return touchPart
	end

	return nil
end

local function getSpawnLocation(): SpawnLocation?
	return Workspace:FindFirstChildWhichIsA("SpawnLocation", true)
end

function WinsService:init(dataService: DataServiceServer): ()
	self._dataService = dataService
	debugPrint("WinsService iniciado")

	for _, winZone in ipairs(CollectionService:GetTagged(WinsConfig.TagName)) do
		self:_setupWinZone(winZone)
	end

	CollectionService:GetInstanceAddedSignal(WinsConfig.TagName):Connect(function(winZone)
		debugPrint(`Tag agregado: {winZone:GetFullName()}`)
		self:_setupWinZone(winZone)
	end)

	CollectionService:GetInstanceRemovedSignal(WinsConfig.TagName):Connect(function(winZone)
		debugPrint(`Tag removido: {winZone:GetFullName()}`)
		self:_cleanupWinZone(winZone)
	end)
end

function WinsService:_setupWinZone(winZone: Instance): ()
	if self._winZoneStates[winZone] then
		return
	end

	local touchPart = getTouchPart(winZone)
	if not touchPart then
		debugPrint(`Zona ignorada sin TouchPart: {winZone:GetFullName()}`)
		return
	end

	local winsQuantity = winZone:GetAttribute(WinsConfig.WinsQuantityAttribute)
	if typeof(winsQuantity) ~= "number" then
		debugPrint(`Zona ignorada sin atributo WinsQuantity numerico: {winZone:GetFullName()}`)
		return
	end

	local state: WinZoneState = {
		connections = {},
		debounceByPlayer = {},
	}

	self._winZoneStates[winZone] = state

	table.insert(state.connections, touchPart.Touched:Connect(function(touchedPart)
		self:_onTouchPartTouched(winZone, touchedPart)
	end))

	debugPrint(`Zona Wins configurada: {winZone:GetFullName()}, wins={winsQuantity}`)
end

function WinsService:_onTouchPartTouched(winZone: Instance, touchedPart: BasePart): ()
	local state = self._winZoneStates[winZone]
	if not state then
		return
	end

	local player = getPlayerFromTouchedPart(touchedPart)
	if not player or state.debounceByPlayer[player] then
		return
	end

	state.debounceByPlayer[player] = true
	task.delay(WinsConfig.TouchDebounceSeconds, function()
		state.debounceByPlayer[player] = nil
	end)

	self:_giveWins(player, winZone)
	self:_teleportToSpawn(player)
end

function WinsService:_giveWins(player: Player, winZone: Instance): ()
	local dataService = self._dataService
	if not dataService or not dataService:hasProfile(player) then
		debugPrint(`No se pudo dar Wins a {player.Name}: profile no disponible`)
		return
	end

	local winsQuantity = winZone:GetAttribute(WinsConfig.WinsQuantityAttribute)
	if typeof(winsQuantity) ~= "number" then
		debugPrint(`No se pudo dar Wins a {player.Name}: WinsQuantity invalido`)
		return
	end

	local currentWins = dataService:get(player, { "WinCurrency" }) or 0
	local newWins = currentWins + winsQuantity
	dataService:set(player, { "WinCurrency" }, newWins)

	debugPrint(`Wins entregados: {player.Name}, +{winsQuantity}, total={newWins}`)
end

function WinsService:_teleportToSpawn(player: Player): ()
	local character = player.Character
	if not character then
		debugPrint(`No se pudo teleportar a {player.Name}: character no disponible`)
		return
	end

	local spawnLocation = getSpawnLocation()
	if not spawnLocation then
		debugPrint(`No se pudo teleportar a {player.Name}: no hay SpawnLocation en Workspace`)
		return
	end

	character:PivotTo(spawnLocation.CFrame + WinsConfig.SpawnTeleportOffset)
	debugPrint(`Jugador teleportado al spawn: {player.Name}`)
end

function WinsService:_cleanupWinZone(winZone: Instance): ()
	local state = self._winZoneStates[winZone]
	if not state then
		return
	end

	for _, connection in ipairs(state.connections) do
		connection:Disconnect()
	end

	self._winZoneStates[winZone] = nil
	debugPrint(`Zona Wins limpiada: {winZone:GetFullName()}`)
end

return WinsService
