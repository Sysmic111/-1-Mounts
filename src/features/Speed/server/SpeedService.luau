--!strict

local Players = game:GetService("Players")
local RunService = game:GetService("RunService")

local SpeedConfig = require(game.ReplicatedStorage.Shared.SpeedConfig)
local Packets = require(game.ReplicatedStorage.Shared.Packets)

type DataServiceServer = {
	waitForData: (self: DataServiceServer, player: Player) -> any,
	hasProfile: (self: DataServiceServer, player: Player) -> boolean,
	get: (self: DataServiceServer, player: Player, path: any?) -> any,
	set: (self: DataServiceServer, player: Player, path: any, value: any, dontReplicate: boolean?) -> (),
}

type PlayerState = {
	lastPosition: Vector3?,
	distanceRemainder: number,
	heartbeatTime: number,
}

local SpeedService = {
	_dataService = nil :: DataServiceServer?,
	_playerStates = {} :: { [Player]: PlayerState },
	_connections = {} :: { [Player]: { RBXScriptConnection } },
}

local function debugPrint(message: string)
	if SpeedConfig.Debug then
		print("[Speed] " .. message)
	end
end

local function getRootPart(character: Model): BasePart?
	return character:FindFirstChild("HumanoidRootPart") :: BasePart?
end

local function getHumanoid(character: Model): Humanoid?
	return character:FindFirstChildOfClass("Humanoid")
end

function SpeedService:init(dataService: DataServiceServer): ()
	self._dataService = dataService
	debugPrint("SpeedService iniciado")

	Players.PlayerAdded:Connect(function(player)
		debugPrint(`PlayerAdded detectado: {player.Name}`)
		self:_setupPlayer(player)
	end)

	Players.PlayerRemoving:Connect(function(player)
		debugPrint(`PlayerRemoving detectado: {player.Name}`)
		self:_cleanupPlayer(player)
	end)

	for _, player in ipairs(Players:GetPlayers()) do
		task.spawn(function()
			self:_setupPlayer(player)
		end)
	end

	RunService.Heartbeat:Connect(function(deltaTime)
		self:_onHeartbeat(deltaTime)
	end)
end

function SpeedService:_setupPlayer(player: Player): ()
	local dataService = self._dataService
	if not dataService then
		debugPrint(`No hay DataService disponible para {player.Name}`)
		return
	end

	debugPrint(`Esperando data de {player.Name}`)
	dataService:waitForData(player)
	if not player:IsDescendantOf(Players) then
		debugPrint(`Data cargada, pero {player.Name} ya no esta en Players`)
		return
	end

	self._playerStates[player] = {
		lastPosition = nil,
		distanceRemainder = 0,
		heartbeatTime = 0,
	}

	local connections: { RBXScriptConnection } = {}
	self._connections[player] = connections

	debugPrint(`Player configurado: {player.Name}`)

	table.insert(connections, player.CharacterAdded:Connect(function(character)
		debugPrint(`CharacterAdded detectado para {player.Name}`)
		self:_setupCharacter(player, character)
	end))

	if player.Character then
		self:_setupCharacter(player, player.Character)
	end
end

function SpeedService:_setupCharacter(player: Player, character: Model): ()
	local dataService = self._dataService
	local state = self._playerStates[player]
	if not dataService or not state or not dataService:hasProfile(player) then
		debugPrint(`No se pudo configurar character de {player.Name}: data/profile/state no disponible`)
		return
	end

	local humanoid = getHumanoid(character)
	if humanoid then
		local level = dataService:get(player, { "Level" }) or 1
		humanoid.WalkSpeed = SpeedConfig.getWalkSpeedForLevel(level)
		debugPrint(`WalkSpeed aplicado a {player.Name}: nivel={level}, walkspeed={humanoid.WalkSpeed}`)
	else
		debugPrint(`No se encontro Humanoid para {player.Name}`)
	end

	local rootPart = getRootPart(character)
	state.lastPosition = if rootPart then rootPart.Position else nil
	state.distanceRemainder = 0
	state.heartbeatTime = 0

	if rootPart then
		debugPrint(`Tracking de movimiento iniciado para {player.Name}`)
	else
		debugPrint(`No se encontro HumanoidRootPart para {player.Name}`)
	end
end

function SpeedService:_onHeartbeat(deltaTime: number): ()
	for player, state in pairs(self._playerStates) do
		state.heartbeatTime += deltaTime
		if state.heartbeatTime < SpeedConfig.MovementCheckInterval then
			continue
		end

		local elapsed = state.heartbeatTime
		state.heartbeatTime = 0
		self:_trackPlayerMovement(player, state, elapsed)
	end
