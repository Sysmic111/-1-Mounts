--!strict

-- Carreras 1v1 contra el NPC de un stage. AUTORITATIVO EN EL SERVIDOR: el NPC, la
-- cuenta atrás y la detección de meta viven aquí. El cliente solo pinta el menú, los
-- números y el resultado que le llega por packet.
--
-- Geometría que espera dentro de un `Workspace.Stages.Stage N` (hoy solo el Stage 2,
-- pero cualquier stage que la reciba entra solo, sin tocar código):
--   Npc                → rig del NPC con el ProximityPrompt
--   Race.Player        → marcador de salida del jugador
--   Race.Npc           → marcador de salida del NPC
--   Race.Goal          → meta
-- (Race tiene además seis hijos llamados "Baseplate" — el suelo y las paredes de la
--  pista. Solo se buscan los tres de arriba, que sí son únicos.)
--
-- Una pista solo admite un corredor a la vez: el NPC es un objeto físico compartido,
-- no una copia por jugador. Los demás ven la carrera.

local Players           = game:GetService("Players")
local RunService        = game:GetService("RunService")
local ServerScriptService = game:GetService("ServerScriptService")
local Workspace         = game:GetService("Workspace")

local RaceConfig    = require(game.ReplicatedStorage.Shared.RaceConfig)
local EconomyConfig = require(game.ReplicatedStorage.Shared.EconomyConfig)
local SpeedConfig   = require(game.ReplicatedStorage.Shared.SpeedConfig)
local Packets       = require(game.ReplicatedStorage.Shared.Packets)
local MorphService  = require(ServerScriptService.Mounts.MorphService)

local FREEZE_REFRESH = 0.2 -- cada cuánto se re-clampea el WalkSpeed durante el freeze

type DataServiceServer = {
	hasProfile: (self: DataServiceServer, player: Player) -> boolean,
	get: (self: DataServiceServer, player: Player, path: any?) -> any,
	set: (self: DataServiceServer, player: Player, path: any, value: any, dontReplicate: boolean?) -> (),
}

type WinsServiceLike = {
	awardWins: (self: any, player: Player, amount: number) -> (),
	teleportToSpawn: (self: any, player: Player) -> (),
}

-- Pista registrada al arrancar (una por stage con geometría de carrera).
type Track = {
	stage: number,
	npcModel: Model,
	playerMarker: BasePart,
	npcMarker: BasePart,
	goal: BasePart,
	-- Eje horizontal salida → meta. Todo el progreso se mide proyectando sobre él, así
	-- que la pista puede estar orientada de cualquier forma (la del Stage 2 va en +Z).
	axis: Vector3,
	goalPlane: number, -- proyección de la meta sobre el eje
}

-- Carrera en curso.
type ActiveRace = {
	player: Player,
	track: Track,
	racer: Model?,
	freezing: boolean,
	savedJumpPower: number?,
	savedJumpHeight: number?,
	heartbeat: RBXScriptConnection?,
	startedAt: number,
	over: boolean,
}

local RaceService = {
	_dataService = nil :: DataServiceServer?,
	_winsService = nil :: WinsServiceLike?,
	_tracks = {} :: { [number]: Track },
	_active = {} :: { [Player]: ActiveRace },
	_busy = {} :: { [number]: Player },       -- pista ocupada por stage
	_cooldown = {} :: { [Player]: { [number]: number } },
}

-- Mismo criterio que StagesService/EconomyService: el stage se saca del nombre.
local function getStageNumber(stageName: string): number
	return tonumber(stageName:match("%d+")) or 0
end

local function getHumanoid(player: Player): Humanoid?
	local character = player.Character
	if not character then return nil end
	return character:FindFirstChildOfClass("Humanoid")
end

local function isAlive(player: Player): boolean
	local humanoid = getHumanoid(player)
	return humanoid ~= nil and humanoid.Health > 0
end

-- Progreso a lo largo de la pista. Se cruza la meta cuando alcanza goalPlane
-- (menos la tolerancia de GoalRadius, porque el HumanoidRootPart nunca llega justo).
local function progressOf(track: Track, position: Vector3): number
	return position:Dot(track.axis)
end

local function hasFinished(track: Track, position: Vector3): boolean
	return progressOf(track, position) >= (track.goalPlane - RaceConfig.GoalRadius)
end

-- Registra un stage si tiene la geometría completa. Devuelve nil si le falta algo.
local function buildTrack(stage: Model, stageNumber: number): Track?
	local npcModel = stage:FindFirstChild(RaceConfig.NpcModelName)
	local raceModel = stage:FindFirstChild(RaceConfig.RaceModelName)
	if not npcModel or not npcModel:IsA("Model") then return nil end
	if not raceModel or not raceModel:IsA("Model") then return nil end

	local playerMarker = raceModel:FindFirstChild(RaceConfig.PlayerMarkerName) :: BasePart?
	local npcMarker    = raceModel:FindFirstChild(RaceConfig.NpcMarkerName)    :: BasePart?
	local goal         = raceModel:FindFirstChild(RaceConfig.GoalName)         :: BasePart?

	if not (playerMarker and playerMarker:IsA("BasePart")) then
		warn(`[Race] {stage.Name}: falta la parte "{RaceConfig.PlayerMarkerName}" dentro de Race`)
		return nil
	end
	if not (npcMarker and npcMarker:IsA("BasePart")) then
		warn(`[Race] {stage.Name}: falta la parte "{RaceConfig.NpcMarkerName}" dentro de Race`)
		return nil
	end
	if not (goal and goal:IsA("BasePart")) then
		warn(`[Race] {stage.Name}: falta la parte "{RaceConfig.GoalName}" dentro de Race`)
		return nil
	end

	local flat = (goal.Position - playerMarker.Position) * Vector3.new(1, 0, 1)
	if flat.Magnitude < 1 then
		warn(`[Race] {stage.Name}: la meta y la salida están en el mismo sitio`)
		return nil
	end
	local axis = flat.Unit

	return {
		stage        = stageNumber,
		npcModel     = npcModel,
		playerMarker = playerMarker,
		npcMarker    = npcMarker,
		goal         = goal,
		axis         = axis,
		goalPlane    = goal.Position:Dot(axis),
	}
end

function RaceService:init(dataService: DataServiceServer, winsService: WinsServiceLike): ()
	self._dataService = dataService
	self._winsService = winsService

	local stagesFolder = Workspace:FindFirstChild("Stages")
	if not stagesFolder then
		warn("[Race] No se encontró Workspace.Stages")
		return
	end

	for _, child in stagesFolder:GetChildren() do
		if not child:IsA("Model") then continue end
		local stageNumber = getStageNumber(child.Name)
		if stageNumber == 0 then continue end

		local track = buildTrack(child, stageNumber)
		if track then
			self._tracks[stageNumber] = track
			self:_setupTrack(track)
		end
	end

	Packets.RaceAccept.OnServerEvent:Connect(function(player: Player, stage: number)
		if typeof(stage) ~= "number" then return end
		self:_handleAccept(player, math.floor(stage))
	end)

	Players.PlayerRemoving:Connect(function(player: Player)
		local race = self._active[player]
		if race then
			self:_abort(race)
		end
		self._cooldown[player] = nil
	end)
end

function RaceService:_setupTrack(track: Track): ()
	local cfg = RaceConfig.get(track.stage)

	-- El NPC de escaparate no debe deambular ni caerse: se queda quieto en su sitio.
	for _, d in track.npcModel:GetDescendants() do
		if d:IsA("BasePart") then
			(d :: BasePart).Anchored = true
		end
	end

	local prompt = track.npcModel:FindFirstChildWhichIsA("ProximityPrompt", true) :: ProximityPrompt?
	if not prompt then
		warn(`[Race] Stage {track.stage}: el Npc no tiene ProximityPrompt`)
		return
	end

	-- En el .rbxl el prompt cuelga directamente del Model, y así Roblox no lo renderiza
	-- ni lo dispara nunca. Se reparenta en runtime al HumanoidRootPart (el place no se
	-- toca: todo el código del proyecto se edita aquí, no en Studio).
	if not (prompt.Parent :: Instance):IsA("BasePart") and not (prompt.Parent :: Instance):IsA("Attachment") then
		local hrp = track.npcModel:FindFirstChild("HumanoidRootPart") :: BasePart?
		if not hrp then
			warn(`[Race] Stage {track.stage}: el Npc no tiene HumanoidRootPart donde poner el prompt`)
			return
		end
		prompt.Parent = hrp
	end

	prompt.ObjectText = cfg.NpcName

	prompt.Triggered:Connect(function(player: Player)
		if not self:_canRace(player, track.stage) then return end
		Packets.RaceOpen:FireClient(player, track.stage, cfg.NpcName)
	end)
end