end

function SpeedService:_trackPlayerMovement(player: Player, state: PlayerState, elapsed: number): ()
	local dataService = self._dataService
	local character = player.Character
	if not dataService or not character or not dataService:hasProfile(player) then
		debugPrint(`Movimiento omitido para {player.Name}: data/profile/character no disponible`)
		return
	end

	local humanoid = getHumanoid(character)
	local rootPart = getRootPart(character)
	if not humanoid or not rootPart or humanoid.Health <= 0 then
		debugPrint(`Movimiento pausado para {player.Name}: HumanoidRootPart/Humanoid no disponible o sin vida`)
		state.lastPosition = nil
		return
	end

	local currentPosition = rootPart.Position
	local lastPosition = state.lastPosition
	state.lastPosition = currentPosition

	if not lastPosition then
		return
	end

	local movedDistance = (currentPosition - lastPosition).Magnitude
	local maxAllowedDistance = math.max(
		SpeedConfig.TeleportDistanceBuffer,
		humanoid.WalkSpeed * elapsed * SpeedConfig.TeleportSpeedMultiplier
	)

	if movedDistance > maxAllowedDistance then
		debugPrint(
			`Movimiento ignorado por posible teleport: {player.Name}, distancia={math.floor(movedDistance * 100) / 100}, max={math.floor(maxAllowedDistance * 100) / 100}`
		)
		state.distanceRemainder = 0
		return
	end

	state.distanceRemainder += movedDistance

	local speedToAdd = math.floor(state.distanceRemainder / SpeedConfig.StudsPerSpeed)
	if speedToAdd <= 0 then
		return
	end

	state.distanceRemainder -= speedToAdd * SpeedConfig.StudsPerSpeed
	debugPrint(
		`Speed ganado: {player.Name}, +{speedToAdd}, distancia={math.floor(movedDistance * 100) / 100}, remainder={math.floor(state.distanceRemainder * 100) / 100}`
	)
	self:_addSpeed(player, speedToAdd)
end

function SpeedService:_addSpeed(player: Player, amount: number): ()
	local dataService = self._dataService
	if not dataService or not dataService:hasProfile(player) then
		debugPrint(`No se pudo sumar Speed a {player.Name}: profile no disponible`)
		return
	end

	Packets.SpeedGained:FireClient(player, amount)

	local speedCurrency = dataService:get(player, { "SpeedCurrency" }) or 0
	local level = dataService:get(player, { "Level" }) or 1
	local previousLevel = level

	speedCurrency += amount
	debugPrint(`SpeedCurrency actualizado para {player.Name}: speed={speedCurrency}, nivel={level}`)

	local requiredSpeed = SpeedConfig.getRequiredSpeedForLevel(level)
	while speedCurrency >= requiredSpeed do
		debugPrint(`Level up listo para {player.Name}: nivel={level} -> {level + 1}, requisito={requiredSpeed}`)
		speedCurrency -= requiredSpeed
		level += 1
		requiredSpeed = SpeedConfig.getRequiredSpeedForLevel(level)
	end

	dataService:set(player, { "SpeedCurrency" }, speedCurrency)
	if level ~= previousLevel then
		dataService:set(player, { "Level" }, level)
		debugPrint(`Nuevo nivel guardado para {player.Name}: nivel={level}, speedRestante={speedCurrency}`)
		self:_applyWalkSpeed(player, level)
	end
end

function SpeedService:_applyWalkSpeed(player: Player, level: number): ()
	local character = player.Character
	if not character then
		debugPrint(`No se pudo aplicar WalkSpeed a {player.Name}: character no disponible`)
		return
	end

	local humanoid = getHumanoid(character)
	if humanoid then
		humanoid.WalkSpeed = SpeedConfig.getWalkSpeedForLevel(level)
		debugPrint(`WalkSpeed actualizado para {player.Name}: nivel={level}, walkspeed={humanoid.WalkSpeed}`)
	else
		debugPrint(`No se pudo aplicar WalkSpeed a {player.Name}: Humanoid no encontrado`)
	end
end

function SpeedService:_cleanupPlayer(player: Player): ()
	local connections = self._connections[player]
	if connections then
		for _, connection in ipairs(connections) do
			connection:Disconnect()
		end
	end

	self._connections[player] = nil
	self._playerStates[player] = nil
	debugPrint(`Player limpiado: {player.Name}`)
end

return SpeedService