-- Todas las condiciones para poder correr. Se comprueba tanto al activar el prompt
-- como al recibir el RaceAccept: el cliente puede mandar el packet a mano sin haber
-- pasado por el prompt, así que la segunda comprobación no es redundante.
function RaceService:_canRace(player: Player, stage: number): boolean
	local track = self._tracks[stage]
	if not track then return false end
	if self._busy[stage] then return false end
	if self._active[player] then return false end

	local dataService = self._dataService
	if not dataService or not dataService:hasProfile(player) then return false end
	if not isAlive(player) then return false end

	if RaceConfig.CooldownSeconds > 0 then
		local byStage = self._cooldown[player]
		local last = byStage and byStage[stage]
		if last and (os.clock() - last) < RaceConfig.CooldownSeconds then
			return false
		end
	end

	return true
end

function RaceService:_handleAccept(player: Player, stage: number): ()
	if not self:_canRace(player, stage) then return end
	local track = self._tracks[stage]
	if not track then return end

	local race: ActiveRace = {
		player    = player,
		track     = track,
		racer     = nil,
		freezing  = false,
		heartbeat = nil,
		startedAt = os.clock(),
		over      = false,
	}

	self._active[player] = race
	self._busy[stage] = player
	player:SetAttribute("Racing", true)

	task.spawn(function()
		self:_run(race)
	end)
end

-- Coloca a los dos corredores, congela al jugador, lanza la cuenta atrás y arranca
-- la carrera. Corre en su propia corrutina porque la cuenta atrás usa task.wait.
function RaceService:_run(race: ActiveRace): ()
	local player = race.player
	local track  = race.track
	local cfg    = RaceConfig.get(track.stage)

	local character = player.Character
	if not character then
		self:_abort(race)
		return
	end

	-- Salida del jugador. El character puede ser el modelo de la montura (atributo
	-- IsMountCharacter), así que se mueve con PivotTo sobre el modelo entero, no
	-- asumiendo un rig R15.
	local playerStart = track.playerMarker.Position + Vector3.new(0, RaceConfig.SpawnHeight, 0)
	character:PivotTo(CFrame.lookAt(playerStart, playerStart + track.axis))

	self:_freeze(race)

	-- El NPC corredor: el rig de escaparate del stage, montado sobre la montura del
	-- stage. Mismo rigging que el morph del jugador (Seat + RigidConstraint), pero sin
	-- IsMountCharacter, así que DeathEffectService y el cliente de Mounts lo ignoran.
	local npcStart = track.npcMarker.Position + Vector3.new(0, RaceConfig.SpawnHeight, 0)
	local racer = MorphService.BuildMountRig(
		cfg.Mount,
		track.npcModel,
		CFrame.lookAt(npcStart, npcStart + track.axis)
	)
	if not racer then
		warn(`[Race] Stage {track.stage}: no se pudo construir el NPC con la montura {cfg.Mount}`)
		self:_abort(race)
		return
	end

	racer.Name = RaceConfig.RacerName
	race.racer = racer

	-- Un paso de física antes de anclar: el SeatWeld que acaba de crear el Sit coloca
	-- al NPC sobre la montura en el siguiente Heartbeat. Anclando en el mismo frame se
	-- quedaría flotando al lado en vez de encima.
	RunService.Heartbeat:Wait()
	if race.over then return end

	-- Anclado: se mueve por PivotTo autoritativo, no por física. Sin anclar, la física
	-- del server pelea con el PivotTo (mismo motivo que en RingEnemyService).
	for _, d in racer:GetDescendants() do
		if d:IsA("BasePart") then
			(d :: BasePart).Anchored = true
		end
	end

	-- Cuenta atrás. El último paso ("Start!") da la salida.
	for index, text in RaceConfig.CountdownSteps do
		if race.over then return end
		if not isAlive(player) or not player:IsDescendantOf(Players) then
			self:_abort(race)
			return
		end

		Packets.RaceCountdown:FireClient(player, text)

		if index < #RaceConfig.CountdownSteps then
			task.wait(RaceConfig.CountdownStep)
		end
	end

	if race.over then return end

	self:_unfreeze(race)
	race.startedAt = os.clock()

	race.heartbeat = RunService.Heartbeat:Connect(function(dt: number)
		self:_step(race, dt)
	end)
end

function RaceService:_step(race: ActiveRace, dt: number): ()
	if race.over then return end

	local player = race.player
	local track  = race.track
	local racer  = race.racer

	-- Abandono: muerte, desconexión o character perdido. Sin premio.
	if not player:IsDescendantOf(Players) or not isAlive(player) or not racer or not racer.Parent then
		self:_abort(race)
		return
	end

	-- Corte de seguridad: nadie llega a meta (jugador atascado, NPC bloqueado). Se
	-- cierra como derrota para no dejar la pista ocupada el resto de la partida.
	if (os.clock() - race.startedAt) > RaceConfig.MaxRaceSeconds then
		self:_finish(race, false)
		return
	end

	-- El jugador primero: si los dos cruzan en el mismo frame, gana él.
	-- El character se re-resuelve cada frame a propósito: un evolve a mitad de carrera
	-- lo sustituye por otro modelo (MorphService reasigna player.Character).
	local character = player.Character
	local hrp = if character then character:FindFirstChild("HumanoidRootPart") :: BasePart? else nil
	if hrp and hasFinished(track, hrp.Position) then
		self:_finish(race, true)
		return
	end

	-- Traslación pura sobre el pivot actual: `CFrame + Vector3` no toca la rotación, que
	-- ya viene mirando al eje desde BuildMountRig. Se mueve por el pivot (así no importa
	-- dónde lo tenga el modelo de cada montura, no hay deriva) pero la meta se mide con
	-- el HumanoidRootPart, que es el cuerpo real del corredor.
	local cfg = RaceConfig.get(track.stage)
	racer:PivotTo(racer:GetPivot() + track.axis * cfg.NpcSpeed * dt)

	local racerHRP = racer:FindFirstChild("HumanoidRootPart") :: BasePart?
	if racerHRP and hasFinished(track, racerHRP.Position) then
		self:_finish(race, false)
	end
end

-- WalkSpeed = 0 no basta: SpeedService lo reaplica en cada level-up y en cada morph.
-- Se re-clampea en bucle mientras dure el freeze (mismo truco que la ventana de
-- slow-down de AdminService).
function RaceService:_freeze(race: ActiveRace): ()
	local humanoid = getHumanoid(race.player)
	if not humanoid then return end

	race.savedJumpPower  = humanoid.JumpPower
	race.savedJumpHeight = humanoid.JumpHeight
	race.freezing = true

	task.spawn(function()
		while race.freezing and not race.over do
			local h = getHumanoid(race.player)
			if h then
				h.WalkSpeed  = 0
				h.JumpPower  = 0
				h.JumpHeight = 0
			end
			task.wait(FREEZE_REFRESH)
		end
	end)
end

function RaceService:_unfreeze(race: ActiveRace): ()
	race.freezing = false

	local humanoid = getHumanoid(race.player)
	if not humanoid then return end

	local dataService = self._dataService
	local level = 1
	if dataService and dataService:hasProfile(race.player) then
		level = (dataService:get(race.player, { "Level" }) or 1) :: number
	end

	humanoid.WalkSpeed  = SpeedConfig.getWalkSpeedForLevel(level)
	humanoid.JumpPower  = race.savedJumpPower or humanoid.JumpPower
	humanoid.JumpHeight = race.savedJumpHeight or humanoid.JumpHeight
end

-- Fin normal: paga y devuelve al spawn. Ganar = el doble de los Wins del stage,
-- perder = la mitad. Pasa por WinsService:awardWins para heredar el multiplicador de
-- rebirth y el WeatherWinsBoost, igual que un botón de Wins normal.
function RaceService:_finish(race: ActiveRace, won: boolean): ()
	if race.over then return end

	local player = race.player
	local winsService = self._winsService

	local base   = EconomyConfig.StageWins[race.track.stage] or 0
	local factor = if won then RaceConfig.WinFactor else RaceConfig.LoseFactor
	local earned = math.max(1, math.round(base * factor))

	self:_cleanup(race)

	if winsService and player:IsDescendantOf(Players) then
		winsService:awardWins(player, earned)
		Packets.RaceResult:FireClient(player, won, earned)
		winsService:teleportToSpawn(player)
	end
end

-- Fin anormal (muerte, desconexión, geometría rota): libera todo sin pagar nada.
function RaceService:_abort(race: ActiveRace): ()
	if race.over then return end
	self:_cleanup(race)
end

-- Único sitio que suelta los recursos de una carrera. Lo llaman _finish y _abort, así
-- que ningún camino puede dejar la pista ocupada o el NPC colgado en Workspace.
function RaceService:_cleanup(race: ActiveRace): ()
	race.over = true
	race.freezing = false

	if race.heartbeat then
		race.heartbeat:Disconnect()
		race.heartbeat = nil
	end

	if race.racer then
		race.racer:Destroy()
		race.racer = nil
	end

	self:_unfreeze(race)

	local player = race.player
	player:SetAttribute("Racing", nil)

	self._active[player] = nil
	if self._busy[race.track.stage] == player then
		self._busy[race.track.stage] = nil
	end

	if RaceConfig.CooldownSeconds > 0 then
		local byStage = self._cooldown[player]
		if not byStage then
			byStage = {}
			self._cooldown[player] = byStage
		end
		byStage[race.track.stage] = os.clock()
	end
end

return RaceService
